extends TestCase
## Real settings actions must not retire a live world when its save cannot be written.

const ROOT := "user://tests/save-exit-guard"
const UNAVAILABLE := ROOT + "-unavailable"


func run() -> void:
	var old_path := GameState.slot_path(1)
	var old_slot := GameState.active_slot
	_cleanup()
	DirAccess.make_dir_recursive_absolute(ROOT)
	GameState.select_slot(1)
	GameState.save_path = ROOT + "/slot.json"
	for cave: bool in [false, true]:
		for restart: bool in [false, true]:
			await _check_exit(cave, restart)
	await _check_victory_exit()
	await _check_ordinary_close()
	_cleanup()
	GameState.save_path = old_path
	GameState.select_slot(old_slot)


func _check_exit(cave: bool, restart: bool) -> void:
	var game: Node = await make_game("mage")
	game.set_process(false)
	game.player.set_process(false)
	if cave:
		game.player.position = SpatialCombat3D.teleport_actor(game, game.player, game.dungeon.entry_point(), Player.RADIUS)
		if not check("cave exit fixture enters through the actual runtime", game.dungeon.enter()):
			game.queue_free()
			await _frames(2)
			return
		await _frames(2)
	GameState.gold += 17
	GameState.boss_defeated = true
	GameState.boss_heart_pending = true
	check("exit fixture saves the pending reward before storage failure", GameState.save_game())
	var before_inventory := GameState.inventory.size()
	var path := GameState.save_path
	var hidden_path := UNAVAILABLE.path_join(path.get_file())
	var before_bytes := FileAccess.get_file_as_bytes(path)
	var source_world: Node = game.world
	var source_position: Vector2 = game.player.position
	var previous_location := GameState.location_mode
	var previous_return := GameState.return_to_cave_entrance
	var exits: Array[String] = []
	game.quit_requested.connect(func(): exits.append("title"))
	game.restart_requested.connect(func(): exits.append("selection"))
	var save_events: Array[bool] = []
	var on_save: Callable = func(success: bool, _message: String): save_events.append(success)
	GameState.save_finished.connect(on_save)
	game.hud.open_settings()
	var panel: SettingsPanel = game.hud._panel
	var label := ("cave" if cave else "forest") + (" selection" if restart else " title")
	if not check(label + " hides the actual save parent to force an IO error", DirAccess.rename_absolute(ROOT, UNAVAILABLE) == OK):
		GameState.save_finished.disconnect(on_save)
		get_tree().paused = false
		game.queue_free()
		await _frames(2)
		return
	_press_exit(panel, restart)
	check(label + " failed write keeps the same settings panel and pause", game.hud._panel == panel and not panel.is_queued_for_deletion() and get_tree().paused)
	check(label + " failed write emits no menu transition", exits.is_empty() and not game._menu_exit_committed)
	check(label + " failed write preserves cave scope, position and checkpoint metadata", game.dungeon.active == cave and game.world == source_world and game.player.position.is_equal_approx(source_position) and GameState.location_mode == previous_location and GameState.return_to_cave_entrance == previous_return)
	check(label + " attempts one checked write, including the pending heart", save_events == [false] and GameState.inventory.size() == before_inventory + 1 and not GameState.boss_heart_pending)
	check(label + " leaves the existing recoverable save unchanged", FileAccess.get_file_as_bytes(hidden_path) == before_bytes)
	var feedback := panel.body.find_child("SaveFeedback", true, false) as Label
	check(label + " shows the save error inside settings with error styling", feedback != null and feedback.is_visible_in_tree() and feedback.text == GameState.save_error and panel._feedback_error)
	check(label + " restores the original storage parent for a real retry", DirAccess.rename_absolute(UNAVAILABLE, ROOT) == OK)
	_press_exit(panel, restart)
	check(label + " retry emits the requested transition once after saving", exits == (["selection"] if restart else ["title"]) and save_events == [false, true] and game._menu_exit_committed)
	check(label + " only successful save releases the panel and cave", game.hud._panel == null and not get_tree().paused and not game.dungeon.active)
	var saved := SaveStore._read_one(path)
	check(label + " persists the reward exactly once and the existing forest exit checkpoint", saved.get("gold") == GameState.gold and saved.get("inventory", []).size() == before_inventory + 1 and not bool(saved.get("boss_heart_pending", true)) and saved.get("location_mode") == "forest")
	check(label + " duplicate exit calls neither save nor emit again", not game.quit_to_title() and save_events == [false, true] and exits.size() == 1)
	GameState.save_finished.disconnect(on_save)
	game.queue_free()
	await _frames(2)


func _check_victory_exit() -> void:
	var game: Node = await make_game("warrior")
	game.set_process(false)
	game.player.set_process(false)
	GameState.boss_defeated = true
	GameState.boss_heart_pending = true
	check("victory fixture saves its real pending completion reward", GameState.save_game())
	var before_inventory := GameState.inventory.size()
	var path := GameState.save_path
	var before_bytes := FileAccess.get_file_as_bytes(path)
	var position: Vector2 = game.player.position
	var exits: Array[String] = []
	game.restart_requested.connect(func(): exits.append("selection"))
	game.quit_requested.connect(func(): exits.append("title"))
	var saves: Array[bool] = []
	var on_save: Callable = func(success: bool, _message: String): saves.append(success)
	GameState.save_finished.connect(on_save)
	game.hud.open_victory()
	var panel: VictoryPanel = game.hud._panel
	if not check("victory fixture forces the actual same save IO error", DirAccess.rename_absolute(ROOT, UNAVAILABLE) == OK):
		GameState.save_finished.disconnect(on_save)
		get_tree().paused = false
		game.queue_free()
		await _frames(2)
		return
	var button := _button_named(panel, "다른 직업으로 새 모험")
	if check("the actual victory restart button exists", button != null):
		button.pressed.emit()
	check("failed victory exit keeps the same paused achievement panel and live position", game.hud._panel == panel and not panel.is_queued_for_deletion() and get_tree().paused and game.player.position.is_equal_approx(position))
	check("failed victory exit neither navigates nor duplicates the completion reward", exits.is_empty() and saves == [false] and GameState.inventory.size() == before_inventory + 1 and not GameState.boss_heart_pending and not game._menu_exit_committed)
	check("failed victory exit leaves the recoverable pending-reward save untouched", FileAccess.get_file_as_bytes(UNAVAILABLE.path_join(path.get_file())) == before_bytes)
	var feedback := panel.body.find_child("SaveFeedback", true, false) as Label
	check("victory failure explains the save error inside the same panel", feedback != null and feedback.is_visible_in_tree() and feedback.text == GameState.save_error)
	check("victory fixture restores storage for an actual successful retry", DirAccess.rename_absolute(UNAVAILABLE, ROOT) == OK)
	if button != null:
		button.pressed.emit()
	check("successful victory retry saves once then navigates once", exits == ["selection"] and saves == [false, true] and game.hud._panel == null and not get_tree().paused)
	var saved := SaveStore._read_one(path)
	check("victory retry persists its completion and only one heart reward", bool(saved.get("boss_defeated", false)) and not bool(saved.get("boss_heart_pending", true)) and saved.get("inventory", []).size() == before_inventory + 1)
	check("victory duplicate transition is ignored without another write", not game.return_to_selection() and exits == ["selection"] and saves == [false, true])
	GameState.save_finished.disconnect(on_save)
	game.queue_free()
	await _frames(2)


func _check_ordinary_close() -> void:
	var game: Node = await make_game("warrior")
	game.set_process(false)
	GameState.boss_defeated = true
	GameState.boss_heart_pending = true
	var before := GameState.inventory.size()
	var saves: Array[bool] = []
	var on_save: Callable = func(success: bool, _message: String): saves.append(success)
	GameState.save_finished.connect(on_save)
	game.hud.open_settings()
	game.hud.close_panel()
	check("ordinary panel close still applies and persists pending rewards with one write", saves == [true] and GameState.inventory.size() == before + 1 and not GameState.boss_heart_pending and not get_tree().paused)
	var saved := SaveStore._read_one(GameState.save_path)
	check("ordinary close persists the claimed reward", saved.get("inventory", []).size() == before + 1 and not bool(saved.get("boss_heart_pending", true)))
	GameState.save_finished.disconnect(on_save)
	game.queue_free()
	await _frames(2)


func _press_exit(panel: SettingsPanel, restart: bool) -> void:
	var button := _button_named(panel, "새 모험 준비" if restart else "저장하고 타이틀로")
	if not check("real settings exit action exists", button != null):
		return
	button.pressed.emit()
	if restart:
		button = _button_named(panel, "저장하고 슬롯 선택으로")
		if check("real slot-selection confirmation exists", button != null):
			button.pressed.emit()


func _button_named(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for child in node.get_children():
		var found := _button_named(child, text)
		if found != null:
			return found
	return null


func _cleanup() -> void:
	for directory: String in [ROOT, UNAVAILABLE]:
		if not DirAccess.dir_exists_absolute(directory):
			continue
		for name in DirAccess.get_files_at(directory):
			DirAccess.remove_absolute(directory.path_join(name))
		DirAccess.remove_absolute(directory)

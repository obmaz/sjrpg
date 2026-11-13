extends TestCase
## 세 메뉴의 실제 신호·닫힘·저장 실패 경로를 확인한다.


class EntryRoot:
	extends "res://scripts/app/main.gd"
	var launches := 0

	func _ready() -> void:
		pass

	func start_game() -> void:
		launches += 1
		_swap(Node.new())


func run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	add_child(view)
	var root := EntryRoot.new()
	view.add_child(root)
	root.show_title()
	await _frames(2)
	for dimensions: Vector2i in [Vector2i(720, 1280), Vector2i(1280, 720)]:
		view.size = dimensions
		await _frames(2)
		var buttons: Array[Button] = [
			root.current._btn_new_game, root.current._btn_load_game, root.current._btn_settings
		]
		var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
		for index in buttons.size():
			check(
				"title menu stays inside the viewport",
				bounds.encloses(buttons[index].get_global_rect())
			)
			check("title menu keeps a usable touch height", buttons[index].size.y >= 64.0)
			if index > 0:
				check(
					"title menus do not overlap",
					not buttons[index - 1].get_global_rect().intersects(
						buttons[index].get_global_rect()
					)
				)
	root.current._btn_load_game.pressed.emit()
	await _frames(2)
	var menus := _panels(root)
	if check(
		"load button opens the real load panel", menus.size() == 1 and menus[0] is SaveLoadPanel
	):
		root.handle_system_back()
		await _frames(2)
		check("cancelling title load removes its modal", _panels(root).is_empty())
	root.current._btn_settings.pressed.emit()
	await _frames(2)
	menus = _panels(root)
	if check(
		"settings button opens the real settings panel",
		menus.size() == 1 and menus[0] is SettingsPanel
	):
		var settings: SettingsPanel = menus[0]
		settings._open_save_load_dialog()
		await _frames(2)
		var nested := _panels(settings)
		if check("settings opens its nested load menu", nested.size() == 1):
			root.handle_system_back()
			await _frames(2)
			check(
				"nested cancel retains settings and removes only load",
				is_instance_valid(settings) and _panels(settings).is_empty()
			)
		settings.closed.emit()
		await _frames(2)
		check("cancelling title settings removes its modal", _panels(root).is_empty())
	GameState.select_slot(1)
	GameState.delete_save()
	check("title load fixture creates a fresh saved adventure", GameState.new_game("mage"))
	GameState.gold = 137
	check("title load fixture saves its actual progress", GameState.save_game())
	GameState.gold = 1
	root.current._btn_load_game.pressed.emit()
	await _frames(2)
	var load_menu: SaveLoadPanel = _panels(root)[0]
	var select: Button = load_menu._slot_cards[0].get_node("SelectSaveSlot1")
	select.pressed.emit()
	await _frames(2)
	check("selecting a real saved row enables load", not load_menu._load_button.disabled)
	load_menu._load_button.pressed.emit()
	for frame in 120:
		await _frames(1)
		if not root._entry_starting:
			break
	check(
		"title load reads the selected save before launching once",
		root.launches == 1 and GameState.hero_class == "mage" and GameState.gold == 137
	)
	check(
		"successful title load retires its modal and loading screen",
		_panels(root).is_empty() and not root._entry_starting
	)
	view.queue_free()
	await _frames(2)
	await _failed_save_keeps_settings()


func _panels(parent: Node) -> Array[PanelFrame]:
	var result: Array[PanelFrame] = []
	for child in parent.get_children():
		if child is PanelFrame and not child.is_queued_for_deletion():
			result.append(child)
	return result


func _failed_save_keeps_settings() -> void:
	var game := await make_game("mage")
	game.hud.open_settings()
	var settings: SettingsPanel = game.hud._panel
	settings._open_save_load_dialog()
	await _frames(2)
	var dialog: SaveLoadPanel = _panels(settings)[0]
	dialog.selected_slot = GameState.active_slot
	var original := GameState.save_path
	var slot := GameState.active_slot
	GameState.save_path = original + "/unavailable.json"
	dialog._on_load_pressed()
	await _frames(2)
	check(
		"failed save keeps the original live world and slot",
		not game._menu_exit_committed and GameState.active_slot == slot
	)
	check(
		"failed save retains settings and its visible error",
		game.hud._panel == settings and is_instance_valid(settings) and settings._feedback_error
	)
	GameState.save_path = original
	game.hud.close_panel(false)
	game.queue_free()
	await _frames(3)

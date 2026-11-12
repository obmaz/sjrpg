extends TestCase
## Actual Adventure3D and Main notifications: OS Back pauses without leaving or toggling away.


func _progress(game: Node) -> Dictionary:
	return {
		"slot": GameState.active_slot, "class": GameState.hero_class,
		"level": GameState.level, "xp": GameState.xp, "gold": GameState.gold,
		"potions": GameState.potions, "mana_potions": GameState.mana_potions,
		"quests": GameState.quests.duplicate(true), "ranks": GameState.ranks.duplicate(true),
		"slots": GameState.slots.duplicate(), "location": GameState.location_mode,
		"opened_chests": GameState.opened_chests.duplicate(),
		"position": game.player.position, "hp": game.player.hp,
		"resource": game.player.resource, "cooldowns": game.player.cooldowns.duplicate(true)
	}


func run() -> void:
	var old_path := GameState.slot_path(1)
	var old_slot := GameState.active_slot
	var old_go_back := get_tree().quit_on_go_back
	var old_scale := get_window().content_scale_size
	GameState.save_path = "user://tests/system-back.json"
	GameState.select_slot(1)
	GameState.delete_save()
	check("system-back fixture creates an isolated real save", GameState.new_game("mage"))
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	add_child(view)
	var root := preload("res://scripts/app/main.gd").new()
	view.add_child(root)
	await _frames(2)
	check("Main disables the engine's automatic Android Back exit", not get_tree().quit_on_go_back)
	var title: Node = root.current
	root.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	check("system Back on the title does not start or replace an adventure", root.current == title and not get_tree().paused)
	root.start_game()
	var adventure := root.current as Adventure3D
	var game: Node = adventure.simulation
	for frame in 300:
		if game.native_ready:
			break
		await get_tree().physics_frame
		await _frames(1)
	if check("system-back fixture boots the actual native world", game.native_ready):
		for enemy in game.enemies:
			enemy.queue_free()
		game.enemies.clear()
		game._spawn_timer = 10000.0
		await _frames(2)
		GameState.gold = 317
		GameState.xp = 13
		var primary: String = str(GameState.slots[0])
		game.player.cooldowns[primary] = 5.0
		var hud: Hud = game.hud
		var renderer: Node = game.world_renderer
		var before := _progress(game)
		var saved := FileAccess.get_file_as_string(GameState.save_path)
		root.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
		await _frames(3)
		var settings: PanelFrame = hud._panel
		check("actual OS Back opens settings and pauses the same world", settings is SettingsPanel and get_tree().paused and root.current == adventure and game.world_renderer == renderer)
		for press in 4:
			root.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
			root.handle_system_back()
			await _frames(1)
		check("repeated OS Back keeps the same settings open while paused", hud._panel == settings and get_tree().paused and root.current == adventure)
		check("opening and repeating system Back preserves live progress and save bytes", _progress(game) == before and FileAccess.get_file_as_string(GameState.save_path) == saved)

		hud.close_panel()
		hud.open_bag()
		await _frames(2)
		var bag: PanelFrame = hud._panel
		var bag_was_open := bag is BagPanel
		var bag_ref: WeakRef = weakref(bag)
		before = _progress(game)
		root.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
		await _frames(3)
		check("OS Back replaces an already paused bag with settings", bag_was_open and bag_ref.get_ref() == null and hud._panel is SettingsPanel and get_tree().paused)
		check("replacing another panel keeps the same character and adventure progress", _progress(game) == before and root.current == adventure and game.world_renderer == renderer)
		settings = hud._panel
		root._on_web_back([])
		await _frames(2)
		check("the retained web callback shares the idempotent system Back handler", hud._panel == settings and get_tree().paused and _progress(game) == before)
		hud.close_panel()
		root.show_class_select()
		await _frames(2)
		var selection: Node = root.current
		root.handle_system_back()
		check("class selection is outside the adventure Back interception", root.current == selection and not get_tree().paused)
	get_tree().paused = false
	view.queue_free()
	await _frames(3)
	GameState.delete_save()
	GameState.save_path = old_path
	GameState.select_slot(old_slot)
	get_tree().quit_on_go_back = old_go_back
	get_window().content_scale_size = old_scale

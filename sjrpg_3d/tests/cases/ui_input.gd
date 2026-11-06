extends TestCase

func run() -> void:
	var game := await make_game()
	var controls: TouchControls = game.hud.controls
	controls._layout()
	for name in controls._buttons:
		var button: Dictionary = controls._buttons[name]
		check("touch target at least 64 units: " + name, float(button["radius"]) * 2.0 >= 64.0)
	var empty: Dictionary = controls._buttons["slot4"]
	var socket_edge: Vector2 = empty["center"] + Vector2.RIGHT * (float(empty["radius"]) - 1.0)
	check("empty-slot touch test lies outside its smaller engraving", socket_edge.distance_to(empty["center"]) > controls.slot_visual_radius(4))
	controls._press(29, socket_edge)
	await _frames(2)
	check("empty-slot outer touch still opens the skill panel", game.hud.panel_open() and controls._held.is_empty())
	game.hud.close_panel()
	await _frames(2)
	controls._layout()
	controls._press(10, controls._stick_center)
	controls._drag(10, controls._stick_center + Vector2(50, 0))
	controls._press(11, controls._buttons["slot0"]["center"])
	check("move and attack can be held independently", game.player.move_input.x > 0.0 and game.player.held_slots.get(0, false))
	controls._release(10)
	check("releasing joystick keeps held attack", game.player.move_input == Vector2.ZERO and game.player.held_slots.get(0, false))
	controls._press(12, controls._buttons["slot0"]["center"])
	controls._release(11)
	check("one finger releasing a shared slot preserves the other hold", game.player.held_slots.get(0, false))
	controls._release(12)
	check("the last finger releases the shared slot", not game.player.held_slots.get(0, false))
	controls.hold_mouse_primary()
	controls._press(13, controls._buttons["slot0"]["center"])
	controls._release(-1)
	check("mouse release preserves a simultaneous touch on primary", game.player.held_slots.get(0, false))
	game.hud.open_map()
	await _frames(2)
	check("opening a panel releases combat touches", not game.player.held_slots.get(0, false) and controls._held.is_empty())
	game.hud.close_panel()
	# Replacing one panel in the same frame must retain the large font scale.
	game.hud.open_settings()
	game.hud.close_panel()
	game.hud.open_bag()
	await _frames(2)
	check("replacement panel retains mobile text size", is_equal_approx(UiKit.boost, PanelFrame.BOOST))
	game.hud.close_panel()
	await _frames(2)
	check("closing final panel restores HUD font scale", is_equal_approx(UiKit.boost, 1.0))
	# Two old fingers and new presses during the death screen cannot survive revival.
	controls._press(41, controls._buttons["slot0"]["center"])
	controls._press(42, controls._buttons["slot0"]["center"])
	game.player._invulnerable = 0.0
	game.player.take_damage(game.player.max_hp * 100.0)
	check("warrior death releases every pointer and slot entry", game.player.dead and controls._held.is_empty() and game.player.held_slots.is_empty())
	controls._press(43, controls._buttons["slot0"]["center"])
	controls._press(44, controls._stick_center)
	check("death screen cannot collect fresh combat or movement holds", controls._held.is_empty() and controls._stick_index == -2 and game.player.held_slots.is_empty())
	game.player.revive(game.player.position)
	for pointer in [41, 42, 43, 44]:
		controls._release(pointer)
	check("releasing pre-death fingers cannot restart a revived warrior", game.player.held_slots.is_empty() and game.player.move_input == Vector2.ZERO)
	game.queue_free()
	await _frames(2)
	GameState.gold = 321
	GameState.save_game()
	var root := preload("res://scripts/main.gd").new()
	add_child(root)
	root.show_class_select()
	var saved := FileAccess.get_file_as_bytes(GameState.save_path)
	root._choose_hero("mage")
	var confirmation: PanelFrame = null
	for child in root.get_children():
		if child is PanelFrame:
			confirmation = child
	check("an occupied slot refuses a new hero without a replacement flow", confirmation == null and root.current.get_script() == preload("res://scripts/class_select.gd"))
	check("refusing an occupied start preserves the save", FileAccess.get_file_as_bytes(GameState.save_path) == saved and GameState.load_game() and GameState.gold == 321 and GameState.hero_class == "warrior")
	var old := OldScene.new()
	root._swap(old)
	await get_tree().process_frame
	old.armed = true
	root._swap(Node.new())
	await get_tree().process_frame
	check("old scene cannot mutate progress after replacement", GameState.gold == 321)
	root.queue_free()
	await _frames(2)


class OldScene:
	extends Node
	var armed := false
	func _process(_delta: float) -> void:
		if armed:
			GameState.gold = 0

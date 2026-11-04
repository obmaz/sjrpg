extends TestCase

func run() -> void:
	var game := await make_game()
	var controls: TouchControls = game.hud.controls
	controls._layout()
	for name in controls._buttons:
		var button: Dictionary = controls._buttons[name]
		check("touch target at least 64 units: " + name, float(button["radius"]) * 2.0 >= 64.0)
	controls._press(10, controls._stick_center)
	controls._drag(10, controls._stick_center + Vector2(50, 0))
	controls._press(11, controls._buttons["slot0"]["center"])
	check("move and attack can be held independently", game.player.move_input.x > 0.0 and game.player.held_slots.get(0, false))
	controls._release(10)
	check("releasing joystick keeps held attack", game.player.move_input == Vector2.ZERO and game.player.held_slots.get(0, false))
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
	game.queue_free()
	await _frames(2)
	GameState.gold = 321
	GameState.save_game()
	var root := preload("res://scripts/main.gd").new()
	add_child(root)
	root.show_class_select()
	root._choose_hero("mage")
	var confirmation: PanelFrame = null
	for child in root.get_children():
		if child is PanelFrame:
			confirmation = child
	check("existing adventure requires explicit replacement", confirmation != null)
	if confirmation != null:
		confirmation.closed.emit()
		await _frames(2)
	check("canceling new adventure preserves the save", GameState.load_game() and GameState.gold == 321 and GameState.hero_class == "warrior")
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

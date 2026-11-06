extends TestCase
## Larger warp actions retain clear input ownership and a visible first destination after rotation.


func run() -> void:
	GameState.delete_save()
	GameState.new_game("warrior")
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	add_child(view)
	var game := preload("res://scripts/game.gd").new()
	view.add_child(game)
	await _frames(3)
	for enemy in game.enemies:
		enemy.queue_free()
	game.enemies.clear()
	game._spawn_timer = 10000.0
	game.player.set_process(false)
	game.exploration.set_process(false)
	game.quest_runtime.set_process(false)
	if game.encounters != null:
		game.encounters.set_process(false)
	GameState.discovered_sanctuaries.assign(["town", "tree", "cave"])
	game.player.position = game.exploration.gate_approach("town")
	var controls: TouchControls = game.hud.controls
	for dimensions in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(540, 960), Vector2i(720, 1280)]:
		view.size = dimensions
		await _frames(4)
		controls._layout()
		check("physical gate keeps its warp action after rotation %s" % dimensions, controls._near_name == "워프게이트" and controls._buttons.has("near_shop"))
		if not controls._buttons.has("near_shop"):
			continue
		var target: Dictionary = controls._buttons["near_shop"]
		var half: Vector2 = target["half_size"]
		var touch := Rect2(target["center"] - half, half * 2.0)
		var visual := controls.interaction_visual_rect(target["center"], half)
		var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
		var u := controls._unit
		check("larger warp plaque fits its touch target and screen", bounds.encloses(touch) and touch.encloses(visual) and touch.size.x >= 64 and touch.size.y >= 64 and visual.size.x >= 180.0 * u and visual.size.y >= 54.0 * u)
		check("larger warp action owns the whole visible edge", controls._hit_button(Vector2(visual.end.x - 1, visual.get_center().y)) == "near_shop")
		for name in controls._buttons:
			if name == "near_shop":
				continue
			var other: Dictionary = controls._buttons[name]
			var radius: float = other["radius"]
			var rect := Rect2(other["center"] - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
			check("larger warp action avoids the menu and combat targets: " + name, not touch.intersects(rect))
		game.hud.interact("워프게이트")
		await _frames(5)
		var panel: WarpGatePanel = game.hud._panel
		var button: Button = panel.destination_buttons["tree"]
		check("destination action names the target and is larger", not button.disabled and button.size.y >= 96.0 and Exploration.NAMES["tree"] in button.text)
		check("first discovered destination stays visible on a short screen", panel.body_holder.get_global_rect().encloses(button.get_global_rect()))
		for id in Exploration.NAMES:
			var destination: Button = panel.destination_buttons[id]
			check("every warp destination remains a full touch target: " + id, destination.size.y >= 64.0 and destination.size.x >= 64.0)
		game.hud.close_panel()
		await _frames(2)
	view.queue_free()
	await _frames(2)

extends TestCase


func run() -> void:
	var old_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var game := await make_game()
	var fountain: IsoSprite = game.village.fountain
	check("fountain is a substantial plaza feature", fountain.texture.get_size().x > 0 and float(fountain.def["source"][2]) * fountain.k > 280.0)
	check("enlarged stone basin blocks walking through its base", game._blocked(fountain.position + Vector2(0, -70), Player.RADIUS))
	check("new journey keeps the plaza approach clear", not game._blocked(game.village.spawn_point, Player.RADIUS))
	check("three stage-one gate anchors are authoritative", game.village.portal_points.size() == 3)
	var animated: Array[PlazaWater] = []
	for child in game.world.get_children():
		for node in child.get_children():
			if node is PlazaWater:
				animated.append(node)
	check("fountain and all village gate copies animate", animated.size() == 5)
	var animation: PlazaWater = fountain.get_child(0)
	var original_material: Material = fountain.material
	var phase := animation.phase
	await _frames(3)
	check("water movement advances in game time", animation.phase > phase)
	game.hud.open_settings()
	phase = animation.phase
	await _frames(3)
	check("paused panels also pause the fountain", animation.phase == phase)
	game.hud.close_panel()
	WorldOcclusion.update(fountain.global_position - Vector2(0, 30), false)
	check("native hero stays visible while the animated source canvas remains hidden", game.ortho_preview.actor.is_visible_in_tree() and not fountain.is_visible_in_tree() and fountain.material == original_material)
	WorldOcclusion.update(Vector2(100000, 100000), false)
	check("leaving the occluder preserves its animated material", fountain.material == original_material)
	Prefs.reduce_motion = true
	await _frames(2)
	check("motion reduction freezes fluid phase", animation.phase == 0.0 and float(animation.water_material.get_shader_parameter("phase")) == 0.0)
	Prefs.reduce_motion = old_reduce
	game.queue_free()
	await _frames(2)

extends TestCase


func run() -> void:
	var game := await make_game()
	var lighting: ForestLighting = game.forest_lighting
	check("daylight has a fixed two-light budget", lighting.openings.size() == 2 and lighting.surfaces.size() > 5)
	var isolated := true
	for surface in lighting.surfaces:
		var ink := surface.material as ShaderMaterial
		isolated = isolated and ink != null and ink.shader == lighting.ground_material.shader
	check("ground lighting adds no canvas-wide light nodes", lighting.get_child_count() == 0)
	check("only textured ground receives forest daylight", isolated and game.player.material != lighting.ground_material and game.village.fountain.material != lighting.ground_material)
	check("lighting leaves ground projection unchanged", lighting.surfaces[0].get_parent().transform == Iso.ground_transform())
	var positions := lighting.openings.duplicate()
	game.camera.position += Vector2(75, 90)
	await _frames(2)
	check("light footprints stay in the world when the camera moves", lighting.openings == positions and lighting.ground_material.get_shader_parameter("opening_a") == positions[0] and lighting.ground_material.get_shader_parameter("opening_b") == positions[1])
	lighting.set_enabled(false)
	check("comparison mode disables light and ambient together", not lighting.enabled and is_zero_approx(float(lighting.ground_material.get_shader_parameter("amount"))))
	for ink in lighting.materials:
		check("terrain mask materials share the daylight toggle", is_zero_approx(float(ink.get_shader_parameter("amount"))))
	var shade_ok := not lighting.shades.is_empty()
	for shade in lighting.shades:
		shade_ok = shade_ok and is_equal_approx(shade.opacity, 0.11)
	check("comparison restores the baseline caster shadows", shade_ok)
	lighting.set_enabled(true)
	shade_ok = true
	for shade in lighting.shades:
		shade_ok = shade_ok and is_equal_approx(shade.opacity, ForestLighting.SHADE_OPACITY)
	check("daylight restores source-backed canopy contrast", shade_ok)
	var previous := Prefs.low_resolution
	Prefs.set_low_resolution(not previous)
	await _frames(2)
	check("quality switching keeps lights in the ground viewport", lighting.get_viewport() == lighting.surfaces[0].get_viewport() and lighting.openings == positions)
	game.player.position = game.dungeon.entry_point()
	check("cave entry culls the forest receivers and disables their shared light", game.dungeon.enter() and game.field_root.visibility_layer == 0 and not WorldLighting.is_enabled())
	game.dungeon.leave("")
	await _frames(2)
	check("returning restores native forest lighting while keeping source receivers culled", game.world_renderer._world_environment.forest.visible and game.world_renderer.sunlight.visible and game.field_root.visibility_layer == 0 and not WorldLighting.is_enabled() and lighting.openings.size() == 2)
	Prefs.set_low_resolution(previous)
	game.queue_free()
	await _frames(2)

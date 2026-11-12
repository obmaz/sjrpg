extends TestCase
## Exercise actual spatial light and scope lifetimes. Canvas shader parity lives
## in the preserved2D edition; its hidden adapter must not tint native actors.


func run() -> void:
	var old_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var game := await make_game("mage")
	game.set_process(false)
	game.encounters.set_process(false)
	var renderer: WorldRenderer3D = game.world_renderer
	renderer.set_process(false)
	var environment: EnvironmentRenderer3D = renderer._world_environment
	var bounce: DirectionalLight3D = renderer.stage.get_node("WarmDaylightBounce")
	var world_environment: WorldEnvironment
	for child in renderer.stage.get_children():
		if child is WorldEnvironment:
			world_environment = child
	var outdoor_fill := world_environment.environment.ambient_light_energy
	check("native sun casts real geometry shadows with a separate softer fill", renderer.sunlight.visible and renderer.sunlight.shadow_enabled and renderer.sunlight.light_energy > bounce.light_energy and bounce.visible and not bounce.shadow_enabled)
	var incoming := renderer.sunlight.global_basis.z
	check("both camera-facing stone axes receive the spatial key light", incoming.dot(Vector3.RIGHT) > .15 and incoming.dot(Vector3.BACK) > .15)
	check("hidden Canvas lighting cannot double-tint native bodies", not WorldLighting.is_enabled() and WorldLighting.color_at(game.player.position) == Color.WHITE and not game.field_root.is_visible_in_tree())
	var grass: ShaderMaterial = renderer._materials["grass"]
	check("native grass keeps its approved albedo and receives spatial lighting", grass.get_shader_parameter("surface_tint") == Color.WHITE and grass.get_shader_parameter("grass_layers") == NativeTerrainSurfaces.layers("grass") and not grass.shader.code.contains("unshaded"))
	var light: OmniLight3D = renderer.contact_light
	var impact := Effect.spawn_impact(game, game.player.position, game.player)
	impact.set_process(false)
	renderer._process(0.5)
	check("confirmed impact creates a local reflected light despite a slow first frame", light.visible and light.light_energy > 0.0 and not light.shadow_enabled and light.omni_range <= 3.0)
	var expected_height := 0.15 if is_finite(impact.spatial_height) else 0.9
	check("contact light follows actual impact height", light.position.is_equal_approx(impact.native_position() + Vector3.UP * expected_height))
	var full_energy := light.light_energy
	get_tree().paused = true
	renderer._process(0.5)
	check("pause holds native contact light instead of consuming its lifetime", light.visible and is_equal_approx(light.light_energy, full_energy))
	Prefs.reduce_motion = true
	renderer._process(0.0)
	check("reduced motion lowers local reflected energy without another pulse", light.visible and light.light_energy > 0.0 and light.light_energy < full_energy * 0.5)
	Prefs.reduce_motion = false
	get_tree().paused = false
	renderer._process(1.0)
	check("native impact light expires without relying on another draw", not light.visible)
	for hit in 12:
		var repeated := Effect.spawn_impact(game, game.player.position, game.player)
		repeated.set_process(false)
	renderer._process(0.0)
	var contact_count := 0
	for child in renderer.stage.get_children():
		if child is OmniLight3D:
			contact_count += 1
	check("many contacts reuse one bounded light", renderer.contact_light == light and contact_count == 1)
	game.player.position = game.dungeon.entry_point()
	check("existing cave entry remains available under native lighting", game.dungeon.enter())
	renderer._process(0.0)
	check("entering cave clears outdoor contacts and disables the sun and bounce", not light.visible and not renderer.sunlight.visible and not bounce.visible and not environment.forest.visible and environment.cave.visible)
	var lamps_valid := environment._cave_lights.size() == 10
	for lamp in environment._cave_lights:
		lamps_valid = lamps_valid and lamp.is_visible_in_tree() and lamp.light_energy > 0.0 and lamp.omni_range > 0.0
	check("ten authored cave lamps remain actual spatial lights", lamps_valid)
	check("cave source stays hidden while native actor and HUD remain visible", not game.dungeon._root.visible and renderer.actor.is_visible_in_tree() and game.hud.visible and not WorldLighting.is_enabled())
	game.dungeon.leave("")
	renderer._process(0.0)
	check("cave return restores outdoor exposure without stale glow or Canvas rendering", renderer.sunlight.visible and bounce.visible and is_equal_approx(world_environment.environment.ambient_light_energy, outdoor_fill) and not light.visible and not game.field_root.visible and not WorldLighting.is_enabled())
	game.queue_free()
	await _frames(2)
	Prefs.reduce_motion = old_reduce

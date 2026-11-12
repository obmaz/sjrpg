extends TestCase
## Render targets are bounded without changing world coverage; paused frames do no repeated sync.
func run() -> void:
	for dimensions: Vector2 in [Vector2(1280,720), Vector2(720,1280), Vector2(3840,2160), Vector2(720,5000), Vector2(8192,1080)]:
		var high := WorldRenderer3D.render_size(dimensions, false)
		var low := WorldRenderer3D.render_size(dimensions, true)
		check("native render area/edges bounded at " + str(dimensions),
			high.x * high.y <= 1536000 and maxi(high.x, high.y) <= 1920 and mini(high.x, high.y) >= 1)
		check("economy remains half each capped dimension", absi(high.x - low.x * 2) <= 1 and absi(high.y - low.y * 2) <= 1)
		check("native cap preserves aspect to one raster pixel",
			absf(float(high.x) / high.y - dimensions.x / dimensions.y) <= 2.0 / mini(high.x, high.y))
	var old_low := Prefs.low_resolution
	var old_reduced := Prefs.reduce_motion
	GameState.delete_save()
	GameState.new_game("warrior")
	var view := SubViewport.new()
	view.size = Vector2i(3840, 2160)
	add_child(view)
	var game := preload("res://scripts/gameplay/game.gd").new()
	view.add_child(game)
	while not game.native_ready:
		await get_tree().physics_frame
		await _frames(1)
	var renderer: WorldRenderer3D = game.world_renderer
	for dimensions: Vector2i in [Vector2i(3840,2160), Vector2i(720,5000)]:
		view.size = dimensions
		for low: bool in [false,true]:
			Prefs.set_low_resolution(low)
			await _frames(5)
			check("actual viewport uses render budget in either quality", renderer.viewport.size == WorldRenderer3D.render_size(Vector2(dimensions), low))
			var expected_height := game.scene_view.get_visible_rect().size.y / WorldRenderer3D.pixels_per_meter(game.camera.zoom.y)
			check("render cap never changes orthographic world height", is_equal_approx(renderer.camera.size, expected_height))
			for offset: Vector2 in [Vector2.ZERO, Vector2(40,-30), Vector2(-30,20)]:
				var point: Vector2 = game.player.position + offset
				var native := SpatialWorld3D.native_point(point, game.spatial_world.height_at(point))
				var screen := renderer.camera.unproject_position(native)
				screen *= game.get_viewport_rect().size / Vector2(renderer.viewport.size)
				check("capped raster targeting round-trips through real spatial floor", game.screen_to_world(screen).distance_to(point) < 0.02)
	get_tree().paused = true
	await _frames(5)
	var syncs: int = renderer.render_activity()["full_syncs"]
	var skips: int = renderer.render_activity()["paused_skips"]
	var clock: float = renderer._world_environment._clock
	await _frames(12)
	check("unchanged paused world skips full presentation sync", int(renderer.render_activity()["full_syncs"]) == syncs and int(renderer.render_activity()["paused_skips"]) > skips)
	check("paused render target retains last frame without redrawing", renderer.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	var original: Vector2 = game.player.position
	game.player.position += Vector2(12,0)
	game.player.facing += 0.3
	game.player.sprite.flash = 0.4
	await _frames(3)
	var expected := renderer.actor_foot(game.player) + WorldRenderer3D.ground_position(game.player.sprite.position)
	check("paused dirty actor position updates with zero time", renderer.actor.position.distance_to(expected) < 0.001 and is_equal_approx(renderer._world_environment._clock, clock))
	check("paused source mutation causes a bounded new sync", int(renderer.render_activity()["full_syncs"]) > syncs)
	syncs = int(renderer.render_activity()["full_syncs"])
	Prefs.set_reduce_motion(not old_reduced)
	await _frames(3)
	check("reduced motion invalidates a paused presentation", int(renderer.render_activity()["full_syncs"]) > syncs and is_equal_approx(renderer._world_environment._clock, clock))
	syncs = int(renderer.render_activity()["full_syncs"])
	Prefs.set_low_resolution(not Prefs.low_resolution)
	await _frames(3)
	check("quality change redraws while paused and keeps native budget", int(renderer.render_activity()["full_syncs"]) > syncs and renderer.viewport.size == WorldRenderer3D.render_size(Vector2(view.size), Prefs.low_resolution))
	get_tree().paused = false
	await _frames(3)
	check("resumed native viewport renders continuously", renderer.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
	game.player.position = original
	view.queue_free()
	await _frames(3)
	Prefs.set_reduce_motion(old_reduced)
	Prefs.set_low_resolution(old_low)

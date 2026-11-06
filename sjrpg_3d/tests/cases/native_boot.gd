extends TestCase
## Native startup waits for real physics before validating saved/ambient spawns.


func run() -> void:
	GameState.new_game("mage")
	var adventure := NativeAdventure.new()
	add_child(adventure)
	var game: Node2D = adventure.simulation
	for tick in 120:
		if game.native_ready:
			break
		await get_tree().physics_frame
		await _frames(1)
	check("native adventure is a real3D project entry", adventure is Node3D and game.native_ready)
	check("initial enemy density survives native physics initialization", game.enemies.size() >= 12)
	check("native actor bodies own initial player and enemies", game.spatial_world.actor_bodies.size() >= game.enemies.size() + 1 and game.spatial_world.physics_ticks > 0)
	game.ortho_preview._sync_camera()
	var point: Vector2 = game.player.position + Vector2(35, 0)
	var native: Vector3 = SpatialWorld3D.native_point(point, game.spatial_world.height_at(point))
	var screen: Vector2 = game.ortho_preview.camera.unproject_position(native)
	screen *= game.get_viewport_rect().size / Vector2(game.ortho_preview.viewport.size)
	check("mouse targeting intersects the real3D floor", game.screen_to_world(screen).distance_to(point) < 1.0)
	adventure.queue_free()
	await _frames(3)

extends TestCase
## 프레임 간 이동 거리와 진입 위치가 달라도 실제 교대 모서리를 돌아 건넌다.
func run() -> void:
	var game := await make_game("warrior")
	game._spawn_timer = 1000000000.0
	game.encounters.set_process(false)
	game.player.set_process(false)
	var spatial: SpatialWorld3D = game.spatial_world
	var failures_at := []
	for distance: float in [0.5, 1.0, 2.0, 3.0, 4.0, 6.0, 8.0, 12.0, 20.0, 40.0]:
		for offset: float in [-4.0, 0.0, 4.0]:
			var start := Iso.project(game.village.forecourt_g) + Vector2(offset, 0)
			spatial.teleport_source_actor(game.player, start, Player.RADIUS)
			for target: Vector2 in [game.village.bridge.axis_point(0.0), game.village.bridge.axis_point(1.0)]:
				var stalled := 0
				for tick: int in 4096:
					var previous: Vector2 = game.player.position
					var remaining := target - previous
					if remaining.length() < 6.0:
						break
					spatial.move_source_actor(game.player, previous + remaining.limit_length(distance), Player.RADIUS)
					stalled = stalled + 1 if game.player.position.distance_squared_to(previous) < 0.000001 else 0
					if stalled >= 12:
						break
			if game.player.position.distance_to(game.village.bridge.axis_point(1.0)) >= 40.0:
				failures_at.append({"step": distance, "offset": offset, "at": str(game.player.position)})
	check("native bridge sweeps clear the actual abutment across thirty step/approach combinations", failures_at.is_empty(), JSON.stringify(failures_at))
	game.queue_free()
	await _frames(2)

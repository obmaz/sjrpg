extends TestCase
## Count actual FLOOR rays through the native walking motor against the real village geometry.


class MeasuredWorld:
	extends SpatialWorld3D
	var floor_queries := 0
	func _floor_sample(point: Vector2) -> Dictionary:
		floor_queries += 1
		return super._floor_sample(point)


func run() -> void:
	var game: Node = await make_game("warrior")
	game.player.set_process(false)
	game._spawn_timer = 10000.0
	var spatial: SpatialWorld3D = game.spatial_world
	var measured := MeasuredWorld.new()
	measured.game = game
	measured.set_physics_process(false)
	game.ortho_preview.stage.add_child(measured)
	var dimensions := SpatialWorld3D.actor_dimensions(game.player, Player.RADIUS)
	var body := measured._new_body("MeasuredWalker", dimensions, false)
	body.collision_layer = 0
	body.set_meta("height", dimensions.y)
	measured._resolver_shape = (body.get_child(0) as CollisionShape3D).shape as CapsuleShape3D
	await get_tree().physics_frame
	await _frames(1)
	var foot := spatial.actor_foot(game.player)
	var origin := foot + Vector3.UP * (dimensions.y * 0.5 + SpatialWorld3D.SKIN)
	body.position = origin
	var direction := Vector2.ZERO
	for angle in 8:
		var candidate := Vector2.from_angle(angle * TAU / 8.0)
		var clear := true
		for step in range(1, 9):
			var point := foot + Vector3(candidate.x, 0.0, candidate.y) * 0.02 * step
			var projected := SpatialWorld3D.projected(point)
			if spatial.blocked(projected, Player.RADIUS) or absf(spatial.height_at(projected) - foot.y) > 0.0001:
				clear = false
				break
		if clear:
			direction = candidate
			break
	if check("native ray-budget fixture finds an actually clear supported walking lane", direction.length_squared() > 0.5):
		measured.floor_queries = 0
		for step in range(1, 9):
			var destination := SpatialWorld3D.projected(foot + Vector3(direction.x, 0.0, direction.y) * 0.02 * step)
			measured._move_body(body, destination)
		var actual_foot := body.position - Vector3.UP * (dimensions.y * 0.5 + SpatialWorld3D.SKIN)
		var actual_floor := spatial.height_at(SpatialWorld3D.projected(body.position))
		check("eight unobstructed native steps make eight FLOOR rays instead of sixteen", measured.floor_queries == 8, "actual rays=%d" % measured.floor_queries)
		check("ray reuse retains actual motion and FLOOR support", Vector2(body.position.x - origin.x, body.position.z - origin.z).length() > 0.15 and absf(actual_foot.y - actual_floor) < 0.00001)

		var supported := body.position
		body.position += Vector3.UP * 0.04
		measured.floor_queries = 0
		measured._settle_support(body, supported, dimensions.y, supported)
		check("a recovered pose different from the validated target still resamples FLOOR", measured.floor_queries > 0 and body.position.distance_to(supported) < 0.00001)

		body.position += Vector3.UP * 0.04
		measured.floor_queries = 0
		measured._settle_support(body, supported, dimensions.y)
		check("legacy support callers without a validated pose still query and settle", measured.floor_queries > 0 and body.position.distance_to(supported) < 0.00001)
	game.queue_free()
	await _frames(2)

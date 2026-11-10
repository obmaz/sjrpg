extends TestCase
## Different frame distances must not let solid-edge recovery lift the foot off FLOOR.


func run() -> void:
	var game: Node = await make_game("warrior")
	game.player.set_process(false)
	var spatial: SpatialWorld3D = game.spatial_world
	var surface: Dictionary = SpatialWorld3D.terrain_surfaces(game.village)[0]
	var bottom: Vector2 = surface["bottom"]
	var upper: Vector2 = surface["upper"]
	var direction := (upper - bottom).normalized()
	var across := direction.orthogonal()
	var target := upper + direction * 40.0
	var worst_error := 0.0
	var worst_detail := ""
	var body_clear := true
	var capsule_clear := true
	var trials := 0
	var first_overlap := ""
	for distance in [0.20, 0.50, 1.0, 2.0, 4.0, 8.0, 16.0, 40.0]:
		for offset in [-10.0, 0.0, 10.0]:
			spatial.teleport_source_actor(game.player, bottom + across * offset, Player.RADIUS)
			for tick in 320:
				var delta: Vector2 = target + across * offset - game.player.position
				spatial.move_source_actor(game.player, game.player.position + delta.limit_length(distance), Player.RADIUS)
				var floor_height := spatial.height_at(game.player.position)
				var foot := spatial.actor_foot(game.player)
				var error := absf(foot.y - floor_height)
				if error > worst_error:
					worst_error = error
					worst_detail = "step=%s offset=%s tick=%s floor=%s foot=%s" % [distance, offset, tick, floor_height, foot.y]
				body_clear = body_clear and not Geometry2D.is_point_in_polygon(game.player.position, surface["building"])
			var body := spatial.register_actor(game.player, Player.RADIUS)
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = (body.get_child(0) as CollisionShape3D).shape
			query.transform = body.global_transform
			query.collision_mask = SpatialWorld3D.SOLID | SpatialWorld3D.PROP
			query.exclude = [body.get_rid()]
			var overlaps := spatial.get_world_3d().direct_space_state.intersect_shape(query, 1)
			if not overlaps.is_empty() and first_overlap.is_empty():
				first_overlap = "%s floor=%s foot=%s step=%s" % [overlaps[0]["collider"].name, spatial.height_at(game.player.position), spatial.actor_foot(game.player), distance]
			capsule_clear = capsule_clear and overlaps.is_empty()
			trials += 1
	check("doorway remains native-solid across varied movement steps", body_clear and capsule_clear and trials == 24, first_overlap)
	check("solid-edge recovery preserves actual native FLOOR support at every step", worst_error < 0.001, worst_detail)
	game.queue_free()
	await _frames(2)

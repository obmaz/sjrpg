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
	# float 좌표의 접촉 오차(수십 μm)와 실제 관통을 구분한다.
	# 허용 폭 0.1mm는 native safe_margin 2mm보다 훨씬 작다.
	var tolerance := 0.0001
	var maximum_penetration := 0.0
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
			var depth := _penetration(spatial, query)
			maximum_penetration = maxf(maximum_penetration, depth)
			if depth > tolerance and first_overlap.is_empty():
				first_overlap = "depth=%s floor=%s foot=%s step=%s" % [depth, spatial.height_at(game.player.position), spatial.actor_foot(game.player), distance]
			capsule_clear = capsule_clear and depth <= tolerance
			trials += 1
	check("doorway remains native-solid across varied movement steps", body_clear and capsule_clear and trials == 24, first_overlap)
	check("solid-edge recovery preserves actual native FLOOR support at every step", worst_error < 0.001, worst_detail)
	# 같은 검사가 실제로 벽을 뚫은 캡슐을 잡는지 검증한다.
	var body := spatial.register_actor(game.player, Player.RADIUS)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = (body.get_child(0) as CollisionShape3D).shape
	query.transform = body.global_transform
	query.transform.origin += Vector3.FORWARD * 0.03
	query.collision_mask = SpatialWorld3D.SOLID | SpatialWorld3D.PROP
	query.exclude = [body.get_rid()]
	var control := _penetration(spatial, query)
	check("contact tolerance still detects actual wall penetration", control > 0.01)
	print("ART_AUDIT THRESHOLD_SOLID ", JSON.stringify({"maximum_contact_m": maximum_penetration, "tolerance_m": tolerance, "negative_control_m": control}))
	game.queue_free()
	await _frames(2)


func _penetration(spatial: SpatialWorld3D, query: PhysicsShapeQueryParameters3D) -> float:
	var contacts := spatial.get_world_3d().direct_space_state.collide_shape(query, 16)
	var depth := 0.0
	for i in range(0, contacts.size(), 2):
		depth = maxf(depth, contacts[i].distance_to(contacts[i + 1]))
	return depth

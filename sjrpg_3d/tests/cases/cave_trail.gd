extends TestCase


## 안내되는 길과 실제 통행 가능한 길이 일치해야 한다.
func run() -> void:
	var game := await make_game("mage")
	game.player.set_process(false)
	game.encounters.set_process(false)
	game._spawn_timer = 1000000.0
	var frame := CaveTrailPlan3D.frame(game.village)
	var points := CaveTrailPlan3D.points(game.village)
	var start: Vector2 = game.village.sanctuary_points["cave"]
	var expected := SpatialWorld3D.projected(frame * Vector3(points[5].x, 0, points[5].y))
	check(
		"field trail joins the cave waypoint before the descent",
		start.distance_to(expected) < 0.01 and points[5].y >= 38.0 and points[5].y < 48.0
	)
	start = SpatialWorld3D.projected(frame * Vector3(points[0].x, 0, points[0].y))
	var attached := false
	for road: PackedVector2Array in game.village.map_roads:
		attached = attached or Geometry2D.is_point_in_polygon(start, road)
		for index in road.size():
			attached = (
				attached
				or (
					start.distance_to(
						Geometry2D.get_closest_point_to_segment(
							start, road[index], road[(index + 1) % road.size()]
						)
					)
					< .01
				)
			)
	check("trail branches directly from the actual south bridge road", attached)
	check(
		"four actual signs guide both the field route and waypoint approach",
		(
			CaveTrailPlan3D.signs(game.village).size() == 4
			and (
				(
					game
					. world_renderer
					. _world_environment
					. forest
					. find_children("CaveTrailSign*", "Node3D", true, false)
					. size()
				)
				== 4
			)
		)
	)
	game.spatial_world.teleport_source_actor(game.player, start, Player.RADIUS)
	var reached := true
	for index in range(1, points.size()):
		var destination := SpatialWorld3D.projected(
			frame * Vector3(points[index].x, 0, points[index].y)
		)
		for step in 1100:
			if game.player.position.distance_to(destination) < 3.0:
				break
			game.spatial_world.move_source_actor(
				game.player, game.player.position.move_toward(destination, 4.0), Player.RADIUS
			)
		reached = reached and game.player.position.distance_to(destination) < 6.0
		check(
			"dirt trail has a vegetation clearing at segment %d" % index,
			game.village.near_water(Iso.unproject(destination), 0.0)
		)
	check(
		"the real player can walk from the field road through every trail bend downhill",
		reached and game.spatial_world.height_at(game.player.position) < -1.0
	)
	var mouth := SpatialWorld3D.projected(frame * Vector3(0, 0, 0.4))
	for step in 1100:
		if game.player.position.distance_to(mouth) < 3.0:
			break
		game.spatial_world.move_source_actor(
			game.player, game.player.position.move_toward(mouth, 4.0), Player.RADIUS
		)
	check(
		"the trail continues through the ravine to the actual cave mouth",
		(
			game.player.position.distance_to(mouth) < 6.0
			and game.spatial_world.height_at(game.player.position) < -3.0
		)
	)
	var ground: MeshInstance3D = game.world_renderer._forest_stage.find_child(
		"NativeNaturalGround", true, false
	)
	check(
		"visible dirt path uses exactly the tested route on the existing terrain",
		ground.material_override.get_shader_parameter("cave_trail") == points
	)
	game.queue_free()
	await _frames(2)

extends TestCase
## 집 문 앞의 판석·합쳐진 길 표시·미니맵·실제 보행 지지가 이어지는지 검사한다.


func run() -> void:
	var game := await make_game("mage")
	game.set_process(false)
	game.player.set_process(false)
	game.encounters.set_process(false)
	var village: Village = game.village
	var spatial: SpatialWorld3D = game.spatial_world
	check(
		"residential lanes share the baked ground distance field",
		GroundRenderer3D.roads_match(village.map_roads)
	)
	for site: Dictionary in VillageCourtyardPlan3D.sites(village):
		if not str(site["id"]) in VillageCourtyardPlan3D.HOUSE_KEYS:
			continue
		var path: Rect2 = site["local_path"]
		var pose: Transform3D = site["frame"]
		var end := WorldSpace3D.world_to_projected(
			pose * Vector3(path.get_center().x, 0, path.end.y)
		)
		var connected := false
		for road: PackedVector2Array in village.map_roads:
			connected = connected or Geometry2D.is_point_in_polygon(end, road)
		check("door pavers meet a real road: " + str(site["id"]), connected)
	var maximum_foot_error := 0.0
	for lane: Dictionary in VillageCourtyardPlan3D.lanes(village):
		var projected := PackedVector2Array()
		for point: Vector2 in lane["polygon"]:
			projected.append(Iso.project(point * 65))
		var mapped := false
		for shape: Dictionary in game.map_shapes:
			mapped = mapped or (shape["kind"] == "road" and shape["poly"] == projected)
		check("minimap reads the shared lane polygon: " + str(lane["id"]), mapped)
		var points: PackedVector2Array = lane["points"]
		spatial.teleport_source_actor(game.player, Iso.project(points[0] * 65), Player.RADIUS)
		var reached := true
		for index in range(1, points.size()):
			var target := Iso.project(points[index] * 65)
			for step in 150:
				if game.player.position.distance_to(target) < 3:
					break
				spatial.move_source_actor(
					game.player,
					game.player.position + (target - game.player.position).limit_length(3),
					Player.RADIUS
				)
				maximum_foot_error = maxf(
					maximum_foot_error,
					absf(
						spatial.actor_foot(game.player).y - spatial.height_at(game.player.position)
					)
				)
			reached = reached and game.player.position.distance_to(target) < 8
		check(
			"native hero walks the whole lane to the plaza: " + str(lane["id"]),
			reached,
			str(game.player.position)
		)
	check("lanes keep native floor support", maximum_foot_error < .001, str(maximum_foot_error))
	game.queue_free()
	await _frames(2)

extends TestCase
## Ground-level chapel: small doorway steps, a solid body, and clear walking along both walls.


func _inside_any(p: Vector2, polys: Array) -> bool:
	for q in polys:
		if Geometry2D.is_point_in_polygon(p, q):
			return true
	return false


func run() -> void:
	var game: Node = await make_game()
	var player: Player = game.player
	var v: Village = game.village
	var chapel: IsoSprite = v.buildings["chapel"]
	var yard: Dictionary = v.data["chapel"]
	var building := chapel.native_polygon(yard["building"])

	check("chapel has only the measured three-step threshold", yard["kind"] == "door_steps" and yard["riser_count"] == 3 and v.terrace.size() == 4 and v.chapel_steps.size() == 6)

	var door: Dictionary = yard["door_opening"]
	var door_a := chapel.native_point(Vector2(door["a"][0], door["a"][1]))
	var door_b := chapel.native_point(Vector2(door["b"][0], door["b"][1]))
	var door_height := door_a.distance_to(door_b) / Iso.S
	check("the actual timber opening keeps human proportions", door_height >= 120.0 and door_height <= 130.0, str(door_height))
	var area := 0.0
	for index in v.terrace.size():
		area += v.terrace[index].cross(v.terrace[(index + 1) % v.terrace.size()])
	check("a broad fenced forecourt has not returned", absf(area) * 0.5 < 84.0 * 84.0 * 0.7)
	check("door steps leave room for the hero's actual diameter and clearance", v.terrace[0].distance_to(v.terrace[1]) > Player.RADIUS * 2.0 + 12.0)
	# The small steps and compound church body must clear every other structure.
	var others: Array[PackedVector2Array] = []
	for i in v.solids.size():
		if i < v.chapel_solids.x or i >= v.chapel_solids.y:
			others.append(v.solids[i])
	var mine: Array = [v.terrace, building]
	for i in range(v.chapel_solids.x, v.chapel_solids.y):
		mine.append(v.solids[i])
	var overlaps := 0
	var where := ""
	for poly in mine:
		for q in others:
			if not Geometry2D.intersect_polygons(poly, q).is_empty():
				overlaps += 1
				where += " [mine %s vs other %s]" % [str(v.uv_of(Iso.poly_bounds(poly).get_center())), str(v.uv_of(Iso.poly_bounds(q).get_center()))]
	check("chapel does not overlap walls, gates or other solids", overlaps == 0, "%d overlaps%s" % [overlaps, where])
	for c in v.chest_points:
		var hidden := Geometry2D.is_point_in_polygon(c, v.terrace)
		for i in range(v.chapel_solids.x, v.chapel_solids.y):
			hidden = hidden or Geometry2D.is_point_in_polygon(c, v.solids[i])
		hidden = hidden or Geometry2D.is_point_in_polygon(c, building)
		if hidden:
			check("chest under the chapel", false, str(c))
	# The nave stays in the north-east garden, inside the walls and beyond the central road.
	var base_ok := true
	for p in chapel.atlas_polygon(v.data["frames"]["chapel"]["ground"]):
		var uv := v.uv_of(p)
		base_ok = base_ok and uv.x > 0.547 and uv.x < 0.927 and uv.y > 0.1138 and uv.y < 0.47
	check("chapel nave is inside its quadrant", base_ok)

	# Preserve the source street connection, then walk the actual native+Z door
	# ramp. The old illustration's step coordinates are a different doorway.
	var steps := v.chapel_steps
	var path: PackedVector2Array = v.map_roads[v.map_roads.size() - 1]
	check("the actual doorway connects to the paved town street", Geometry2D.is_point_in_polygon(steps[0], path) and not Geometry2D.intersect_polygons(path, v.map_roads[0]).is_empty())
	var native_surface: Dictionary = SpatialWorld3D.terrain_surfaces(v)[0]
	var native_building: PackedVector2Array = native_surface["building"]
	var native_bottom: Vector2 = native_surface["bottom"]
	var native_upper: Vector2 = native_surface["upper"]
	var native_top: PackedVector2Array = native_surface["top"]
	player.position = native_bottom
	for i in range(1, 6):
		await _walk(player, native_bottom.lerp(native_upper, i / 5.0), 120)
	await _frames(2)
	check("native chapel steps lead onto the doorway threshold", Geometry2D.is_point_in_polygon(player.position, native_top), str(player.position))
	check("the hero really rises above the native entrance steps", game.spatial_world.actor_foot(player).y > 0.05)

	# The closed timber door and projecting church body remain solid.
	var entry_direction := (native_upper - native_bottom).normalized()
	await _walk(player, native_upper + entry_direction * 40.0, 180)
	check("closed native doorway blocks entry into the church", not Geometry2D.is_point_in_polygon(player.position, native_building) and player.position.distance_to(native_upper) < 40.0, str(player.position))
	var threshold_height: float = game.spatial_world.height_at(player.position)
	var threshold_foot: Vector3 = game.spatial_world.actor_foot(player)
	check("the blocked doorway keeps the hero on its actual native threshold", threshold_height > 0.05 and absf(threshold_foot.y - threshold_height) < 0.03, "floor=%s, foot=%s" % [threshold_height, threshold_foot.y])

	# The native rectangular nave/plinth replace the old illustration's ground
	# runs. Probe both visible native axes, with the actual capsule radius.
	var radius := SpatialWorld3D.radius_metres(float(Player.RADIUS))
	var center := Vector3.ZERO
	for point in native_building:
		center += SpatialWorld3D.native_point(point)
	center /= native_building.size()
	check("native chapel threshold is the model's small three-step plinth", str(native_surface["id"]) == "chapel" and is_equal_approx(float(native_surface["rise"]) / SpatialWorld3D.VERTICAL, 0.28))
	for edge in [1, 2]:
		var a := SpatialWorld3D.native_point(native_building[edge])
		var b := SpatialWorld3D.native_point(native_building[(edge + 1) % native_building.size()])
		var outward := Vector3.UP.cross(b - a).normalized()
		var mid := (a + b) * 0.5
		if outward.dot(mid - center) < 0.0:
			outward = -outward
		var clearance := radius + 0.85
		var from := SpatialWorld3D.projected(a.lerp(b, 0.3) + outward * clearance)
		var to := SpatialWorld3D.projected(a.lerp(b, 0.7) + outward * clearance)
		check("native wall approaches begin on clear ground on axis %s" % edge, not game._blocked(from, Player.RADIUS) and not game._blocked(to, Player.RADIUS))
		player.position = from
		await _walk(player, to, 180)
		check("both native wall faces allow normal parallel walking", player.position.distance_to(to) < 8.0, str(player.position))
		await _frames(2)
		check("ground beside the native church stays at ground elevation", absf(game.spatial_world.actor_foot(player).y) < 0.03)
		player.position = SpatialWorld3D.projected(mid + outward * clearance)
		await _walk(player, SpatialWorld3D.projected(mid - outward), 180)
		var foot := SpatialWorld3D.native_point(player.position)
		check("each actual native wall blocks the full capsule", not Geometry2D.is_point_in_polygon(player.position, native_building) and (foot - mid).dot(outward) >= radius - 0.025)
		# The old high yard no longer exists; its0.28m curb is below MAX_STEP.
		# Preserve the fast-sweep protection on the real solid nave instead.
		for along in [0.35, 0.65]:
			var wall := a.lerp(b, along)
			var probe := SpatialWorld3D.projected(wall + outward * clearance)
			check("native fast-sweep probe begins outside the solid wall", not game._blocked(probe, Player.RADIUS))
			var stopped: Vector2 = game.move_actor(probe, SpatialWorld3D.projected(wall - outward), Player.RADIUS)
			var stopped_foot := SpatialWorld3D.native_point(stopped)
			check("fast sweeps cannot tunnel through either native chapel wall", not Geometry2D.is_point_in_polygon(stopped, native_building) and (stopped_foot - wall).dot(outward) >= radius - 0.025)
	game.queue_free()
	await _frames(2)

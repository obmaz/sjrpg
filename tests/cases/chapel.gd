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

	# Walk from ordinary ground up the three measured doorway steps.
	var steps := v.chapel_steps
	var path: PackedVector2Array = v.map_roads[v.map_roads.size() - 1]
	check("the actual doorway connects to the paved town street", Geometry2D.is_point_in_polygon(steps[0], path) and not Geometry2D.intersect_polygons(path, v.map_roads[0]).is_empty())
	player.position = steps[0]
	for i in range(1, steps.size()):
		await _walk(player, steps[i], 240)
	await _frames(2)
	check("chapel stairs lead onto the doorway threshold", Geometry2D.is_point_in_polygon(player.position, v.terrace), str(player.position))
	check("the hero stands above the small step artwork", player.z_index == 1)

	# The closed timber door and projecting church body remain solid.
	var entry_direction := (door_b - steps[0]).normalized()
	await _walk(player, door_b + entry_direction * 40.0, 180)
	check("closed doorway blocks entry into the church", not Geometry2D.is_point_in_polygon(player.position, building) and player.position.distance_to(door_b) < 40.0, str(player.position))
	check("the threshold keeps the hero above its own steps", Geometry2D.is_point_in_polygon(player.position, v.terrace) and player.z_index == 1)

	# Both nave faces now meet ordinary ground. Walk parallel to each actual
	# wall, then try to cross it; no invisible former forecourt may stop the walk.
	for run: Array in yard["ground_runs"]:
		var a := chapel.native_point(Vector2(run[0][0], run[0][1]))
		var b := chapel.native_point(Vector2(run[1][0], run[1][1]))
		var outward := (b - a).normalized().orthogonal()
		var mid := (a + b) * 0.5
		if Geometry2D.is_point_in_polygon(mid + outward * 8.0, building):
			outward = -outward
		var from := a.lerp(b, 0.3) + outward * 65.0
		var to := a.lerp(b, 0.7) + outward * 65.0
		check("both wall approaches begin on genuinely clear ground", not game._blocked(from, Player.RADIUS) and not game._blocked(to, Player.RADIUS))
		player.position = from
		await _walk(player, to, 180)
		check("both wall faces allow normal ground walking", player.position.distance_to(to) < 8.0 and not Geometry2D.is_point_in_polygon(player.position, v.terrace), str(player.position))
		await _frames(2)
		check("ground beside the church is not raised above the building", player.z_index == 0)
		player.position = mid + outward * 65.0
		await _walk(player, mid - outward * 55.0, 180)
		# Buildings collide with the isometric ground-foot radius used by resolve_movement.
		check("each actual wall blocks walking through its painted body", not Geometry2D.is_point_in_polygon(player.position, building) and (player.position - mid).dot(outward) >= Player.RADIUS * 0.6 - 0.5)

	# Side approaches still cannot bypass the little stair risers, even in a fast sweep.
	for edge in [1, 3]:
		var a := v.terrace[edge]
		var b := v.terrace[(edge + 1) % v.terrace.size()]
		var normal := (b - a).normalized().orthogonal()
		var mid := (a + b) * 0.5
		if Geometry2D.is_point_in_polygon(mid + normal * 2.0, v.terrace):
			normal = -normal
		var probe := mid + normal * 45.0
		check("stair side probe begins on open ground", not game._blocked(probe, Player.RADIUS))
		var stopped: Vector2 = game.move_actor(probe, mid - normal * 25.0, Player.RADIUS)
		check("stair side risers cannot be crossed in one fast move", not Geometry2D.is_point_in_polygon(stopped, v.terrace))
	game.queue_free()
	await _frames(2)

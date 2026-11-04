extends TestCase
## 예배당 높은 마당: 계단으로만 오를 수 있고, 정면 절벽과 건물 자리는 막힌다.


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

	check("chapel yard is built", v.terrace.size() == 8 and v.chapel_steps.size() == 6)

	# Retain the village footprint when replacing the illustration.
	var footprint := Iso.poly_bounds(chapel.atlas_polygon(v.data["frames"]["chapel"]["ground"]))
	check("chapel keeps its large village footprint", footprint.size.x > 900.0 and footprint.size.x < 1200.0)
	# Layout: the raised yard, cliff faces and church body must not overlap walls, gates, other buildings or the plaza props.
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
	# The plinth sits in the north-east quadrant: east of the central road, inside the east wall, and no further
	# north than the north wall's inner face (the stairs may land on the east road).
	var base_ok := true
	for p in chapel.atlas_polygon(v.data["frames"]["chapel"]["ground"]):
		var uv := v.uv_of(p)
		base_ok = base_ok and uv.x > 0.547 and uv.x < 0.927 and uv.y > 0.1138 and uv.y < 0.47
	check("chapel plinth is inside its quadrant", base_ok)

	# Climb: start on open ground below the stairs and follow the measured stair path.
	var steps := v.chapel_steps
	player.position = steps[0]
	for i in range(1, steps.size()):
		await _walk(player, steps[i], 240)
	await _frames(2)
	check("chapel stairs lead onto the yard", Geometry2D.is_point_in_polygon(player.position, v.terrace), str(player.position))
	check("chapel yard draws above the art", player.z_index == 1)

	# The church body and its porch are solid: walking at the building from the door side stops outside it.
	var centre := Vector2.ZERO
	for p in building:
		centre += p
	centre /= building.size()
	await _walk(player, centre, 240)
	check("chapel building blocks the yard", not Geometry2D.is_point_in_polygon(player.position, building), str(player.position))
	check("chapel yard keeps the player on top", Geometry2D.is_point_in_polygon(player.position, v.terrace))

	# From open ground in front of the right cliff, walking straight up the wall must not reach the yard.
	var face: Array = v.data["chapel"]["faces"][0]
	var foot_a := chapel.native_point(Vector2(face[2][0], face[2][1]))
	var foot_b := chapel.native_point(Vector2(face[3][0], face[3][1]))
	var mid := (foot_a + foot_b) / 2.0
	var below := mid + Vector2(0, 45)
	check("cliff probe starts on open ground", not _inside_any(below, v.solids) and not Geometry2D.is_point_in_polygon(below, v.terrace), "probe %s uv %s" % [str(below), str(v.uv_of(below))])
	player.position = below
	var up := mid + Vector2(0, -170)  # over the cliff face, toward the yard
	await _walk(player, up, 300)
	await _frames(2)
	check("chapel cliff face is not walkable", not Geometry2D.is_point_in_polygon(player.position, v.terrace), str(player.position))
	game.queue_free()
	await _frames(2)

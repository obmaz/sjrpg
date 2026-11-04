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
	var foot_a := chapel.native_point(Vector2(1425, 1020))
	var foot_b := chapel.native_point(Vector2(775, 1380))
	var mid := (foot_a + foot_b) / 2.0
	var below := mid + Vector2(0, 90)
	check("cliff probe starts on open ground", not _inside_any(below, v.solids) and not Geometry2D.is_point_in_polygon(below, v.terrace))
	player.position = below
	var up := mid + Vector2(0, -170)  # over the cliff face, toward the yard
	await _walk(player, up, 300)
	await _frames(2)
	check("chapel cliff face is not walkable", not Geometry2D.is_point_in_polygon(player.position, v.terrace), str(player.position))
	game.queue_free()
	await _frames(2)

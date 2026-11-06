extends TestCase
## 성문·성벽: 쌍탑 문루의 통로로 지나갈 수 있고, 탑·날개벽은 막히며, 성벽이 문루 날개벽 끝에서 이어진다.


func _inside_any(p: Vector2, polys: Array) -> bool:
	for q in polys:
		if Geometry2D.is_point_in_polygon(p, q):
			return true
	return false


func run() -> void:
	var game: Node = await make_game()
	var player: Player = game.player
	var v: Village = game.village
	var world: Node2D = player.get_parent()

	check("wall dims come from the gate art", v.wall_height == 200.0 and v.wall_thick == 64.0)
	check("four gates built", v.gate_ends.size() == 4 and v.gate_passages.size() == 4)
	var wall_a: Dictionary = v.data["wall"]["segs"]["a"]
	var wall_b: Dictionary = v.data["wall"]["segs"]["b"]
	check("both wall directions use one generated module and identical physical scale", wall_a["baked_warp"] == wall_b["baked_warp"] and wall_a["k"] == wall_b["k"] and not wall_a["mirror_x"] and wall_b["mirror_x"])
	var family: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/gate_family.json"))
	for item in family["sources"] + family["renders"] + [family["master_reference"], family["concept"], family["generation"]]:
		check("reviewed gate family source and render hash: " + item["path"], FileAccess.get_sha256("res://" + item["path"]) == item["sha256"])
	for gate in 4:
		var key := "gate-%d" % (0 if gate < 2 else 2)
		var reference: Dictionary = v.data["gate_model_reference"][key]
		var pose := IsoSprite.new().setup(v.data["sprites"][key], float(v.data["sprites"][key]["world_height"]))
		pose.position = v.gate_points[gate]
		var actual: Array = v.data["gates"][key]["solids"]
		for polygon in actual.size():
			for index in actual[polygon].size():
				var point: Array = reference["solids"][polygon][index]
				check("gate collision preserves its existing world placement", pose.atlas_point(Vector2(actual[polygon][index][0], actual[polygon][index][1])).distance_to(v.gate_points[gate] + Vector2(point[0], point[1]) * Iso.S) < 0.1)
		pose.free()

	# Wall runs start/end exactly at a gate wing end: some wall piece footprint has a corner there.
	var joined := 0
	var strips := 0
	for n in world.get_children():
		if n is WallPiece:
			strips += 1
	check("wall runs are drawn as art strips", strips > 40, str(strips))
	for gate in 4:
		for e in v.gate_ends[gate]:
			var sp := Iso.project(e)
			for fp in v.wall_footprints:
				var mid := (fp[0] + fp[3]) / 2.0  # the segment's start edge centre; the end edge is (fp[1] + fp[2]) / 2
				var tail := (fp[1] + fp[2]) / 2.0
				if mid.distance_to(sp) < 2.0 or tail.distance_to(sp) < 2.0:
					joined += 1
					break
	check("every wing end has a wall run", joined == 8, str(joined))

	# Walk through each passage along the road axis (gates 0/1 run along v, gates 2/3 along u).
	for gate in 4:
		var axis := Iso.project(Vector2(0, 1) if gate < 2 else Vector2(1, 0)).normalized()
		var centre := v.gate_points[gate]
		var from := centre - axis * 300.0
		var to := centre + axis * 300.0
		player.position = from
		await _frames(2)
		await _walk(player, centre, 240)
		await _frames(2)
		var in_arch := Geometry2D.is_point_in_polygon(player.position, v.gate_passages[gate])
		check("gate %d passage is open" % gate, player.position.distance_to(centre) < 20.0, str(player.position))
		check("gate %d passage preserves native actor visibility and height" % gate, in_arch and game.ortho_preview.actor.is_visible_in_tree() and absf(game.spatial_world.actor_foot(player).y - game.spatial_world.height_at(player.position)) < 0.05)
		await _walk(player, to, 300)
		await _frames(2)
		check("gate %d can be crossed" % gate, player.position.distance_to(to) < 20.0, str(player.position))

		# Towers block: walking at a tower centre from the front stops outside the footprint.
		var tower := PackedVector2Array()
		for poly in v.solids:
			if poly.size() == 12 and poly[0].distance_to(centre) < 600.0:
				tower = poly
				break
		var c := Vector2.ZERO
		for p in tower:
			c += p
		c /= maxf(1.0, tower.size())
		player.position = c + Vector2(0, 160)
		await _walk(player, c, 200)
		await _frames(2)
		check("gate %d tower is solid" % gate, not Geometry2D.is_point_in_polygon(player.position, tower), str(player.position))
	game.queue_free()
	await _frames(2)

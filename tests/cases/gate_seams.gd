extends TestCase
## Compare actual drawn profile datums, not only collision centres or shared height labels.


func _line_y(a: Vector2, b: Vector2, x: float) -> float:
	return a.y + (b.y - a.y) * (x - a.x) / (b.x - a.x)


func _alpha(image: Image, pixel: Vector2) -> float:
	var sample := pixel - Vector2.ONE * 0.5
	var p := Vector2i(sample.floor())
	var weight := sample - Vector2(p)
	var result := 0.0
	for y in 2:
		for x in 2:
			var at := p + Vector2i(x, y)
			if at.x >= 0 and at.y >= 0 and at.x < image.get_width() and at.y < image.get_height():
				result += image.get_pixelv(at).a * (weight.x if x == 1 else 1.0 - weight.x) * (weight.y if y == 1 else 1.0 - weight.y)
	return result


func _gate_alpha(pose: IsoSprite, image: Image, at: Vector2) -> float:
	var delta := (at - pose.position) / pose.k
	var foot: Array = pose.def["foot"]
	var pixel := Vector2(foot[0], foot[1]) + Vector2(delta.x, (delta.y - delta.x * float(pose.def["gvk"])) / float(pose.def["gvs"]))
	var source: Array = pose.def["source"]
	return _alpha(image, pixel) if Rect2(source[0], source[1], source[2], source[3]).has_point(pixel) else 0.0


func _wall_alpha(walls: Array[WallPiece], image: Image, at: Vector2) -> float:
	var alpha := 0.0
	for wall in walls:
		var local := wall._xf.affine_inverse() * (at - wall.global_position)
		if wall._local.has_point(local):
			var pixel := wall._src.position + local - wall._local.position
			alpha = 1.0 - (1.0 - alpha) * (1.0 - _alpha(image, pixel))
	return alpha


func run() -> void:
	var game := await make_game()
	var village: Village = game.village
	var measure: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/extract/gate_join_measure.json"))
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/extract/gate_measure.json"))
	var extraction_path: String = config["wall"]["segs"]["a"]["extracted_scale"]
	var extraction: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://" + extraction_path))
	check("wall really reuses the current gate source", FileAccess.get_sha256("res://" + str(extraction["parent"])) == extraction["parent_sha256"] and FileAccess.get_sha256("res://" + str(extraction["output"])) == extraction["sha256"])
	var mesh := ArtWarp.data("gate-0")
	check("wall extraction follows the current gate calibration", extraction["parent_mesh"]["points"] == mesh["points"] and extraction["parent_mesh"]["triangles"] == mesh["triangles"])
	var datums := {"coping": 159.7852, "cap": 196.4467}
	var gate_image := Image.load_from_file("res://assets/art/village/gates.webp")
	var wall_image := Image.load_from_file("res://assets/art/village/walls.webp")
	var walls: Array[WallPiece] = []
	for item in game.world.get_children():
		if item is WallPiece:
			walls.append(item)
	# The rear parapets used to continue through the far corner as two visible X-shaped stubs.
	# Inspect actual draw rectangles in both opposite runs; collision overlaps remain intentional.
	for run_index in [0, 3]:
		var corner: Array = village.data["wall_runs"][run_index][1]
		var center := village.point(Vector2(corner[0], corner[1]))
		var bounded := true
		var nearby := 0
		for wall in walls:
			if wall.position.distance_to(center) > 150.0:
				continue
			nearby += 1
			var start := wall.global_position + wall._xf * wall._local.position
			var end := wall.global_position + wall._xf * wall._local.end
			var along_u := wall._src.position.x < float(village.data["wall"]["segs"]["b"]["source"][0])
			var right_arm := along_u if run_index == 0 else not along_u
			bounded = bounded and (minf(start.x, end.x) >= center.x - 0.26 if right_arm else maxf(start.x, end.x) <= center.x + 0.26)
		check("corner %d rear parapets turn once without crossed overrun" % run_index, nearby > 4 and bounded)
	for gate in 4:
		var key := "gate-0" if gate < 2 else "gate-2"
		var definition: Dictionary = village.data["sprites"][key]
		var pose := IsoSprite.new().setup(definition, float(definition["world_height"]))
		pose.position = village.gate_points[gate]
		var record: Dictionary = config["gates"][key]
		var left: Array = record["front_L"]
		var right: Array = record["front_R"]
		var a := pose.native_point(Vector2(left[0], left[1]))
		var b := pose.native_point(Vector2(right[0], right[1]))
		var front := Iso.project(Vector2(0, village.wall_thick * 0.5) if gate < 2 else Vector2(village.wall_thick * 0.5, 0))
		for index in 2:
			var painted := a if index == 0 else b
			check("painted front face meets the long wall at gate %d/%d" % [gate, index], (Iso.project(village.gate_ends[gate][index]) + front).distance_to(painted) < 0.1)
			var covered := true
			for height in [0.35, 0.55, 0.75]:
				for shift in [-1.8, -0.9, 0.0, 0.9, 1.8]:
					var at: Vector2 = painted - Vector2(0, village.wall_height * height * Iso.S) + (b - a).normalized() * shift
					var gate_alpha := _gate_alpha(pose, gate_image, at)
					var wall_alpha := _wall_alpha(walls, wall_image, at)
					covered = covered and 1.0 - (1.0 - gate_alpha) * (1.0 - wall_alpha) > 0.95
			check("actual filtered masonry leaves no grass slit at gate %d/%d" % [gate, index], covered)
		for side in ["left", "right"]:
			var wing: Dictionary = measure["wings"][key + "." + side]
			for feature in datums:
				for point in wing[feature]:
					var at := pose.native_point(Vector2(point[0], point[1]))
					var height := (_line_y(a, b, at.x) - at.y) / Iso.S
					check("actual %s aligns at gate %d/%s" % [feature, gate, side], absf(height - float(datums[feature])) < 0.25, "%.3f" % height)
		pose.free()
	# Check the long wall's visible coping/cap through its real draw transform too.
	for key in ["a", "b"]:
		var definition: Dictionary = village.data["wall"]["segs"][key]
		var wall: WallPiece
		for item in game.world.get_children():
			if item is WallPiece and item._src.position.x >= definition["source"][0] and item._src.position.x < definition["source"][0] + definition["source"][2]:
				wall = item
				break
		check("wall profile has a real render strip " + key, wall != null)
		if wall == null:
			continue
		var width: float = definition["source"][2]
		var y0: float = definition["y0"]
		var y1: float = definition["y1"]
		var base_a := wall.global_position + wall._xf * Vector2(0, y0)
		var base_b := wall.global_position + wall._xf * Vector2(width, y1)
		for feature in datums:
			# Actual source-local painted edges, remeasured when the gate-derived strip changes.
			var points: Array = measure["wall_profiles"][feature]
			for point in points:
				var native := Vector2(point[0], point[1])
				if definition.has("baked_warp"):
					native = ArtWarp.point(str(definition["baked_warp"]), native)
				if key == "b":
					native.x = width - 1.0 - native.x
				var at := wall.global_position + wall._xf * (native + Vector2(0, definition["source"][1]))
				var height := (_line_y(base_a, base_b, at.x) - at.y) / Iso.S
				check("rendered wall %s %s matches the gate profile" % [key, feature], absf(height - float(datums[feature])) < 0.75, "%.3f" % height)
	game.queue_free()
	await _frames(2)

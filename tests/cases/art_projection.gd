extends TestCase
## Audit visible source-pixel structure through the same coordinate mapping used to draw it.

func _point(record: Dictionary, raw: Array, pose: Node, game: Node) -> Vector2:
	var p := Vector2(raw[0], raw[1])
	match record["kind"]:
		"sprite":
			if record["space"] == "atlas_local":
				return pose.atlas_point(p + Vector2(pose.def["source"][0], pose.def["source"][1]))
			return pose.native_point(p)
		"bridge":
			return pose.point(p)
		"wall":
			if record.has("baked_warp"):
				p = ArtWarp.point(record["baked_warp"], p)
			if record.get("mirror_x", false):
				p.x = float(record["source_size"][0]) - 1.0 - p.x
			var definition: Dictionary = game.village.data["wall"]["segs"][record["key"]]
			var packing: float = float(definition["source"][2]) / float(record["source_size"][0])
			return pose.global_position + pose._xf * (p * packing + Vector2(0, definition["source"][1]))
		"landmark":
			return pose._pt([p.x * Landmark.CELL / record["source_size"][0], p.y * Landmark.CELL / record["source_size"][1]])
	return p


func _poses(record: Dictionary, game: Node) -> Array[Node]:
	var result: Array[Node] = []
	match record["kind"]:
		"sprite":
			var definition: Dictionary
			if record.has("definition_file"):
				var external: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://" + str(record["definition_file"])))
				definition = external[str(record.get("definition_key", "sprite"))]
			else:
				definition = game.village.data["sprites"][record["key"]]
			var height: float = definition.get("world_height", 100.0)
			result.append(IsoSprite.new().setup(definition, height if height > 0.0 else 100.0))
		"bridge":
			result.append(game.village.bridge)
		"landmark":
			for landmark in game.village.landmarks:
				if landmark.index == int(record["key"]):
					result.append(landmark)
		"wall":
			var source: Array = game.village.data["wall"]["segs"][record["key"]]["source"]
			var transforms := {}
			for child in game.world.get_children():
				if child is WallPiece and child._src.position.x >= source[0] and child._src.position.x < source[0] + source[2]:
					var signature := str(child._xf.x.snapped(Vector2(0.0001, 0.0001))) + str(child._xf.y.snapped(Vector2(0.0001, 0.0001)))
					if not transforms.has(signature):
						transforms[signature] = true
						result.append(child)
	return result


func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/art_axes.json"))
	var game := await make_game()
	var covered := []
	for record in manifest["records"]:
		covered.append(record["id"])
		check("source measurement is current: " + record["id"], FileAccess.get_sha256("res://" + record["source_file"]) == record["source_sha256"])
		check("rendered art matches review: " + record["id"], FileAccess.get_sha256("res://" + record["render_file"]) == record["render_sha256"])
		var poses := _poses(record, game)
		check("measured object has a render projection: " + record["id"], not poses.is_empty())
		var levels := {}
		for edge in record["edges"]:
			levels[edge["level"]] = true
		check("multiple structural heights are measured: " + record["id"], levels.size() >= 2)
		var worst := 0.0
		var worst_parallel := 0.0
		for pose in poses:
			var families := {}
			for edge in record["edges"]:
				var a := _point(record, edge["a"], pose, game)
				var b := _point(record, edge["b"], pose, game)
				var axis: float = edge["axis"]
				var angle := fposmod(rad_to_deg((b - a).angle()) + 90.0, 180.0) - 90.0
				if axis == 90.0:
					angle = absf(angle)
				var error := absf(angle - axis)
				worst = maxf(worst, error)
				check("visible edge %s / %s" % [record["id"], edge["name"]], error <= float(manifest["tolerance_degrees"]), "%.2f° expected %.0f°" % [angle, axis])
				if not families.has(axis):
					families[axis] = []
				families[axis].append(angle)
				# Checking intermediate pixels catches a calibration that aligns endpoints but bends the edge.
				for step in range(1, 12):
					var t := float(step) / 12.0
					var raw := Vector2(edge["a"][0], edge["a"][1]).lerp(Vector2(edge["b"][0], edge["b"][1]), t)
					var at := _point(record, [raw.x, raw.y], pose, game)
					check("straight projected edge %s / %s" % [record["id"], edge["name"]], absf((b - a).cross(at - a)) / maxf(0.01, a.distance_to(b)) < 0.75)
			for family in families.values():
				var spread: float = family.max() - family.min()
				worst_parallel = maxf(worst_parallel, spread)
				check("opposing/upper/lower edges stay parallel: " + record["id"], spread <= float(manifest["parallel_tolerance_degrees"]), "spread %.2f°" % spread)
		print("ART_AUDIT " + JSON.stringify({"id": record["id"], "samples": record["edges"].size(), "poses": poses.size(), "worst_degrees": worst, "parallel_spread": worst_parallel}))
		if record["kind"] == "sprite":
			for pose in poses:
				pose.free()
	for key in ["nw", "ne", "sw", "se", "chapel", "gate-0", "gate-2", "wall-a", "wall-b", "bridge", "pool", "portal", "chest", "chest-broken", "landmark-0", "landmark-1", "encounter-stone"]:
		check("rigid world art is covered: " + key, covered.has(key))
	for key in game.village.data["sprites"]:
		var exempt: bool = manifest["exemptions"]["natural_sprites"].has(key) or manifest["exemptions"]["unused_sources"].has(key)
		check("every sprite is measured or explicitly exempt: " + key, covered.has(key) or exempt)
	# Triangles must preserve orientation so texture projection cannot fold or hide an invalid face.
	for key in ["nw", "se", "sw", "hill", "gate-0", "gate-2", "wall-a", "encounter-stone"]:
		var mesh := ArtWarp.data(key)
		check("projection uses the reviewed illustration: " + key, FileAccess.get_sha256("res://" + mesh["source"]) == mesh["source_sha256"])
		for triangle in mesh["triangles"]:
			var a: Array = mesh["points"][triangle[0]]
			var b: Array = mesh["points"][triangle[1]]
			var c: Array = mesh["points"][triangle[2]]
			var source := Vector2(b[0] - a[0], b[1] - a[1]).cross(Vector2(c[0] - a[0], c[1] - a[1]))
			var target := Vector2(b[2] - a[2], b[3] - a[3]).cross(Vector2(c[2] - a[2], c[3] - a[3]))
			check("texture triangles retain orientation: " + key, source * target > 0.0)
	game.queue_free()
	await _frames(2)

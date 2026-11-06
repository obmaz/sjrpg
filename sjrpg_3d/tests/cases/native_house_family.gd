extends TestCase
## Draft integration tests; execute only in root's isolated native-art worktree.


func _stone_hit(meshes: Array[MeshInstance3D], origin: Vector3, ray: Vector3) -> float:
	var distance := INF
	for mesh in meshes:
		if not str(mesh.name).ends_with("_stone"):
			continue
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var count := indices.size() if not indices.is_empty() else points.size()
			for index in range(0, count, 3):
				var a: int = indices[index] if not indices.is_empty() else index
				var b: int = indices[index + 1] if not indices.is_empty() else index + 1
				var c: int = indices[index + 2] if not indices.is_empty() else index + 2
				var hit = Geometry3D.ray_intersects_triangle(origin, ray, points[a], points[b], points[c])
				if hit is Vector3:
					distance = minf(distance, origin.distance_to(hit))
	return distance


func run() -> void:
	var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/source/preview3d/houses/provenance.json"))
	var generator: Dictionary = provenance["generator"]
	check("house provenance identifies the actual native mesh generator", FileAccess.get_sha256("res://" + str(generator["path"])) == generator["sha256"])
	for texture: Dictionary in provenance["materials"]["textures"]:
		check("house reuses recorded generated material pixels", FileAccess.get_sha256("res://" + str(texture["path"])) == texture["sha256"])
	var game := await make_game("mage")
	var preview: Ortho3DPreview = game.ortho_preview
	check("house panes use reflected shared light rather than flat blue emission", not (preview._materials["glass"] as StandardMaterial3D).emission_enabled and (preview._materials["glass"] as StandardMaterial3D).roughness < 0.6)
	var signatures := {}
	for key: String in ["nw", "ne", "sw", "se"]:
		var bounds := preview._building_bounds(key)
		var width := maxf(3.5, bounds.size.x)
		var depth := maxf(3.0, bounds.size.y)
		var root := Node3D.new()
		preview.stage.add_child(root)
		root.position = Vector3(900, 0, 900)
		var report := NativeHouse3D.build(preview, root, key, width, depth, 2.9)
		var meshes: Array[MeshInstance3D] = report["meshes"]
		var actual_bounds: AABB = report["bounds"]
		print("ART_AUDIT native_house " + JSON.stringify({"key": key, "triangles": report["triangles"], "surfaces": report["surfaces"], "width": width, "depth": depth, "height_max": report["height_max"], "door_x": report["door_x"], "door_width": report["door_width"], "door_height": report["door_height"], "door_approach": {"x": report["door_approach"].position.x, "z": report["door_approach"].position.y, "width": report["door_approach"].size.x, "depth": report["door_approach"].size.y}, "openings": report["openings"].size(), "bounds_min": [actual_bounds.position.x, actual_bounds.position.y, actual_bounds.position.z], "bounds_max": [actual_bounds.end.x, actual_bounds.end.y, actual_bounds.end.z]}))
		check("native house stays within its triangle/material budget: " + key, int(report["triangles"]) >= 6000 and int(report["triangles"]) <= 12000 and int(report["surfaces"]) == 5)
		check("roof edge thickness remains inside recorded overhead allowance: " + key, actual_bounds.position.x >= -width * 0.5 - 0.24 and actual_bounds.end.x <= width * 0.5 + 0.24 and actual_bounds.position.z >= -depth * 0.5 - 0.24 and actual_bounds.end.z <= depth * 0.5 + 0.24)
		check("house keeps the actual old collision footprint: " + key, (report["footprint"] as Vector2).is_equal_approx(Vector2(width, depth)) and report["closed_door"])
		var valid := true
		var winding := true
		var envelope := true
		for mesh in meshes:
			check("house reuses only its shared existing materials: " + str(mesh.name), NativeHouse3D.MATERIAL_KEYS.any(func(material: String) -> bool: return mesh.material_override == preview._materials[material]))
			for surface in mesh.mesh.get_surface_count():
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				for index in points.size():
					valid = valid and points[index].is_finite() and uv[index].is_finite() and absf(normals[index].length() - 1.0) < 0.001
					if points[index].y <= 2.2:
						envelope = envelope and absf(points[index].x) <= width * 0.5 + 0.001 and absf(points[index].z) <= depth * 0.5 + 0.001
				var count := indices.size() if not indices.is_empty() else points.size()
				for index in range(0, count, 3):
					var a: int = indices[index] if not indices.is_empty() else index
					var b: int = indices[index + 1] if not indices.is_empty() else index + 1
					var c: int = indices[index + 2] if not indices.is_empty() else index + 2
					winding = winding and (points[b] - points[a]).cross(points[c] - points[a]).dot(normals[a]) <= 0.00001
		check("all house mesh surfaces have finite vertices/UV/unit normals: " + key, valid)
		check("front/back/side roof faces keep clockwise outward winding: " + key, winding)
		check("ground approach receives no new protruding geometry: " + key, envelope)
		for entry: Dictionary in report["openings"]:
			var opening: Dictionary = entry["opening"]
			if opening.get("role", "") not in ["closed_door", "window"]:
				continue
			var facade: Transform3D = entry["transform"]
			var origin := facade * Vector3(float(opening["x"]) + float(opening["width"]) * 0.20, float(opening["bottom"]) + float(opening["height"]) * 0.35, 1.0)
			var ray := facade.basis * Vector3(0, 0, -1)
			check("door/window has a real masonry aperture: %s/%s" % [key, opening], _stone_hit(meshes, origin, ray) > 1.25)
		var approach: Rect2 = report["door_approach"]
		check("door approach starts outside the unchanged body footprint: " + key, absf(approach.position.y - depth * 0.5) < 0.0001 and approach.size.y >= 0.8)
		var signature := "%s/%s/%s" % [report["triangles"], report["openings"].size(), report["eaves_height"]]
		signatures[signature] = true
		root.queue_free()
	check("all four major houses have distinct structural signatures", signatures.size() == 4)
	game.queue_free()
	await _frames(2)

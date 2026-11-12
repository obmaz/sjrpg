extends TestCase
## Real house geometry, aperture, shared material and metre-scaled timber UV contracts.


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
	var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/source/architecture/houses/reference/provenance.json"))
	var generator: Dictionary = provenance["generator"]
	check("house provenance identifies the actual native mesh generator", FileAccess.get_sha256("res://" + str(generator["path"])) == generator["sha256"])
	for texture: Dictionary in provenance["materials"]["textures"]:
		check("house reuses recorded generated material pixels", FileAccess.get_sha256("res://" + str(texture["path"])) == texture["sha256"])
	var game := await make_game("mage")
	var renderer: WorldRenderer3D = game.world_renderer
	check("house panes use reflected shared light rather than flat blue emission", not (renderer._materials["glass"] as StandardMaterial3D).emission_enabled and (renderer._materials["glass"] as StandardMaterial3D).roughness < 0.6)
	_timber_axes(renderer)
	var signatures := {}
	var styles := {}
	for key: String in HouseRenderer3D.STYLES:
		var style: Dictionary = HouseRenderer3D.STYLES[key]
		styles[str(style["wall"]) + "/" + str(style["slate"])] = true
	check("the four houses never share the same wall and roof pair", styles.size() == 4)
	for key: String in ["nw", "ne", "sw", "se"]:
		var bounds := renderer._building_bounds(key)
		var width := maxf(3.5, bounds.size.x)
		var depth := maxf(3.0, bounds.size.y)
		var root := Node3D.new()
		renderer.stage.add_child(root)
		root.position = Vector3(900, 0, 900)
		var report := HouseRenderer3D.build(renderer, root, key, width, depth, 2.9)
		var meshes: Array[MeshInstance3D] = report["meshes"]
		var actual_bounds: AABB = report["bounds"]
		print("ART_AUDIT native_house " + JSON.stringify({"key": key, "triangles": report["triangles"], "surfaces": report["surfaces"], "width": width, "depth": depth, "height_max": report["height_max"], "door_x": report["door_x"], "door_width": report["door_width"], "door_height": report["door_height"], "door_approach": {"x": report["door_approach"].position.x, "z": report["door_approach"].position.y, "width": report["door_approach"].size.x, "depth": report["door_approach"].size.y}, "openings": report["openings"].size(), "bounds_min": [actual_bounds.position.x, actual_bounds.position.y, actual_bounds.position.z], "bounds_max": [actual_bounds.end.x, actual_bounds.end.y, actual_bounds.end.z]}))
		check("native house stays within its triangle/material budget: " + key, int(report["triangles"]) >= 6000 and int(report["triangles"]) <= 12000 and int(report["surfaces"]) == 6)
		var style: Dictionary = report["style"]
		check("each house has its own wall infill and roof cover: " + key, str(style["wall"]) != "stone" and FileAccess.file_exists(BuildingSurfaceMaterials.ROOT + {"nw":"shop","ne":"smith","sw":"stable","se":"home"}[key] + "/asset.json") and renderer._materials.has(str(style["slate"])))
		check("roof edge thickness remains inside recorded overhead allowance: " + key, actual_bounds.position.x >= -width * 0.5 - 0.24 and actual_bounds.end.x <= width * 0.5 + 0.24 and actual_bounds.position.z >= -depth * 0.5 - 0.24 and actual_bounds.end.z <= depth * 0.5 + 0.24)
		check("house keeps the actual old collision footprint: " + key, (report["footprint"] as Vector2).is_equal_approx(Vector2(width, depth)) and report["closed_door"])
		check("all houses use bonded edge dressings and staggered slate volumes: " + key, int(report["corner_quoins"]) >= 24 and int(report["slate_tiles"]) >= 100)
		check("house wood reuses the actual shared timber pixels with explicit UVs: " + key, not (renderer._materials["door"] as StandardMaterial3D).uv1_triplanar and (renderer._materials["door"] as StandardMaterial3D).albedo_texture == (renderer._materials["wood"] as StandardMaterial3D).albedo_texture)
		var valid := true
		var winding := true
		var envelope := true
		var slate_uv := true
		var slate_course_grid := true
		var slate_column_grid := true
		var measured_joints := 0
		var measured_lips := 0
		for mesh in meshes:
			var role := String(mesh.name).trim_prefix("House_" + key + "_")
			if role == "wall":
				check("house installs its independent facade material", mesh.material_override is ShaderMaterial and mesh.material_override.has_meta("asset_id"))
				check("actual house facade reaches its measured gable peak: " + key, is_equal_approx(mesh.material_override.get_shader_parameter("gable_rise"), float(report["roof_rise"])) and (mesh.material_override.get_shader_parameter("extent") as Vector3).is_equal_approx(Vector3(width - 0.40, report["eaves_height"], depth - 0.40)))
			else:
				check("house keeps shared structural materials", mesh.material_override == renderer._materials[HouseRenderer3D.resource_key(key, role)])
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
					if str(mesh.name).ends_with("_slate") and (points[b] - points[a]).cross(points[c] - points[a]).length_squared() > 0.00000001:
						slate_uv = slate_uv and absf((uv[b] - uv[a]).cross(uv[c] - uv[a])) > 0.00000001
						# Actual eave-facing lip triangles identify the course boundaries;
						# caps, underlay and dormer roofs have different surface normals.
						if normals[a].y < -0.05 and absf(normals[a].z) < 0.0001 and absf(normals[a].x) > 0.05:
							var phase := minf(uv[a].y, minf(uv[b].y, uv[c].y)) * HouseRenderer3D.SLATE_COURSES
							slate_course_grid = slate_course_grid and absf(phase - roundf(phase)) < 0.0001
							measured_lips += 1
							var stagger := fposmod(roundf(phase), 2.0) * 0.5
							for vertex: int in [a, b, c]:
								if absf(absf(points[vertex].z) - (depth * 0.5 + HouseRenderer3D.EAVES)) < 0.005:
									continue
								var joint := uv[vertex].x * HouseRenderer3D.SLATE_COLUMNS - stagger
								var gutter := 0.004 / HouseRenderer3D.SLATE_TILE * HouseRenderer3D.SLATE_COLUMNS
								slate_column_grid = slate_column_grid and absf(absf(joint - roundf(joint)) - gutter) < 0.0001
								measured_joints += 1
		check("all house mesh surfaces have finite vertices/UV/unit normals: " + key, valid)
		check("front/back/side roof faces keep clockwise outward winding: " + key, winding)
		check("ground approach receives no new protruding geometry: " + key, envelope)
		check("all slate slopes and ridge-cap faces retain a nonzero physical UV area: " + key, slate_uv)
		check("actual slate lips follow the eight-course texture grid without a second painted rhythm: " + key, measured_lips >= 100 and slate_course_grid)
		check("actual slate column joints share the six-column UV pitch and stagger", measured_joints >= 100 and slate_column_grid)
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


func _timber_axes(renderer: WorldRenderer3D) -> void:
	# Measure UV derivatives on the actual emitted beam geometry after rotation.
	# A two-metre beam must retain grain direction and metre scale in all axes.
	for axis in 3:
		var builder := preload("res://tools/assets/architecture/house_builder.gd").new()
		var root := Node3D.new()
		renderer.stage.add_child(root)
		root.position = Vector3(900, 0, 900)
		builder._root = root
		builder._materials["wood"] = renderer._materials["door"]
		var primitive := BoxMesh.new()
		primitive.size = Vector3.ONE
		builder._box_arrays = primitive.surface_get_arrays(0)
		var size := Vector3.ONE * 0.24
		size[axis] = 2.0
		var at := Transform3D(Basis(Vector3(0.3, 0.8, 0.2).normalized(), 0.63), Vector3(2, 1, -3))
		builder._box(Vector3.ZERO, size, "wood", at)
		var models := builder._flush()
		var arrays := models[0].mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normal: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var local_grain := Vector3.ZERO
		local_grain[axis] = 1.0
		var grain: Vector3 = at.basis * local_grain
		var measured := 0
		var aligned := true
		for triangle in range(0, indices.size(), 3):
			var first := indices[triangle]
			var second := indices[triangle + 1]
			var third := indices[triangle + 2]
			if absf(normal[first].dot(grain)) > 0.0001:
				continue
			var d1 := uv[second] - uv[first]
			var d2 := uv[third] - uv[first]
			var determinant := d1.cross(d2)
			if absf(determinant) < 0.000001:
				continue
			var gradient: Vector3 = ((points[third] - points[first]) * d1.x - (points[second] - points[first]) * d2.x) / determinant
			aligned = aligned and absf(gradient.normalized().dot(grain)) > 0.9999 and absf(gradient.length() - HouseRenderer3D.TIMBER_TILE) < 0.0005
			measured += 1
		check("rotated timber grain follows its real length and physical repeat axis" + str(axis), measured >= 8 and aligned)
		root.queue_free()

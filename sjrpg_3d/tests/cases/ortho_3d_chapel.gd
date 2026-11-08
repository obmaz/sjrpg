extends TestCase
## Check actual generated surfaces and openings, not just a footprint rectangle.


func _nearest_mesh(stone: MeshInstance3D, origin: Vector3, direction: Vector3) -> float:
	var nearest := INF
	for surface in stone.mesh.get_surface_count():
		var arrays := stone.mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var count := indices.size() if not indices.is_empty() else points.size()
		for index in range(0, count, 3):
			var a: int = indices[index] if not indices.is_empty() else index
			var b: int = indices[index + 1] if not indices.is_empty() else index + 1
			var c: int = indices[index + 2] if not indices.is_empty() else index + 2
			var hit = Geometry3D.ray_intersects_triangle(origin, direction, points[a], points[b], points[c])
			if hit is Vector3:
				nearest = minf(nearest, origin.distance_to(hit))
	return nearest


func run() -> void:
	var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/source/preview3d/chapel/refinement.json"))
	var generator: Dictionary = provenance["generator"]
	check("chapel refinement keeps its exact native geometry source", FileAccess.get_sha256("res://" + str(generator["path"])) == generator["sha256"])
	for source: Dictionary in provenance["inputs"]:
		check("chapel reference and shared material source remains exact: " + str(source["path"]), FileAccess.get_sha256("res://" + str(source["path"])) == source["sha256"])
	var glass: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/preview3d/chapel-glass.json"))
	check("chapel glass retains its recorded generated-art pixels and reference", FileAccess.get_sha256("res://" + str(glass["source"])) == glass["source_sha256"] and FileAccess.get_sha256("res://" + str(glass["output"])) == glass["sha256"] and FileAccess.get_sha256("res://" + str(glass["reference"])) == glass["reference_sha256"])
	var game := await make_game("mage")
	game._enable_ortho_preview()
	await _frames(2)
	var preview: Ortho3DPreview = game.ortho_preview
	var report := {}
	for candidate in preview._world_environment.forest.find_children("*", "Node3D", true, false):
		if candidate.has_meta("chapel_detail"):
			report = candidate.get_meta("chapel_detail")
	check("native chapel has its detailed architecture", not report.is_empty())
	if report.is_empty():
		game.queue_free()
		return
	check("chapel detail keeps a bounded geometry and material budget", int(report["triangles"]) > 1000 and int(report["triangles"]) < 30000 and int(report["surfaces"]) <= 8)
	check("bell tower remains inside the camera shadow height slab", float(report["tower_height"]) < 11.5)
	var side_count := 0
	var rear_count := 0
	for window: Dictionary in report["windows"]:
		if window["role"] == "side_lancet":
			side_count += 1
		elif window["role"] == "rear_lancet":
			rear_count += 1
	check("both sides retain paired real lancets and rear has a coherent opening", side_count == 4 and rear_count == 1)
	check("front and rear gables have recessed real masonry oculi", report["oculi"].size() == 2)
	check("door ramp and native platform keep their existing height", absf(float(report["floor_height"]) - 0.28) < 0.00001)
	check("entry has actual stone orders and jamb shafts", int(report["entry_orders"]) == 3 and int(report["entry_shafts"]) == 2 and float(report["door_recess"]) >= 0.27)
	var actual_bounds: AABB = report["bounds"]
	print("ART_AUDIT chapel_refinement " + JSON.stringify({"triangles": report["triangles"], "surfaces": report["surfaces"], "footprint": [report["footprint"].x, report["footprint"].y], "door_recess": report["door_recess"], "door_width": report["door_width"], "door_height": report["door_height"], "floor_height": report["floor_height"], "side_lancets": side_count, "rear_lancets": rear_count, "oculi": report["oculi"].size(), "tower_height": report["tower_height"], "roof_rows": report["roof_rows"], "bounds_min": [actual_bounds.position.x, actual_bounds.position.y, actual_bounds.position.z], "bounds_max": [actual_bounds.end.x, actual_bounds.end.y, actual_bounds.end.z]}))
	var valid := true
	var winding := true
	var slate_course_grid := true
	var slate_lips := 0
	var spire_min := Vector2(INF, INF)
	var spire_max := Vector2(-INF, -INF)
	var spire_vertices := 0
	var stone: MeshInstance3D
	var oak: MeshInstance3D
	for node: MeshInstance3D in report["meshes"]:
		if node.name == "ChapelDetail_stone":
			stone = node
		elif node.name == "ChapelDetail_oak":
			oak = node
		for surface in node.mesh.get_surface_count():
			var arrays := node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for index in vertices.size():
				valid = valid and vertices[index].is_finite() and uv[index].is_finite() and absf(normals[index].length() - 1.0) < 0.001
				if node.name == "ChapelDetail_slate" and vertices[index].y > float(report["tower_height"]) - 2.511 and absf(normals[index].y) < 0.99:
					spire_min = spire_min.min(uv[index])
					spire_max = spire_max.max(uv[index])
					spire_vertices += 1
			var count := indices.size() if not indices.is_empty() else vertices.size()
			for index in range(0, count, 3):
				var a: int = indices[index] if not indices.is_empty() else index
				var b: int = indices[index + 1] if not indices.is_empty() else index + 1
				var c: int = indices[index + 2] if not indices.is_empty() else index + 2
				winding = winding and (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).dot(normals[a]) <= 0.00001
				if node.name == "ChapelDetail_slate" and normals[a].y < -0.05 and absf(normals[a].z) < 0.0001 and absf(normals[a].x) > 0.05:
					var phase := minf(uv[a].y, minf(uv[b].y, uv[c].y)) * Ortho3DChapel.SLATE_COURSES
					slate_course_grid = slate_course_grid and absf(phase - roundf(phase)) < 0.0001 and absf((uv[b] - uv[a]).cross(uv[c] - uv[a])) > 0.00000001
					slate_lips += 1
	check("all stone roof glass and trim surfaces have finite unit normals and UVs", valid)
	check("actual front and back mesh faces keep consistent outward winding", winding)
	check("chapel slate uses the same eight physical courses as the house family", Ortho3DChapel.SLATE_TILE == NativeHouse3D.SLATE_TILE and Ortho3DChapel.SLATE_COURSES == NativeHouse3D.SLATE_COURSES)
	check("actual chapel lips align with the shared slate UV grid and retain area", slate_lips == int(report["roof_rows"]) * 4 and slate_lips > 0 and slate_course_grid)
	var spire_perimeter := 4.0 * 2.0 * 1.04 * sin(PI / 4.0)
	var spire_slope := Vector2(2.35, (1.04 - 0.035) * cos(PI / 4.0)).length()
	check("actual spire slate UV covers its physical perimeter and slope rather than one stretched image", spire_vertices > 8 and absf((spire_max.x - spire_min.x) - spire_perimeter / Ortho3DChapel.SLATE_TILE) < 0.0001 and absf((spire_max.y - spire_min.y) - spire_slope / Ortho3DChapel.SLATE_TILE) < 0.0001)
	check("chapel stone material is available for aperture checks", is_instance_valid(stone))
	if is_instance_valid(stone):
		var size: Vector2 = report["footprint"]
		var origin := Vector3(0, 1.15, size.y * 0.5 + 1.0)
		check("doorway is an actual opening in the facade stone", _nearest_mesh(stone, origin, Vector3(0, 0, -1)) > 1.3)
		if is_instance_valid(oak):
			var distance := _nearest_mesh(oak, Vector3(0.12, 1.15, size.y * 0.5 + 1.0), Vector3(0, 0, -1))
			check("closed oak leaves use the measured .28m entry recess", absf(distance - 1.28) < 0.005)
		var landing_hit := _nearest_mesh(stone, Vector3(0, 1.0, size.y * 0.5 + 0.04), Vector3.DOWN)
		check("visible stone landing meets the unchanged .28m physics floor", absf(landing_hit - 0.72) < 0.005)
		for opening: Dictionary in report["windows"]:
			var facade: Transform3D = opening["transform"]
			for side in [-1.0, 1.0]:
				var local := Vector3(float(opening["center"]) + side * float(opening["width"]) * 0.225, float(opening["bottom"]) + float(opening["height"]) * 0.38, 1.0)
				var distance := _nearest_mesh(stone, facade * local, facade.basis * Vector3(0, 0, -1))
				check("actual window stone clearance %s/%s/%s = %s" % [facade.origin, opening["center"], side, distance], distance > 1.14)
		for oculus: Dictionary in report["oculi"]:
			var facade: Transform3D = oculus["transform"]
			var center: Vector2 = oculus["center"]
			var radius: float = oculus["radius"]
			# Sample a glazed region between radial bars and the four stone lobes.
			var angle := PI * 0.19
			var point := Vector3(center.x + cos(angle) * radius * 0.75, center.y + sin(angle) * radius * 0.75, 1.0)
			check("front/rear oculus is cut through masonry, not a disk on a wall", _nearest_mesh(stone, facade * point, facade.basis * Vector3(0, 0, -1)) > 1.16)
	game.queue_free()
	await _frames(2)

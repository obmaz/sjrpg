extends TestCase
## Check actual generated surfaces and openings, not just a footprint rectangle.


func _nearest_stone(stone: MeshInstance3D, origin: Vector3, direction: Vector3) -> float:
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
	var glass: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/preview3d/chapel-glass.json"))
	check("chapel glass retains its recorded generated-art pixels and reference", FileAccess.get_sha256("res://" + str(glass["source"])) == glass["source_sha256"] and FileAccess.get_sha256("res://" + str(glass["output"])) == glass["sha256"] and FileAccess.get_sha256("res://" + str(glass["reference"])) == glass["reference_sha256"])
	var game := await make_game("mage")
	game._enable_ortho_preview()
	await _frames(2)
	var preview: Ortho3DPreview = game.ortho_preview
	var report := {}
	for candidate in preview.stage.get_children():
		if candidate.has_meta("chapel_detail"):
			report = candidate.get_meta("chapel_detail")
	check("native chapel has its detailed architecture", not report.is_empty())
	if report.is_empty():
		game.queue_free()
		return
	check("chapel detail keeps a bounded geometry and material budget", int(report["triangles"]) > 1000 and int(report["triangles"]) < 30000 and int(report["surfaces"]) <= 8)
	check("bell tower remains inside the camera shadow height slab", float(report["tower_height"]) < 11.5)
	check("both sides have paired real lancet windows", report["windows"].size() == 4)
	var valid := true
	var winding := true
	var stone: MeshInstance3D
	for node: MeshInstance3D in report["meshes"]:
		if node.name == "ChapelDetail_stone":
			stone = node
		for surface in node.mesh.get_surface_count():
			var arrays := node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for index in vertices.size():
				valid = valid and vertices[index].is_finite() and uv[index].is_finite() and absf(normals[index].length() - 1.0) < 0.001
			var count := indices.size() if not indices.is_empty() else vertices.size()
			for index in range(0, count, 3):
				var a: int = indices[index] if not indices.is_empty() else index
				var b: int = indices[index + 1] if not indices.is_empty() else index + 1
				var c: int = indices[index + 2] if not indices.is_empty() else index + 2
				winding = winding and (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).dot(normals[a]) <= 0.00001
	check("all stone roof glass and trim surfaces have finite unit normals and UVs", valid)
	check("actual front and back mesh faces keep consistent outward winding", winding)
	check("chapel stone material is available for aperture checks", is_instance_valid(stone))
	if is_instance_valid(stone):
		var size: Vector2 = report["footprint"]
		var origin := Vector3(0, 1.15, size.y * 0.5 + 1.0)
		check("doorway is an actual opening in the facade stone", _nearest_stone(stone, origin, Vector3(0, 0, -1)) > 1.3)
		for opening: Dictionary in report["windows"]:
			var facade: Transform3D = opening["transform"]
			var local := Vector3(float(opening["center"]) + float(opening["width"]) * 0.225, float(opening["bottom"]) + float(opening["height"]) * 0.38, 1.0)
			var distance := _nearest_stone(stone, facade * local, facade.basis * Vector3(0, 0, -1))
			check("side window stone clearance %s/%s = %s" % [facade.origin, opening["center"], distance], distance > 1.14)
	game.queue_free()
	await _frames(2)

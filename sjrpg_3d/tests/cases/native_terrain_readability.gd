extends TestCase
## Terrain styling must reveal height without changing native support or entrances.


func run() -> void:
	var game := await make_game("mage")
	var preview: Ortho3DPreview = game.ortho_preview
	var environment: Ortho3DEnvironment = preview._world_environment
	var root: Node3D = environment.forest.get_node("NativeLandmarks")
	var report: Dictionary = root.get_meta("native_landmark_report")
	var low_grass: StandardMaterial3D = preview._materials["grass"]
	var shared_top: StandardMaterial3D
	var shared_earth: StandardMaterial3D
	var styled_count := 0
	for entry: Dictionary in report["entries"]:
		var surface: Dictionary = entry["surface"]
		var group: Node3D = entry["root"]
		var role: int = entry["role"]
		var faces := SpatialWorld3D.surface_faces(surface)
		var top := group.get_node("WalkableTop") as MeshInstance3D
		var arrays := top.mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		if not _same_vertices(points, faces, Vector3.UP * 0.008):
			var degenerate_count := 0
			for triangle in range(0, faces.size(), 3):
				if (faces[triangle + 1] - faces[triangle]).cross(faces[triangle + 2] - faces[triangle]).length_squared() < 0.00000001:
					degenerate_count += 1
			print("TERRAIN_DIAGNOSTIC_TOP ", JSON.stringify({"role": role, "rendered_count": points.size(), "physical_count": faces.size(), "source_degenerate_triangles": degenerate_count, "source": faces, "actual": points}))
		check("all top and ramp vertices retain exact native support " + str(role), _same_vertices(points, faces, Vector3.UP * 0.008))
		var correct_uv := uv.size() == points.size()
		for i in points.size():
			var expected := Vector2(points[i].x, points[i].z)
			if absf(normals[i].y) < 0.7:
				var tangent := Vector3(normals[i].z, 0, -normals[i].x).normalized()
				expected = Vector2(points[i].dot(tangent), -points[i].y)
			correct_uv = correct_uv and uv[i].distance_squared_to(expected / 2.56) < 0.00000001
		check("top and ramp retain their metre UV density " + str(role), correct_uv)
		var earthy := group.get_node_or_null("ExposedEarth") as MeshInstance3D
		if role == 1:
			check("stone garden keeps paving and has no grass or earth rim", top.material_override == preview._materials["paving"] and earthy == null)
			continue
		styled_count += 1
		var turf := top.material_override as StandardMaterial3D
		if not check("only measured raised grass receives the new family " + str(role), float(surface["rise"]) > 0.001 and turf != null and earthy != null):
			continue
		if shared_top == null:
			shared_top = turf
			shared_earth = earthy.material_override as StandardMaterial3D
		check("raised turf shares the original texture and one material " + str(role), turf == shared_top and turf.albedo_texture == low_grass.albedo_texture and turf.uv1_scale == Vector3.ONE)
		check("upper grass is visibly cooler and lighter without emissive light " + str(role), turf.albedo_color.b / turf.albedo_color.g > low_grass.albedo_color.b / low_grass.albedo_color.g * 1.25 and turf.albedo_color.get_luminance() > low_grass.albedo_color.get_luminance() * 1.10 and not turf.emission_enabled and turf.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL)
		var earth := earthy.material_override as StandardMaterial3D
		var cliff := (group.get_node("CliffSides") as MeshInstance3D).material_override as StandardMaterial3D
		check("earth uses one opaque lit rock texture at its original world scale " + str(role), earth == shared_earth and earth.albedo_texture == cliff.albedo_texture and earth.uv1_world_triplanar and earth.uv1_scale.is_equal_approx(Vector3.ONE / 2.56) and earth.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not earth.emission_enabled)
		_check_earth(earthy, surface, role)
		check("visual turf and earth do not add collision " + str(role), group.find_children("*", "CollisionObject3D", true, false).is_empty())
	check("all three raised grass landmarks are styled", styled_count == 3)
	var nodes := root.get_child_count()
	var top_id := shared_top.get_instance_id() if shared_top != null else 0
	var earth_id := shared_earth.get_instance_id() if shared_earth != null else 0
	for i in 3:
		environment.sync(0.0, true)
	check("idle scenery reuses built geometry and terrain materials", root.get_child_count() == nodes and shared_top != null and shared_top.get_instance_id() == top_id and shared_earth != null and shared_earth.get_instance_id() == earth_id)
	game.queue_free()
	await _frames(2)


func _same_vertices(actual: PackedVector3Array, source: PackedVector3Array, offset: Vector3) -> bool:
	if actual.size() != source.size():
		return false
	var matched: Array[bool] = []
	matched.resize(source.size())
	matched.fill(false)
	for point in actual:
		var found := false
		for i in source.size():
			if not matched[i] and point.distance_squared_to(source[i] + offset) < 0.00000001:
				matched[i] = true
				found = true
				break
		if not found:
			return false
	return true


func _check_earth(node: MeshInstance3D, surface: Dictionary, role: int) -> void:
	var arrays := node.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var polygon: PackedVector2Array = surface["top"]
	var entrance: PackedVector2Array = surface["entrance"]
	var bounded := points.size() > 0
	var walls_only := true
	var entrance_clear := true
	var diagnostics: Array[Dictionary] = []
	var faces := SpatialWorld3D.surface_faces(surface)
	for i in points.size():
		var point := points[i]
		var projected := SpatialWorld3D.projected(point)
		var height := SpatialWorld3D._surface_height(surface, projected)
		var fits_height := point.y <= height + 0.0001 and point.y >= maxf(0.0, height - 0.20) - 0.0001
		bounded = bounded and fits_height
		var on_boundary := false
		for edge in polygon.size():
			on_boundary = on_boundary or Geometry2D.get_closest_point_to_segment(projected, polygon[edge], polygon[(edge + 1) % polygon.size()]).distance_squared_to(projected) < 0.0001
		var fits_wall := on_boundary and absf(normals[i].y) < 0.001
		walls_only = walls_only and fits_wall
		var entrance_distance := Geometry2D.get_closest_point_to_segment(projected, entrance[0], entrance[1]).distance_to(projected)
		if diagnostics.size() < 20 and (not fits_height or not fits_wall or (entrance_distance < 0.01 and point.y >= 0.0001)):
			var source_y: Array[float] = []
			for source_point in faces:
				if Vector2(source_point.x - point.x, source_point.z - point.z).length_squared() < 0.00000001:
					source_y.append(source_point.y)
			diagnostics.append({"point": point, "projected": projected, "sampled_height": height, "matching_source_y": source_y, "normal": normals[i], "on_boundary": on_boundary, "entrance_distance": entrance_distance})
		if Geometry2D.get_closest_point_to_segment(projected, entrance[0], entrance[1]).distance_squared_to(projected) < 0.0001:
			entrance_clear = entrance_clear and point.y < 0.0001
	if not diagnostics.is_empty():
		print("TERRAIN_DIAGNOSTIC_EARTH ", JSON.stringify({"role": role, "surface": surface, "points": diagnostics}))
	check("earth stays in the exposed upper 20cm of actual cliff faces " + str(role), bounded and walls_only)
	check("open ground entrance receives no blocking visual rim " + str(role), entrance_clear)

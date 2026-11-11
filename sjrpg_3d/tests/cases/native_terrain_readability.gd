extends TestCase
## Terrain styling must reveal height without changing native support or entrances.


func run() -> void:
	var game := await make_game("mage")
	var preview: Ortho3DPreview = game.ortho_preview
	var environment: Ortho3DEnvironment = preview._world_environment
	var root: Node3D = environment.forest.get_node("NativeLandmarks")
	var report: Dictionary = root.get_meta("native_landmark_report")
	var low_grass: ShaderMaterial = preview._materials["grass"]
	var shared_top: ShaderMaterial
	var shared_earth: StandardMaterial3D
	var turf_variants := {}
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
		check("all top and ramp vertices retain exact native support " + str(role), _same_vertices(points, _visible_faces(faces), Vector3.UP * 0.008))
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
		var turf := top.material_override as ShaderMaterial
		if not check("only measured raised grass receives the new family " + str(role), float(surface["rise"]) > 0.001 and turf != null and earthy != null):
			continue
		if shared_top == null:
			shared_top = turf
			shared_earth = earthy.material_override as StandardMaterial3D
		var expected_bias: float = 1.25 if role == 3 else 0.45
		check("raised terrain shares the ten generated grass families at metre scale " + str(role), turf.get_shader_parameter("grass_layers") == low_grass.get_shader_parameter("grass_layers") and is_equal_approx(float(turf.get_shader_parameter("habitat_bias")), expected_bias) and turf.get_shader_parameter("rock_shelf") == (role == 0))
		turf_variants[turf.get_instance_id()] = true
		var tint: Color = turf.get_shader_parameter("surface_tint")
		var low_tint: Color = low_grass.get_shader_parameter("surface_tint")
		check("upper grass retains its cool lit tint " + str(role), tint.b / tint.g > low_tint.b / low_tint.g * 1.25 and tint.get_luminance() > low_tint.get_luminance() * 1.10 and not turf.shader.code.contains("EMISSION") and not turf.shader.code.contains("unshaded"))
		var geology := group.get_node("NaturalGeology") as MeshInstance3D
		check("geological silhouette uses the actual solid shell " + str(role), _same_vertices(geology.mesh.get_faces(), NativeTerrainForms.faces(surface), Vector3.ZERO))
		var outside := 0
		for point: Vector3 in geology.mesh.get_faces():
			if not Geometry2D.is_point_in_polygon(SpatialWorld3D.projected(point), surface["top"]):
				outside += 1
		check("natural slopes extend beyond the old vertical cliff " + str(role), outside > 20)
		print("ART_AUDIT geological_shell " + JSON.stringify({"role": role, "faces": geology.mesh.get_faces().size(), "outside": outside, "bounds": str(geology.mesh.get_aabb())}))

		var earth := earthy.material_override as StandardMaterial3D
		check("earth uses one opaque lit rock texture at its original world scale " + str(role), earth == shared_earth and earth.albedo_texture == load("res://assets/art/forest/earth.webp") and earth.uv1_world_triplanar and earth.uv1_scale.is_equal_approx(Vector3.ONE / 2.56) and earth.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not earth.emission_enabled)
		_check_earth(earthy, surface, role)
		check("visual turf and earth do not add collision " + str(role), group.find_children("*", "CollisionObject3D", true, false).is_empty())
	check("all three raised grass landmarks are styled", styled_count == 3)
	check("three landmarks share three rock and earth habitat materials", turf_variants.size() == 3)
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


func _visible_faces(source: PackedVector3Array) -> PackedVector3Array:
	# SurfaceTool deliberately omits zero-area physical triangles. Evaluate
	# after the visual depth bias, exactly where the rendering primitive does.
	var result := PackedVector3Array()
	for i in range(0, source.size(), 3):
		var a := source[i] + Vector3.UP * 0.008
		var b := source[i + 1] + Vector3.UP * 0.008
		var c := source[i + 2] + Vector3.UP * 0.008
		if (b - a).cross(c - a).length_squared() >= 0.00000001:
			result.append_array(PackedVector3Array([source[i], source[i + 1], source[i + 2]]))
	return result


func _check_earth(node: MeshInstance3D, surface: Dictionary, role: int) -> void:
	# The physical source is the reference: retain each old vertical boundary
	# quad to Y=-0.02m. Analytic height_at is not equivalent at clipped ramp
	# corners, where flat pieces retain full rise and oblique ramp corners vary.
	var sides := _physical_boundary(surface)
	var group := node.get_parent()
	var contained := true
	var earth_rail := true
	var outward := true
	var mapped := true
	for name: String in ["CliffSides", "ExposedEarth"]:
		var part := group.get_node(name) as MeshInstance3D
		var arrays := part.mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		mapped = mapped and points.size() == normals.size() and points.size() == uv.size()
		for i in range(0, points.size(), 3):
			var triangle := PackedVector3Array([points[i], points[i + 1], points[i + 2]])
			var owner := -1
			for side in sides.size():
				if _inside_side(triangle, sides[side]):
					owner = side
					break
			if owner < 0:
				contained = false
				continue
			var boundary: Dictionary = sides[owner]
			var poly := PackedVector2Array()
			for point in triangle:
				var local := _side_point(point, boundary)
				poly.append(local)
				if name == "ExposedEarth":
					var a: Vector3 = boundary["a"]
					var b: Vector3 = boundary["b"]
					var length: float = boundary["length"]
					var upper := lerpf(a.y, b.y, clampf(local.x / length, 0.0, 1.0))
					var lower := maxf(0.0, upper - 0.20)
					earth_rail = earth_rail and (absf(point.y - upper) < 0.0001 or absf(point.y - lower) < 0.0001)
			var pieces: Array = boundary["pieces"]
			pieces.append(poly)
			boundary["area"] = float(boundary["area"]) + _polygon_area(poly)
			if name == "ExposedEarth":
				boundary["earth_area"] = float(boundary["earth_area"]) + _polygon_area(poly)
			var geometric := (points[i + 1] - points[i]).cross(points[i + 2] - points[i])
			var expected_normal: Vector3 = boundary["normal"]
			outward = outward and geometric.dot(normals[i]) < 0.0 and normals[i].dot(expected_normal) > 0.999 and absf(normals[i].y) < 0.001 and absf(normals[i].length() - 1.0) < 0.001
			mapped = mapped and absf((uv[i + 1] - uv[i]).cross(uv[i + 2] - uv[i])) > 0.00000001
			for offset in [1, 2]:
				mapped = mapped and is_equal_approx((uv[i + offset].y - uv[i].y) * 2.56, -(points[i + offset].y - points[i].y))
	var partitioned := not sides.is_empty()
	var nonoverlapping := true
	for boundary: Dictionary in sides:
		var a: Vector3 = boundary["a"]
		var b: Vector3 = boundary["b"]
		var length: float = boundary["length"]
		var expected := length * (a.y + b.y + 0.04) * 0.5
		# A short side tapers naturally where the original ramp reaches ground.
		var expected_earth := length * (minf(a.y, 0.20) + minf(b.y, 0.20)) * 0.5
		partitioned = partitioned and absf(float(boundary["area"]) - expected) < maxf(0.0001, expected * 0.0001) and absf(float(boundary["earth_area"]) - expected_earth) < maxf(0.0001, expected_earth * 0.0001)
		var pieces: Array = boundary["pieces"]
		for i in pieces.size():
			for j in range(i + 1, pieces.size()):
				for overlap: PackedVector2Array in Geometry2D.intersect_polygons(pieces[i], pieces[j]):
					nonoverlapping = nonoverlapping and _polygon_area(overlap) < 0.0001
	check("soil and rock exactly partition original cliff faces without overlays " + str(role), contained and partitioned and nonoverlapping)
	check("earth lower rail follows actual native top minus20cm or ground " + str(role), earth_rail)
	check("all split cliff faces preserve clockwise outward winding and metre UVs " + str(role), outward and mapped)
	# Containment and exact coverage above also preserve the old open entrance:
	# no face can appear over a zero-height opening, while the preexisting
	# partial face of an oblique ramp is not incorrectly treated as a new wall.
	check("earth split preserves the original open passage and ramp footprint " + str(role), contained and partitioned)


func _physical_boundary(surface: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var points := SpatialWorld3D.surface_faces(surface)
	var outline: PackedVector2Array = surface["top"]
	var used := {}
	for triangle in range(0, points.size(), 3):
		for edge in 3:
			var a := points[triangle + edge]
			var b := points[triangle + (edge + 1) % 3]
			if maxf(a.y, b.y) < 0.001:
				continue
			var from := SpatialWorld3D.projected(a)
			var to := SpatialWorld3D.projected(b)
			var perimeter := false
			for side in outline.size():
				var p := outline[side]
				var q := outline[(side + 1) % outline.size()]
				perimeter = perimeter or (Geometry2D.get_closest_point_to_segment(from, p, q).distance_squared_to(from) < 0.0001 and Geometry2D.get_closest_point_to_segment(to, p, q).distance_squared_to(to) < 0.0001)
			if not perimeter:
				continue
			var first := "%.5f:%.5f:%.5f" % [a.x, a.y, a.z]
			var second := "%.5f:%.5f:%.5f" % [b.x, b.y, b.z]
			var key := first + "|" + second if first < second else second + "|" + first
			if used.has(key):
				continue
			used[key] = true
			var along := Vector2(b.x - a.x, b.z - a.z)
			if along.length_squared() < 0.00000001:
				continue
			var normal := Vector3(along.y, 0, -along.x).normalized()
			var outside := (from + to) * 0.5 + Iso.project(Vector2(normal.x, normal.z) * Ortho3DPreview.GROUND_PER_METER).normalized()
			if Geometry2D.is_point_in_polygon(outside, outline):
				normal = -normal
			result.append({"a": a, "b": b, "axis": along.normalized(), "length": along.length(), "normal": normal, "pieces": [], "area": 0.0, "earth_area": 0.0})
	return result


func _side_point(point: Vector3, side: Dictionary) -> Vector2:
	var a: Vector3 = side["a"]
	var axis: Vector2 = side["axis"]
	return Vector2(Vector2(point.x - a.x, point.z - a.z).dot(axis), point.y)


func _inside_side(triangle: PackedVector3Array, side: Dictionary) -> bool:
	var a: Vector3 = side["a"]
	var b: Vector3 = side["b"]
	var axis: Vector2 = side["axis"]
	var length: float = side["length"]
	for point in triangle:
		var flat := Vector2(point.x - a.x, point.z - a.z)
		var local := _side_point(point, side)
		var upper := lerpf(a.y, b.y, clampf(local.x / length, 0.0, 1.0))
		if absf(flat.cross(axis)) > 0.0001 or local.x < -0.0001 or local.x > length + 0.0001 or point.y < -0.0201 or point.y > upper + 0.0001:
			return false
	return true


func _polygon_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for i in points.size():
		area += points[i].cross(points[(i + 1) % points.size()])
	return absf(area) * 0.5

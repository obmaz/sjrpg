class_name NativeLandmarks3D
extends RefCounted
## Native terrain/solid picture built from the same authored footprint as physics.
## Simulation and colliders remain SpatialWorld3D's responsibility.

static func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	if (b - a).cross(c - a).length_squared() < 0.00000001:
		return
	if (b - a).cross(c - a).dot(normal) < 0:
		var swap := b
		b = c
		c = swap
	for point in [a, c, b]:
		tool.set_normal(normal)
		var uv := Vector2(point.x, point.z)
		if absf(normal.y) < 0.7:
			var tangent := Vector3(normal.z, 0, -normal.x).normalized()
			uv = Vector2(point.dot(tangent), -point.y)
		tool.set_uv(uv / 2.56)
		tool.add_vertex(point)

static func _finish(tool: SurfaceTool, material: Material, parent: Node3D, name: String) -> MeshInstance3D:
	var mesh := tool.commit()
	if mesh == null:
		return null
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.material_override = material
	parent.add_child(node)
	return node

static func _prism(polygon: PackedVector2Array, bottom: float, top: float, material: Material, parent: Node3D, name: String) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var native := PackedVector3Array()
	var flat := PackedVector2Array()
	var center := Vector3.ZERO
	for point in polygon:
		var p := Ortho3DPreview.ground_position(point, top)
		native.append(p)
		flat.append(Vector2(p.x, p.z))
		center += p
	center /= maxf(1.0, native.size())
	var indices := Geometry2D.triangulate_polygon(flat)
	for index in range(0, indices.size(), 3):
		var a := native[indices[index]]
		var b := native[indices[index + 1]]
		var c := native[indices[index + 2]]
		_tri(tool, a, b, c, Vector3.UP)
		_tri(tool, Vector3(a.x, bottom, a.z), Vector3(c.x, bottom, c.z), Vector3(b.x, bottom, b.z), Vector3.DOWN)
	for i in native.size():
		var a := native[i]
		var b := native[(i + 1) % native.size()]
		var normal := Vector3(b.z - a.z, 0, a.x - b.x).normalized()
		if Geometry2D.is_point_in_polygon(Vector2((a.x + b.x) * 0.5, (a.z + b.z) * 0.5) + Vector2(normal.x, normal.z) * 0.01, flat):
			normal = -normal
		var low_a := Vector3(a.x, bottom, a.z)
		var low_b := Vector3(b.x, bottom, b.z)
		_tri(tool, a, low_a, low_b, normal)
		_tri(tool, a, low_b, b, normal)
	_finish(tool, material, parent, name)

static func build(preview: Node, parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "NativeLandmarks"
	parent.add_child(root)
	var rock_material := StandardMaterial3D.new()
	rock_material.albedo_texture = load("res://assets/art/village/rock.webp")
	rock_material.roughness = 0.96
	rock_material.uv1_triplanar = true
	rock_material.uv1_world_triplanar = true
	rock_material.uv1_scale = Vector3.ONE / 2.56
	var owned := {}
	var entries: Array[Dictionary] = []
	var surfaces := {}
	for surface: Dictionary in SpatialWorld3D.terrain_surfaces(preview.game.village):
		surfaces[str(surface["id"])] = surface
	for source: Landmark in preview.game.village.landmarks:
		if source.index == 2:
			var trees := Ortho3DTrees.mesh_library()
			if trees.is_empty() or trees[0]["mesh"] == null:
				continue
		var id := "landmark_%d" % source.index
		var surface: Dictionary = surfaces.get(id, {"id": id, "top": source.top, "rise": 0.0})
		var points := SpatialWorld3D.surface_faces(surface)
		if points.is_empty():
			continue
		var group := Node3D.new()
		group.name = "Landmark%d" % source.index
		root.add_child(group)
		var floor_tool := SurfaceTool.new()
		floor_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for index in range(0, points.size(), 3):
			var a := points[index] + Vector3.UP * 0.008
			var b := points[index + 1] + Vector3.UP * 0.008
			var c := points[index + 2] + Vector3.UP * 0.008
			var normal := (b - a).cross(c - a).normalized()
			if normal.y < 0:
				normal = -normal
			_tri(floor_tool, a, b, c, normal)
		var floor_material: Material = preview._materials["paving"]
		if source.index in [0, 2, 3]:
			var turf := (preview._materials["grass"] as StandardMaterial3D).duplicate() as StandardMaterial3D
			turf.uv1_scale = Vector3.ONE
			floor_material = turf
		_finish(floor_tool, floor_material, group, "WalkableTop")
		var sides := SurfaceTool.new()
		sides.begin(Mesh.PRIMITIVE_TRIANGLES)
		var has_sides := false
		var top: PackedVector2Array = surface["top"]
		var used := {}
		for triangle in range(0, points.size(), 3):
			for edge in 3:
				var a := points[triangle + edge]
				var b := points[triangle + (edge + 1) % 3]
				var from := SpatialWorld3D.projected(a)
				var to := SpatialWorld3D.projected(b)
				var on_boundary := false
				for i in top.size():
					if Geometry2D.get_closest_point_to_segment(from, top[i], top[(i + 1) % top.size()]).distance_squared_to(from) < 0.0001 and Geometry2D.get_closest_point_to_segment(to, top[i], top[(i + 1) % top.size()]).distance_squared_to(to) < 0.0001:
						on_boundary = true
						break
				if not on_boundary or maxf(a.y, b.y) < 0.001:
					continue
				var first := "%.5f:%.5f:%.5f" % [a.x, a.y, a.z]
				var second := "%.5f:%.5f:%.5f" % [b.x, b.y, b.z]
				var key := first + "|" + second if first < second else second + "|" + first
				if used.has(key):
					continue
				used[key] = true
				var normal := Vector3(b.z - a.z, 0, a.x - b.x).normalized()
				var middle := (from + to) * 0.5
				var test_point := middle + Iso.project(Vector2(normal.x, normal.z) * Ortho3DPreview.GROUND_PER_METER).normalized()
				if Geometry2D.is_point_in_polygon(test_point, top):
					normal = -normal
				var low_a := Vector3(a.x, -0.02, a.z)
				var low_b := Vector3(b.x, -0.02, b.z)
				_tri(sides, a, low_a, low_b, normal)
				_tri(sides, a, low_b, b, normal)
				has_sides = true
		if has_sides:
			_finish(sides, rock_material, group, "CliffSides")
		var definition: Dictionary = Landmark.data()[source.index]
		for i in definition["solids"].size():
			var polygon := source._poly(definition["solids"][i])
			var at := Iso.poly_bounds(polygon).get_center()
			var base := SpatialWorld3D.surface_height_at(preview.game.village, at)
			# Existing native Obstacle colliders use exactly base+3.5m.
			if source.index == 2:
				_ancient_tree(preview, group, polygon, base)
			else:
				_weathered_rock(polygon, base, base + 3.5, preview._materials["stone"] if source.index == 1 else rock_material, group, "WeatheredStone%d" % i)
		for i in source.water.size():
			var water: PackedVector2Array = source.water[i]
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("3e6463")
			material.roughness = 0.38
			var water_centre := Iso.poly_bounds(water).get_center()
			var height := SpatialWorld3D.surface_height_at(preview.game.village, water_centre) + 0.012
			_prism(water, height - 0.03, height, material, group, "Water%d" % i)
		if source.index == 3 and source.water.size() >= 2:
			_waterfall(preview, source, group)
		owned[source.get_instance_id()] = true
		entries.append({"source_id": source.get_instance_id(), "role": source.index, "surface": surface, "faces": points, "root": group})
	var report := {"owned_source_ids": owned, "entries": entries, "root": root, "billboards": false}
	root.set_meta("native_landmark_report", report)
	return report

static func _weathered_rock(polygon: PackedVector2Array, bottom: float, top: float, material: Material, parent: Node3D, name: String) -> void:
	var outline := PackedVector2Array()
	var lower := PackedVector3Array()
	var upper := PackedVector3Array()
	var centre := Ortho3DPreview.ground_position(Iso.poly_bounds(polygon).get_center())
	for i in polygon.size():
		var a := Ortho3DPreview.ground_position(polygon[i], bottom)
		lower.append(a)
		var b := a.lerp(Vector3(centre.x, bottom, centre.z), 0.12)
		b.y = top - 0.08 - 0.14 * (0.5 + 0.5 * sin(i * 2.4))
		upper.append(b)
		outline.append(Vector2(b.x, b.z))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(outline)
	for i in range(0, indices.size(), 3):
		var a := upper[indices[i]]
		var b := upper[indices[i + 1]]
		var c := upper[indices[i + 2]]
		var normal := (b - a).cross(c - a).normalized()
		if normal.y < 0:
			normal = -normal
		_tri(tool, a, b, c, normal)
	for i in lower.size():
		var next := (i + 1) % lower.size()
		var a := lower[i]
		var b := lower[next]
		var high_a := upper[i]
		var high_b := upper[next]
		var mid_a := a.lerp(high_a, 0.48)
		var mid_b := b.lerp(high_b, 0.48)
		# Broad weathered planes instead of perfect rectangular pillars.
		var normal := Vector3(b.z - a.z, 0, a.x - b.x).normalized()
		if normal.dot((a + b) * 0.5 - centre) < 0:
			normal = -normal
		for pair in [[a, b, mid_a, mid_b], [mid_a, mid_b, high_a, high_b]]:
			_tri(tool, pair[0], pair[2], pair[3], normal)
			_tri(tool, pair[0], pair[3], pair[1], normal)
	_finish(tool, material, parent, name)

static func _ancient_tree(preview: Node, parent: Node3D, polygon: PackedVector2Array, base: float) -> void:
	var entry: Dictionary = Ortho3DTrees.mesh_library()[0]
	var mesh := entry["mesh"] as Mesh
	if mesh == null:
		return
	var bounds := mesh.get_aabb()
	var source := Iso.poly_bounds(polygon).get_center()
	var centre := Ortho3DPreview.ground_position(source, base)
	var factor := 7.2 / maxf(0.1, bounds.size.y)
	var tree := MeshInstance3D.new()
	tree.name = "AncientOak"
	tree.mesh = mesh
	tree.scale = Vector3.ONE * factor
	tree.position = centre - Vector3.UP * bounds.position.y * factor
	parent.add_child(tree)
	var bark: Material = mesh.surface_get_material(0)
	if bark == null:
		bark = preview._materials["wood"]
	var native_polygon := PackedVector2Array()
	for point in polygon:
		var native := Ortho3DPreview.ground_position(point)
		native_polygon.append(Vector2(native.x, native.z))
	var radius := 1000.0
	var native_center := Vector2(centre.x, centre.z)
	for i in native_polygon.size():
		radius = minf(radius, native_center.distance_to(Geometry2D.get_closest_point_to_segment(native_center, native_polygon[i], native_polygon[(i + 1) % native_polygon.size()])))
	# The root bed visibly marks the existing broad solid footprint; it must not
	# turn into a narrow visible trunk inside a large invisible obstacle.
	_weathered_rock(polygon, base, base + 0.32, bark, parent, "RootMound")
	for i in 7:
		var angle := TAU * i / 7.0
		var start := centre + Vector3(cos(angle), 0, sin(angle)) * minf(radius * 0.8, 1.7)
		var end := centre + Vector3(cos(angle) * 0.18, 1.25, sin(angle) * 0.18)
		var root := CylinderMesh.new()
		root.radial_segments = 8
		root.rings = 1
		root.bottom_radius = 0.15
		root.top_radius = 0.10
		root.height = start.distance_to(end)
		var node := MeshInstance3D.new()
		node.name = "AncientRoot%d" % i
		node.mesh = root
		node.material_override = bark
		node.position = (start + end) * 0.5
		node.basis = Basis(Quaternion(Vector3.UP, (end - start).normalized()))
		parent.add_child(node)

static func _waterfall(preview: Node, source: Landmark, parent: Node3D) -> void:
	var upper: PackedVector2Array = source.water[0]
	var lower: PackedVector2Array = source.water[1]
	var top := Iso.poly_bounds(upper).get_center()
	var bottom := Iso.poly_bounds(lower).get_center()
	var a := Ortho3DPreview.ground_position(top, SpatialWorld3D.surface_height_at(preview.game.village, top) + 0.03)
	var b := Ortho3DPreview.ground_position(bottom, SpatialWorld3D.surface_height_at(preview.game.village, bottom) + 0.03)
	var side := Vector3(b.z - a.z, 0, a.x - b.x).normalized() * 0.42
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var from := a.lerp(b, float(i) / 6.0)
		var to := a.lerp(b, float(i + 1) / 6.0)
		from.y = lerpf(a.y, b.y, pow(float(i) / 6.0, 0.65))
		to.y = lerpf(a.y, b.y, pow(float(i + 1) / 6.0, 0.65))
		var normal := (to + side - from + side).cross(to - side - from + side).normalized()
		if normal.y < 0:
			normal = -normal
		_tri(tool, from - side, to + side, to - side, normal)
		_tri(tool, from - side, from + side, to + side, normal)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color("6b9693")
	water.roughness = 0.34
	water.cull_mode = BaseMaterial3D.CULL_DISABLED
	_finish(tool, water, parent, "FallingWater")

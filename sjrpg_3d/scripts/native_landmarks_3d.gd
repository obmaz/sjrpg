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
	for point in [a, b, c]:
		tool.set_normal(normal)
		tool.set_uv(Vector2(point.x, point.z) / 2.56)
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
	var owned := {}
	var entries: Array[Dictionary] = []
	var surfaces := {}
	for surface: Dictionary in SpatialWorld3D.terrain_surfaces(preview.game.village):
		surfaces[str(surface["id"])] = surface
	for source: Landmark in preview.game.village.landmarks:
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
		_finish(floor_tool, preview._materials["paving"], group, "WalkableTop")
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
			_finish(sides, preview._materials["stone"], group, "CliffSides")
		var definition: Dictionary = Landmark.data()[source.index]
		for i in definition["solids"].size():
			var polygon := source._poly(definition["solids"][i])
			var at := Iso.poly_bounds(polygon).get_center()
			var base := SpatialWorld3D.surface_height_at(preview.game.village, at)
			# Existing native Obstacle colliders use exactly base+3.5m.
			_prism(polygon, base, base + 3.5, preview._materials["wood"] if source.index == 2 else preview._materials["stone"], group, "Solid%d" % i)
		for i in source.water.size():
			var water: PackedVector2Array = source.water[i]
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("3e6463")
			material.roughness = 0.38
			var height := float(surface["rise"]) / SpatialWorld3D.VERTICAL + 0.012
			_prism(water, height - 0.03, height, material, group, "Water%d" % i)
		owned[source.get_instance_id()] = true
		entries.append({"source_id": source.get_instance_id(), "role": source.index, "surface": surface, "faces": points, "root": group})
	var report := {"owned_source_ids": owned, "entries": entries, "root": root, "billboards": false}
	root.set_meta("native_landmark_report", report)
	return report

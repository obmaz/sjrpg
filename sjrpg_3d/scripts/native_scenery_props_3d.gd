class_name NativeSceneryProps3D
extends RefCounted
## Exact authored definitions/roles, never atlas-wide ownership or name guessing.

static func role_of(source: IsoSprite, village: Village) -> String:
	var role := str(source.get_meta("cave_role", ""))
	if role in ["arch", "boulder", "crystal"]:
		return role
	if source.def == village.data["sprites"]["rock"]:
		return "boulder"
	if source.def == DungeonArt.data()["frames"]["entrance"]:
		return "entrance"
	return ""

static func _face(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, centre: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.dot((a + b + c + d) * 0.25 - centre) < 0:
		normal = -normal
	NativeLandmarks3D._tri(tool, a, b, c, normal)
	NativeLandmarks3D._tri(tool, a, c, d, normal)

static func _box(tool: SurfaceTool, origin: Vector3, size: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	var faces := box.get_faces()
	for i in range(0, faces.size(), 3):
		var a := faces[i] + origin
		var b := faces[i + 1] + origin
		var c := faces[i + 2] + origin
		var normal := (b - a).cross(c - a).normalized()
		if normal.dot((a + b + c) / 3.0 - origin) < 0:
			normal = -normal
		NativeLandmarks3D._tri(tool, a, b, c, normal)

static func arch_mesh(clear_width: float, height: float, thickness := 0.36, depth := 0.62) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radius := clear_width * 0.5
	var spring := maxf(1.85, height - (radius + thickness) * 0.85)
	_box(tool, Vector3(-radius - thickness * 0.5, spring * 0.5, 0), Vector3(thickness, spring, depth))
	_box(tool, Vector3(radius + thickness * 0.5, spring * 0.5, 0), Vector3(thickness, spring, depth))
	for i in 12:
		var a := PI * i / 12.0
		var b := PI * (i + 1) / 12.0
		var inner_a := Vector3(cos(a) * radius, spring + sin(a) * radius * 0.85, 0)
		var inner_b := Vector3(cos(b) * radius, spring + sin(b) * radius * 0.85, 0)
		var outer_a := Vector3(cos(a) * (radius + thickness), spring + sin(a) * (radius + thickness) * 0.85, 0)
		var outer_b := Vector3(cos(b) * (radius + thickness), spring + sin(b) * (radius + thickness) * 0.85, 0)
		var front := Vector3.BACK * depth * 0.5
		var back := -front
		var centre := (inner_a + inner_b + outer_a + outer_b) * 0.25
		_face(tool, inner_a + front, inner_b + front, outer_b + front, outer_a + front, centre)
		_face(tool, inner_b + back, inner_a + back, outer_a + back, outer_b + back, centre)
		_face(tool, inner_a + back, inner_b + back, inner_b + front, inner_a + front, centre)
		_face(tool, outer_b + back, outer_a + back, outer_a + front, outer_b + front, centre)
		_face(tool, inner_a + back, inner_a + front, outer_a + front, outer_a + back, centre)
		_face(tool, inner_b + front, inner_b + back, outer_b + back, outer_b + front, centre)
	return tool.commit()

static func _rock_mesh(radius: float, height: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var primitive := SphereMesh.new()
	primitive.radius = 1
	primitive.height = 2
	primitive.radial_segments = 10
	primitive.rings = 4
	var faces := primitive.get_faces()
	for part in 3:
		var scale := Vector3(radius * (0.72 if part == 0 else 0.44), height * (0.5 if part == 0 else 0.29), radius * (0.64 if part == 0 else 0.42))
		var centre := Vector3(0 if part == 0 else radius * (0.48 if part == 1 else -0.44), scale.y * 0.88, radius * (0.12 if part == 1 else -0.12))
		for i in range(0, faces.size(), 3):
			var a := faces[i] * scale + centre
			var b := faces[i + 1] * scale + centre
			var c := faces[i + 2] * scale + centre
			var normal := (b - a).cross(c - a).normalized()
			if normal.dot((a + b + c) / 3.0 - centre) < 0:
				normal = -normal
			NativeLandmarks3D._tri(tool, a, b, c, normal)
	return tool.commit()

static func _crystal_mesh(height: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for stem in 3:
		var radius := height * (0.13 if stem == 0 else 0.09)
		var centre := Vector3((stem - 1) * height * 0.15, 0, stem * height * 0.06)
		var top := centre + Vector3.UP * height * (1.0 if stem == 0 else 0.68)
		for i in 6:
			var a := centre + Vector3(cos(TAU * i / 6), 0, sin(TAU * i / 6)) * radius
			var b := centre + Vector3(cos(TAU * (i + 1) / 6), 0, sin(TAU * (i + 1) / 6)) * radius
			var high_a := a + Vector3.UP * top.y * 0.72
			var high_b := b + Vector3.UP * top.y * 0.72
			_face(tool, a, b, high_b, high_a, centre + Vector3.UP * top.y * 0.5)
			var normal := (high_b - high_a).cross(top - high_a).normalized()
			if normal.dot((top + high_a + high_b) / 3.0 - centre - Vector3.UP * top.y * 0.5) < 0:
				normal = -normal
			NativeLandmarks3D._tri(tool, high_a, high_b, top, normal)
			NativeLandmarks3D._tri(tool, centre, b, a, Vector3.DOWN)
	return tool.commit()

static func build(preview: Node, parent: Node3D, world: Node2D, cave: bool, excluded: Dictionary = {}) -> Dictionary:
	var root := Node3D.new()
	root.name = "NativeCaveScenery" if cave else "NativeFieldScenery"
	parent.add_child(root)
	var stone := StandardMaterial3D.new()
	stone.albedo_texture = load("res://assets/art/village/rock.webp")
	stone.uv1_triplanar = true
	stone.uv1_world_triplanar = true
	stone.uv1_scale = Vector3.ONE / 2.56
	stone.roughness = 0.95
	var crystal := StandardMaterial3D.new()
	crystal.albedo_color = Color("648889")
	crystal.roughness = 0.42
	crystal.metallic = 0.14
	var owned := {}
	var entries: Array[Dictionary] = []
	for child in world.get_children():
		if not child is IsoSprite or excluded.has(child.get_instance_id()) or child.clip != Vector2.ZERO or not child.visible:
			continue
		var source := child as IsoSprite
		var role := role_of(source, preview.game.village)
		if role.is_empty():
			continue
		var at := Ortho3DPreview.ground_position(source.global_position, preview.surface_height(source.global_position))
		var height := float(source.def["height"]) * source.k / SpatialWorld3D.VERTICAL
		var basis := Basis.IDENTITY
		var mesh: ArrayMesh
		var opening := 0.0
		if role == "arch":
			var corners: Array = source.def["opening"]
			var left := source.atlas_point(Vector2(corners[0][0], corners[0][1]))
			var right := source.atlas_point(Vector2(corners[1][0], corners[1][1]))
			var a := Ortho3DPreview.ground_position(left)
			var b := Ortho3DPreview.ground_position(right)
			at = (a + b) * 0.5
			var axis := (b - a).normalized()
			basis = Basis(axis, Vector3.UP, axis.cross(Vector3.UP))
			opening = a.distance_to(b)
			mesh = arch_mesh(opening, height)
		elif role == "entrance":
			# This is a scene-transition mouth, not a newly walkable floor.
			# Keep the existing circular cliff body behind its open frontal portal.
			var centre := Ortho3DPreview.ground_position(source.global_position + Vector2(0, -60))
			var forward := Vector3(1, 0, 1).normalized()
			var axis := Vector3(1, 0, -1).normalized()
			at = centre + forward * 0.85
			basis = Basis(axis, Vector3.UP, forward)
			opening = 1.40
			mesh = _entrance_mesh(minf(height, 3.4), SpatialWorld3D.radius_metres(120.0))
		elif role == "crystal":
			mesh = _crystal_mesh(height)
		else:
			var radius := 0.55
			for circle: Array in preview.game.village.circles:
				var point: Vector2 = circle[0]
				if point.distance_squared_to(source.global_position) < 0.001:
					radius = SpatialWorld3D.radius_metres(float(circle[1]))
					break
			mesh = _rock_mesh(radius, minf(height, 2.2))
		if mesh == null:
			continue
		var node := MeshInstance3D.new()
		node.name = "Native_" + role + "_" + str(entries.size())
		node.mesh = mesh
		node.material_override = crystal if role == "crystal" else stone
		node.transform = Transform3D(basis, at)
		root.add_child(node)
		if role == "entrance":
			var back := MeshInstance3D.new()
			var back_shape := BoxMesh.new()
			back_shape.size = Vector3(1.35, 3.3, 0.16)
			back.mesh = back_shape
			var dark := StandardMaterial3D.new()
			dark.albedo_color = Color("101c1b")
			dark.roughness = 1.0
			back.material_override = dark
			back.position = Vector3(0, 2.15, -0.97)
			back.name = "TunnelDepth"
			node.add_child(back)
		owned[source.get_instance_id()] = true
		entries.append({"source_id": source.get_instance_id(), "role": role, "source_foot": source.global_position, "transform": node.transform, "clear_width": opening, "mesh": mesh})
	var report := {"owned_source_ids": owned, "entries": entries, "root": root}
	root.set_meta("native_scenery_report", report)
	return report

static func _polygon_volume(tool: SurfaceTool, polygon: PackedVector2Array, bottom: float, top: float, broken := false) -> void:
	if polygon.size() < 3:
		return
	var centre := Vector3.ZERO
	var high := PackedVector3Array()
	var low := PackedVector3Array()
	var planar_centre := Vector2.ZERO
	for point in polygon:
		planar_centre += point
	planar_centre /= polygon.size()
	for i in polygon.size():
		var p := polygon[i]
		low.append(Vector3(p.x, bottom, p.y))
		var peak := top
		if broken:
			# The front descends toward the visible mouth; the rear is an irregular
			# rocky ridge, rather than a constant-height capped cylinder.
			peak -= 0.65 * clampf((p.y + 0.85) / 1.55, 0.0, 1.0)
			peak += 0.16 * sin(p.x * 3.1) + 0.13 * cos(p.y * 2.4)
		var roof_point := p.lerp(planar_centre, 0.14) if broken else p
		high.append(Vector3(roof_point.x, peak, roof_point.y))
		centre += low[-1]
	centre /= polygon.size()
	var indices := Geometry2D.triangulate_polygon(polygon)
	for i in range(0, indices.size(), 3):
		var a := high[indices[i]]
		var b := high[indices[i + 1]]
		var c := high[indices[i + 2]]
		var normal := (b - a).cross(c - a).normalized()
		if normal.y < 0:
			normal = -normal
		NativeLandmarks3D._tri(tool, a, b, c, normal)
		NativeLandmarks3D._tri(tool, low[indices[i]], low[indices[i + 2]], low[indices[i + 1]], Vector3.DOWN)
	for i in low.size():
		_face(tool, low[i], low[(i + 1) % low.size()], high[(i + 1) % high.size()], high[i], centre + Vector3.UP * (top - bottom) * 0.5)

static func _entrance_mesh(height: float, body_radius: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var circle := PackedVector2Array()
	for i in 16:
		circle.append(Vector2(cos(TAU * i / 16.0) * body_radius, -0.85 + sin(TAU * i / 16.0) * body_radius))
	# The original transition body is a solid cliff circle, not a freely walkable
	# doorway. A 0.50m visible ledge exceeds MAX_STEP and marks that whole envelope.
	_polygon_volume(tool, circle, 0.0, 0.50)
	var regions := [
		PackedVector2Array([Vector2(-5, -5), Vector2(-0.7, -5), Vector2(-0.7, 5), Vector2(-5, 5)]),
		PackedVector2Array([Vector2(0.7, -5), Vector2(5, -5), Vector2(5, 5), Vector2(0.7, 5)]),
		PackedVector2Array([Vector2(-0.7, -5), Vector2(0.7, -5), Vector2(0.7, -0.95), Vector2(-0.7, -0.95)])
	]
	for region: PackedVector2Array in regions:
		for polygon in Geometry2D.intersect_polygons(circle, region):
			_polygon_volume(tool, polygon, 0.5, height + 0.20, true)
	var vault := arch_mesh(1.4, height, 0.36, 1.25)
	var arrays := vault.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in range(0, points.size(), 3):
		var offset := Vector3(0, 0.5, -0.35)
		NativeLandmarks3D._tri(tool, points[i] + offset, points[i + 1] + offset, points[i + 2] + offset, normals[i])
	return tool.commit()

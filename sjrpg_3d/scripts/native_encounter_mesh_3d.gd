class_name NativeEncounterMesh3D
extends RefCounted
## Reproducible, fully sided metre geometry. No camera-facing asset planes.

const STONE_SIZE := Vector3(0.80, 1.58, 32.0 / 65.0)
const CHEST_WIDTH := 0.44
const CHEST_DEPTH := 0.26
const CHEST_RIM := 0.28
const LID_RADIUS := CHEST_DEPTH * 0.5
const OPEN_ANGLE := -65.0
const LID_PIVOT := Vector3(0, CHEST_RIM, -LID_RADIUS)
var _tools := {}
var _triangles := 0
var _unit: Array
var _merge_wood_iron := false


static func build() -> Dictionary:
	var stone := NativeEncounterMesh3D.new()
	stone._stone()
	var glyph := NativeEncounterMesh3D.new()
	glyph._glyph()
	var base := NativeEncounterMesh3D.new()
	base._merge_wood_iron = true
	base._chest_base()
	var lid := NativeEncounterMesh3D.new()
	lid._merge_wood_iron = true
	lid._chest_lid()
	var broken := NativeEncounterMesh3D.new()
	broken._merge_wood_iron = true
	broken._splinters()
	return {"stone": stone._finish(), "glyph": glyph._finish(), "base": base._finish(),
		"lid": lid._finish(), "splinters": broken._finish(),
		"stone_triangles": stone._triangles + glyph._triangles,
		"chest_triangles": base._triangles + lid._triangles + broken._triangles}


func _stone() -> void:
	_box(Vector3(0, 0.035, 0), Vector3(0.80, 0.07, STONE_SIZE.z), "stone")
	_box(Vector3(0, 0.115, 0), Vector3(0.72, 0.09, 0.42), "stone")
	_box(Vector3(0, 0.185, 0), Vector3(0.64, 0.05, 0.35), "stone")
	_prism(PackedVector2Array([Vector2(-0.25, 0.21), Vector2(0.25, 0.21), Vector2(0.25, 1.43), Vector2(0.19, 1.51), Vector2(0, 1.58), Vector2(-0.21, 1.51), Vector2(-0.25, 1.44)]), 0.26, Transform3D.IDENTITY, "stone")
	for side in [-1.0, 1.0]:
		for end in [-1.0, 1.0]:
			_box(Vector3(side * 0.29, 0.30, end * 0.15), Vector3(0.075, 0.22, 0.075), "stone")
		# Both faces have a real shallow frame around an inlaid marker.
		var face := Transform3D(Basis(Vector3.UP, 0.0 if side > 0 else PI), Vector3(0, 0, side * 0.131))
		var diamond := PackedVector2Array([Vector2(0, 0.68), Vector2(0.145, 1.04), Vector2(0, 1.40), Vector2(-0.145, 1.04)])
		for edge in 4:
			var a := diamond[edge]
			var b := diamond[(edge + 1) % 4]
			var vector := b - a
			var transform := face * Transform3D(Basis(Vector3.FORWARD, atan2(vector.x, vector.y)), Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, 0.012))
			_box_at(transform, Vector3(0.035, vector.length() + 0.018, 0.025), "stone")


func _glyph() -> void:
	for side in [-1.0, 1.0]:
		var face := Transform3D(Basis(Vector3.UP, 0.0 if side > 0 else PI), Vector3(0, 0, side * 0.133))
		var outer := PackedVector2Array([Vector2(0, 0.72), Vector2(0.118, 1.04), Vector2(0, 1.36), Vector2(-0.118, 1.04)])
		_prism(outer, 0.008, face, "iron")
		var diamond := PackedVector2Array([Vector2(0, 0.78), Vector2(0.089, 1.04), Vector2(0, 1.30), Vector2(-0.089, 1.04)])
		_prism(diamond, 0.008, face.translated_local(Vector3(0, 0, 0.006)), "rune")
		var core := PackedVector2Array([Vector2(0, 0.94), Vector2(0.043, 1.04), Vector2(0, 1.14), Vector2(-0.043, 1.04)])
		_prism(core, 0.008, face.translated_local(Vector3(0, 0, 0.011)), "iron")


func _chest_base() -> void:
	# An actual empty box: separate walls and bottom, no solid block hiding its interior.
	_box(Vector3(0, 0.026, 0), Vector3(CHEST_WIDTH, 0.052, CHEST_DEPTH), "wood")
	for side in [-1.0, 1.0]:
		_box(Vector3(0, 0.16, side * 0.118), Vector3(CHEST_WIDTH, 0.24, 0.024), "wood")
		_box(Vector3(side * 0.208, 0.16, 0), Vector3(0.024, 0.24, CHEST_DEPTH - 0.048), "wood")
		for level in [0.075, 0.255]:
			_box(Vector3(0, level, side * 0.133), Vector3(CHEST_WIDTH + 0.008, 0.037, 0.008), "iron")
			_box(Vector3(side * 0.224, level, 0), Vector3(0.008, 0.037, CHEST_DEPTH + 0.008), "iron")
		for end in [-1.0, 1.0]:
			_box(Vector3(side * 0.145, 0.16, end * 0.133), Vector3(0.025, 0.20, 0.008), "iron")
			for level in [0.08, 0.25]:
				_octahedron(Vector3(side * 0.145, level, end * 0.141), 0.009, "iron")
		# Actual rear hinge knuckles remain with the box, while the lid pivots here.
		_box(Vector3(side * 0.145, CHEST_RIM - 0.014, -0.135), Vector3(0.052, 0.035, 0.025), "iron")
	_box(Vector3(0, 0.228, 0.139), Vector3(0.055, 0.080, 0.012), "iron")
	_box(Vector3(0, 0.237, 0.147), Vector3(0.012, 0.025, 0.006), "iron")


func _chest_lid() -> void:
	var rotation := Basis(Vector3.UP, PI * 0.5)
	var profile := PackedVector2Array()
	for index in 13:
		var angle: float = PI * index / 12.0
		profile.append(Vector2(LID_RADIUS * cos(angle), LID_RADIUS * sin(angle)))
	for index in range(12, -1, -1):
		var angle: float = PI * index / 12.0
		profile.append(Vector2((LID_RADIUS - 0.018) * cos(angle), (LID_RADIUS - 0.018) * sin(angle)))
	var origin := Vector3(0, 0, LID_RADIUS)
	_prism(profile, CHEST_WIDTH, Transform3D(rotation, origin), "wood")
	var end_profile := PackedVector2Array()
	for index in 13:
		var angle: float = PI * index / 12.0
		end_profile.append(Vector2(LID_RADIUS * cos(angle), LID_RADIUS * sin(angle)))
	for side in [-1.0, 1.0]:
		_prism(end_profile, 0.016, Transform3D(rotation, origin + Vector3(side * (CHEST_WIDTH * 0.5 - 0.008), 0, 0)), "wood")
		var band := PackedVector2Array()
		for index in 13:
			var angle: float = PI * index / 12.0
			band.append(Vector2((LID_RADIUS + 0.007) * cos(angle), (LID_RADIUS + 0.007) * sin(angle)))
		for index in range(12, -1, -1):
			var angle: float = PI * index / 12.0
			band.append(Vector2((LID_RADIUS + 0.001) * cos(angle), (LID_RADIUS + 0.001) * sin(angle)))
		_prism(band, 0.027, Transform3D(rotation, origin + Vector3(side * 0.145, 0, 0)), "iron")
		for index in [1, 4, 7, 10]:
			var angle: float = PI * index / 12.0
			_octahedron(Vector3(side * 0.145, (LID_RADIUS + 0.011) * sin(angle), LID_RADIUS + (LID_RADIUS + 0.011) * cos(angle)), 0.007, "iron")


func _splinters() -> void:
	for side in [-1.0, 1.0]:
		var points := PackedVector2Array([Vector2(-0.032, 0), Vector2(0.029, 0), Vector2(0.009, 0.070), Vector2(-0.008, 0.040), Vector2(-0.020, 0.095)])
		_prism(points, 0.018, Transform3D(Basis(Vector3.UP, side * 0.25), Vector3(side * 0.12, CHEST_RIM - 0.018, 0.065)), "wood")


func _box(center: Vector3, size: Vector3, slot: String) -> void:
	_box_at(Transform3D(Basis.IDENTITY, center), size, slot)


func _box_at(transform: Transform3D, size: Vector3, slot: String) -> void:
	if _unit.is_empty():
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		_unit = box.surface_get_arrays(0)
	var vertices: PackedVector3Array = _unit[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = _unit[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = _unit[Mesh.ARRAY_INDEX]
	for index in range(0, indices.size(), 3):
		_triangle(transform * (vertices[indices[index]] * size), transform * (vertices[indices[index + 1]] * size), transform * (vertices[indices[index + 2]] * size), transform.basis * normals[indices[index]], slot)


func _prism(outline: PackedVector2Array, depth: float, transform: Transform3D, slot: String) -> void:
	var indices := Geometry2D.triangulate_polygon(outline)
	for side in [-1.0, 1.0]:
		for index in range(0, indices.size(), 3):
			var vertices := PackedVector3Array()
			for corner in 3:
				var point := outline[indices[index + corner]]
				vertices.append(transform * Vector3(point.x, point.y, side * depth * 0.5))
			_triangle(vertices[0], vertices[1], vertices[2], transform.basis * Vector3(0, 0, side), slot)
	for index in outline.size():
		var first := outline[index]
		var last := outline[(index + 1) % outline.size()]
		var edge := last - first
		var normal := transform.basis * Vector3(edge.y, -edge.x, 0).normalized()
		var a := transform * Vector3(first.x, first.y, -depth * 0.5)
		var b := transform * Vector3(first.x, first.y, depth * 0.5)
		var c := transform * Vector3(last.x, last.y, depth * 0.5)
		var d := transform * Vector3(last.x, last.y, -depth * 0.5)
		_triangle(a, b, c, normal, slot)
		_triangle(a, c, d, normal, slot)


func _octahedron(center: Vector3, radius: float, slot: String) -> void:
	for side in [-1.0, 1.0]:
		var top := center + Vector3(0, radius * side, 0)
		for edge in 4:
			var first := center + Vector3(cos(edge * PI * 0.5), 0, sin(edge * PI * 0.5)) * radius
			var last := center + Vector3(cos((edge + 1) * PI * 0.5), 0, sin((edge + 1) * PI * 0.5)) * radius
			_triangle(top, first, last, ((top + first + last) / 3.0 - center).normalized(), slot)


func _triangle(a: Vector3, b: Vector3, c: Vector3, expected: Vector3, slot: String) -> void:
	var cross := (b - a).cross(c - a)
	if cross.length_squared() <= 0.0000000001:
		return
	var normal := cross.normalized()
	if normal.dot(expected) < 0.0:
		normal = -normal
	var group := "chest" if _merge_wood_iron else slot
	if not _tools.has(group):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[group] = tool
	var output: SurfaceTool = _tools[group]
	for vertex: Vector3 in ([a, c, b] if cross.dot(normal) > 0.0 else [a, b, c]):
		output.set_normal(normal)
		# Metre UVs keep the shared timber tile consistent on all six faces.
		var dominant := normal.abs().max_axis_index()
		output.set_uv(Vector2(vertex.z, vertex.y) if dominant == 0 else Vector2(vertex.x, vertex.z) if dominant == 1 else Vector2(vertex.x, vertex.y))
		output.set_color(Color(1, 0, 0) if slot == "iron" else Color(0, 0, 0))
		output.add_vertex(vertex)
	_triangles += 1


func _finish() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for slot: String in _tools:
		var output: SurfaceTool = _tools[slot]
		output.index()
		output.commit(mesh)
		mesh.surface_set_name(mesh.get_surface_count() - 1, slot)
	return mesh

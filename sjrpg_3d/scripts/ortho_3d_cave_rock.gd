class_name Ortho3DCaveRock
extends RefCounted
## Closed rock volumes on the existing cave union boundary, never camera cards.
## The inner toe uses the same4cm inset as SpatialWorld3D's8cm boundary boxes.

const COLLISION_INSET := 0.04
const OUTER_DEPTH := 1.05
const TILE_METRES := 2.6
const STRIP_METRES := 0.80
const CHUNK_METRES := 12.0
const FRONT_HEIGHT := 0.45
const CHAMBER_HEIGHT := 3.50
const CORRIDOR_HEIGHT := 1.45
const PROFILE := [Vector2(-COLLISION_INSET, 0), Vector2(-COLLISION_INSET, 0.20), Vector2(0.05, 0.55), Vector2(0.17, 0.83), Vector2(0.26, 1.0), Vector2(0.75, 0.97), Vector2(OUTER_DEPTH, 0.62), Vector2(OUTER_DEPTH, 0)]

var _tools := {}
var _corners := {}
var _triangles := 0


static func build(layout: DungeonLayout, parent: Node3D, texture: Texture2D, boundary_sources: Array[Dictionary]) -> Dictionary:
	var builder := Ortho3DCaveRock.new()
	return builder._build(layout, parent, texture, boundary_sources)


func _build(layout: DungeonLayout, parent: Node3D, texture: Texture2D, segments: Array[Dictionary]) -> Dictionary:
	for segment in segments:
		var height := _base_height(segment)
		for point: Vector2 in [segment["a"], segment["b"]]:
			var key := _key(point)
			if not _corners.has(key):
				_corners[key] = {"normals": [], "height": height}
			var corner: Dictionary = _corners[key]
			var normals: Array = corner["normals"]
			if not normals.has(segment["outward"]):
				normals.append(segment["outward"])
			corner["height"] = minf(float(corner["height"]), height)
	var profiles: Array[Dictionary] = []
	var cutaways := 0
	for segment in segments:
		var a: Vector2 = segment["a"]
		var b: Vector2 = segment["b"]
		var outward: Vector2 = segment["outward"]
		var height := _base_height(segment)
		if height == FRONT_HEIGHT:
			cutaways += 1
		var count := maxi(1, ceili(a.distance_to(b) / (SpatialWorld3D.UNITS * STRIP_METRES)))
		var last := PackedVector3Array()
		var first := PackedVector3Array()
		for station in count + 1:
			var point := a.lerp(b, float(station) / count)
			var direction := outward
			var native_height := height
			if station == 0 or station == count:
				var corner: Dictionary = _corners[_key(point)]
				native_height = float(corner["height"])
				var normals: Array = corner["normals"]
				if normals.size() == 2:
					var other: Vector2 = normals[0] if normals[1] == outward else normals[1]
					direction = (outward + other) / maxf(0.25, 1.0 + outward.dot(other))
			# Deterministic shared endpoint height prevents cracks between turns.
			native_height *= 0.92 + 0.08 * absf(sin(point.dot(Vector2(0.017, 0.031))))
			var section := PackedVector3Array()
			for offset: Vector2 in PROFILE:
				var flat := point / SpatialWorld3D.UNITS + direction * offset.x
				section.append(Vector3(flat.x, native_height * offset.y, flat.y))
			if station == 0:
				first = section
			if not last.is_empty():
				for face in PROFILE.size():
					var next := (face + 1) % PROFILE.size()
					var edge: Vector2 = PROFILE[next] - PROFILE[face]
					var expected := Vector3(outward.x * -edge.y, edge.x, outward.y * -edge.y)
					_triangle(last[face], section[face], section[next], expected)
					_triangle(last[face], section[next], last[next], expected)
			last = section
		profiles.append({"a": a, "b": b, "outward": outward, "height": height, "strips": count,
			"section_a": first, "section_b": last})
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = Color(0.92, 0.94, 0.91)
	material.roughness = 0.96
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / TILE_METRES
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var meshes: Array[MeshInstance3D] = []
	for chunk: int in _tools:
		var tool: SurfaceTool = _tools[chunk]
		tool.index()
		var mesh := MeshInstance3D.new()
		mesh.name = "CaveRockChunk_%d" % chunk
		mesh.mesh = tool.commit()
		mesh.material_override = material
		mesh.set_meta("native_cave_boundary", true)
		parent.add_child(mesh)
		meshes.append(mesh)
	var result := {"segments": segments.size(), "profiles": profiles, "corners": _corners.size(),
		"front_cutaways": cutaways, "meshes": meshes, "groups": meshes.size(), "triangles": _triangles,
		"material": material, "tile_metres": TILE_METRES, "outer_depth": OUTER_DEPTH,
		"collision_inset": COLLISION_INSET, "layout_id": layout.get_instance_id()}
	parent.set_meta("native_cave_rock", result)
	return result


static func _key(point: Vector2) -> String:
	return "%d:%d" % [roundi(point.x), roundi(point.y)]


static func _base_height(segment: Dictionary) -> float:
	var outward: Vector2 = segment["outward"]
	if Iso.project(outward).y >= 0.0:
		return FRONT_HEIGHT
	var a: Vector2 = segment["a"]
	var b: Vector2 = segment["b"]
	for fraction in [0.25, 0.5, 0.75]:
		var inside := a.lerp(b, fraction) - outward * 4.0
		for room: Vector2 in DungeonLayout.ROOMS:
			if Rect2(room - Vector2(300, 300), Vector2(600, 600)).has_point(inside):
				return CHAMBER_HEIGHT
		if Rect2(-220, -220, 440, 440).has_point(inside) or Rect2(4500, -220, 420, 440).has_point(inside):
			return CHAMBER_HEIGHT
	return CORRIDOR_HEIGHT


func _triangle(a: Vector3, b: Vector3, c: Vector3, expected: Vector3) -> void:
	var cross := (b - a).cross(c - a)
	if cross.length_squared() <= 0.0000000001:
		return
	var normal := cross.normalized()
	if normal.dot(expected) < 0.0:
		normal = -normal
	var chunk := floori(((a.x + b.x + c.x) / 3.0) / CHUNK_METRES)
	if not _tools.has(chunk):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[chunk] = tool
	var output: SurfaceTool = _tools[chunk]
	var vertices := [a, c, b] if cross.dot(normal) > 0.0 else [a, b, c]
	for vertex: Vector3 in vertices:
		output.set_normal(normal)
		output.set_uv(Vector2(vertex.x, vertex.z) / TILE_METRES)
		output.add_vertex(vertex)
	_triangles += 1

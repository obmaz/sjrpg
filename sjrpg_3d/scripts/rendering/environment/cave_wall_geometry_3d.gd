class_name CaveWallGeometry3D
extends RefCounted
## 같은 동굴 합집합 경계에 층리·돌출 암반·절단부 깊이를 갖는 닫힌 체적을 만든다.
## 보행 안쪽 발끝은 물리 경계와 같은4cm를 유지하며 굴곡은 바깥쪽 질량에만 둔다.

const COLLISION_INSET := 0.04
const OUTER_DEPTH := 1.60
const FOUNDATION_DEPTH := 1.35
const TILE_METRES := 2.6
const OUTER_TILE_METRES := 2.6
const INNER := "inner"
const OUTER := "outer"
const STRIP_METRES := 0.80

const FRONT_HEIGHT := 0.32
const CHAMBER_HEIGHT := 3.50
const CORRIDOR_HEIGHT := 1.45
const PROFILE := [Vector2(-COLLISION_INSET, 0), Vector2(-COLLISION_INSET, 0.04), Vector2(0.30, 0.45), Vector2(0.16, 0.78), Vector2(0.36, 1.0), Vector2(0.98, 0.94), Vector2(OUTER_DEPTH, 0.52), Vector2(OUTER_DEPTH, -FOUNDATION_DEPTH)]

var _tools := {}
var _corners := {}
var _triangles := 0
var _segment_id := -1
var _rubble_footprints: Array[PackedVector2Array] = []


static func build(layout: DungeonLayout, parent: Node3D, boundary_sources: Array[Dictionary]) -> Dictionary:
	var builder := CaveWallGeometry3D.new()
	return builder._build(layout, parent, boundary_sources)


func _build(layout: DungeonLayout, parent: Node3D, segments: Array[Dictionary]) -> Dictionary:
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
		_segment_id += 1
		var a: Vector2 = segment["a"]
		var b: Vector2 = segment["b"]
		var outward: Vector2 = segment["outward"]
		var height := _base_height(segment)
		if height == FRONT_HEIGHT:
			cutaways += 1
		var count := maxi(1, ceili(a.distance_to(b) / (WorldSpace3D.GROUND_UNITS_PER_METER * STRIP_METRES)))
		var last := PackedVector3Array()
		var first := PackedVector3Array()
		var sections: Array[PackedVector3Array] = []
		for station in count + 1:
			var point := a.lerp(b, float(station) / count)
			var direction := outward
			var first_corner: Dictionary = _corners[_key(a)]
			var last_corner: Dictionary = _corners[_key(b)]
			var from_first := point.distance_to(a) / WorldSpace3D.GROUND_UNITS_PER_METER
			var from_last := point.distance_to(b) / WorldSpace3D.GROUND_UNITS_PER_METER
			# 전경 절단부로 연결되는 높이를2m에 걸쳐 낮춰 날카로운 삼각 벽 끝을 피한다.
			var native_height := minf(
				lerpf(float(first_corner["height"]), height, smoothstep(0.0, 2.0, from_first)),
				lerpf(float(last_corner["height"]), height, smoothstep(0.0, 2.0, from_last))
			)
			if station == 0 or station == count:
				var corner: Dictionary = _corners[_key(point)]
				native_height = float(corner["height"])
				var normals: Array = corner["normals"]
				if normals.size() == 2:
					var other: Vector2 = normals[0] if normals[1] == outward else normals[1]
					direction = (outward + other) / maxf(0.25, 1.0 + outward.dot(other))
			# 세계 좌표의 같은 지층 함수를 써서 꺾이는 두 구간의 모든 끝점을 맞춘다.
			var native_point := point / WorldSpace3D.GROUND_UNITS_PER_METER
			native_height *= .91 + .10 * sin(native_point.dot(Vector2(.77, .43)))
			var section := PackedVector3Array()
			for index in PROFILE.size():
				var offset: Vector2 = PROFILE[index]
				var depth := offset.x
				# 횃불 높이의 두 면은 같은 요철을 공유해 수직 장착 패치를 남긴다.
				var layer_phase := 2.4 if index in [2, 3] else float(index) * 1.37
				var layer := sin(native_point.dot(Vector2(.83, -.41)) + layer_phase)
				if index in [2, 3, 4, 5, 6]:
					depth = maxf(.025, depth + layer * .085 + sin(native_point.x * .31 + native_point.y * .67) * .055)
				var flat := native_point + direction * depth
				var vertical := native_height * offset.y
				if index == PROFILE.size() - 1:
					vertical = -FOUNDATION_DEPTH * (1.0 + .10 * sin(native_point.x * .41 + native_point.y * .57))
				elif index in [2, 3, 4, 5, 6]:
					vertical += layer * .020 * minf(1.0, native_height)
				section.append(Vector3(flat.x, DungeonRelief.flat_height(flat * WorldSpace3D.GROUND_UNITS_PER_METER) + vertical, flat.y))
			sections.append(section)
			if station == 0:
				first = section
			if not last.is_empty():
				for face in PROFILE.size():
					var next := (face + 1) % PROFILE.size()
					var edge: Vector2 = PROFILE[next] - PROFILE[face]
					var expected := Vector3(outward.x * -edge.y, edge.x, outward.y * -edge.y)
					# The real ridge is PROFILE[4], not a painted horizontal boundary.
					var role := INNER if face < 4 else OUTER
					var cap_uv := face in [4, 5, 7]
					_triangle(last[face], section[face], section[next], expected, outward, role, cap_uv)
					_triangle(last[face], section[next], last[next], expected, outward, role, cap_uv)
			last = section
		_add_wall_fragments(a, b, outward, height)
		profiles.append({"a": a, "b": b, "outward": outward, "height": height, "strips": count,
			"section_a": first, "section_b": last, "sections": sections})
	# The inside and exposed rock share geometry, but not a triplanar skin.
	# Explicit metre UVs avoid blending floor-like XZ stone into upright faces.
	var material := NativeCaveSurfaces.material("wall")
	var outer := NativeCaveSurfaces.material("wall",true)
	var materials := {INNER: material, OUTER: outer}
	var meshes: Array[MeshInstance3D] = []
	var surfaces := 0
	for chunk: int in _tools:
		var tools: Dictionary = _tools[chunk]
		var volume := ArrayMesh.new()
		for role: String in [INNER, OUTER]:
			if not tools.has(role):
				continue
			var tool: SurfaceTool = tools[role]
			tool.index()
			tool.commit(volume)
			volume.surface_set_material(volume.get_surface_count() - 1, materials[role])
		var mesh := MeshInstance3D.new()
		mesh.name = "CaveRockChunk_%d" % chunk
		NativePlayerOcclusion.mark_object(mesh)
		mesh.mesh = volume
		mesh.set_meta("native_cave_boundary", true)
		mesh.set_meta("cave_wall_segment", chunk)
		parent.add_child(mesh)
		meshes.append(mesh)
		surfaces += volume.get_surface_count()
	var result := {"segments": segments.size(), "profiles": profiles, "corners": _corners.size(),
		"front_cutaways": cutaways, "meshes": meshes, "groups": meshes.size(), "triangles": _triangles,
		"material": material, "materials": materials, "surfaces": surfaces,
		"tile_metres": TILE_METRES, "outer_tile_metres": OUTER_TILE_METRES, "outer_depth": OUTER_DEPTH,
		"collision_inset": COLLISION_INSET, "rubble_footprints": _rubble_footprints, "rubble_pieces": _rubble_footprints.size(), "foundation_depth": FOUNDATION_DEPTH, "sculpt_recipe": "layered-cutaway-v2", "layout_id": layout.get_instance_id()}
	parent.set_meta("native_cave_rock", result)
	return result


## 중앙 통로에 돌을 흩뿌리지 않고 기존 경계 바깥의 암반 부피에 파쇄층을 붙인다.
func _add_wall_fragments(a: Vector2, b: Vector2, outward: Vector2, height: float) -> void:
	var length := a.distance_to(b) / WorldSpace3D.GROUND_UNITS_PER_METER
	if height == FRONT_HEIGHT or length < 2.4:
		return
	var count := maxi(1, floori(length / 3.4))
	var tangent := (b - a).normalized()
	for index in count:
		var seed := sin(a.dot(Vector2(.0137, .0231)) + b.dot(Vector2(.0173, -.0119)) + float(index) * 3.73)
		var variety := absf(sin(seed * 19.73 + 4.1))
		var fraction := (float(index) + .24 + variety * .50) / float(count)
		var width := .72 + variety * .46
		var end_clearance := (width * .62 + .06) / length
		fraction = clampf(fraction, end_clearance, 1.0 - end_clearance)
		var boundary := a.lerp(b, fraction) / WorldSpace3D.GROUND_UNITS_PER_METER
		var depth := .42 + absf(sin(seed * 11.31)) * .22
		var rise := .58 + absf(cos(seed * 7.7)) * .27
		var centre := boundary + outward * (depth * .5 + .015)
		var footprint := PackedVector2Array()
		var lower := PackedVector3Array()
		var upper := PackedVector3Array()
		var plan := [Vector2(-.50, -.28), Vector2(-.20, -.50), Vector2(.35, -.42), Vector2(.55, .10), Vector2(.18, .50), Vector2(-.45, .35)]
		for corner in plan.size():
			var offset: Vector2 = plan[corner]
			var base := centre + tangent * offset.x * width + outward * offset.y * depth
			var top := centre + tangent * (offset.x * .68 + .07) * width + outward * (offset.y * .72 - .12) * depth
			footprint.append(base)
			footprint.append(top)
			lower.append(Vector3(base.x, DungeonRelief.flat_height(base * 65) - .018, base.y))
			upper.append(Vector3(top.x, DungeonRelief.flat_height(top * 65) + rise * (.90 + .08 * sin(float(corner) * 1.91 + seed)), top.y))
		_rubble_footprints.append(Geometry2D.convex_hull(footprint))
		var lower_centre := Vector3.ZERO
		var upper_centre := Vector3.ZERO
		for corner in plan.size():
			lower_centre += lower[corner]
			upper_centre += upper[corner]
		lower_centre /= plan.size()
		upper_centre /= plan.size()
		var centre_3d := (lower_centre + upper_centre) * .5
		for corner in plan.size():
			var next := (corner + 1) % plan.size()
			_fragment_triangle(lower[corner], lower[next], upper[next], centre_3d, outward)
			_fragment_triangle(lower[corner], upper[next], upper[corner], centre_3d, outward)
			_fragment_triangle(lower_centre, lower[next], lower[corner], centre_3d, outward)
			_fragment_triangle(upper_centre, upper[corner], upper[next], centre_3d, outward)


func _fragment_triangle(a: Vector3, b: Vector3, c: Vector3, centre: Vector3, outward: Vector2) -> void:
	_triangle(a, b, c, (a + b + c) / 3.0 - centre, outward, OUTER, true)


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


func _triangle(a: Vector3, b: Vector3, c: Vector3, expected: Vector3, outward: Vector2, role: String, cap_uv: bool) -> void:
	var cross := (b - a).cross(c - a)
	if cross.length_squared() <= 0.0000000001:
		return
	var normal := cross.normalized()
	if normal.dot(expected) < 0.0:
		normal = -normal
	var chunk := _segment_id
	if not _tools.has(chunk):
		_tools[chunk] = {}
	var tools: Dictionary = _tools[chunk]
	if not tools.has(role):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[role] = tool
	var output: SurfaceTool = tools[role]
	var tile := TILE_METRES if role == INNER else OUTER_TILE_METRES
	var vertices := [a, c, b] if cross.dot(normal) > 0.0 else [a, b, c]
	for vertex: Vector3 in vertices:
		output.set_normal(normal)
		output.set_uv(_surface_uv(vertex, outward, cap_uv) / tile)
		output.add_vertex(vertex)
	_triangles += 1


static func _surface_uv(vertex: Vector3, outward: Vector2, cap: bool) -> Vector2:
	if cap:
		return Vector2(vertex.x, vertex.z)
	# Fixed per boundary face, so both triangles of a strip have the same chart.
	# Texture V is native height on every upright wall, including reverse faces.
	return Vector2(vertex.z if absf(outward.x) > 0.5 else vertex.x, vertex.y)


static func floor_material() -> ShaderMaterial:
	return NativeCaveSurfaces.material("floor")

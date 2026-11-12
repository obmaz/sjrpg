class_name NativeCaveSculptor
extends RefCounted
## 밀도장에서 연속 암반을 만들고 하강 통로를 실제로 뚫는다.
const PITCH := 0.30
const TETRA := [[0, 1, 3, 7], [0, 3, 2, 7], [0, 2, 6, 7], [0, 6, 4, 7], [0, 4, 5, 7], [0, 5, 1, 7]]
const EDGES := [[0, 1], [0, 2], [0, 3], [1, 2], [1, 3], [2, 3]]
static var _cached: ArrayMesh
static var _noise: FastNoiseLite
static var _border := PackedVector2Array()


static func _hill_height(p: Vector2) -> float:
	var q := p - Vector2(0, -NativeCavePlan.front_offset())
	var peak_a := 4.65 * exp(-Vector2((q.x + 1.1) / 4.3, (q.y + 0.6) / 4.9).length_squared())
	var peak_b := 4.10 * exp(-Vector2((q.x - 2.6) / 3.6, (q.y - 1.4) / 3.7).length_squared())
	var shoulder := 3.85 * exp(-Vector2((p.x + 0.25) / 4.0, (p.y + 1.6) / 3.0).length_squared())
	var distance := INF
	for i: int in _border.size():
		distance = minf(
			distance,
			p.distance_to(
				Geometry2D.get_closest_point_to_segment(
					p, _border[i], _border[(i + 1) % _border.size()]
				)
			)
		)
	var stratum := 0.12 * sin(p.y * 3.4 + p.x * 1.1 + sin(p.x * 2.5) * 0.7)
	return maxf(
		0.015, (maxf(maxf(peak_a, peak_b), shoulder) + stratum) * smoothstep(0.0, 0.85, distance)
	)


static func _field(p: Vector3) -> float:
	var q := Vector2(p.x, p.z)
	var boundary := INF
	for i: int in _border.size():
		boundary = minf(
			boundary,
			q.distance_to(
				Geometry2D.get_closest_point_to_segment(
					q, _border[i], _border[(i + 1) % _border.size()]
				)
			)
		)
	if Geometry2D.is_point_in_polygon(q, _border):
		boundary = -boundary
	var fracture := _noise.get_noise_3d(p.x * 1.1, p.y * 2.8, p.z * 1.1) * 0.12
	var body := maxf(maxf(p.y - _hill_height(q) + fracture, boundary), -1.60 - p.y)
	var floor_y := NativeCavePlan.floor_height(p.z)
	var width := lerpf(1.96, 1.56, clampf(-p.z / 3.5, 0.0, 1.0))
	var arch := (pow(p.x / width, 2.0) + pow((p.y - floor_y - 0.20) / 2.95, 2.0) - 1.0) * 1.5
	var tunnel := maxf(maxf(arch, floor_y - 0.065 - p.y), -3.50 - p.z)
	return maxf(body, -tunnel)


static func _normal(p: Vector3) -> Vector3:
	var e := 0.025
	return (
		Vector3(
			_field(p + Vector3(e, 0, 0)) - _field(p - Vector3(e, 0, 0)),
			_field(p + Vector3(0, e, 0)) - _field(p - Vector3(0, e, 0)),
			_field(p + Vector3(0, 0, e)) - _field(p - Vector3(0, 0, e))
		)
		. normalized()
	)


static func _tetra(tool: SurfaceTool, points: Array[Vector3], values: Array[float]) -> void:
	var cuts: Array[Vector3] = []
	for edge: Array in EDGES:
		var a: int = edge[0]
		var b: int = edge[1]
		if (values[a] < 0.0) == (values[b] < 0.0):
			continue
		cuts.append(points[a].lerp(points[b], values[a] / (values[a] - values[b])))
	if cuts.size() < 3:
		return
	var centre := Vector3.ZERO
	for p: Vector3 in cuts:
		centre += p
	centre /= cuts.size()
	var normal := _normal(centre)
	var axis := normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).normalized()
	var across := normal.cross(axis)
	cuts.sort_custom(
		func(a: Vector3, b: Vector3) -> bool:
			return (
				atan2((a - centre).dot(across), (a - centre).dot(axis))
				< atan2((b - centre).dot(across), (b - centre).dot(axis))
			)
	)
	for i in range(1, cuts.size() - 1):
		var a := cuts[0]
		var b := cuts[i]
		var c := cuts[i + 1]
		if (b - a).cross(c - a).length_squared() < 0.00000001:
			continue
		if (b - a).cross(c - a).dot(normal) < 0.0:
			var swap := b
			b = c
			c = swap
		for vertex: Vector3 in [a, c, b]:
			tool.set_normal(_normal(vertex))
			tool.set_uv(Vector2(vertex.x, vertex.z) / 3.2)
			tool.add_vertex(vertex)


static func mesh(_height: float, body_radius: float) -> ArrayMesh:
	if _cached != null:
		return _cached
	_noise = FastNoiseLite.new()
	_noise.seed = 3917
	_noise.frequency = 1.0
	_noise.fractal_octaves = 3
	_border = NativeCavePlan.outline(body_radius)
	var bounds := Iso.poly_bounds(_border).grow(PITCH)
	var nx := ceili(bounds.size.x / PITCH) + 1
	var nz := ceili(bounds.size.y / PITCH) + 1
	var ny := ceili(7.6 / PITCH) + 1
	var origin := Vector3(bounds.position.x, -1.8, bounds.position.y)
	var samples := PackedFloat32Array()
	samples.resize(nx * nz * ny)
	for y: int in ny:
		for z: int in nz:
			for x: int in nx:
				samples[(y * nz + z) * nx + x] = _field(origin + Vector3(x, y, z) * PITCH)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var offsets := [
		Vector3i(0, 0, 0),
		Vector3i(1, 0, 0),
		Vector3i(0, 0, 1),
		Vector3i(1, 0, 1),
		Vector3i(0, 1, 0),
		Vector3i(1, 1, 0),
		Vector3i(0, 1, 1),
		Vector3i(1, 1, 1)
	]
	for y in ny - 1:
		for z in nz - 1:
			for x in nx - 1:
				var points: Array[Vector3] = []
				var values: Array[float] = []
				for offset: Vector3i in offsets:
					var q := Vector3i(x, y, z) + offset
					points.append(origin + Vector3(q) * PITCH)
					values.append(samples[(q.y * nz + q.z) * nx + q.x])
				if values.min() >= 0.0 or values.max() < 0.0:
					continue
				for t: Array in TETRA:
					_tetra(
						tool,
						[points[t[0]], points[t[1]], points[t[2]], points[t[3]]],
						[values[t[0]], values[t[1]], values[t[2]], values[t[3]]]
					)
	_cached = tool.commit()
	return _cached

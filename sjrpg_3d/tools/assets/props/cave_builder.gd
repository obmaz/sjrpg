class_name NativeCaveSculptor
extends RefCounted
## 밀도장에서 연속 암반을 만들고 하강 통로를 실제로 뚫는다.
const PITCH := 0.31
const TETRA := [[0, 1, 3, 7], [0, 3, 2, 7], [0, 2, 6, 7], [0, 6, 4, 7], [0, 4, 5, 7], [0, 5, 1, 7]]
const EDGES := [[0, 1], [0, 2], [0, 3], [1, 2], [1, 3], [2, 3]]
static var _cached: ArrayMesh
static var _noise: FastNoiseLite
static var _border := PackedVector2Array()


static func _hill_height(p: Vector2, edge_distance: float) -> float:
	var q := p - Vector2(0, -NativeCavePlan.front_offset())
	var peak_a := 5.80 * exp(-Vector2((q.x + 1.25) / 4.3, (q.y + 0.7) / 4.9).length_squared())
	var peak_b := 4.85 * exp(-Vector2((q.x - 2.6) / 3.6, (q.y - 1.4) / 3.7).length_squared())
	var shoulder := 3.65 * exp(-Vector2((p.x + 0.25) / 4.0, (p.y + 1.6) / 3.0).length_squared())
	var height := maxf(maxf(peak_a, peak_b), shoulder)
	# 실제 경사에 넓은 층리 단을 만들고 미세 노이즈로 암반 구조를 대신하지 않는다.
	var tilted := height + p.x * .16 + p.y * .07
	var bed := floorf(tilted / .48) * .48
	height = lerpf(tilted, bed, .40) - p.x * .16 - p.y * .07
	var cleft := pow(maxf(0.0, 1.0 - absf(sin(p.x * .67 + p.y * .19))), 9.0) * .24
	return maxf(.015, (height - cleft) * smoothstep(0.0, .85, edge_distance))


## 같은 암반에서 뻗는 낮고 넓은 돌출 층. 터널 빼기 전에 합쳐 독립 박스를 붙이지 않는다.
static func _plate_field(p: Vector3, centre: Vector3, half_size: Vector3, yaw: float) -> float:
	var offset := p - centre
	var horizontal := Vector2(offset.x, offset.z).rotated(-yaw)
	var local := Vector3(horizontal.x, offset.y + horizontal.x * .10 + horizontal.y * .07, horizontal.y)
	var distance := local.abs() - half_size
	return distance.max(Vector3.ZERO).length() + minf(maxf(distance.x, maxf(distance.y, distance.z)), 0.0) - .075


static func _field(p: Vector3) -> float:
	var q := Vector2(p.x, p.z)
	var boundary := INF
	for i: int in _border.size():
		boundary = minf(boundary, q.distance_to(Geometry2D.get_closest_point_to_segment(q, _border[i], _border[(i + 1) % _border.size()])))
	var edge_distance := boundary
	if Geometry2D.is_point_in_polygon(q, _border):
		boundary = -boundary
	var fracture := _noise.get_noise_3d(p.x * .85, p.y * 1.9, p.z * .85) * .095
	var mass := p.y - _hill_height(q, edge_distance) + fracture
	# 좌우의 다른 지지 암반과 비스듬한 처마가 입구의 앞/중간/뒤 깊이를 만든다.
	mass = minf(mass, _plate_field(p, Vector3(-2.35, 1.65, -.85), Vector3(.95, .68, 1.45), -.18))
	mass = minf(mass, _plate_field(p, Vector3(2.05, 1.45, -1.0), Vector3(.85, .72, 1.55), .13))
	var roof_plate := minf(
		_plate_field(p, Vector3(-1.10, 3.58, -1.30), Vector3(1.55, .34, 1.65), -.24),
		_plate_field(p, Vector3(1.00, 3.12, -1.55), Vector3(1.40, .40, 1.80), .17)
	)
	# 지붕 두께를 보장하되 바깥 hull의 평평한 앞면까지 판석이 일렬로 잘리지 않게 한다.
	var broken_lip := p.z - (.36 + .14 * sin(p.x * 1.15) + p.x * .045)
	mass = minf(mass, maxf(roof_plate, broken_lip))
	var body := maxf(maxf(mass, boundary), -1.60 - p.y)
	var floor_y := NativeCavePlan.floor_height(p.z)
	var width := lerpf(1.96, 1.84, clampf(-p.z / NativeCavePlan.RECESS_DEPTH, 0.0, 1.0))
	# 깊은 곳만 조금 꺾어 가까운 정면 후벽이 입구 전체를 막지 않게 한다.
	var centre := -.12 + .035 * sin(p.z * 1.4) - .14 * smoothstep(2.5, NativeCavePlan.RECESS_DEPTH, -p.z)
	# 바닥의 넓은 통과 폭을 보존하고 위쪽만 비대칭으로 좁혀 직벽/일자 린텔을 없앤다.
	var height := 3.12 - p.x * .08
	var roof_part := maxf(0.0, (p.y - floor_y - .25) / height)
	var arch := (pow(absf((p.x - centre) / width), 1.8) + roof_part * roof_part - 1.0) * 1.5
	arch += .012 * sin(p.x * 2.4 + p.z * .7) * smoothstep(.2, 1.0, roof_part)
	var recess_end := -NativeCavePlan.RECESS_DEPTH - p.z + .22 * sin(p.x * 1.4 + p.y * .9) + .07 * cos(p.y * 3.3 - p.x * .7)
	var tunnel := maxf(maxf(arch, floor_y - .065 - p.y), recess_end)
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
		# 이웃 사면체도 같은 끝점 순서로 보간해 공유 절단점의 float 오차를 막는다.
		var first := a
		var last := b
		if points[first].x > points[last].x or (points[first].x == points[last].x and (points[first].y > points[last].y or (points[first].y == points[last].y and points[first].z > points[last].z))):
			first = b
			last = a
		var crossing := points[first].lerp(points[last], values[first] / (values[first] - values[last]))
		var duplicate := false
		for existing: Vector3 in cuts:
			duplicate = duplicate or existing.distance_squared_to(crossing) < .000000000001
		if not duplicate:
			cuts.append(crossing)
	if cuts.size() < 3:
		return
	var centre := Vector3.ZERO
	for p: Vector3 in cuts:
		centre += p
	centre /= cuts.size()
	# 네 절단점은 선형 보간한 사면체 평면 위에 있다. 비선형 SDF의 중심 법선으로
	# 정렬하면 층리/터널 꺾임에서 삼각형 순서가 뒤집혀 검은 구멍이 생길 수 있다.
	var frame := Basis(points[1] - points[0], points[2] - points[0], points[3] - points[0])
	var change := Vector3(values[1] - values[0], values[2] - values[0], values[3] - values[0])
	var normal := (frame.transposed().inverse() * change).normalized()
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
		# 작지만 유효한 절단면을 버리면 이웃 삼각형 세 변에 실제 구멍이 남는다.
		if (b - a).cross(c - a).length_squared() == 0.0:
			continue
		if (b - a).cross(c - a).dot(normal) < 0.0:
			var swap := b
			b = c
			c = swap
		for vertex: Vector3 in [a, c, b]:
			var smooth_normal := _normal(vertex)
			if smooth_normal.dot(normal) < .15:
				smooth_normal = normal
			tool.set_normal(smooth_normal.lerp(normal, .20).normalized())
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

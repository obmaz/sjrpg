class_name NativeCaveEntrance3D
extends RefCounted
## 큰 바위 구릉 아래의 전이 입구. 메시와 실제 원형 차폐는 공용 설계를 따른다.
static func _polygon_volume(tool: SurfaceTool, polygon: PackedVector2Array, bottom: float, top: float, broken := false) -> void:
	if polygon.size() < 3:
		return
	var centre := Vector3.ZERO
	var high := PackedVector3Array()
	var low := PackedVector3Array()
	for p: Vector2 in polygon:
		low.append(Vector3(p.x, bottom, p.y))
		high.append(Vector3(p.x, _hill_height(p, top) if broken else top, p.y))
		centre += low[-1]
	centre /= polygon.size()
	if broken:
		# 내부 정점으로 큰 삼각 지붕 대신 작게 깨진 둥근 암반을 만든다.
		var samples := PackedVector2Array(polygon)
		var rect := Iso.poly_bounds(polygon)
		for x in range(floori(rect.position.x / 0.65), ceili(rect.end.x / 0.65) + 1):
			for z in range(floori(rect.position.y / 0.65), ceili(rect.end.y / 0.65) + 1):
				var q := Vector2(x * 0.65 + 0.06 * sin(z * 2.4), z * 0.65 + 0.06 * cos(x * 2.1))
				if Geometry2D.is_point_in_polygon(q, polygon):
					samples.append(q)
		var triangles := Geometry2D.triangulate_delaunay(samples)
		for i in range(0, triangles.size(), 3):
			var points: Array[Vector3] = []
			for k in 3:
				var q := samples[triangles[i + k]]
				points.append(Vector3(q.x, _hill_height(q, top), q.y))
			NativeLandmarks3D._tri(tool, points[0], points[1], points[2], Vector3.UP)
	var indices := Geometry2D.triangulate_polygon(polygon)
	for i in range(0, indices.size(), 3):
		var a := high[indices[i]]
		var b := high[indices[i + 1]]
		var c := high[indices[i + 2]]
		if not broken:
			NativeLandmarks3D._tri(tool, a, b, c, Vector3.UP)
		NativeLandmarks3D._tri(tool, low[indices[i]], low[indices[i + 2]], low[indices[i + 1]], Vector3.DOWN)
	for i in low.size():
		NativeSceneryProps3D._face(tool, low[i], low[(i + 1) % low.size()], high[(i + 1) % high.size()], high[i], centre + Vector3.UP * (top - bottom) * 0.5)

static func _hill_height(p: Vector2, top: float) -> float:
	var radius := SpatialWorld3D.radius_metres(NativeCavePlan.SOURCE_RADIUS)
	var r := clampf(Vector2(p.x, p.y + NativeCavePlan.front_offset()).length() / radius, 0.0, 1.0)
	var dome := pow(maxf(0.0, 1.0 - r * r), 0.82)
	dome *= 0.89 + 0.11 * sin(p.x * 0.47 + p.y * 0.19 + 0.8)
	var broken := 0.16 * sin(p.x * 3.0 + sin(p.y * 1.9)) + 0.10 * cos(p.y * 4.1 + p.x * 1.3)
	var level := (top - 0.80) * dome + broken * dome
	var shelf := floorf(level / 0.65) * 0.65 + smoothstep(0.12, 0.88, fposmod(level, 0.65) / 0.65) * 0.65
	return lerpf(level, shelf, 0.52)

static func _boulder(tool: SurfaceTool, at: Vector3, size: Vector3, yaw: float, seed: float, embedded := false) -> void:
	var rings: Array[PackedVector3Array] = []
	for level: int in 3:
		var ring := PackedVector3Array()
		for side: int in 14:
			var angle := TAU * side / 14.0 + 0.10 * sin(side * 1.7 + seed)
			var jitter := 1.0 + 0.17 * sin(side * 2.7 + seed)
			var spread: float = 1.0 if embedded and level == 0 else [0.72, 1.0, 0.84][level]
			var p := Vector3(cos(angle) * size.x * 0.5 * spread * jitter, size.y * [0.0, 0.35, 0.88][level], sin(angle) * size.z * 0.5 * spread * jitter)
			p.y += size.y * 0.07 * sin(side * 2.1 + seed + level)
			p = Basis(Vector3.UP, yaw) * p + at
			var centre := Vector2(0, -NativeCavePlan.front_offset())
			var flat := Vector2(p.x, p.z) - centre
			var limit := SpatialWorld3D.radius_metres(NativeCavePlan.SOURCE_RADIUS) * 0.996
			if flat.length() > limit:
				flat = flat.normalized() * limit
				p.x = centre.x + flat.x
				p.z = centre.y + flat.y
			var border := NativeCavePlan.outline(SpatialWorld3D.radius_metres(NativeCavePlan.SOURCE_RADIUS))
			var q := Vector2(p.x,p.z)
			if not Geometry2D.is_point_in_polygon(q,border):
				var nearest := q
				var distance := INF
				for edge: int in border.size():
					var candidate := Geometry2D.get_closest_point_to_segment(q,border[edge],border[(edge+1)%border.size()])
					if candidate.distance_squared_to(q) < distance:
						distance = candidate.distance_squared_to(q)
						nearest = candidate
				p.x = nearest.x
				p.z = nearest.y
			if embedded and level == 0:
				p.y = minf(p.y,_hill_height(Vector2(p.x,p.z),NativeCavePlan.HILL_HEIGHT)-0.12)
			ring.append(p)
		rings.append(ring)
	var mid := at + Vector3.UP * size.y * 0.4
	for level: int in 2:
		for side: int in 14:
			var next := (side + 1) % 14
			NativeSceneryProps3D._face(tool, rings[level][side], rings[level][next], rings[level+1][next], rings[level+1][side], mid)
	var top := at + Vector3(size.x * 0.08, size.y * 0.97, size.z * 0.07)
	for side: int in 14:
		var next := (side + 1) % 14
		NativeLandmarks3D._tri(tool, rings[2][side], rings[2][next], top, Vector3.UP)
		NativeLandmarks3D._tri(tool, rings[0][side], at, rings[0][next], Vector3.DOWN)

static func mesh(height: float, body_radius: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for polygon: PackedVector2Array in NativeCavePlan.ground_regions(body_radius):
		var fractured := PackedVector2Array()
		for i: int in polygon.size():
			var a := polygon[i]
			var b := polygon[(i+1)%polygon.size()]
			var pieces := maxi(1,ceili(a.distance_to(b)/0.60))
			for part: int in pieces:
				fractured.append(a.lerp(b,float(part)/pieces))
		_polygon_volume(tool,fractured,0.0,height,true)
	# 입구 바닥은 실제 기존 지면과 같은 높이. 별도 발판이나 경사를 만들지 않는다.
	NativeLandmarks3D._tri(tool,Vector3(-1.96,0.008,0.35),Vector3(1.96,0.008,0.35),Vector3(1.96,0.008,-3.5),Vector3.UP)
	NativeLandmarks3D._tri(tool,Vector3(-1.96,0.008,0.35),Vector3(1.96,0.008,-3.5),Vector3(-1.96,0.008,-3.5),Vector3.UP)
	# 생성형 동굴 컨셉의 비대칭 파쇄암 입구. 규칙적인 석조 아치를 쓰지 않는다.
	var inner := PackedVector2Array([Vector2(-0.70, 0.50), Vector2(-0.84, 1.35), Vector2(-0.66, 2.45), Vector2(-0.31, 2.88), Vector2(0.22, 3.02), Vector2(0.62, 2.58), Vector2(0.79, 1.52), Vector2(0.70, 0.50)])
	var outer := PackedVector2Array([Vector2(-1.25, 0.50), Vector2(-1.32, 1.47), Vector2(-1.26, 2.67), Vector2(-0.54, 3.39), Vector2(0.29, 3.54), Vector2(1.03, 3.06), Vector2(1.32, 1.83), Vector2(1.23, 0.50)])
	for i: int in inner.size():
		inner[i].x *= 2.80
		outer[i].x *= 2.80
		inner[i].y = 0.50 + (inner[i].y - 0.50) * 1.15
		outer[i].y = 0.50 + (outer[i].y - 0.50) * 1.15
	inner[0].y = 0.0
	inner[-1].y = 0.0
	outer[0].y = 0.0
	outer[-1].y = 0.0
	for i in range(inner.size() - 1):
		var a := Vector3(inner[i].x, inner[i].y, 0.10 + 0.07 * sin(i * 2.3))
		var b := Vector3(inner[i + 1].x, inner[i + 1].y, 0.10 + 0.07 * sin((i + 1) * 2.3))
		var c := Vector3(outer[i + 1].x, outer[i + 1].y, -0.30)
		var d := Vector3(outer[i].x, outer[i].y, -0.30)
		var ridge := (a + b + c + d) * 0.25 + Vector3(0.03 * sin(i), 0.03, 0.17)
		for pair: Array in [[a, b], [b, c], [c, d], [d, a]]:
			NativeLandmarks3D._tri(tool, pair[0], pair[1], ridge, Vector3.BACK)
		# 실제로 뒤로 들어간 천장·측벽이 입구 안쪽의 어둠을 만든다.
		var back_a := Vector3(a.x * 0.72, a.y, -3.45)
		var back_b := Vector3(b.x * 0.72, b.y, -3.45)
		NativeSceneryProps3D._face(tool, a, back_a, back_b, b, Vector3(0, 1.6, -0.5))
		var back_c := Vector3(c.x * 0.94, c.y - 0.12, -3.45)
		var back_d := Vector3(d.x * 0.94, d.y - 0.12, -3.45)
		var rock_center := (a + b + c + d + back_a + back_b + back_c + back_d) / 8.0
		NativeSceneryProps3D._face(tool, d, c, back_c, back_d, rock_center)
		NativeSceneryProps3D._face(tool, back_a, back_d, back_c, back_b, rock_center)
	for i: int in 11:
		var angle := TAU * i / 11.0
		var r := 2.0 + 1.6 * (0.5 + 0.5 * sin(i * 2.4))
		var p := Vector2(cos(angle) * r, -NativeCavePlan.front_offset() + sin(angle) * r)
		if p.y > -1.5 and absf(p.x) < 2.6:
			continue
		var y := _hill_height(p, height) - 0.25
		_boulder(tool, Vector3(p.x, y, p.y), Vector3(2.55 + 0.45 * sin(i), 0.48 + 0.18 * cos(i * 1.8), 1.65), angle * 0.45, float(i), true)
	_boulder(tool, Vector3(-0.15, 3.28, -0.42), Vector3(5.0, 0.90, 1.65), 0.07, 25.0)
	_boulder(tool, Vector3(-2.65, -0.05, -0.65), Vector3(1.35, 2.90, 1.75), -0.15, 27.0)
	_boulder(tool, Vector3(2.65, -0.05, -0.70), Vector3(1.30, 3.12, 1.70), 0.21, 29.0)
	return tool.commit()

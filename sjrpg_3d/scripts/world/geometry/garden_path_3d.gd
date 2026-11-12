class_name GardenPath3D
extends RefCounted
## 정원의 표시와 FLOOR가 공유하는 미터 단위 낮은 불규칙 판석.
const MAX_HEIGHT := .045


static func generate(
	path: Rect2, random_seed: int, columns := 4, rows := 8, irregular_edges := false
) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var result: Array[Dictionary] = []
	var grid: Array[PackedVector2Array] = []
	# 모서리를 공유한 불규칙 사분할을 만든 뒤 각 돌을 안쪽으로 줄인다.
	# 색만 달리한 직사각 격자나 서로 겹치는 돌을 만들지 않는다.
	for row in rows + 1:
		var line := PackedVector2Array()
		for column in columns + 1:
			var point := (
				path.position
				+ Vector2(column * path.size.x / float(columns), row * path.size.y / float(rows))
			)
			if irregular_edges or (column > 0 and column < columns):
				point.x += rng.randf_range(-.12, .12)
			if irregular_edges or (row > 0 and row < rows):
				point.y += rng.randf_range(-.12, .12)
			line.append(point)
		grid.append(line)
	for row in rows:
		for column in columns:
			if irregular_edges and row == rows - 1 and column in [0, columns - 1]:
				continue
			if irregular_edges and row == rows - 2 and column == columns - 1 and rng.randf() < .65:
				continue
			var corners := PackedVector2Array(
				[
					grid[row][column],
					grid[row][column + 1],
					grid[row + 1][column + 1],
					grid[row + 1][column]
				]
			)
			var center := Vector2.ZERO
			for point in corners:
				center += point / 4.0
			for i in corners.size():
				corners[i] += (center - corners[i]).normalized() * rng.randf_range(.026, .045)
			var polygon := PackedVector2Array()
			for i in corners.size():
				var corner := corners[i]
				polygon.append(
					(
						corner
						+ (corners[(i + 3) % 4] - corner).normalized() * rng.randf_range(.025, .065)
					)
				)
				polygon.append(
					(
						corner
						+ (corners[(i + 1) % 4] - corner).normalized() * rng.randf_range(.025, .065)
					)
				)
			result.append(
				{
					"polygon": polygon,
					"height": rng.randf_range(.018, MAX_HEIGHT),
					"tint": Color(.86, .88, .83) * rng.randf_range(.84, 1.04)
				}
			)
	return result


static func bounds(stones: Array) -> Rect2:
	var points := PackedVector2Array()
	for stone: Dictionary in stones:
		points.append_array(stone["polygon"])
	return Iso.poly_bounds(points)


static func cap_polygon(stone: Dictionary) -> PackedVector2Array:
	var polygon: PackedVector2Array = stone["polygon"]
	var center := Iso.poly_bounds(polygon).get_center()
	var cap := PackedVector2Array()
	for p: Vector2 in polygon:
		cap.append(p + (center - p).normalized() * .018)
	return cap


static func _face(
	result: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, normal: Vector3
) -> void:
	if (b - a).cross(c - a).dot(normal) > 0:
		result.append_array(PackedVector3Array([a, c, b]))
	else:
		result.append_array(PackedVector3Array([a, b, c]))


static func floor_faces(stones: Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	for stone: Dictionary in stones:
		var polygon: PackedVector2Array = stone["polygon"]
		var cap := cap_polygon(stone)
		var indices := Geometry2D.triangulate_polygon(cap)
		var height: float = stone["height"]
		for i in range(0, indices.size(), 3):
			var a := cap[indices[i]]
			var b := cap[indices[i + 1]]
			var c := cap[indices[i + 2]]
			_face(
				result,
				Vector3(a.x, height, a.y),
				Vector3(b.x, height, b.y),
				Vector3(c.x, height, c.y),
				Vector3.UP
			)
		var center := Iso.poly_bounds(polygon).get_center()
		for i in polygon.size():
			var j := (i + 1) % polygon.size()
			var a := Vector3(polygon[i].x, .003, polygon[i].y)
			var b := Vector3(polygon[j].x, .003, polygon[j].y)
			var c := Vector3(cap[j].x, height, cap[j].y)
			var d := Vector3(cap[i].x, height, cap[i].y)
			var outward := Vector3((a.x + b.x) * .5 - center.x, 0, (a.z + b.z) * .5 - center.y)
			_face(result, a, b, c, outward)
			_face(result, a, c, d, outward)
	return result


static func height_at(stones: Array, point: Vector2) -> float:
	var ground := Iso.unproject(point) / WorldSpace3D.GROUND_UNITS_PER_METER
	for stone: Dictionary in stones:
		if Geometry2D.is_point_in_polygon(ground, stone["polygon"]):
			var polygon: PackedVector2Array = stone["polygon"]
			var distance := INF
			for i in polygon.size():
				distance = minf(
					distance,
					ground.distance_to(
						Geometry2D.get_closest_point_to_segment(
							ground, polygon[i], polygon[(i + 1) % polygon.size()]
						)
					)
				)
			return lerpf(.003, float(stone["height"]), clampf(distance / .018, 0, 1))
	return 0.0

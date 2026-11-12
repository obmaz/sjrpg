class_name ChapelGardenPlan3D
extends RefCounted
## 예배당 주변의 판석·화단·후경 나무를 미터 단위로 설계한다.
## 판석 상면은 표시와 FLOOR에 같은 다각형/높이를 전달한다.
const MAX_PAVER_HEIGHT := .045
const CACHE_KEY := "chapel_garden_plan"


static func layout(village: Village) -> Dictionary:
	if village.has_meta(CACHE_KEY):
		return village.get_meta(CACHE_KEY)
	var chapel := SpatialWorld3D._native_chapel(village)
	var bodies: Array = chapel["native_bodies"]
	var bounds: Rect2 = bodies[0]
	for body: Rect2 in bodies:
		bounds = bounds.merge(body)
	var center := bounds.get_center()
	var entry := Iso.unproject(chapel["bottom"]) / WorldSpace3D.GROUND_UNITS_PER_METER
	var path := Rect2(entry + Vector2(-1.05, .12), Vector2(2.10, 3.85))
	var beds: Array[Vector4] = [
		Vector4(center.x - 3.47, center.y - .25, .62, 2.30),
		Vector4(center.x + 3.42, center.y - .35, .62, 2.10),
		Vector4(center.x + .95, center.y + 2.96, 1.65, .47),
		Vector4(center.x - 3.13, center.y + 2.90, .54, .72),
		Vector4(path.position.x - .28, path.get_center().y, .25, 1.65),
		Vector4(path.end.x + .28, path.get_center().y, .25, 1.65),
	]
	var result := {
		"center": center,
		"path": path,
		"beds": beds,
		"base": bounds.grow(.15),
		"background_trees":
		[center + Vector2(-1.3, -6.2), center + Vector2(1.9, -6.8), center + Vector2(4.0, -5.7)]
	}
	village.set_meta(CACHE_KEY, result)
	return result


static func pavers(village: Village) -> Array[Dictionary]:
	var data := layout(village)
	if data.has("pavers"):
		return data["pavers"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x43484150454c
	var path: Rect2 = data["path"]
	var result: Array[Dictionary] = []
	var grid: Array[PackedVector2Array] = []
	# 모서리를 공유한 불규칙 사분할을 만든 뒤 각 돌을 안쪽으로 줄인다.
	# 색만 달리한 직사각 격자나 서로 겹치는 돌을 만들지 않는다.
	for row in 9:
		var line := PackedVector2Array()
		for column in 5:
			var point := (
				path.position + Vector2(column * path.size.x / 4.0, row * path.size.y / 8.0)
			)
			if column > 0 and column < 4:
				point.x += rng.randf_range(-.12, .12)
			if row > 0 and row < 8:
				point.y += rng.randf_range(-.12, .12)
			line.append(point)
		grid.append(line)
	for row in 8:
		for column in 4:
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
					"height": rng.randf_range(.018, MAX_PAVER_HEIGHT),
					"tint": Color(.86, .88, .83) * rng.randf_range(.84, 1.04)
				}
			)
	data["pavers"] = result
	return result


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


static func surface(village: Village) -> Dictionary:
	var path: Rect2 = layout(village)["path"]
	var top := PackedVector2Array()
	for point: Vector2 in ChapelPlan3D.polygon(path):
		top.append(Iso.project(point * WorldSpace3D.GROUND_UNITS_PER_METER))
	return {
		"id": "chapel_garden_path",
		"top": top,
		"rise": 0.0,
		"blockers": [],
		"garden_pavers": pavers(village)
	}


static func plant_positions(village: Village) -> Array[Dictionary]:
	var data := layout(village)
	if data.has("plants"):
		return data["plants"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x47524f5645
	var chapel := SpatialWorld3D._native_chapel(village)
	var path: Rect2 = data["path"]
	var result: Array[Dictionary] = []
	for bed: Vector4 in data["beds"]:
		var placed := 0
		for attempt in 240:
			if placed >= 28:
				break
			var local := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
			if local.length_squared() > 1.0:
				continue
			var at := Vector2(bed.x, bed.y) + local * Vector2(bed.z, bed.w)
			if path.grow(.12).has_point(at):
				continue
			var projected := Iso.project(at * WorldSpace3D.GROUND_UNITS_PER_METER)
			if (
				Geometry2D.is_point_in_polygon(projected, chapel["top"])
				or not _clear(village, projected)
			):
				continue
			var choice := rng.randf()
			var kind := 0 if choice < .58 else (1 if choice < .84 else (2 if choice < .94 else 3))
			result.append(
				{
					"at": Vector3(at.x, 0, at.y),
					"kind": kind,
					"yaw": rng.randf_range(0, TAU),
					"scale": rng.randf_range(.66, 1.12)
				}
			)
			placed += 1
	data["plants"] = result
	return result


static func _clear(village: Village, point: Vector2) -> bool:
	for polygon: PackedVector2Array in village.solids:
		if Geometry2D.is_point_in_polygon(point, polygon):
			return false
	for at: Vector2 in village.npc_points.values():
		if point.distance_to(at) < 65.0:
			return false
	for at: Vector2 in village.chest_points:
		if point.distance_to(at) < 75.0:
			return false
	for at: Vector2 in village.portal_points.values():
		if point.distance_to(at) < 140.0:
			return false
	return true

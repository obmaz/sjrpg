class_name ChapelGardenPlan3D
extends RefCounted
## 예배당 주변의 판석·화단·후경 나무를 미터 단위로 설계한다.
## 판석 상면은 표시와 FLOOR에 같은 다각형/높이를 전달한다.
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
	# 광장이 넓어져도 오른쪽 수관은 포장 밖의 식재 띠에 남긴다.
	# 건물 상대 위치만 사용하면 확대된 광장 제외 검사에서 이 나무가 사라진다.
	var right_frame := Vector2(
		maxf(center.x + 3.60, TownPlazaPlan3D.PLAZA.end.x + .85), center.y + 3.40
	)
	var entry := Iso.unproject(chapel["bottom"]) / WorldSpace3D.GROUND_UNITS_PER_METER
	var path := Rect2(entry + Vector2(-1.05, .12), Vector2(2.10, 3.85))
	var island := Vector4(center.x - 3.05, center.y + 4.70, .75, 1.0)
	var beds: Array[Vector4] = [
		Vector4(center.x - 3.55, center.y - .65, .86, 1.75),
		Vector4(center.x + 3.55, center.y + .05, .94, 1.65),
		Vector4(center.x + 1.40, center.y + 3.02, 1.25, .78),
		Vector4(center.x - 3.28, center.y + 2.90, .76, .82),
		island,
		Vector4(path.end.x + .46, path.get_center().y + .42, .55, .87),
	]
	var result := {
		"center": center,
		"path": path,
		"beds": beds,
		"base": bounds.grow(.15),
		"planting_island": island,
		"chest_point": center + Vector2(2.40, 4.30),
		"background_trees":
		[
			{
				"at": center + Vector2(-3.20, 4.30),
				"height": 350.0,
				"role": "left_rear_frame",
				"variant": 2,
				"tint": Color(.46, .58, .46)
			},
			{
				"at": center + Vector2(-2.75, 5.10),
				"height": 220.0,
				"role": "left_frame",
				"variant": 0,
				"tint": Color(.48, .60, .45)
			},
			{"at": right_frame, "height": 230.0, "role": "right_frame"},
			{"at": center + Vector2(1.90, -6.80), "height": 590.0},
			{"at": center + Vector2(4.00, -5.70), "height": 590.0},
		]
	}
	village.set_meta(CACHE_KEY, result)
	return result


static func pavers(village: Village) -> Array[Dictionary]:
	var data := layout(village)
	if not data.has("pavers"):
		var island := island_polygon(village)
		var stones: Array[Dictionary] = []
		for stone: Dictionary in GardenPath3D.generate(data["path"], 0x43484150454c, 4, 8, true):
			if Geometry2D.intersect_polygons(stone["polygon"], island).is_empty():
				stones.append(stone)
		data["pavers"] = stones
	return data["pavers"]


static func surface(village: Village) -> Dictionary:
	var path := GardenPath3D.bounds(pavers(village))
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
	for bed_index in data["beds"].size():
		var bed: Vector4 = data["beds"][bed_index]
		var island_bed: bool = bed_index == 4
		var placed := 0
		for attempt in 240:
			if placed >= (42 if island_bed else 24):
				break
			var local := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
			if local.length_squared() > 1.0:
				continue
			var at := Vector2(bed.x, bed.y) + local * Vector2(bed.z, bed.w)
			if path.grow(.12).has_point(at) or sin(at.x * 3.1 + at.y * 4.3) > .72:
				continue
			if island_bed and fountain_clearance(village, at) < .40:
				continue
			var projected := Iso.project(at * WorldSpace3D.GROUND_UNITS_PER_METER)
			if (
				Geometry2D.is_point_in_polygon(projected, chapel["top"])
				or not VillageCourtyardPlan3D.plant_clear(village, projected)
			):
				continue
			var choice := rng.randf()
			var kind := (
				(0 if choice < .48 else (1 if choice < .94 else 2))
				if island_bed
				else (1 if choice < .42 else (0 if choice < .60 else (2 if choice < .90 else 3)))
			)
			if not island_bed and kind == 0 and path.grow(.65).has_point(at):
				kind = 1
			result.append(
				{
					"at": Vector3(at.x, 0, at.y),
					"kind": kind,
					"yaw": rng.randf_range(0, TAU),
					"scale":
					(
						rng.randf_range(.95, 1.40)
						if island_bed
						else (
							rng.randf_range(.65, 1.0) if kind == 0 else rng.randf_range(.80, 1.16)
						)
					),
					"tint":
					(
						Color(.42, .55, .39)
						if island_bed
						else (Color(.88, .90, .81) if kind > 1 else Color(.64, .77, .61))
					),
					"stretch":
					(
						Vector3(1.22, 1, 1.22)
						if kind == 1
						else (Vector3(.82, 1.10, .82) if kind > 1 else Vector3.ONE)
					)
				}
			)
			placed += 1
	data["plants"] = result
	return result


## 포장 안의 실제 조경 섬. 흙 마스크·판석 노치·지도·식재 검증이 같은 타원을 사용한다.
static func island_polygon(village: Village) -> PackedVector2Array:
	var bed: Vector4 = layout(village)["planting_island"]
	var result := PackedVector2Array()
	for index in 24:
		var angle := TAU * index / 24.0
		result.append(Vector2(bed.x, bed.y) + Vector2(cos(angle) * bed.z, sin(angle) * bed.w))
	return result


static func planned_island_tree(village: Village, at: Vector2) -> bool:
	for tree: Dictionary in layout(village)["background_trees"]:
		if (
			str(tree.get("role", "")) in ["left_frame", "left_rear_frame"]
			and at.distance_to(tree["at"]) < .02
		):
			return true
	return false


## 광장 사각 제외를 대신하는 실제 배치 검증. 분수와 트렁크 사이에도 인물 통행 폭을 남긴다.
static func island_tree_clear(village: Village, at: Vector2) -> bool:
	if not Geometry2D.is_point_in_polygon(at, island_polygon(village)):
		return false
	var chapel := SpatialWorld3D._native_chapel(village)
	for body: Rect2 in chapel["native_bodies"]:
		if body.grow(.35).has_point(at):
			return false
	for tier: Dictionary in chapel["native_steps"]:
		var step: Rect2 = tier["rect"]
		if step.grow(.35).has_point(at):
			return false
	return fountain_clearance(village, at) >= .85


static func fountain_clearance(village: Village, at: Vector2) -> float:
	var fountain := village.fountain.atlas_polygon(village.data["frames"]["pool"]["ground"])
	for index in fountain.size():
		fountain[index] = Iso.unproject(fountain[index]) / WorldSpace3D.GROUND_UNITS_PER_METER
	if Geometry2D.is_point_in_polygon(at, fountain):
		return 0.0
	var distance := INF
	for index in fountain.size():
		distance = minf(
			distance,
			(
				Geometry2D
				. get_closest_point_to_segment(
					at, fountain[index], fountain[(index + 1) % fountain.size()]
				)
				. distance_to(at)
			)
		)
	return distance

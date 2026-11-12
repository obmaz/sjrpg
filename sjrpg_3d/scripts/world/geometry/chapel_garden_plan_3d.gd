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
	if not data.has("pavers"):
		data["pavers"] = GardenPath3D.generate(data["path"], 0x43484150454c)
	return data["pavers"]


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
				or not VillageCourtyardPlan3D.plant_clear(village, projected)
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

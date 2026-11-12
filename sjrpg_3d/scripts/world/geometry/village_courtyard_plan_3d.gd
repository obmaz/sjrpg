class_name VillageCourtyardPlan3D
extends RefCounted
## 실제 건물 접점에서 마당·진입 판석·화단을 도출한다. 광장과 상호작용 동선을 비운다.
const CACHE_KEY := "village_courtyards"
const HOUSE_KEYS := ["nw", "ne", "sw", "se"]


static func building_bounds(village: Village, key: String) -> Rect2:
	var sprite: IsoSprite = village.buildings[key]
	var definition: Dictionary = village.data["frames"][key]
	var points := PackedVector2Array()
	for point: Vector2 in sprite.atlas_polygon(definition["ground"]):
		points.append(Iso.unproject(point) / WorldSpace3D.GROUND_UNITS_PER_METER)
	return Iso.poly_bounds(points)


static func sites(village: Village) -> Array[Dictionary]:
	if village.has_meta(CACHE_KEY):
		return village.get_meta(CACHE_KEY)
	var result: Array[Dictionary] = []
	for key: String in HOUSE_KEYS:
		var bounds := building_bounds(village, key)
		var center := bounds.get_center()
		var asset_id: String = NativeHousePlan.STYLES[key]["wall"]
		var authored := (
			load(ArchitectureSceneLibrary.ARCHITECTURE_SCENE_ROOT + asset_id + "/layout.tres")
			as Resource
		)
		var report: Dictionary = authored.get_meta("report")
		var footprint: Vector2 = report["footprint"]
		var entrance: Rect2 = report["door_approach"]
		var path_width := maxf(1.90, entrance.size.x)
		# 모델 제작 기록의 문 접점을 사용해 시각 모델과 마당의 수식이 갈라지지 않게 한다.
		var path := Rect2(
			center.x + entrance.get_center().x - path_width * .5,
			center.y + entrance.position.y + .12,
			path_width,
			2.20 if key == "ne" else 2.65
		)
		var theme := "workyard" if key == "ne" else ("stable" if key == "sw" else "garden")
		result.append(
			_site(key, center, footprint.x, footprint.y, path, theme, 0x484f4d45 + result.size())
		)
	for id: String in TownPlazaPlan3D.SERVICES:
		var center: Vector2 = TownPlazaPlan3D.SERVICES[id]["center"]
		var market := id == "market_shop"
		var path := Rect2(center.x + (.15 if market else -1.05) - .95, center.y + 3.50, 1.90, 2.90)
		result.append(
			_site(
				id,
				center,
				6.8,
				6.2,
				path,
				"market" if market else "workyard",
				0x53484f50 + result.size()
			)
		)
	village.set_meta(CACHE_KEY, result)
	return result


static func _site(
	id: String,
	center: Vector2,
	width: float,
	depth: float,
	path: Rect2,
	theme: String,
	random_seed: int
) -> Dictionary:
	var front := center.y + depth * .5
	var left := Vector4(center.x - width * .5 - .38, center.y + .12, .38, depth * .36)
	var right := Vector4(center.x + width * .5 + .38, center.y - .12, .38, depth * .36)
	var front_x := (
		center.x + width * .29 if path.get_center().x < center.x else center.x - width * .29
	)
	var beds: Array[Vector4] = [left, right, Vector4(front_x, front + .56, .58, .32)]
	# 작업장 앞은 흙과 쇄석 위주로 비우고 식생은 벽 가장자리에 모은다.
	if theme == "workyard":
		beds[2] = Vector4(center.x - width * .36, center.y - depth * .5 - .36, .70, .28)
	var bounds := Rect2(center - Vector2(width, depth) * .5, Vector2(width, depth)).grow(.95).merge(
		path.grow(.40)
	)
	return {
		"id": id,
		"center": center,
		"footprint": Rect2(center - Vector2(width, depth) * .5, Vector2(width, depth)),
		"path": path,
		"beds": beds,
		"bounds": bounds,
		"theme": theme,
		"seed": random_seed,
		"apron": Vector4(center.x, front + .80, width * .45, 1.28)
	}


static func stones(village: Village) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for site: Dictionary in sites(village):
		if not site.has("stones"):
			var path: Rect2 = site["path"]
			var authored := GardenPath3D.generate(path, int(site["seed"]), 3, 5)
			for stone: Dictionary in authored:
				if site["theme"] == "workyard":
					stone["tint"] *= Color(.82, .84, .84)
			site["stones"] = authored
		result.append_array(site["stones"])
	return result


static func surfaces(village: Village) -> Array[Dictionary]:
	stones(village)
	var result: Array[Dictionary] = []
	for site: Dictionary in sites(village):
		var top := PackedVector2Array()
		for point: Vector2 in ChapelPlan3D.polygon(site["path"]):
			top.append(Iso.project(point * WorldSpace3D.GROUND_UNITS_PER_METER))
		result.append(
			{
				"id": "courtyard_" + str(site["id"]),
				"top": top,
				"rise": 0.0,
				"blockers": [],
				"garden_pavers": site["stones"]
			}
		)
	return result


static func on_path(village: Village, ground: Vector2) -> bool:
	for site: Dictionary in sites(village):
		var path: Rect2 = site["path"]
		if path.has_point(ground):
			return true
	return false


static func plants(village: Village) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for site: Dictionary in sites(village):
		if not site.has("plants"):
			site["plants"] = _plants(village, site)
		result.append_array(site["plants"])
	return result


static func _plants(village: Village, site: Dictionary) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(site["seed"]) + 0x47524f57
	var path: Rect2 = site["path"]
	var footprint: Rect2 = site["footprint"]
	var result: Array[Dictionary] = []
	var workyard: bool = site["theme"] == "workyard"
	for bed: Vector4 in site["beds"]:
		var placed := 0
		for attempt in 160:
			if placed >= (10 if workyard else 18):
				break
			var offset := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
			if offset.length_squared() > 1.0:
				continue
			var point := Vector2(bed.x, bed.y) + offset * Vector2(bed.z, bed.w)
			if (
				path.grow(.18).has_point(point)
				or footprint.grow(.18).has_point(point)
				or TownPlazaPlan3D.PLAZA.grow(.35).has_point(point)
			):
				continue
			var projected := Iso.project(point * WorldSpace3D.GROUND_UNITS_PER_METER)
			if not plant_clear(village, projected):
				continue
			var choice := rng.randf()
			var kind := (
				0
				if choice < .50
				else (1 if choice < (.90 if workyard else .72) else (2 if choice < .91 else 3))
			)
			var scale := rng.randf_range(.62, .92) if workyard else rng.randf_range(.70, 1.05)
			result.append(
				{
					"at": Vector3(point.x, 0, point.y),
					"kind": kind,
					"yaw": rng.randf_range(0, TAU),
					"scale": scale
				}
			)
			placed += 1
	return result


static func owns_groundcover(village: Village, ground: Vector2) -> bool:
	if not TownPlazaPlan3D.TOWN_INTERIOR.has_point(ground):
		return false
	for site: Dictionary in sites(village):
		var bounds: Rect2 = site["bounds"]
		if not bounds.has_point(ground):
			continue
		var path: Rect2 = site["path"]
		var footprint: Rect2 = site["footprint"]
		if path.grow(.18).has_point(ground) or footprint.grow(.18).has_point(ground):
			return true
		for bed: Vector4 in site["beds"]:
			if ((ground - Vector2(bed.x, bed.y)) / Vector2(bed.z, bed.w)).length() < 1.3:
				return true
	return false


static func plant_clear(village: Village, point: Vector2) -> bool:
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

class_name VillageCourtyardPlan3D
extends RefCounted
## 실제 건물 접점에서 마당·진입 판석·화단을 도출한다. 광장과 상호작용 동선을 비운다.
const CACHE_KEY := "village_courtyards"
const HOUSE_KEYS := ["nw", "ne", "sw", "se"]


## GLB 제작 치수와 중심이다. 회전된 월드 발자국/AABB는 house_footprint를 사용한다.
static func building_bounds(village: Village, key: String) -> Rect2:
	var size: Vector2 = village.buildings[key].get_meta("native_source_size", Vector2.ZERO)
	if key == "chapel":
		var sprite: IsoSprite = village.buildings[key]
		var definition: Dictionary = village.data["frames"][key]
		var points := PackedVector2Array()
		for point: Vector2 in sprite.atlas_polygon(definition["ground"]):
			points.append(Iso.unproject(point) / WorldSpace3D.GROUND_UNITS_PER_METER)
		return Iso.poly_bounds(points)
	var pose := TownPlazaPlan3D.frame(key)
	var center := Vector2(pose.origin.x, pose.origin.z)
	return Rect2(center - size * .5, size)


static func sites(village: Village) -> Array[Dictionary]:
	if village.has_meta(CACHE_KEY):
		return village.get_meta(CACHE_KEY)
	var result: Array[Dictionary] = []
	for key: String in HOUSE_KEYS:
		var asset_id: String = NativeHousePlan.STYLES[key]["wall"]
		var authored := (
			load(ArchitectureSceneLibrary.ARCHITECTURE_SCENE_ROOT + asset_id + "/layout.tres")
			as Resource
		)
		var report: Dictionary = authored.get_meta("report")
		var footprint: Vector2 = report["footprint"]
		var entrance: Rect2 = report["door_approach"]
		var path_width := maxf(1.90, entrance.size.x)
		var path := Rect2(
			entrance.get_center().x - path_width * .5,
			entrance.position.y + .12,
			path_width,
			2.20 if key == "ne" else (2.0 if key == "se" else 2.65)
		)
		var theme := "workyard" if key == "ne" else ("stable" if key == "sw" else "garden")
		result.append(_site(key, footprint.x, footprint.y, path, theme, 0x484f4d45 + result.size()))
	for id: String in TownPlazaPlan3D.SERVICES:
		var market := id == "market_shop"
		var path := Rect2((.15 if market else -1.05) - .95, 3.50, 1.90, 2.90)
		result.append(
			_site(
				id, 6.8, 6.2, path, "market" if market else "workyard", 0x53484f50 + result.size()
			)
		)
	village.set_meta(CACHE_KEY, result)
	return result


static func world_rect(local: Rect2, pose: Transform3D) -> Rect2:
	var points := PackedVector2Array()
	for point: Vector2 in ChapelPlan3D.polygon(local):
		var world := pose * Vector3(point.x, 0, point.y)
		points.append(Vector2(world.x, world.z))
	return Iso.poly_bounds(points)


static func _world_bed(local: Vector4, pose: Transform3D) -> Vector4:
	var world := pose * Vector3(local.x, 0, local.y)
	var radius := Vector2(
		absf(pose.basis.x.x) * local.z + absf(pose.basis.z.x) * local.w,
		absf(pose.basis.x.z) * local.z + absf(pose.basis.z.z) * local.w
	)
	return Vector4(world.x, world.z, radius.x, radius.y)


static func _site(
	id: String, width: float, depth: float, path: Rect2, theme: String, random_seed: int
) -> Dictionary:
	var front := depth * .5
	var left := Vector4(-width * .5 - .55, -depth * .10, .65, depth * .32)
	var right := Vector4(width * .5 + .58, depth * .18, .55, depth * .40)
	var front_x := width * .34 if path.get_center().x < 0 else -width * .34
	var local_beds: Array[Vector4] = [left, right, Vector4(front_x, front + .65, .85, .60)]
	if theme == "workyard":
		local_beds[2] = Vector4(-width * .36, -depth * .5 - .45, .90, .55)
	var pose := TownPlazaPlan3D.frame(id)
	var footprint := Rect2(-Vector2(width, depth) * .5, Vector2(width, depth))
	var bounds := footprint.grow(1.55).merge(path.grow(.50))
	var beds: Array[Vector4] = []
	for bed: Vector4 in local_beds:
		beds.append(_world_bed(bed, pose))
	return {
		"id": id,
		"frame": pose,
		"center": Vector2(pose.origin.x, pose.origin.z),
		"local_path": path,
		"path": world_rect(path, pose),
		"local_footprint": footprint,
		"footprint": world_rect(footprint, pose),
		"local_beds": local_beds,
		"beds": beds,
		"bounds": world_rect(bounds, pose),
		"theme": theme,
		"seed": random_seed,
		"apron": _world_bed(Vector4(0, front + .80, width * .45, 1.28), pose)
	}


## 집 앞 판석을 실제 광장까지 잇는다. 새 남쪽 주거지는 성문 축 옆 골목으로 연결한다.
static func lanes(village: Village) -> Array[Dictionary]:
	var ends := {}
	for site: Dictionary in sites(village):
		var path: Rect2 = site["local_path"]
		var pose: Transform3D = site["frame"]
		var end := pose * Vector3(path.get_center().x, 0, path.end.y)
		ends[site["id"]] = Vector2(end.x, end.z)
	var routes: Array[Dictionary] = [
		{
			"id": "northwest_lane",
			"points": PackedVector2Array([ends["nw"], Vector2(-7.5, 9.0)])
		},
		{
			"id": "southern_lane",
			"points":
			PackedVector2Array(
				[
					ends["se"],
					Vector2(14.0, 22.0),
					Vector2(10.0, 22.0),
					Vector2(6.0, 22.0),
					Vector2(2.0, 22.0),
					Vector2(0.0, 22.0),
					Vector2(0.0, 17.0),
					Vector2(0.0, 12.0),
					Vector2(0.0, 9.0)
				]
			)
		},
		{
			"id": "stable_lane",
			"points": PackedVector2Array([ends["sw"], Vector2(0, 19), Vector2(0, 14), Vector2(0, 9)])
		},
	]
	for route: Dictionary in routes:
		route["width"] = 1.8
		var polygons := Geometry2D.offset_polyline(
			route["points"], .90, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND
		)
		assert(polygons.size() == 1, "마을 골목은 하나의 이어진 보행 다각형이어야 합니다.")
		route["polygon"] = polygons[0]
	return routes


static func stones(village: Village) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for site: Dictionary in sites(village):
		if not site.has("stones"):
			var path: Rect2 = site["local_path"]
			var authored := GardenPath3D.generate(path, int(site["seed"]), 4, 6, true)
			var pose: Transform3D = site["frame"]
			for stone: Dictionary in authored:
				var polygon: PackedVector2Array = stone["polygon"]
				for i in polygon.size():
					var point := pose * Vector3(polygon[i].x, 0, polygon[i].y)
					polygon[i] = Vector2(point.x, point.z)
				stone["polygon"] = polygon
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
		for point: Vector2 in ChapelPlan3D.polygon(GardenPath3D.bounds(site["stones"])):
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
		if path.grow(.15).has_point(ground):
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
	var path: Rect2 = site["local_path"]
	var footprint: Rect2 = site["local_footprint"]
	var pose: Transform3D = site["frame"]
	var result: Array[Dictionary] = []
	var workyard: bool = site["theme"] == "workyard"
	for bed: Vector4 in site["local_beds"]:
		var placed := 0
		for attempt in 260:
			if placed >= (12 if workyard else 24):
				break
			var offset := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
			if offset.length_squared() > 1.0:
				continue
			var point := Vector2(bed.x, bed.y) + offset * Vector2(bed.z, bed.w)
			if path.grow(.18).has_point(point) or footprint.grow(.18).has_point(point):
				continue
			var world := pose * Vector3(point.x, 0, point.y)
			if TownPlazaPlan3D.PLAZA.grow(.35).has_point(Vector2(world.x, world.z)):
				continue
			if sin(point.x * 3.7 + point.y * 2.1) + sin(point.x * 1.3 - point.y * 4.1) > .95:
				continue
			var projected := WorldSpace3D.world_to_projected(world)
			if not plant_clear(village, projected):
				continue
			var choice := rng.randf()
			var kind := (
				1
				if choice < .48
				else (0 if choice < (.88 if workyard else .68) else (2 if choice < .91 else 3))
			)
			if kind == 0 and path.grow(.65).has_point(point):
				kind = 1
			var scale := (
				rng.randf_range(.64, 1.05)
				if kind == 1
				else (rng.randf_range(.58, .90) if kind == 0 else rng.randf_range(.72, 1.10))
			)
			result.append(
				{
					"at": world,
					"kind": kind,
					"yaw": rng.randf_range(0, TAU) + pose.basis.get_euler().y,
					"scale": scale,
					"stretch":
					(
						Vector3(1.15, 1, 1.15)
						if kind == 1
						else (Vector3(.82, 1.10, .82) if kind > 1 else Vector3.ONE)
					)
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

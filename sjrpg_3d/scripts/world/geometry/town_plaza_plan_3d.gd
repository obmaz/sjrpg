class_name TownPlazaPlan3D
extends RefCounted
## 미터 단위 마을 배치. 표시·충돌·주민·마당은 같은 중심과 Y 회전을 공유한다.
## 성벽 안쪽 보행 범위. 가장자리로 옮긴 주민도 마을 안전 구역에 포함한다.
const WALL_EXTENSION := Vector2(10.0, 10.0)
const TOWN_INTERIOR := Rect2(-21.0, -19.2, 51.0, 46.2)
const PLAZA := Rect2(-8.5, -7.5, 18.0, 18.0)
const GATE_ROAD_HALF_WIDTH := 1.65
const LEGACY_CENTERS := {
	"nw": Vector2(-15.0, 9.0),
	"ne": Vector2(-6.0, -12.6),
	"sw": Vector2(-6.0, 19.0),
	"se": Vector2(19.0, 18.0),
}
## +90°는 로컬 +Z 정면을 월드 +X, 즉 화면 우하단으로 돌린다.
const LEGACY_YAWS := {"nw": PI * .5, "ne": PI * .5, "sw": PI * .5, "se": 0.0}
## 길을 가로막지 않는 뒤쪽 수관 군락. 건물과 길 사이의 숲 층을 만든다.
const WOODLAND_TREES := [
	Vector2(-16.5, -15.2),
	Vector2(-12.0, -17.3),
	Vector2(-11.4, -12.7),
	Vector2(3.1, -16.4),
	Vector2(6.9, -17.0),
	Vector2(10.5, -16.0),
	Vector2(-18.1, 13.1),
	Vector2(13.0, 23.5)
]
const SERVICES := {
	"market_shop":
	{
		"center": Vector2(-14.3, -6.6),
		"size": Vector2(8.0, 8.0),
		"npc": "상인",
		"approach": Vector2(-0.6, 4.65)
	},
	"open_smithy":
	{
		"center": Vector2(22.0, -7.5),
		"size": Vector2(8.0, 8.0),
		"npc": "대장장이",
		"approach": Vector2(0.7, 4.65)
	},
}


## 원본 UV는 보존하고 동·남 성곽만 바깥으로 옮긴다. 지붕·문 크기는 늘리지 않는다.
static func wall_ground(village: Village, uv: Vector2) -> Vector2:
	var at := village.ground(uv)
	if uv.x > .75:
		at.x += WALL_EXTENSION.x * WorldSpace3D.GROUND_UNITS_PER_METER
	if uv.y > .75:
		at.y += WALL_EXTENSION.y * WorldSpace3D.GROUND_UNITS_PER_METER
	return at


## 실제 성문 개구부에서 광장 가장자리까지의 넓은 축. 외부 길도 이 출발점을 읽는다.
static func gate_routes(village: Village) -> Array[Dictionary]:
	var routes: Array[Dictionary] = []
	for index in village.gate_passages.size():
		var center := Vector2.ZERO
		for point: Vector2 in village.gate_passages[index]:
			center += Iso.unproject(point) / WorldSpace3D.GROUND_UNITS_PER_METER
		center /= village.gate_passages[index].size()
		var destination := center.clamp(PLAZA.position + Vector2.ONE, PLAZA.end - Vector2.ONE)
		routes.append({
			"gate": index,
			"points": PackedVector2Array([center, destination]),
			"width": GATE_ROAD_HALF_WIDTH * 2.0
		})
	return routes


## 둥근 광장 모서리와 성문 길을 같은 다각형으로 합쳐 지도/거리장에 전달한다.
static func paving(village: Village) -> PackedVector2Array:
	var rounded := Geometry2D.offset_polygon(
		ChapelPlan3D.polygon(PLAZA.grow(-1.0)), 1.0, Geometry2D.JOIN_ROUND
	)
	var merged: PackedVector2Array = rounded[0]
	for route: Dictionary in gate_routes(village):
		var polygons := Geometry2D.offset_polyline(
			route["points"], GATE_ROAD_HALF_WIDTH, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND
		)
		var joined := Geometry2D.merge_polygons(merged, polygons[0])
		assert(joined.size() == 1, "성문 길은 분수 광장에 이어져야 합니다.")
		merged = joined[0]
	for index in merged.size():
		merged[index] *= WorldSpace3D.GROUND_UNITS_PER_METER
	return merged


static func frame(id: String) -> Transform3D:
	var legacy := LEGACY_CENTERS.has(id)
	var center: Vector2 = LEGACY_CENTERS[id] if legacy else SERVICES[id]["center"]
	var yaw: float = LEGACY_YAWS[id] if legacy else float(SERVICES[id].get("yaw", 0.0))
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(center.x, 0, center.y))


static func house_size(village: Village, key: String) -> Vector2:
	var size: Vector2 = village.buildings[key].get_meta("native_source_size")
	return Vector2(maxf(3.5, size.x), maxf(3.0, size.y))


static func house_footprint(village: Village, key: String) -> PackedVector2Array:
	var size := house_size(village, key)
	return project(ChapelPlan3D.polygon(Rect2(-size * .5, size)), frame(key))


## 호환 원화의 배치 점을 해당 건물의 실제 월드 포즈로 옮긴다.
static func source_point(key: String, point: Vector2) -> Vector2:
	var pose := frame(key)
	var flat := Iso.unproject(point) / WorldSpace3D.GROUND_UNITS_PER_METER
	var local := flat - Vector2(pose.origin.x, pose.origin.z)
	return WorldSpace3D.world_to_projected(pose * Vector3(local.x, 0, local.y))


## 주민은 예전 그림의 먼 마당 좌표 대신 실제 GLB 문 접근 구역 바깥에 선다.
static func house_approach(key: String) -> Vector2:
	var identity: String = NativeHousePlan.STYLES[key]["wall"]
	var layout := (
		load(ArchitectureSceneLibrary.ARCHITECTURE_SCENE_ROOT + identity + "/layout.tres")
		as Resource
	)
	var report: Dictionary = layout.get_meta("report")
	var doorway: Rect2 = report["door_approach"]
	return WorldSpace3D.world_to_projected(
		frame(key) * Vector3(doorway.get_center().x, 0, doorway.end.y + .15)
	)


static func approach(id: String) -> Vector2:
	var local: Vector2 = SERVICES[id]["approach"]
	return WorldSpace3D.world_to_projected(frame(id) * Vector3(local.x, 0, local.y))


static func footprint(id: String) -> PackedVector2Array:
	var size: Vector2 = SERVICES[id]["size"]
	return project(ChapelPlan3D.polygon(Rect2(-size * .5, size)), frame(id))


static func project(points: PackedVector2Array, transform: Transform3D) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p: Vector2 in points:
		result.append(WorldSpace3D.world_to_projected(transform * Vector3(p.x, 0, p.y)))
	return result


## 보이는 본체/진열대/아궁이만 막고 열린 작업장 바닥은 걸을 수 있다.
## box = 중심/치수, 모두 모델 제작기와 공유하는 로컬 미터.
static func blockers(id: String) -> Array[Dictionary]:
	if id == "market_shop":
		return [
			{"at": Vector3(0, 1.85, -0.8), "size": Vector3(6.8, 3.7, 4.4)},
			{"at": Vector3(-1.05, .58, 2.80), "size": Vector3(4.05, 1.16, .85)},
			{"at": Vector3(.62, 1.26, 1.73), "size": Vector3(.66, 2.52, .60)},
			{"at": Vector3(-3.35, .48, 2.30), "size": Vector3(.60, .96, .60)},
			{"at": Vector3(1.28, .42, 2.45), "size": Vector3(.64, .84, .64)},
		]
	return [
		{"at": Vector3(-2.25, 1.9, -.8), "size": Vector3(2.3, 3.8, 4.4)},
		{"at": Vector3(1.15, 1.6, -2.88), "size": Vector3(4.5, 3.2, .24)},
		{"at": Vector3(3.30, 1.55, -1.35), "size": Vector3(.20, 3.1, 3.0)},
		{"at": Vector3(.42, 1.13, 1.68), "size": Vector3(2.36, 2.26, 1.40)},
		{"at": Vector3(.25, .60, 3.15), "size": Vector3(1.24, 1.2, .80)},
		{"at": Vector3(2.62, .55, 1.35), "size": Vector3(.88, 1.1, 1.7)},
	]


static func posts(id: String) -> Array[Vector3]:
	if id == "market_shop":
		return [Vector3(-3.10, 1.37, 3.18), Vector3(.90, 1.37, 3.18)]
	return [Vector3(-.85, 1.88, 2.45), Vector3(3.25, 1.68, 2.45)]

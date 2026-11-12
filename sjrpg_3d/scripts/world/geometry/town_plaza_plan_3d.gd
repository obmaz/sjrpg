class_name TownPlazaPlan3D
extends RefCounted
## 미터 단위 마을 설계. 기존 주택의 치수/모델은 유지하고 중심만 옮긴다.
## 성벽 안쪽 보행 범위. 가장자리로 옮긴 주민도 마을 안전 구역에 포함한다.
const TOWN_INTERIOR := Rect2(-21.0, -19.2, 41.0, 36.2)
const PLAZA := Rect2(-7.2, -7.0, 14.4, 14.5)
const LEGACY_CENTERS := {
	"nw": Vector2(-15.0, 8.0),
	"ne": Vector2(-12.0, -15.0),
	"sw": Vector2(6.2, 10.0),
	"se": Vector2(15.0, 8.0),
}
const SERVICES := {
	"market_shop":
	{
		"center": Vector2(-12.0, -6.6),
		"size": Vector2(8.0, 8.0),
		"npc": "상인",
		"approach": Vector2(-0.6, 4.65)
	},
	"open_smithy":
	{
		"center": Vector2(14.0, -6.6),
		"size": Vector2(8.0, 8.0),
		"npc": "대장장이",
		"approach": Vector2(0.7, 4.65)
	},
}


static func frame(id: String) -> Transform3D:
	var center: Vector2 = SERVICES[id]["center"]
	return Transform3D(Basis.IDENTITY, Vector3(center.x, 0, center.y))


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

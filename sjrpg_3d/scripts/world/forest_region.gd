class_name ForestRegion
extends RefCounted
## 확장 필드의 실제 지면·탐험 동선. 좌표는 원본 지면 단위이며 표시/지도/판정이 공유한다.
const FIELD := Rect2(-3600, -3600, 14400, 14400)
## 확장 맵의 투영 모서리(최대 약12097px)와 배우 배치 여백을 포함한다.
const SAVE_COORD_LIMIT := 12500.0
const CAVE_GROUND := Vector2(7600, 7600)
const BRIDGE_U := 5200.0
const BRIDGE_V := 5200.0
const RIVER_START_U := -4000.0
const RIVER_END_U := 11200.0
const BOSS_GROUND := Vector2(3700, 8600)
const LANDMARK_SPOTS := [
	[2, Vector2(3600, 1600)],
	[1, Vector2(7600, 1800)],
	[0, Vector2(1200, 7800)],
	[3, Vector2(9400, 900)]
]
const ENCOUNTER_SITES := {
	"west": Vector2(-1700, 320),
	"north": Vector2(320, -1700),
	"east": Vector2(3100, 1000),
	"south": Vector2(1200, 2600),
	"deep_west": Vector2(7000, 1900),
	"deep_east": Vector2(4300, 7800)
}


static func native_bounds() -> Rect2:
	return Rect2(FIELD.position / WorldSpace3D.GROUND_UNITS_PER_METER, FIELD.size / WorldSpace3D.GROUND_UNITS_PER_METER)


static func area_name(projected: Vector2) -> String:
	var ground := Iso.unproject(projected)
	if ground.distance_to(CAVE_GROUND) < 1700:
		return "동굴 골짜기"
	if ground.distance_to(BOSS_GROUND) < 1200:
		return "파수꾼 공터"
	if ground.length() < 3000:
		return "마을 외곽"
	if ground.y > BRIDGE_V:
		return "강 건너 숲"
	return "동쪽 깊은 숲" if ground.x > 6000 else "숲 가장자리"

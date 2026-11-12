class_name ForestBalance
extends RefCounted
## Godot forest tuning lives outside the extracted source catalogs.
## Fixed area levels let upgrades make familiar routes easier; the cave scales separately.

const AREA_LEVELS := [1, 3, 5, 7]
const SPAWN_SECONDS := 2.0
const NEAR_TOWN_RADIUS := 2100.0
const NEAR_TOWN_HP := 0.65
const NEAR_TOWN_DAMAGE := 0.8
const BOSS_HP := 1800.0
const BOSS_DAMAGE := 22.0


static func area_level(zone: int) -> int:
	return AREA_LEVELS[clampi(zone, 0, AREA_LEVELS.size() - 1)]


static func field_limit(near_town: bool) -> int:
	return 10 if near_town else 16


## 화면 좌표 길이는 방향마다 배율이 다르므로 실제 지면 거리로 확장 필드의 난이도를 나눈다.
static func zone_at(projected: Vector2) -> int:
	var distance := Iso.unproject(projected).length()
	if distance < 2400:
		return 0
	if distance < 4600:
		return 1
	return 2 if distance < 7600 else 3

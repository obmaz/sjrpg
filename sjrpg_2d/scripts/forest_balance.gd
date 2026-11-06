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

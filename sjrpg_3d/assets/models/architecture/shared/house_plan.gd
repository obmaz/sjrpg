class_name NativeHousePlan
extends RefCounted
## 런타임 배치와 오프라인 모델 제작이 공유하는 주택 패밀리 규격.

const WALL := 0.20
const EAVES := 0.22
const FLOOR := 0.16
const MATERIAL_KEYS := ["stone", "wall", "slate", "wood", "iron", "glass"]
## Each house reads as its own building: wall infill, trim stone and roof cover
## differ by role, while timber, iron and glass stay shared with the family.
const STYLES := {
	"nw":
	{
		"wall": "shop",
		"stone": "village_stone",
		"slate": "roof_shop",
		"wood": "door_shop",
		"label": "half-timbered merchant shop"
	},
	"ne":
	{
		"wall": "smith",
		"stone": "village_stone",
		"slate": "roof_smith",
		"wood": "door_smith",
		"label": "fieldstone smithy"
	},
	"sw":
	{
		"wall": "stable",
		"stone": "village_stone",
		"slate": "roof_stable",
		"wood": "door_stable",
		"label": "timber stable house"
	},
	"se":
	{
		"wall": "home",
		"stone": "village_stone",
		"slate": "roof_home",
		"wood": "door_home",
		"label": "lime-plaster dormer house"
	},
}
const TIMBER_TILE := 1.0 / 0.65
const SLATE_TILE := 2.6
const SLATE_COURSES := 8
const SLATE_PITCH := SLATE_TILE / SLATE_COURSES
const SLATE_COLUMNS := 6
const SLATE_WIDTH := SLATE_TILE / SLATE_COLUMNS
const ASHLAR_COURSE := 0.32


static func resource_key(key: String, material: String) -> String:
	if material == "wood":
		return str(STYLES.get(key, {}).get("wood", "door"))
	var style: Dictionary = STYLES.get(key, {})
	return str(style.get(material, "stone" if material == "wall" else material))

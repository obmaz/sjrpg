extends Node
## Persistent hero progress (autoload `GameState`). Saved to user:// (IndexedDB on the web).

const SAVE_PATH := "user://guardian_save.json"

const CLASSES := {
	"warrior": {
		"name": "전사",
		"desc": "강인한 체력과 분노로 싸우는 근접 전투가.\n기본 공격: 베기 · 기술: 회오리 베기",
		"hp": 120.0, "hp_per_level": 18.0,
		"resource": "분노", "resource_max": 100.0,
		"attack": 14.0, "attack_per_level": 3.0,
		"defense": 4.0, "defense_per_level": 1.2,
		"speed": 190.0,
		"atlas": "warrior", "attack_atlas": "warrior-attack",
		"skill": "회오리 베기", "basic": "베기",
	},
	"mage": {
		"name": "마법사",
		"desc": "냉기·번개·화염을 다루는 원거리 주문사.\n기본 공격: 화염탄 · 기술: 얼음 폭발",
		"hp": 85.0, "hp_per_level": 11.0,
		"resource": "마나", "resource_max": 100.0,
		"attack": 16.0, "attack_per_level": 3.4,
		"defense": 2.0, "defense_per_level": 0.7,
		"speed": 180.0,
		"atlas": "mage", "attack_atlas": "mage-cast",
		"skill": "얼음 폭발", "basic": "화염탄",
	},
}

var hero_class := "warrior"
var level := 1
var xp := 0
var potions := 3
var kills := 0


func class_info() -> Dictionary:
	return CLASSES[hero_class]


func max_hp() -> float:
	var c := class_info()
	return c["hp"] + c["hp_per_level"] * (level - 1)


func attack_power() -> float:
	var c := class_info()
	return c["attack"] + c["attack_per_level"] * (level - 1)


func defense() -> float:
	var c := class_info()
	return c["defense"] + c["defense_per_level"] * (level - 1)


func xp_to_next() -> int:
	return 40 + (level - 1) * 35 + (level - 1) * (level - 1) * 6


## Returns the number of levels gained.
func add_xp(amount: int) -> int:
	xp += amount
	var gained := 0
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		gained += 1
	return gained


func new_game(cls: String) -> void:
	hero_class = cls
	level = 1
	xp = 0
	potions = 3
	kills = 0
	save_game()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"class": hero_class, "level": level, "xp": xp,
		"potions": potions, "kills": kills,
	}))


func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or not CLASSES.has(data.get("class", "")):
		return false
	hero_class = data["class"]
	level = int(data.get("level", 1))
	xp = int(data.get("xp", 0))
	potions = int(data.get("potions", 3))
	kills = int(data.get("kills", 0))
	return true

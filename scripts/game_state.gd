extends Node
## Persistent hero progress (autoload `GameState`). Saved to user:// (IndexedDB on the web).

const SAVE_PATH := "user://guardian_save.json"

const CLASSES := {
	"warrior": {
		"name": "전사",
		"desc": "강인한 체력과 분노로 싸우는 근접 전투가.\n함성 · 전투 숙련 · 전투 기술 30종",
		"hp": 100.0, "hp_per_level": 10.0,
		"resource": "분노", "resource_max": 100.0, "resource_start": 25.0,
		"attack": 14.0, "attack_per_level": 3.0,
		"defense": 4.0, "defense_per_level": 1.2,
		"speed": 190.0,
		"atlas": "warrior", "attack_atlas": "warrior-attack",
	},
	"mage": {
		"name": "마법사",
		"desc": "냉기·번개·화염을 다루는 원거리 주문사.\n냉기 · 번개 · 화염 주문 30종",
		"hp": 80.0, "hp_per_level": 10.0,
		"resource": "마나", "resource_max": 90.0, "resource_start": 90.0,
		"attack": 16.0, "attack_per_level": 3.4,
		"defense": 2.0, "defense_per_level": 0.7,
		"speed": 180.0,
		"atlas": "mage", "attack_atlas": "mage-cast",
	},
}

var hero_class := "warrior"
var level := 1
var xp := 0
var potions := 3
var mana_potions := 2
var kills := 0
## Skill tree (원본 rpg_model.dart): 2 starting points, +1 per level and +2 every fifth level.
var skill_points := 2
var ranks: Dictionary = {}
## slots[0] is the main (big) button, 1–4 are the auxiliary combat slots.
var slots: Array = ["", "", "", "", ""]
## Temporary +ranks from 전투 명령 (battleCommand); never saved.
var bonus_ranks := 0

static var _skill_data: Dictionary = {}


static func skill_data() -> Dictionary:
	if _skill_data.is_empty():
		var file := FileAccess.open("res://assets/data/skills.json", FileAccess.READ)
		_skill_data = JSON.parse_string(file.get_as_text())
		for cls in _skill_data:
			var by_id := {}
			for skill in _skill_data[cls]["skills"]:
				by_id[skill["id"]] = skill
			_skill_data[cls]["by_id"] = by_id
	return _skill_data


func skills() -> Array:
	return skill_data()[hero_class]["skills"]


func skill(id: String) -> Dictionary:
	return skill_data()[hero_class]["by_id"].get(id, {})


func rank(id: String) -> int:
	return int(ranks.get(id, 0))


## Rank used in combat (includes 전투 명령 while it lasts).
func effective_rank(id: String) -> int:
	var r := rank(id)
	return r + bonus_ranks if r > 0 else 0


func starter_ids() -> Array:
	return ["cleave", "howl"] if hero_class == "warrior" else ["firebolt", "sorceressAttack"]


func required_level_for_rank(s: Dictionary, desired: int) -> int:
	var base := int(s["level"])
	if int(s["limit"]) == 20:
		return base + clampi(desired - 1, 0, 19)
	return base


func prerequisites_met(s: Dictionary) -> bool:
	for req in s["requires"]:
		if rank(req) < int(s["requires"][req]):
			return false
	return true


## Empty string when learnable, otherwise the reason (shown in the tree).
func learn_block_reason(s: Dictionary) -> String:
	var r := rank(s["id"])
	if r >= int(s["limit"]):
		return "최고 등급입니다"
	if r == 0 and not prerequisites_met(s):
		var names := []
		for req in s["requires"]:
			if rank(req) < int(s["requires"][req]):
				names.append("%s %d등급" % [skill(req).get("name", req), s["requires"][req]])
		return "선행 기술: " + ", ".join(names)
	var need := required_level_for_rank(s, r + 1)
	if level < need:
		return "레벨 %d 필요" % need
	if skill_points <= 0:
		return "스킬 포인트가 없습니다"
	return ""


func is_assignable(s: Dictionary) -> bool:
	return s["basic"] or not s["passive"]


func learn(id: String) -> bool:
	var s := skill(id)
	if s.is_empty() or learn_block_reason(s) != "":
		return false
	var first := rank(id) == 0
	skill_points -= 1
	ranks[id] = rank(id) + 1
	# Newly learned active skills fill the first empty slot, like the original.
	if first and is_assignable(s) and not slots.has(id):
		for i in range(1, 5):
			if slots[i] == "":
				slots[i] = id
				break
	save_game()
	return true


func invested_points() -> int:
	var total := 0
	var starters := starter_ids()
	for id in ranks:
		total += maxi(0, int(ranks[id]) - (1 if starters.has(id) else 0))
	return total


func reset_skills() -> void:
	skill_points += invested_points()
	_starter_skills()
	save_game()


func _starter_skills() -> void:
	ranks = {}
	var starters := starter_ids()
	for id in starters:
		ranks[id] = 1
	slots = [starters[0], "howl" if hero_class == "warrior" else "", "", "", ""]


func assign_slot(index: int, id: String) -> void:
	for i in slots.size():
		if slots[i] == id:
			slots[i] = ""
	slots[index] = id
	save_game()


func clear_slot(index: int) -> void:
	slots[index] = ""
	save_game()


static func points_for_level(lv: int) -> int:
	var total := 2
	for l in range(2, lv + 1):
		total += 2 if l % 5 == 0 else 1
	return total


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
		skill_points += 2 if level % 5 == 0 else 1
	return gained


func new_game(cls: String) -> void:
	hero_class = cls
	level = 1
	xp = 0
	potions = 3
	mana_potions = 2
	kills = 0
	skill_points = 2
	_starter_skills()
	save_game()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"class": hero_class, "level": level, "xp": xp,
		"potions": potions, "mana_potions": mana_potions, "kills": kills,
		"skill_points": skill_points, "ranks": ranks, "slots": slots,
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
	mana_potions = int(data.get("mana_potions", 2))
	kills = int(data.get("kills", 0))
	if data.has("ranks"):
		ranks = {}
		for id in data["ranks"]:
			if not skill(id).is_empty():
				ranks[id] = clampi(int(data["ranks"][id]), 0, int(skill(id)["limit"]))
		skill_points = int(data.get("skill_points", 0))
		slots = ["", "", "", "", ""]
		var saved: Array = data.get("slots", [])
		for i in mini(saved.size(), 5):
			if rank(str(saved[i])) > 0:
				slots[i] = str(saved[i])
	else:
		# Saves from before the skill tree: grant the points earned so far.
		_starter_skills()
		skill_points = points_for_level(level)
	return true

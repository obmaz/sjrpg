extends Node
## Persistent hero progress (autoload `GameState`). Saved to user:// (IndexedDB on the web).

signal save_finished(success: bool, message: String)

const SAVE_PATH := "user://guardian_save.json"
const SAVE_VERSION := 1
var save_path := SAVE_PATH
var save_error := ""
var loaded_backup := false

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
## 제1장 진행: 의뢰 상태, 이번 장 처치 수, 파수꾼 처치 여부.
var quests := {}
var stage_kills := 0
var boss_defeated := false
var boss_heart_pending := false
var boss_summoned := false
var memory_rewarded := false
var discovered_sanctuaries: Array[String] = ["town"]
var last_sanctuary := "town"
var location_mode := "forest"
var return_to_cave_entrance := false
## Encounter clocks use active gameplay seconds; no wall-clock timestamp is persisted.
var encounters: Dictionary = {}
## A live world refreshes survivors immediately before saving. Never persisted.
var encounter_capture: Callable = Callable()
var gold := 0
## 상점 축복(수련): 공격 +5 / 생명 +20씩 쌓임 (원본 bonusAttack / bonusHealth).
var bonus_attack := 0.0
var bonus_health := 0.0
## 장비 (원본 Progress.inventory / equipped): 보관함 24칸, 부위별 착용 1개.
var inventory: Array[Gear] = []
var equipped := {}  # slot name -> Gear
var unseen: Array[int] = []
var next_serial := 1
## 상자 보상 순서 (원본 chestContent: 열 개 중 장비 7 · 보급 1 · 골드 1 · 매복 1) and opened chests.
var chest_seed := 1
var opened_chests: Array[int] = []
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


## Canonical combat numbers (원본 rpg_model.dart); the HUD shows health/damage ×100, resources ×10.
const PLAYER_DAMAGE_SCALE := 0.75 * 0.85


func equipped_sum(stat: String) -> float:
	var total := 0.0
	for g in equipped.values():
		total += g.call(stat)
	return total


func max_hp() -> float:
	var c := class_info()
	return c["hp"] + c["hp_per_level"] * (level - 1) + equipped_sum("health") + bonus_health


func max_resource() -> float:
	return class_info()["resource_max"] + equipped_sum("mana")


## swordDamage: (레벨 보너스 + 착용 장비 공격) × 0.6375. 마법사의 주문은 무기 공격을 절반만
## 반영하고(원본: 주문 곡선은 무기를 상속하지 않음) 기본 위력을 따로 가집니다.
func attack_power() -> float:
	var gear_attack := equipped_sum("attack")
	if hero_class == "warrior":
		return (bonus_attack + (level - 1) * 2.0 + gear_attack) * PLAYER_DAMAGE_SCALE
	return (10.0 + bonus_attack * 0.5 + (level - 1) * 2.0 + gear_attack * 0.5) * PLAYER_DAMAGE_SCALE * 1.5


## 수련 단계: 레벨 3마다 한 단계씩 상한이 늘어남.
func max_training_rank() -> int:
	return 1 + (level - 1) / 3


func attack_training_rank() -> int:
	return floori(bonus_attack / 5.0)


func vitality_training_rank() -> int:
	return floori(bonus_health / 20.0)


func attack_training_cost() -> int:
	return 45 + attack_training_rank() * 35


func vitality_training_cost() -> int:
	return 60 + vitality_training_rank() * 40


func defense() -> float:
	return equipped_sum("armor")


## ── 장비 ──

func new_gear(def_id: String, r := 0, p := 0, v := 0, f := 0) -> Gear:
	var g := Gear.make(next_serial, def_id, r, p, v, f, level)
	next_serial += 1
	return g


func add_gear(g: Gear) -> bool:
	if inventory.size() >= Gear.CAPACITY:
		return false
	inventory.append(g)
	next_serial = maxi(next_serial, g.serial + 1)
	unseen.append(g.serial)
	# 무기가 없으면(파괴됨) 새 무기를 바로 착용합니다.
	if g.slot() == "weapon" and not equipped.has("weapon") and Gear.usable(g.base, hero_class):
		equip(g)
	return true


func has_gift(id: String) -> bool:
	for g in equipped.values():
		if g.has_gift(id):
			return true
	return false


func is_equipped(g: Gear) -> bool:
	return equipped.get(g.slot()) == g


func can_equip(g: Gear) -> bool:
	return Gear.usable(g.base, hero_class)


func equip(g: Gear) -> bool:
	if not inventory.has(g) or not can_equip(g):
		return false
	equipped[g.slot()] = g
	unseen.erase(g.serial)
	return true


func unequip(g: Gear) -> bool:
	if g.slot() == "weapon" or not is_equipped(g):
		return false
	equipped.erase(g.slot())
	return true


func sell(g: Gear) -> bool:
	if g.locked or is_equipped(g) or not inventory.has(g):
		return false
	inventory.erase(g)
	unseen.erase(g.serial)
	gold += g.sale_value()
	return true


func _starting_gear() -> void:
	inventory.clear()
	equipped.clear()
	unseen.clear()
	next_serial = 1
	var weapon := new_gear("shortsword" if hero_class == "warrior" else "wand")
	var armor := new_gear("linen")
	for g in [weapon, armor]:
		inventory.append(g)
		equipped[g.slot()] = g
		next_serial = maxi(next_serial, g.serial + 1)


## 상자 열 개 묶음 (원본: 장비 7 · 보급 1 · 골드 1 · 매복 1을 시드로 섞음).
func chest_content(index: int) -> String:
	var bag := ["gear", "gear", "gear", "gear", "gear", "gear", "gear", "supplies", "coins", "ambush"]
	var rng := RandomNumberGenerator.new()
	rng.seed = chest_seed * 7919 + (index / 10) * 104729 + 0x193af
	for i in range(bag.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = bag[i]
		bag[i] = bag[j]
		bag[j] = tmp
	return bag[index % 10]


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
	# Detach the previous world before the initial save can request a snapshot.
	encounter_capture = Callable()
	encounters = {}
	bonus_ranks = 0
	hero_class = cls
	level = 1
	xp = 0
	potions = 3
	mana_potions = 2
	kills = 0
	gold = 0
	quests = {}
	stage_kills = 0
	boss_defeated = false
	boss_heart_pending = false
	boss_summoned = false
	memory_rewarded = false
	discovered_sanctuaries.assign(["town"])
	last_sanctuary = "town"
	location_mode = "forest"
	return_to_cave_entrance = false
	bonus_attack = 0.0
	bonus_health = 0.0
	chest_seed = randi() % 0x7fffffff
	opened_chests.clear()
	skill_points = 2
	_starter_skills()
	_starting_gear()
	save_game()


func delete_save() -> void:
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(save_path + suffix)


func has_save() -> bool:
	return not SaveStore.read(save_path, _valid_save).is_empty()


## Unreadable or interrupted saves still belong to the player and require replacement confirmation.
func has_save_files() -> bool:
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			return true
	return false


func save_game() -> bool:
	if encounter_capture.is_valid():
		encounter_capture.call()
	var data := {
		"version": SAVE_VERSION, "class": hero_class, "level": level, "xp": xp,
		"potions": potions, "mana_potions": mana_potions, "kills": kills,
		"skill_points": skill_points, "ranks": ranks, "slots": slots,
		"quests": quests, "stage_kills": stage_kills, "boss_defeated": boss_defeated, "boss_heart_pending": boss_heart_pending, "memory_rewarded": memory_rewarded, "discovered_sanctuaries": discovered_sanctuaries, "last_sanctuary": last_sanctuary, "location_mode": location_mode, "gold": gold, "bonus_attack": bonus_attack, "bonus_health": bonus_health, "chest_seed": chest_seed, "opened_chests": opened_chests,
		"encounters": encounters.duplicate(true),
		"next_serial": next_serial,
		"inventory": inventory.map(func(g): return g.to_save()),
		"equipped": equipped.keys().map(func(k): return {"slot": k, "serial": equipped[k].serial}),
		"unseen": unseen,
	}
	var error := SaveStore.write(save_path, data, _valid_save)
	if error == OK and OS.has_feature("web") and not OS.is_userfs_persistent():
		error = ERR_UNAVAILABLE
	save_error = "" if error == OK else "저장하지 못했습니다. 설정에서 다시 저장해 주세요. (%s)" % error_string(error)
	save_finished.emit(error == OK, save_error)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sjrpgSaveProbe = " + JSON.stringify({"success": error == OK, "class": hero_class, "level": level, "path": ProjectSettings.globalize_path(save_path)}))
	return error == OK


## Validate containers before applying a save so malformed data cannot partially replace the hero.
func _valid_save(data: Dictionary) -> bool:
	if not _valid_encounters(data.get("encounters", {})):
		return false
	if not CLASSES.has(data.get("class", "")):
		return false
	for key in ["version", "level", "xp", "potions", "mana_potions", "kills", "skill_points", "gold", "stage_kills", "bonus_attack", "bonus_health", "chest_seed", "next_serial"]:
		if data.has(key) and (not _number(data[key]) or float(data[key]) < 0):
			return false
	if int(data.get("version", 0)) > SAVE_VERSION or int(data.get("level", 1)) < 1:
		return false
	for key in ["ranks", "quests"]:
		if data.has(key) and not data[key] is Dictionary:
			return false
	for value in data.get("ranks", {}).values():
		if not _number(value):
			return false
	for record in data.get("quests", {}).values():
		if not record is Dictionary:
			return false
		for key in ["altar_kills", "protected_for", "defender_hp", "defeated", "attempt", "spawned"]:
			if record.has(key) and not _number(record[key]):
				return false
	for key in ["slots", "inventory", "equipped", "unseen", "opened_chests", "discovered_sanctuaries"]:
		if data.has(key) and not data[key] is Array:
			return false
	for key in ["unseen", "opened_chests"]:
		for value in data.get(key, []):
			if not _number(value):
				return false
	for record in data.get("inventory", []):
		if not record is Dictionary:
			return false
		for key in ["serial", "rarity", "power", "vitality", "focus", "level", "weapon_level"]:
			if record.has(key) and not _number(record[key]):
				return false
		if record.has("gifts") and not record["gifts"] is Array:
			return false
	for record in data.get("equipped", []):
		if not record is Dictionary or not _number(record.get("serial", 0)):
			return false
	return true


## JSON decodes integers as numbers, so require an integral value rather than a Variant integer tag.
func _encounter_integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value) and float(value) >= minimum and float(value) <= maximum and float(value) == floorf(float(value))


func _encounter_id(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 40:
		return false
	for i in value.length():
		var code: int = value.unicode_at(i)
		if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code in [45, 58, 95]):
			return false
	return true


func _valid_encounters(value: Variant) -> bool:
	if not value is Dictionary or value.size() > 12:
		return false
	var total_members := 0
	for id in value:
		if not _encounter_id(id):
			return false
		var raw: Variant = value[id]
		if not raw is Dictionary:
			return false
		var record: Dictionary = raw
		if not _encounter_integer(record.get("charges"), 0, 3):
			return false
		var recharge: Variant = record.get("recharge")
		if not _number(recharge) or float(recharge) < 0.0 or float(recharge) >= 300.0:
			return false
		if float(record["charges"]) == 3.0 and float(recharge) != 0.0:
			return false
		if not record.get("initial_spawned") is bool or not record.get("members") is Array:
			return false
		var members: Array = record["members"]
		total_members += members.size()
		if members.size() > 12 or total_members > 30:
			return false
		for member in members:
			if not member is Dictionary:
				return false
			if not ["goblin", "wolf", "boar", "skeleton"].has(member.get("kind")) or not _encounter_integer(member.get("level"), 1, 20):
				return false
			var health: Variant = member.get("hp")
			if not _number(health) or float(health) <= 0.0 or float(health) > 100000.0:
				return false
			var at: Variant = member.get("position")
			if not at is Array or at.size() != 2:
				return false
			for coordinate in at:
				if not _number(coordinate) or absf(float(coordinate)) > 10000.0:
					return false
	return true


func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func load_game() -> bool:
	# Even a failed continue attempt must not retain a snapshotter from the old world.
	encounter_capture = Callable()
	var recovered := SaveStore.read(save_path, _valid_save)
	if recovered.is_empty():
		return false
	var data: Dictionary = recovered["data"]
	# Command buffs belong to the old Player and have no timer after a new session starts.
	bonus_ranks = 0
	loaded_backup = recovered["backup"]
	var saved_encounters: Dictionary = data.get("encounters", {})
	encounters = saved_encounters.duplicate(true)
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
	gold = int(data.get("gold", 0))
	quests = {}
	var saved_quests: Dictionary = data.get("quests", {})
	for definition in Quests.DEFS:
		var id: String = definition["id"]
		var state := Quests.fresh(id)
		state.merge(saved_quests.get(id, {}), true)
		if not ["offered", "accepted", "ready", "completed", "failed"].has(state["phase"]):
			state = Quests.fresh(id)
		# Threat nodes are transient; restart an interrupted defense without losing other quests.
		if id == "sun" and state["phase"] == "accepted" and state["started"]:
			var attempt := int(state["attempt"]) + 1
			state = Quests.fresh(id)
			state["phase"] = "accepted"
			state["attempt"] = attempt
		quests[id] = state
	return_to_cave_entrance = data.get("location_mode", "forest") == "cave"
	location_mode = "forest"
	stage_kills = int(data.get("stage_kills", 0))
	boss_defeated = bool(data.get("boss_defeated", false))
	boss_heart_pending = bool(data.get("boss_heart_pending", false))
	memory_rewarded = bool(data.get("memory_rewarded", false))
	discovered_sanctuaries.assign(["town"])
	for id in data.get("discovered_sanctuaries", []):
		if Exploration.NAMES.has(id) and not discovered_sanctuaries.has(id):
			discovered_sanctuaries.append(id)
	last_sanctuary = str(data.get("last_sanctuary", "town"))
	if not discovered_sanctuaries.has(last_sanctuary):
		last_sanctuary = "town"
	boss_summoned = false
	bonus_attack = float(data.get("bonus_attack", 0.0))
	bonus_health = float(data.get("bonus_health", 0.0))
	chest_seed = int(data.get("chest_seed", 1))
	opened_chests.clear()
	for c in data.get("opened_chests", []):
		opened_chests.append(int(c))
	next_serial = int(data.get("next_serial", 1))
	if data.has("inventory"):
		inventory.clear()
		equipped.clear()
		unseen.clear()
		for raw in data["inventory"]:
			var g := Gear.from_save(raw)
			if g != null and inventory.size() < Gear.CAPACITY:
				inventory.append(g)
				next_serial = maxi(next_serial, g.serial + 1)
		for e in data.get("equipped", []):
			for g in inventory:
				if g.serial == int(e.get("serial", 0)) and g.slot() == str(e.get("slot", "")) and can_equip(g):
					equipped[g.slot()] = g
		for u in data.get("unseen", []):
			unseen.append(int(u))
	else:
		_starting_gear()
	collect_memory_reward()
	return true


## Chest flags and the one-time point are committed together; also repairs saves interrupted before the award.
func collect_memory_reward() -> bool:
	if memory_rewarded or MemoryPanel.recovered() != MemoryPanel.MEMORIES.size():
		return false
	memory_rewarded = true
	skill_points += 1
	return true


func claim_boss_heart() -> bool:
	if not boss_heart_pending or inventory.size() >= Gear.CAPACITY:
		return false
	add_gear(new_gear("sentinel", 3, 6, 20, 0))
	boss_heart_pending = false
	save_game()
	return true

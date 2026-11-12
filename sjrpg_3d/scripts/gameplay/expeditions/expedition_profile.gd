class_name ExpeditionProfile
extends RefCounted
## 원정이 기존 슬롯을 덮어쓰지 않도록 현재 진행을 직렬화해 한 저장 문서 안에 보관한다.
const INTS := [
	"level",
	"xp",
	"potions",
	"mana_potions",
	"kills",
	"gold",
	"stage_kills",
	"chest_seed",
	"skill_points",
	"next_serial"
]
const FLAGS := ["boss_defeated", "boss_heart_pending", "memory_rewarded"]
const MAPS := ["quests", "encounters", "ranks"]
const LISTS := ["slots", "opened_chests"]


static func capture() -> Dictionary:
	var data := {"class": GameState.hero_class}
	for key: String in (
		INTS
		+ FLAGS
		+ MAPS
		+ LISTS
		+ ["bonus_attack", "bonus_health", "last_sanctuary", "location_mode"]
	):
		var value: Variant = GameState.get(key)
		data[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	data["discovered_sanctuaries"] = GameState.discovered_sanctuaries.duplicate()
	data["inventory"] = GameState.inventory.map(func(gear: Gear): return gear.to_save())
	data["equipped"] = GameState.equipped.keys().map(
		func(key): return {"slot": key, "serial": GameState.equipped[key].serial}
	)
	data["unseen"] = GameState.unseen.duplicate()
	return data


static func restore(data: Dictionary) -> void:
	GameState.hero_class = str(data["class"])
	for key: String in INTS:
		GameState.set(key, int(data[key]))
	for key: String in FLAGS:
		GameState.set(key, bool(data[key]))
	for key: String in MAPS + ["slots"]:
		GameState.set(key, data[key].duplicate(true))
	GameState.opened_chests.clear()
	for id: Variant in data["opened_chests"]:
		GameState.opened_chests.append(int(id))
	GameState.bonus_attack = float(data["bonus_attack"])
	GameState.bonus_health = float(data["bonus_health"])
	GameState.last_sanctuary = str(data["last_sanctuary"])
	GameState.location_mode = str(data["location_mode"])
	GameState.discovered_sanctuaries.assign(data["discovered_sanctuaries"])
	GameState.inventory.clear()
	GameState.equipped.clear()
	GameState.unseen.clear()
	for record: Dictionary in data["inventory"]:
		var gear := Gear.from_save(record)
		if gear != null:
			GameState.inventory.append(gear)
	for record: Dictionary in data["equipped"]:
		for gear: Gear in GameState.inventory:
			if gear.serial == int(record["serial"]):
				GameState.equipped[str(record["slot"])] = gear
	for serial: Variant in data["unseen"]:
		GameState.unseen.append(int(serial))
	GameState.boss_summoned = false
	GameState.bonus_ranks = 0
	GameState.return_to_cave_entrance = false

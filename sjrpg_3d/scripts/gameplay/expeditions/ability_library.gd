class_name AbilityLibrary
extends RefCounted
## 폴더 하나가 스킬 하나다. 기존 기술은 원본 카탈로그, 새 기술은 ability.json을 읽는다.
const ROOT := "res://assets/abilities/"
static var _abilities: Dictionary = {}
static var _loaded := false


static func all() -> Dictionary:
	if not _loaded:
		_loaded = true
		var folders := DirAccess.get_directories_at(ROOT)
		folders.sort()
		for folder in folders:
			var path := ROOT + folder + "/ability.json"
			if not FileAccess.file_exists(path):
				continue
			var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if (
				raw is Dictionary
				and raw.get("id", "") == folder
				and raw.get("class", "") in ["warrior", "mage"]
				and raw.get("behavior") is Dictionary
			):
				_abilities[folder] = raw
	return _abilities


static func metadata(id: String) -> Dictionary:
	var raw: Dictionary = all().get(id, {})
	if raw.is_empty():
		return {}
	return {
		"id": id,
		"name": raw["name"],
		"desc": raw["desc"],
		"class": raw["class"],
		"cost": raw["cost"],
		"cooldown": raw["cooldown"],
		"level": 1,
		"limit": 1,
		"passive": false,
		"requires": [],
		"school": "원정",
		"basic": false
	}


static func definition(id: String) -> Dictionary:
	var raw: Dictionary = all().get(id, {})
	if raw.is_empty():
		return {}
	var behavior: Dictionary = raw["behavior"].duplicate(true)
	var tint: Variant = behavior.get("color")
	if tint is Array and tint.size() >= 3:
		behavior["color"] = Color(float(tint[0]), float(tint[1]), float(tint[2]))
	return behavior


static func icon_id(id: String) -> String:
	return str(all().get(id, {}).get("icon_skill", id))

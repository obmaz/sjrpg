class_name ExpeditionContent
extends RefCounted
## 챕터·계약·룬은 데이터, 실제 월드 행동은 ExpeditionRun의 어댑터가 소유한다.
const ROOT := "res://assets/data/expeditions/"
static var _chapters: Dictionary = {}
static var _runes: Dictionary = {}
static var _pools: Dictionary = {}


static func read_records(folder: String) -> Dictionary:
	var records := {}
	var files := DirAccess.get_files_at(folder)
	files.sort()
	for file in files:
		if not file.ends_with(".json"):
			continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder + file))
		if data is Dictionary and data.get("id", "") == file.trim_suffix(".json"):
			records[data["id"]] = data
	return records


static func chapters() -> Dictionary:
	if _chapters.is_empty():
		_chapters = read_records(ROOT + "chapters/")
	return _chapters


static func chapter(id := "forest_1") -> Dictionary:
	return chapters().get(id, {})


static func contract(chapter_id: String, id: String) -> Dictionary:
	for record: Dictionary in chapter(chapter_id).get("contracts", []):
		if record["id"] == id:
			return record
	return {}


static func runes() -> Dictionary:
	if _runes.is_empty():
		_runes = read_records(ROOT + "runes/")
	return _runes


static func pools() -> Dictionary:
	if _pools.is_empty():
		_pools = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "pools.json"))
	return _pools


static func skill_metadata(id: String, cls: String) -> Dictionary:
	if not GameState.CLASSES.has(cls):
		return {}
	var custom := AbilityLibrary.metadata(id)
	return GameState.skill_data()[cls]["by_id"].get(
		id, custom if custom.get("class", "") == cls else {}
	)


static func pool(cls: String, renown: int) -> Array[String]:
	var result: Array[String] = []
	for id: String in pools()[cls]["skills"]:
		result.append(id)
	for id: String in AbilityLibrary.all():
		var raw: Dictionary = AbilityLibrary.all()[id]
		if raw["class"] == cls and int(raw.get("unlock_renown", 0)) <= renown:
			result.append(id)
	result.sort()
	return result


static func compatible(skill_id: String, rune_id: String) -> bool:
	var rune: Dictionary = runes().get(rune_id, {})
	return not rune.is_empty() and rune["types"].has(SkillDefs.base_def(skill_id).get("type", ""))

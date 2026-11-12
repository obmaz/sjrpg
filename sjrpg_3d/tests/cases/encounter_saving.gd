extends TestCase
## Encounter charges and living members survive reloads without snapshots from an old world.


func run() -> void:
	var original_path := GameState.save_path
	GameState.save_path = "user://tests/encounter-saving.json"
	GameState.delete_save()
	GameState.new_game("warrior")
	var expected: Dictionary = JSON.parse_string(JSON.stringify(_sample()))
	GameState.encounters = _sample()
	check("encounter state saves without changing the additive format version", GameState.SAVE_VERSION == 1 and GameState.save_game())
	GameState.encounters = {}
	check("encounter save restores", GameState.load_game())
	check("charges, fractional recharge, member health and world coordinates round-trip", GameState.encounters == expected)
	var recharge: float = GameState.encounters["west"]["recharge"]
	await _frames(3)
	check("reload never applies offline recharge", GameState.load_game() and float(GameState.encounters["west"]["recharge"]) == recharge and int(GameState.encounters["west"]["charges"]) == 1)
	await _check_capture_lifecycle()
	_check_old_save()
	_check_rejections()
	_check_backup()
	GameState.encounter_capture = Callable()
	GameState.encounters = {}
	GameState.delete_save()
	GameState.save_path = original_path


func _member() -> Dictionary:
	return {"kind": "goblin", "level": 3, "hp": 42.75, "position": [-2450.5, 1180.25]}


func _area() -> Dictionary:
	return {"charges": 1, "recharge": 149.25, "initial_spawned": true, "members": [_member()]}


func _sample() -> Dictionary:
	var west := _area()
	west["members"].append({"kind": "wolf", "level": 5, "hp": 19.5, "position": [820.0, -1940.75]})
	return {"west": west, "north-east": {"charges": 3, "recharge": 0.0, "initial_spawned": false, "members": []}}


func _read() -> Dictionary:
	var save := SaveStore.read(GameState.save_path, GameState._valid_save)
	return save.get("data", {})


func _write(data: Dictionary) -> void:
	var file := FileAccess.open(GameState.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _check_capture_lifecycle() -> void:
	GameState.encounters = _sample()
	var calls := [0]
	GameState.encounter_capture = func():
		calls[0] += 1
		GameState.encounters["west"]["members"][0]["hp"] = 11.25
	check("live encounter snapshot is accepted", GameState.save_game())
	var saved := _read()
	check("snapshot refresh happens before serialization", calls[0] == 1 and float(saved["encounters"]["west"]["members"][0]["hp"]) == 11.25)
	GameState.encounter_capture = func():
		calls[0] += 1
		GameState.encounters = {"stale": _area()}
	check("loaded encounter state detaches the previous world", GameState.load_game() and not GameState.encounter_capture.is_valid())
	check("saving restored state cannot recapture the old world", GameState.save_game() and calls[0] == 1 and GameState.encounters.has("west") and not _read()["encounters"].has("stale"))
	var old_members: Array = GameState.encounters["west"]["members"]
	check("another restore produces an independent survivor snapshot", GameState.load_game())
	old_members[0]["hp"] = 9999.0
	old_members[0]["position"][0] = 9999.0
	check("old survivor references cannot mutate restored members", float(GameState.encounters["west"]["members"][0]["hp"]) == 11.25 and float(GameState.encounters["west"]["members"][0]["position"][0]) == -2450.5)
	GameState.encounter_capture = func():
		calls[0] += 1
		GameState.encounters = {"stale": _area()}
	GameState.delete_save()
	GameState.new_game("mage")
	check("new adventure clears the old callback before its first save", calls[0] == 1 and not GameState.encounter_capture.is_valid() and GameState.encounters.is_empty() and _read()["encounters"].is_empty())
	var owner := SnapshotOwner.new()
	GameState.encounter_capture = owner.capture
	owner.free()
	check("a freed world snapshotter is ignored safely", not GameState.encounter_capture.is_valid() and GameState.save_game())
	await _frames(1)


func _check_old_save() -> void:
	GameState.delete_save()
	_write({"class": "warrior", "level": 2, "gold": 321})
	GameState.encounters = _sample()
	check("pre-encounter saves load an empty area collection", GameState.load_game() and GameState.encounters.is_empty() and GameState.level == 2 and GameState.gold == 321)


func _bad_record(field: String, value: Variant) -> Dictionary:
	var area := _area()
	area[field] = value
	return {"west": area}


func _bad_member(field: String, value: Variant) -> Dictionary:
	var area := _area()
	area["members"][0][field] = value
	return {"west": area}


func _check_rejections() -> void:
	var cases := [
		["non-dictionary areas", []],
		["empty area id", {"": _area()}],
		["overlong area id", {"a".repeat(41): _area()}],
		["unsafe area id", {"../west": _area()}],
		["non-string area id", {5: _area()}],
		["non-dictionary area", {"west": []}],
		["missing required fields", {"west": {"charges": 1}}],
		["negative charge", _bad_record("charges", -1)],
		["too many charges", _bad_record("charges", 4)],
		["fractional charge", _bad_record("charges", 1.5)],
		["string charge", _bad_record("charges", "1")],
		["boolean charge", _bad_record("charges", true)],
		["negative recharge", _bad_record("recharge", -1.0)],
		["completed recharge not committed", _bad_record("recharge", 300.0)],
		["infinite recharge", _bad_record("recharge", INF)],
		["nan recharge", _bad_record("recharge", NAN)],
		["string recharge", _bad_record("recharge", "30")],
		["nonboolean initial state", _bad_record("initial_spawned", 1)],
		["non-array members", _bad_record("members", {})],
		["non-record member", _bad_record("members", [5])],
		["unknown enemy", _bad_member("kind", "golem")],
		["zero member level", _bad_member("level", 0)],
		["excessive member level", _bad_member("level", 21)],
		["fractional member level", _bad_member("level", 2.5)],
		["boolean member level", _bad_member("level", true)],
		["dead member", _bad_member("hp", 0.0)],
		["negative member health", _bad_member("hp", -1.0)],
		["excessive member health", _bad_member("hp", 100000.1)],
		["infinite member health", _bad_member("hp", INF)],
		["nan member health", _bad_member("hp", NAN)],
		["non-array member position", _bad_member("position", "0,0")],
		["short member position", _bad_member("position", [0])],
		["long member position", _bad_member("position", [0, 0, 0])],
		["infinite member coordinate", _bad_member("position", [0, INF])],
		["outside positive world limit", _bad_member("position", [12500.1, 0])],
		["outside negative world limit", _bad_member("position", [0, -12500.1])],
	]
	var full := _area()
	full["charges"] = 3
	cases.append(["full charge keeps partial time", {"west": full}])
	var many_areas := {}
	for i in 13:
		many_areas["area_%d" % i] = _area()
	cases.append(["too many areas", many_areas])
	var many_members: Array = []
	for i in 13:
		many_members.append(_member())
	cases.append(["too many members in one area", _bad_record("members", many_members)])
	var crowded := {}
	for area_index in 3:
		var area := _area()
		area["members"] = []
		for i in 11:
			area["members"].append(_member())
		crowded["area_%d" % area_index] = area
	cases.append(["too many total survivors", crowded])
	for sample in cases:
		check("invalid encounter data is rejected: " + str(sample[0]), not GameState._valid_save({"class": "mage", "encounters": sample[1]}))
	var boundary := _area()
	boundary["recharge"] = 299.999
	boundary["members"][0] = {"kind": "skeleton", "level": 20, "hp": 100000.0, "position": [-10000.0, 10000.0]}
	check("documented member and timer boundaries remain valid", GameState._valid_save({"class": "warrior", "encounters": {"edge:area_1": boundary}}))
	GameState.delete_save()
	GameState.gold = 876
	GameState.encounters = _sample()
	var before: Dictionary = GameState.encounters.duplicate(true)
	var old_snapshot_calls := [0]
	GameState.encounter_capture = func(): old_snapshot_calls[0] += 1
	_write({"class": "mage", "gold": 9999, "encounters": _bad_record("charges", 4)})
	check("invalid encounter primary cannot partially replace the hero", not GameState.load_game() and GameState.gold == 876 and GameState.encounters == before)
	check("failed load also detaches the stale world snapshotter", not GameState.encounter_capture.is_valid() and old_snapshot_calls[0] == 0)


func _check_backup() -> void:
	GameState.delete_save()
	GameState.new_game("warrior")
	GameState.encounters = _sample()
	GameState.gold = 123
	check("valid encounter snapshot can be saved", GameState.save_game())
	GameState.gold = 456
	GameState.save_game()
	_write({"class": "mage", "gold": 9999, "encounters": _bad_record("members", ["bad"])})
	GameState.gold = 0
	GameState.encounters = {}
	check("invalid encounter primary falls back to the intact prior snapshot", GameState.load_game() and GameState.loaded_backup and GameState.gold == 123 and int(GameState.encounters["west"]["charges"]) == 1 and GameState.encounters["west"]["members"].size() == 2)


class SnapshotOwner:
	extends Node
	func capture() -> void:
		GameState.encounters = {"stale": {}}

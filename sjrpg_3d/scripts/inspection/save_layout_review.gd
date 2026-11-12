class_name SaveLayoutReview
extends Node
## Explicit review URL only; all writes remain in a unique, isolated test namespace.
const PREFIX := "user://tests/save-layout"
const SCENARIOS := ["empty", "mixed", "full", "corrupt", "backup", "long"]
var _root: Node
var _callback: JavaScriptObject
var _original_path := ""
var _original_slot := 1
var _scenario := "mixed"
var _error := ""
var _elapsed := 0.0
var _configured := false
var _scenario_sequence := 0


func setup(root: Node) -> SaveLayoutReview:
	_root = root
	return self


func _ready() -> void:
	if not OS.has_feature("web"):
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_original_path = GameState.slot_path(1)
	_original_slot = GameState.active_slot
	DirAccess.make_dir_recursive_absolute("user://tests")
	GameState.save_path = PREFIX + "-%d.json" % Time.get_ticks_usec()
	_configured = prepare_scenario(_scenario)
	if not _configured:
		_error = "Cannot create isolated review saves: " + GameState.save_error
	_callback = JavaScriptBridge.create_callback(_action)
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	window.__sjrpgSaveLayoutAction = _callback
	_publish()


func _exit_tree() -> void:
	if not _original_path.is_empty():
		GameState.save_path = _original_path
		GameState.select_slot(_original_slot)


static func in_test_namespace() -> bool:
	return GameState.slot_path(1).begins_with(PREFIX)


static func _write(path: String, contents: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(contents)
	file.close()
	return true


static func _create(number: int, cls: String, level: int, where := "forest") -> bool:
	if not GameState.create_slot(number, cls):
		return false
	GameState.level = level
	GameState.gold = number * 111
	GameState.location_mode = where
	return GameState.save_game()


## Same real save preparation is used by the browser and the headless regression.
static func prepare_scenario(name: String) -> bool:
	if not in_test_namespace() or not SCENARIOS.has(name):
		return false
	for number in range(1, 5):
		if not GameState.delete_slot(number):
			return false
	var success := true
	match name:
		"empty":
			pass
		"mixed":
			success = _create(1, "warrior", 7) and _create(3, "mage", 8, "cave")
			success = _write(GameState.slot_path(4), "{unreadable review save") and success
		"full", "long":
			for number in range(1, 5):
				success = _create(number, "warrior" if number % 2 == 1 else "mage", 7 + number, "cave" if number == 4 else "forest") and success
		"corrupt":
			for number in range(1, 5):
				success = _write(GameState.slot_path(number), "{unreadable review save") and success
		"backup":
			success = _create(1, "mage", 8)
			GameState.gold = 999
			success = GameState.save_game() and success
			success = _write(GameState.slot_path(1), "{corrupt primary; real backup retained") and success
			success = _create(3, "warrior", 12) and success
	GameState.select_slot(1)
	return success


static func file_hashes() -> Dictionary:
	var result := {}
	if not in_test_namespace():
		return result
	for number in range(1, 5):
		var files := {}
		for suffix: String in GameState.SAVE_SUFFIXES:
			var path := GameState.slot_path(number) + suffix
			files[suffix] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
		result[str(number)] = files
	return result


func _action(arguments: Array) -> void:
	if arguments.size() != 2 or str(arguments[0]) != "scenario":
		return
	var name := str(arguments[1])
	if not SCENARIOS.has(name):
		return
	var current: Node = _root.get("current")
	if is_instance_valid(current) and current.has_method("refresh_slots") and is_instance_valid(current.get("_delete_dialog")):
		_error = "Close the actual deletion dialog before preparing another scenario."
		_publish()
		return
	if not in_test_namespace():
		_error = "Review scenario preparation requires the isolated test namespace."
		_publish()
		return
	# Prior scenario files stay intact while asynchronous IDBFS may still read them.
	# Only this explicit browser action rotates paths; the static test helper is unchanged.
	_scenario_sequence += 1
	GameState.save_path = PREFIX + "-%d-%d.json" % [Time.get_ticks_usec(), _scenario_sequence]
	_error = ""
	_configured = prepare_scenario(name)
	_scenario = name
	if not _configured:
		_error = "Cannot prepare review scenario: " + GameState.save_error
	if is_instance_valid(current) and current.has_method("refresh_slots"):
		current.set("selected_slot", 1)
		current.call("refresh_slots")
		current.call("show_slots")
		if name == "long":
			current.call("show_error", "모험을 읽지 못했습니다. 다른 저장 슬롯을 선택하거나 잠시 후 다시 시도해 주세요. 기존 모험은 그대로 유지됩니다.")
	_publish()


func _process(delta: float) -> void:
	if not OS.has_feature("web"):
		return
	_elapsed += delta
	if _elapsed >= 0.10:
		_elapsed = 0.0
		_publish()


func _publish() -> void:
	if not OS.has_feature("web") or not is_instance_valid(_root):
		return
	var current: Node = _root.get("current")
	var screen := "title"
	if is_instance_valid(current):
		if current.has_method("refresh_slots"):
			screen = "selection"
		elif current is Adventure3D:
			screen = "adventure"
	var report := {"ready": _configured, "scenario": _scenario, "screen": screen,
		"fixture_error": _error, "file_hashes": file_hashes(), "hero_class": GameState.hero_class,
		"gold": GameState.gold, "level": GameState.level, "xp": GameState.xp, "active_slot": GameState.active_slot}
	JavaScriptBridge.eval("window.__sjrpgSaveLayoutReview = " + JSON.stringify(report), true)

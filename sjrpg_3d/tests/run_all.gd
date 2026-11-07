extends Node
## 헤드리스 테스트 러너: `tests/cases/*.gd`를 찾아 차례로 실행하고 요약을 출력합니다.
##   godot --headless res://tests/run_all.tscn                 # 전부
##   godot --headless res://tests/run_all.tscn -- --only=quests,bag
##   godot --headless res://tests/run_all.tscn -- --list
## 실패가 하나라도 있으면 종료 코드 1.

const CASE_DIR := "res://tests/cases/"


func _ready() -> void:
	# Test runs must never overwrite the player's adventure.
	DirAccess.make_dir_recursive_absolute("user://tests")
	GameState.save_path = "user://tests/guardian_save.json"
	var only: PackedStringArray = []
	var list := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
		elif arg == "--list":
			list = true
	var names: Array[String] = []
	for f in DirAccess.get_files_at(CASE_DIR):
		if f.ends_with(".gd"):
			names.append(f.trim_suffix(".gd"))
	names.sort()
	if list:
		print("cases: %s" % ", ".join(names))
		get_tree().quit(0)
		return
	# Diagnostic-only: keep verbose shutdown resource paths without per-case stdout I/O.
	var original_stdout: bool = Engine.print_to_stdout
	var quiet_verbose: bool = OS.get_environment("SJRPG_QUIET_VERBOSE") == "1"
	if quiet_verbose:
		Engine.print_to_stdout = false
	var total := 0
	var failed: Array[String] = []
	var started := Time.get_ticks_msec()
	for name in names:
		if not only.is_empty() and not only.has(name):
			continue
		var script: GDScript = load(CASE_DIR + name + ".gd")
		if script == null or not script.can_instantiate():
			total += 1
			failed.append(name)
			print("FAIL %s (test script cannot be instantiated)" % name)
			continue
		var case_node: TestCase = script.new()
		add_child(case_node)
		print("── case: %s" % name)
		var t0 := Time.get_ticks_msec()
		await case_node.run()
		var ms := Time.get_ticks_msec() - t0
		total += 1
		print("%s %s (%d ms, failures %d)" % ["PASS" if case_node.failures == 0 else "FAIL", name, ms, case_node.failures])
		if case_node.failures > 0:
			failed.append(name)
		case_node.queue_free()
		await get_tree().process_frame
	if quiet_verbose:
		Engine.print_to_stdout = original_stdout
	if OS.get_environment("SJRPG_TRACE_AUDIO_OWNERS") == "1":
		print("AUDIO_OWNER_TRACE " + JSON.stringify(MusicDirector.debug_owned_audio_snapshot()))
	print("RESULT cases=%d failed=%d time=%dms %s" % [total, failed.size(), Time.get_ticks_msec() - started, str(failed)])
	get_tree().quit(1 if failed.size() > 0 or total == 0 else 0)

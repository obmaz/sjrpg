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
	if DisplayServer.get_name() == "headless":
		var shutdown: Dictionary = await _await_audio_shutdown_boundary()
		print("ART_AUDIT AUDIO_SHUTDOWN_BOUNDARY ", JSON.stringify(shutdown))
		if not bool(shutdown["ok"]):
			failed.append("audio_shutdown_mix_boundary")
			push_error("Audio driver did not complete the required final mix/main-thread cleanup boundary: " + JSON.stringify(shutdown))
	print("RESULT cases=%d failed=%d time=%dms %s" % [total, failed.size(), Time.get_ticks_msec() - started, str(failed)])
	get_tree().quit(1 if failed.size() > 0 or total == 0 else 0)


## TEST-ONLY engine lifecycle barrier; no music/player/cache mutation.
## 4.7.2: stop_playback_stream marks FADE_OUT_TO_DELETION; the audio mix
## erases the stopped playback, then main-loop AudioServer.update destroys it.
## Time and AudioDriver use the same OS microsecond clock. Bracket the public
## elapsed-time query so scheduler/mutex delay cannot fabricate a new mix.
func _audio_mix_window() -> Dictionary:
	var begin_us: int = Time.get_ticks_usec()
	var since: float = AudioServer.get_time_since_last_mix()
	var end_us: int = Time.get_ticks_usec()
	if not is_finite(since) or since < 0.0:
		return {"valid": false, "since_seconds": since}
	var elapsed_us: int = roundi(since * 1000000.0)
	return {"valid": true, "lower_us": begin_us - elapsed_us - 2,
		"upper_us": end_us - elapsed_us + 2, "since_seconds": since,
		"to_next_seconds": AudioServer.get_time_to_next_mix()}


func _await_audio_shutdown_boundary() -> Dictionary:
	var started_us: int = Time.get_ticks_usec()
	var deadline_us: int = started_us + 2000000
	# 마지막 실제 명중음이 끝나기 전에 엔진을 닫으면 WAV 재생기가 믹서에 남는다.
	# 설정/재생기/캐시는 변경하지 않고 짧은 효과음의 자연 종료를 기다린다.
	var feedback_polls := 0
	while _feedback_playing():
		if Time.get_ticks_usec() >= deadline_us:
			return {"ok": false, "reason": "feedback_did_not_finish", "driver": AudioServer.get_driver_name()}
		await get_tree().process_frame
		feedback_polls += 1
	var initial: Dictionary = _audio_mix_window()
	var current: Dictionary = initial
	var polls := 0
	if not bool(initial["valid"]):
		return {"ok": false, "reason": "invalid_audio_clock", "driver": AudioServer.get_driver_name(), "initial": initial}
	while true:
		if Time.get_ticks_usec() >= deadline_us:
			return {"ok": false, "reason": "no_new_completed_mix", "driver": AudioServer.get_driver_name(),
				"waited_us": Time.get_ticks_usec() - started_us, "polls": polls, "initial": initial, "observed": current}
		if bool(current["valid"]) and int(current["lower_us"]) > int(initial["upper_us"]):
			break
		await get_tree().process_frame
		polls += 1
		current = _audio_mix_window()
	# The driver query shares its mutex with the completed mix. Cross the next
	# main-loop update exactly once so SafeList's queued playback destructors run.
	var before_cleanup: int = Engine.get_process_frames()
	await get_tree().process_frame
	var after_cleanup: int = Engine.get_process_frames()
	var finished_us: int = Time.get_ticks_usec()
	return {"ok": finished_us < deadline_us and after_cleanup > before_cleanup,
		"reason": "completed" if finished_us < deadline_us else "cleanup_deadline_exceeded",
		"driver": AudioServer.get_driver_name(),
		"waited_us": finished_us - started_us, "polls": polls, "feedback_polls": feedback_polls,
		"initial": initial, "observed": current, "cleanup_frame_before": before_cleanup,
		"cleanup_frame_after": after_cleanup}


func _feedback_playing() -> bool:
	for voice: AudioStreamPlayer in SoundFx._players:
		if is_instance_valid(voice) and voice.playing:
			return true
	return false

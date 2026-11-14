extends TestCase
## UTC storage stays untouched while offset arithmetic crosses actual date boundaries.

func run() -> void:
	var year_edge := float(Time.get_unix_time_from_datetime_string("2025-12-31T18:45:00"))
	check("Seoul offset advances a saved UTC instant across midnight and year", SaveTimeLabel.with_offset(year_edge, 540) == "01-01 03:45")
	var leap_edge := float(Time.get_unix_time_from_datetime_string("2024-03-01T01:15:00"))
	check("negative local offset crosses onto the actual leap day", SaveTimeLabel.with_offset(leap_edge, -480) == "02-29 17:15")
	check("fractional-hour timezone retains the minute component", SaveTimeLabel.with_offset(year_edge, 345) == "01-01 00:30")
	check("UTC locale does not shift the saved minute", SaveTimeLabel.with_offset(year_edge, 0) == "12-31 18:45")
	check("legacy missing timestamp keeps its existing label", SaveTimeLabel.with_offset(0.0, 540) == "기존 모험")
	if OS.get_environment("TZ") == "Asia/Seoul":
		check("native Korean bias is positive540 minutes and shifts the actual date", SaveTimeLabel.device_offset(year_edge) == 540 and SaveTimeLabel.for_device(year_edge) == "01-01 03:45")
	elif OS.get_environment("TZ") == "Etc/GMT+5":
		check("native UTC-minus-five bias is negative300 minutes", SaveTimeLabel.device_offset(year_edge) == -300 and SaveTimeLabel.for_device(year_edge) == "12-31 13:45")
	var current := Time.get_unix_time_from_system()
	if not OS.has_feature("web"):
		check("native entry uses the operating system timezone bias", SaveTimeLabel.for_device(current) == SaveTimeLabel.with_offset(current, int(Time.get_time_zone_from_system()["bias"])))
	var old_path := GameState.slot_path(1)
	var old_slot := GameState.active_slot
	GameState.save_path = "user://tests/local-save-time.json"
	for slot in range(1, GameState.MAX_SAVE_SLOTS + 1):
		GameState.delete_slot(slot)
	GameState.create_slot(1, "warrior")
	# Keep an actual valid save, with a fixed historical saved instant for the real preview.
	var path := GameState.slot_path(1)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	data["saved_at"] = year_edge
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var bytes := FileAccess.get_file_as_bytes(path)
	var hero_before := GameState.hero_class
	var gold_before := GameState.gold
	var screen := preload("res://scripts/ui/screens/class_select.gd").new()
	add_child(screen)
	await _frames(2)
	var expected := SaveTimeLabel.for_device(year_edge)
	check("actual save row displays the device-local formatter", expected in screen.slot_buttons[0].text)
	screen.select_slot(2)
	screen.select_class("mage")
	screen.show_slots()
	check("formatting and preview preserve exact epoch/progress/save bytes", FileAccess.get_file_as_bytes(path) == bytes and GameState.hero_class == hero_before and GameState.gold == gold_before and float(GameState.slot_summaries()[0]["timestamp"]) == year_edge)
	screen.queue_free()
	await _frames(2)
	for slot in range(1, GameState.MAX_SAVE_SLOTS + 1):
		GameState.delete_slot(slot)
	GameState.save_path = old_path
	GameState.select_slot(old_slot)

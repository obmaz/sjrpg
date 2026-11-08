extends TestCase
## Actual config persistence and startup/change ordering; no unsupported screen API calls in CI.

class ObservedPrefs:
	extends "res://scripts/prefs.gd"
	var applied: Array[String] = []

	func apply_screen_orientation(_from_gesture := false) -> void:
		applied.append(screen_orientation)


const TEST_PATH := "user://tests/screen-orientation.cfg"


func run() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("device", "sound", false)
	cfg.set_value("device", "world_zoom", 1.25)
	check("legacy config can be written", cfg.save(TEST_PATH) == OK)
	var prefs := ObservedPrefs.new()
	prefs.settings_path = TEST_PATH
	add_child(prefs)
	check("legacy settings start automatic and preserve existing preferences",
		prefs.screen_orientation == "auto" and prefs.applied == ["auto"]
		and not prefs.sound_enabled and is_equal_approx(prefs.world_zoom, 1.25))
	for choice: String in ["portrait", "landscape", "auto"]:
		prefs.set_screen_orientation(choice, true)
		check("choosing orientation applies immediately", prefs.applied.back() == choice)
		var saved := ConfigFile.new()
		check("orientation is saved independently of progress",
			saved.load(TEST_PATH) == OK and saved.get_value("device", "screen_orientation") == choice
			and not saved.get_value("device", "sound") and is_equal_approx(float(saved.get_value("device", "world_zoom")), 1.25))
		var loaded := ObservedPrefs.new()
		loaded.settings_path = TEST_PATH
		add_child(loaded)
		check("fresh start applies the saved orientation after loading it",
			loaded.screen_orientation == choice and loaded.applied == [choice])
		loaded.free()
	var attempts := prefs.applied.size()
	prefs.set_screen_orientation("auto", true)
	check("reselecting a saved option can retry a rejected browser request", prefs.applied.size() == attempts + 1)
	for invalid in ["locked", 1, true, null]:
		cfg.set_value("device", "screen_orientation", invalid)
		cfg.save(TEST_PATH)
		var loaded := ObservedPrefs.new()
		loaded.settings_path = TEST_PATH
		add_child(loaded)
		check("invalid settings recover automatic rotation at startup", loaded.screen_orientation == "auto" and loaded.applied == ["auto"])
		loaded.free()
	check("automatic native mode allows both axes", prefs.screen_orientation_mode("auto") == DisplayServer.SCREEN_SENSOR)
	check("native axis locks preserve reverse-device rotation", prefs.screen_orientation_mode("landscape") == DisplayServer.SCREEN_SENSOR_LANDSCAPE and prefs.screen_orientation_mode("portrait") == DisplayServer.SCREEN_SENSOR_PORTRAIT)
	check("project starts with both axes enabled", int(ProjectSettings.get_setting("display/window/handheld/orientation")) == DisplayServer.SCREEN_SENSOR)
	prefs.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

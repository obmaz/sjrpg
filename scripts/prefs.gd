extends Node
## 기기 설정 (원본 DeviceSettings / AudioSettings): 효과음 · 타격 진동 · 전체화면.
## Stored in user://settings.cfg (the browser's IndexedDB on the web).

signal graphics_changed

const PATH := "user://settings.cfg"

var sound_enabled := true
var haptics_enabled := true
var reduce_motion := false
var low_resolution := false
var _last_pulse := 0


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		sound_enabled = bool(cfg.get_value("device", "sound", true))
		haptics_enabled = bool(cfg.get_value("device", "haptics", true))
		reduce_motion = bool(cfg.get_value("device", "reduce_motion", false))
		low_resolution = bool(cfg.get_value("device", "low_resolution", false))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("device", "sound", sound_enabled)
	cfg.set_value("device", "haptics", haptics_enabled)
	cfg.set_value("device", "reduce_motion", reduce_motion)
	cfg.set_value("device", "low_resolution", low_resolution)
	cfg.save(PATH)


func set_sound(on: bool) -> void:
	sound_enabled = on
	_save()


func set_haptics(on: bool) -> void:
	haptics_enabled = on
	_save()


func vibration_supported() -> bool:
	return OS.has_feature("web") or OS.has_feature("mobile")


func fullscreen_supported() -> bool:
	return OS.has_feature("web") or DisplayServer.get_name() != "headless"


func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


func toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen() else DisplayServer.WINDOW_MODE_FULLSCREEN)


## FeedbackKind pulses (DeviceSettings.pulse): hit 12ms, hurt 32/22/45, kill 18/14/14 ...
func pulse(kind: String, preview := false) -> void:
	if not haptics_enabled or not vibration_supported():
		return
	var now := Time.get_ticks_msec()
	if not preview and kind != "hurt" and now - _last_pulse < 100:
		return
	_last_pulse = now
	var ms: int = {"hit": 12, "hurt": 90, "kill": 46, "skill": 54, "dodge": 8, "loot": 30}.get(kind, 12)
	Input.vibrate_handheld(ms)


func set_reduce_motion(on: bool) -> void:
	reduce_motion = on
	_save()


func set_low_resolution(on: bool) -> void:
	if low_resolution == on:
		return
	low_resolution = on
	_save()
	graphics_changed.emit()

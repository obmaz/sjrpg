extends Node
## 기기 설정 (원본 DeviceSettings / AudioSettings): 효과음 · 타격 진동 · 전체화면.
## Stored in user://settings.cfg (the browser's IndexedDB on the web).

signal graphics_changed

const PATH := "user://settings.cfg"
const WORLD_ZOOMS: Array[float] = [0.5, 1.0, 1.5]

var settings_path := "/userfs/sjrpg_3d/settings.cfg" if OS.has_feature("web") else PATH
var sound_enabled := true
## Background music (town / field / dungeon loops), separate from combat sound effects.
var music_enabled := true
var haptics_enabled := true
var reduce_motion := false
var low_resolution := false
var world_zoom := 1.0
var _last_pulse := 0


func _ready() -> void:
	if OS.has_feature("web"):
		DirAccess.make_dir_recursive_absolute("/userfs/sjrpg_3d")
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		sound_enabled = bool(cfg.get_value("device", "sound", true))
		music_enabled = bool(cfg.get_value("device", "music", true))
		haptics_enabled = bool(cfg.get_value("device", "haptics", true))
		reduce_motion = bool(cfg.get_value("device", "reduce_motion", false))
		low_resolution = bool(cfg.get_value("device", "low_resolution", false))
		world_zoom = normalize_world_zoom(cfg.get_value("device", "world_zoom", 1.0))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("device", "sound", sound_enabled)
	cfg.set_value("device", "music", music_enabled)
	cfg.set_value("device", "haptics", haptics_enabled)
	cfg.set_value("device", "reduce_motion", reduce_motion)
	cfg.set_value("device", "low_resolution", low_resolution)
	cfg.set_value("device", "world_zoom", world_zoom)
	cfg.save(settings_path)


## Only supported world scales enter the camera; legacy/corrupt settings use 1x.
static func normalize_world_zoom(value: Variant) -> float:
	if typeof(value) not in [TYPE_FLOAT, TYPE_INT]:
		return 1.0
	var candidate := float(value)
	for supported: float in WORLD_ZOOMS:
		if is_equal_approx(candidate, supported):
			return supported
	return 1.0


func set_world_zoom(value: float) -> void:
	var next := normalize_world_zoom(value)
	if is_equal_approx(world_zoom, next):
		return
	world_zoom = next
	_save()
	graphics_changed.emit()


func set_sound(on: bool) -> void:
	sound_enabled = on
	_save()


func set_music(on: bool) -> void:
	music_enabled = on
	_save()


func set_haptics(on: bool) -> void:
	haptics_enabled = on
	_save()


func vibration_supported() -> bool:
	return OS.has_feature("web") or OS.has_feature("mobile")


func fullscreen_supported() -> bool:
	if OS.has_feature("web"):
		return bool(fullscreen_state().get("supported", false))
	return DisplayServer.get_name() != "headless"


func is_fullscreen() -> bool:
	if OS.has_feature("web"):
		return bool(fullscreen_state().get("active", false))
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]


func fullscreen_state() -> Dictionary:
	if OS.has_feature("web"):
		var raw: Variant = JavaScriptBridge.eval("JSON.stringify(window.SjrpgFullscreen ? window.SjrpgFullscreen.state() : {active:false,supported:false,pending:false,title:'전체화면 지원 안내',detail:'이 브라우저에서 전체화면 기능을 확인할 수 없습니다.'})", true)
		if raw is String:
			var parsed: Variant = JSON.parse_string(raw)
			if parsed is Dictionary:
				return parsed
		return {"active": false, "supported": false, "pending": false, "title": "전체화면 지원 안내", "detail": "이 브라우저에서 전체화면 기능을 확인할 수 없습니다."}
	var supported := DisplayServer.get_name() != "headless"
	var active := is_fullscreen()
	return {"active": active, "supported": supported, "pending": false, "title": ("전체화면 끄기" if active else "전체화면 켜기") if supported else "전체화면 지원 안내", "detail": "게임 화면을 전체화면으로 전환합니다." if supported else "이 실행 환경은 전체화면 전환을 지원하지 않습니다."}


func toggle_fullscreen() -> void:
	if OS.has_feature("web"):
		# Button.pressed must reach the native API before any deferred callback.
		JavaScriptBridge.eval("if (window.SjrpgFullscreen) window.SjrpgFullscreen.toggle();")
		return
	if not fullscreen_supported():
		return
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
	WorldLighting.refresh_contacts()


func set_low_resolution(on: bool) -> void:
	if low_resolution == on:
		return
	low_resolution = on
	_save()
	graphics_changed.emit()

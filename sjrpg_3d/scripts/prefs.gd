extends Node
## 기기 설정 (원본 DeviceSettings / AudioSettings): 효과음 · 타격 진동 · 전체화면.
## Stored in user://settings.cfg (the browser's IndexedDB on the web).

signal graphics_changed

const PATH := "user://settings.cfg"
const WORLD_ZOOMS: Array[float] = [0.5, 0.75, 1.0, 1.25, 1.5]
const SCREEN_ORIENTATIONS: Array[String] = ["auto", "landscape", "portrait"]
## Stored values remain relative UI choices; the new 1x view uses the former 0.75 scale.
const WORLD_ZOOM_BASE := 0.75

var settings_path := "/userfs/sjrpg_3d/settings.cfg" if OS.has_feature("web") else PATH
var sound_enabled := true
## Background music (town / field / dungeon loops), separate from combat sound effects.
var music_enabled := true
var haptics_enabled := true
var reduce_motion := false
var low_resolution := false
var world_zoom := 1.0
var screen_orientation := "auto"
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
		screen_orientation = normalize_screen_orientation(cfg.get_value("device", "screen_orientation", "auto"))
	apply_screen_orientation()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("device", "sound", sound_enabled)
	cfg.set_value("device", "music", music_enabled)
	cfg.set_value("device", "haptics", haptics_enabled)
	cfg.set_value("device", "reduce_motion", reduce_motion)
	cfg.set_value("device", "low_resolution", low_resolution)
	cfg.set_value("device", "world_zoom", world_zoom)
	cfg.set_value("device", "screen_orientation", screen_orientation)
	cfg.save(settings_path)


## Only supported relative choices are stored; absent/corrupt settings use displayed 1x.
static func normalize_world_zoom(value: Variant) -> float:
	if typeof(value) not in [TYPE_FLOAT, TYPE_INT]:
		return 1.0
	var candidate := float(value)
	for supported: float in WORLD_ZOOMS:
		if is_equal_approx(candidate, supported):
			return supported
	return 1.0


## Camera consumers use this once; saved preferences and UI selection stay relative.
func actual_world_zoom() -> float:
	return WORLD_ZOOM_BASE * world_zoom


func set_world_zoom(value: float) -> void:
	var next := normalize_world_zoom(value)
	if is_equal_approx(world_zoom, next):
		return
	world_zoom = next
	_save()
	graphics_changed.emit()


## A shared preference; supported browser APIs or native Android perform the rotation.
static func normalize_screen_orientation(value: Variant) -> String:
	if value is String and value in SCREEN_ORIENTATIONS:
		return str(value)
	return "auto"


static func screen_orientation_mode(value: Variant) -> int:
	match normalize_screen_orientation(value):
		"landscape":
			return DisplayServer.SCREEN_SENSOR_LANDSCAPE
		"portrait":
			return DisplayServer.SCREEN_SENSOR_PORTRAIT
	return DisplayServer.SCREEN_SENSOR


func apply_screen_orientation(from_gesture := false) -> void:
	if OS.has_feature("web"):
		var method := "choose" if from_gesture else "restore"
		JavaScriptBridge.eval("if(window.SjrpgOrientation)window.SjrpgOrientation." + method + "(" + JSON.stringify(screen_orientation) + ");")
	elif OS.has_feature("android"):
		DisplayServer.screen_set_orientation(screen_orientation_mode(screen_orientation))


func screen_orientation_state() -> Dictionary:
	if OS.has_feature("web"):
		var raw: Variant = JavaScriptBridge.eval("JSON.stringify(window.SjrpgOrientation ? window.SjrpgOrientation.state() : {supported:false,pending:false,detail:'이 브라우저에서는 방향 고정을 지원하지 않습니다. 기기를 직접 돌려 주세요.'})", true)
		if raw is String:
			var parsed: Variant = JSON.parse_string(raw)
			if parsed is Dictionary:
				return parsed
		return {"supported": false, "pending": false, "detail": "화면 방향 지원 상태를 확인할 수 없습니다."}
	if OS.has_feature("android"):
		return {"supported": true, "pending": false, "detail": "자동은 기기를 돌린 방향에 맞춥니다. 가로·세로를 선택하면 해당 방향을 유지합니다."}
	return {"supported": false, "pending": false, "detail": "이 환경에서는 방향 고정을 지원하지 않습니다. 창 크기로 화면 방향을 바꿀 수 있습니다."}


func set_screen_orientation(value: String, from_gesture := false) -> void:
	var next := normalize_screen_orientation(value)
	if screen_orientation != next:
		screen_orientation = next
		_save()
	# Re-selecting the same choice retries a browser request that was denied.
	apply_screen_orientation(from_gesture)


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
	# The Android app always runs in immersive full screen (export preset screen/immersive_mode).
	return DisplayServer.get_name() != "headless" and not OS.has_feature("android")


func is_fullscreen() -> bool:
	if OS.has_feature("web"):
		return bool(fullscreen_state().get("active", false))
	if OS.has_feature("android"):
		return true
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]


func fullscreen_state() -> Dictionary:
	if OS.has_feature("web"):
		var raw: Variant = JavaScriptBridge.eval("JSON.stringify(window.SjrpgFullscreen ? window.SjrpgFullscreen.state() : {active:false,supported:false,pending:false,title:'전체화면 지원 안내',detail:'이 브라우저에서 전체화면 기능을 확인할 수 없습니다.'})", true)
		if raw is String:
			var parsed: Variant = JSON.parse_string(raw)
			if parsed is Dictionary:
				return parsed
		return {"active": false, "supported": false, "pending": false, "title": "전체화면 지원 안내", "detail": "이 브라우저에서 전체화면 기능을 확인할 수 없습니다."}
	if OS.has_feature("android"):
		return {"active": true, "supported": false, "pending": false, "title": "전체화면 사용 중", "detail": "안드로이드 앱은 항상 전체화면으로 실행됩니다."}
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

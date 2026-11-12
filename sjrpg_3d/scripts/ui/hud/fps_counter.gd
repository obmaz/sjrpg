class_name FpsCounter
extends Label
## One optional HUD label. Hidden counters have no process callback or FPS polling.

const SAMPLE_SECONDS := 0.5
var _elapsed := 0.0


func _ready() -> void:
	name = "FpsCounter"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	add_theme_font_override("font", HudArt.FONT)
	add_theme_color_override("font_color", Color("dfd9c8"))
	add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.04, 0.92))
	add_theme_constant_override("outline_size", 2)
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Prefs.fps_changed.connect(_sync_preference)
	_sync_preference()


func _sync_preference() -> void:
	visible = Prefs.show_fps
	set_process(Prefs.show_fps)
	_elapsed = 0.0
	if visible:
		_sample_fps()
	else:
		text = ""


func _sample_fps() -> void:
	text = "FPS %d" % roundi(Engine.get_frames_per_second())


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= SAMPLE_SECONDS:
		_elapsed = 0.0
		_sample_fps()


func fit(view: Vector2, margins: Vector4, unit: float) -> void:
	position = Vector2(margins.x + 12.0 * unit, view.y - margins.w - 40.0 * unit)
	size = Vector2(128.0 * unit, 28.0 * unit)
	var font_size := roundi(24.0 * unit)
	if get_theme_font_size("font_size") != font_size:
		add_theme_font_size_override("font_size", font_size)

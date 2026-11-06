extends Control
## The same illustrated entry composition before and after the web engine loads.

signal start_requested

var _backdrop: TextureRect
var _title: Label
var _chapter: Label
var _subtitle: Label
var _start: Button
var _time := 0.0
var _started := false
var _web_start: JavaScriptObject
var _web_entry: JavaScriptObject


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop = EntryUi.backdrop(self)
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.018, 0.022, 0.028, 0.08), Color(0.018, 0.022, 0.028, 0.97)])
	gradient.offsets = PackedFloat32Array([0.15, 0.96])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	shade.texture = texture
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_chapter = _label("제1장 · 숲의 부름", 23, EntryUi.BRONZE)
	_title = _label("자연의 수호자", 60, UiKit.TEXT, true)
	_subtitle = _label("어둠에 잠긴 숲, 당신의 여정이 시작됩니다", 24, EntryUi.MUTED)
	_start = UiKit.button("모험 시작", 27)
	_start.custom_minimum_size = Vector2.ZERO
	EntryUi.style(_start, true)
	_start.pressed.connect(_begin)
	add_child(_start)
	resized.connect(_layout)
	_layout()
	if OS.has_feature("web"):
		_web_entry = JavaScriptBridge.get_interface("__sjrpgEntry")
		if _web_entry != null:
			_web_start = JavaScriptBridge.create_callback(func(_arguments: Array): _begin())
			_web_entry.show(_web_start, Prefs.reduce_motion)
			hide()
		JavaScriptBridge.eval("window.__sjrpgTitleReady = true")


func _label(text: String, font_size: int, color: Color, bold := false) -> Label:
	var label := UiKit.label(text, font_size, color, bold)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("outline_size", 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _layout() -> void:
	if _start == null:
		return
	var margins := PanelFrame.safe_margins(get_viewport())
	var area := Rect2(Vector2(margins.x, margins.y), size - Vector2(margins.x + margins.z, margins.y + margins.w))
	var unit := minf(area.size.x / 720.0, area.size.y / 1280.0) if area.size.y > area.size.x else minf(area.size.x / 1080.0, area.size.y / 720.0)
	var width := minf(area.size.x - 64.0 * unit, 620.0 * unit) if area.size.y > area.size.x else minf(area.size.x * 0.44, 620.0 * unit)
	var left := area.get_center().x - width * 0.5 if area.size.y > area.size.x else area.position.x + area.size.x * 0.52
	var bottom := area.end.y - 48.0 * unit
	for entry in [[_chapter, 286, 34, 23], [_title, 238, 76, 60], [_subtitle, 142, 36, 24], [_start, 100, 100, 27]]:
		var control: Control = entry[0]
		control.position = Vector2(left, bottom - float(entry[1]) * unit)
		control.size = Vector2(width, float(entry[2]) * unit)
		control.add_theme_font_size_override("font_size", roundi(float(entry[3]) * unit))


func _process(delta: float) -> void:
	_time += delta
	_start.self_modulate = Color(1, 1, 1, 1.0 if Prefs.reduce_motion else 0.94 + 0.06 * sin(_time * 1.7))


func _begin() -> void:
	if not _started:
		_started = true
		if _web_entry != null:
			_web_entry.hide()
		start_requested.emit()


func _gui_input(event: InputEvent) -> void:
	if _web_entry != null:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_begin()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _web_entry != null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_begin()

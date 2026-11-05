extends Control
## A quiet forest entry that carries the web loader into the game's own interface.

signal start_requested

var _backdrop: TextureRect
var _title: Label
var _chapter: Label
var _subtitle: Label
var _start: Button
var _time := 0.0
var _started := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop = UiKit.cover(preload("res://assets/art/ui/select-scene.png"))
	add_child(_backdrop)
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.015, 0.025, 0.018, 0.1), Color(0.015, 0.025, 0.018, 0.97)])
	gradient.offsets = PackedFloat32Array([0.15, 0.96])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	shade.texture = texture
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_chapter = _label("제1장  ·  숲의 부름", 23, UiKit.GOLD)
	_title = _label("자연의 수호자", 60, UiKit.TEXT, true)
	_subtitle = _label("잠든 숲을 깨우는 당신의 여정", 24, UiKit.MUTED)
	_start = UiKit.button("모험 시작", 27)
	_start.custom_minimum_size = Vector2.ZERO
	UiKit.style_button(_start, true)
	_start.pressed.connect(_begin)
	add_child(_start)
	resized.connect(_layout)
	_layout()
	if OS.has_feature("web"):
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
	var scene: Texture2D = preload("res://assets/art/ui/select-scene.png")
	var source := scene.get_size()
	var aspect := size.x / maxf(1.0, size.y)
	var crop := Vector2(minf(source.x, source.y * aspect), minf(source.y, source.x / maxf(0.01, aspect)))
	var atlas := AtlasTexture.new()
	atlas.atlas = scene
	atlas.region = Rect2(Vector2((source.x - crop.x) * 0.5, 0), crop)
	_backdrop.texture = atlas
	var unit := minf(area.size.x / 720.0, area.size.y / 1280.0) if area.size.y > area.size.x else minf(area.size.x / 1080.0, area.size.y / 720.0)
	var width := minf(area.size.x - 64.0 * unit, 620.0 * unit)
	var left := area.get_center().x - width * 0.5
	var bottom := area.end.y - 48.0 * unit
	for entry in [[_chapter, 286, 34, 23], [_title, 238, 76, 60], [_subtitle, 142, 36, 24], [_start, 80, 80, 27]]:
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
		start_requested.emit()


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_begin()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_begin()

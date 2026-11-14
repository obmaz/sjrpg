extends Control
## The same illustrated entry composition before and after the web engine loads.

signal start_requested
signal new_game_requested
signal load_game_requested
signal settings_requested

var _backdrop: TextureRect
var _title: Label
var _chapter: Label
var _subtitle: Label
var _start: Button
var _btn_new_game: Button
var _btn_load_game: Button
var _btn_settings: Button
var _started := false
var _layout_pending := false
var _web_start: JavaScriptObject
var _web_entry: JavaScriptObject


func _ready() -> void:
	add_to_group("gamepad_entry")
	set_meta("gamepad_hidden_scope", true)
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
	_chapter = _label("제1장 · 숲의 부름", 23, Color("d7bd8e"))
	_title = _label("자연의 수호자", 60, UiKit.TEXT, true)
	_subtitle = _label("어둠에 잠긴 숲, 당신의 여정이 시작됩니다", 24, Color("d0cbbd"))
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_btn_new_game = UiKit.button("새로운 모험", int(EntryUi.ACTION_FONT_SIZE))
	_btn_new_game.custom_minimum_size = Vector2.ZERO
	EntryUi.style(_btn_new_game)
	_btn_new_game.pressed.connect(_on_new_game_pressed)
	add_child(_btn_new_game)
	_start = _btn_new_game

	_btn_load_game = UiKit.button("모험 불러오기", int(EntryUi.ACTION_FONT_SIZE))
	_btn_load_game.custom_minimum_size = Vector2.ZERO
	EntryUi.style(_btn_load_game)
	_btn_load_game.pressed.connect(_on_load_game_pressed)
	add_child(_btn_load_game)

	_btn_settings = UiKit.button("모험 설정", int(EntryUi.ACTION_FONT_SIZE))
	_btn_settings.custom_minimum_size = Vector2.ZERO
	EntryUi.style(_btn_settings)
	_btn_settings.pressed.connect(_on_settings_pressed)
	add_child(_btn_settings)

	resized.connect(_layout)
	for control: Control in [_chapter, _title, _subtitle, _btn_new_game, _btn_load_game, _btn_settings]:
		control.minimum_size_changed.connect(_queue_layout)
	_layout()
	if OS.has_feature("web"):
		_web_entry = JavaScriptBridge.get_interface("__sjrpgEntry")
		if _web_entry != null:
			# 엔진 로딩이 완료되면 웹 HTML 쉘의 다운로드 오버레이를 닫고 Godot 메인 화면을 노출합니다.
			_web_entry.hide()
		show()
		JavaScriptBridge.eval("window.__sjrpgTitleReady = true; window.__sjrpgEntryReady = true")


func _label(text: String, font_size: int, color: Color, bold := false) -> Label:
	var label := UiKit.label(text, font_size, color, bold)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("outline_size", 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _layout() -> void:
	if _btn_new_game == null or _btn_load_game == null or _btn_settings == null:
		return
	var margins := PanelFrame.safe_margins(get_viewport())
	var area := Rect2(Vector2(margins.x, margins.y), size - Vector2(margins.x + margins.z, margins.y + margins.w))
	var portrait := area.size.y > area.size.x
	var unit := minf(area.size.x / 720.0, area.size.y / 1280.0) if portrait else minf(area.size.x / 1080.0, area.size.y / 720.0)
	var css := _css_scale()
	var outer := maxf(32.0 * unit, 12.0 * css)
	var width := minf(area.size.x - outer * 2.0, 620.0 * unit) if portrait else minf(area.size.x * 0.44, 620.0 * unit)
	var left := area.get_center().x - width * 0.5 if portrait else area.position.x + area.size.x * 0.52
	var bottom := area.end.y - maxf(48.0 * unit, 12.0 * css)

	# 논리 해상도가 큰 웹·Android에서도 실제 손가락 크기로 조작할 수 있게 한다.
	var action_h := EntryUi.action_height(unit, css)
	for button: Button in [_btn_new_game, _btn_load_game, _btn_settings]:
		_font(button, EntryUi.ACTION_FONT_SIZE * unit, EntryUi.ACTION_FONT_DP * css)
		action_h = maxf(action_h, EntryUi.fit_action(button, action_h, css))
	for button: Button in [_btn_new_game, _btn_load_game, _btn_settings]:
		EntryUi.fit_action(button, action_h, css)
	var gap := maxf(12.0 * unit, UiKit.ACTION_GAP_DP * css)

	var settings_y := bottom - action_h
	var load_y := settings_y - gap - action_h
	var new_y := load_y - gap - action_h

	_btn_settings.position = Vector2(left, settings_y)
	_btn_settings.size = Vector2(width, action_h)

	_btn_load_game.position = Vector2(left, load_y)
	_btn_load_game.size = Vector2(width, action_h)

	_btn_new_game.position = Vector2(left, new_y)
	_btn_new_game.size = Vector2(width, action_h)

	_font(_subtitle, 24.0 * unit, 14.0 * css)
	_font(_title, 60.0 * unit, (32.0 if portrait else 28.0) * css)
	_font(_chapter, 23.0 * unit, 14.0 * css)
	var cursor := new_y - maxf(24.0 * unit, 10.0 * css)
	var copy_gap := maxf(12.0 * unit, 6.0 * css)
	for label: Label in [_subtitle, _title, _chapter]:
		var height := label.get_theme_font("font").get_multiline_string_size(
			label.text, HORIZONTAL_ALIGNMENT_CENTER, width,
			label.get_theme_font_size("font_size")
		).y + 2.0
		EntryUi.place(label, Rect2(Vector2(left, cursor - height), Vector2(width, height)))
		cursor -= height + copy_gap
	_publish_buttons()


func _font(control: Control, base: float, minimum: float) -> void:
	var pixels := ceili(maxf(base, minimum))
	if control.get_theme_font_size("font_size") != pixels:
		control.add_theme_font_size_override("font_size", pixels)


func _queue_layout() -> void:
	if _layout_pending:
		return
	_layout_pending = true
	_settle_layout.call_deferred()


func _settle_layout() -> void:
	_layout_pending = false
	# 회전 직후 글꼴/줄바꿈 최소 크기가 갱신되면 이전 폭·높이를 버리고 다시 맞춘다.
	_layout()


func _css_scale() -> float:
	return UiMetrics.units_per_display_pixel(get_viewport())


func _publish_buttons() -> void:
	if not OS.has_feature("web"):
		return
	var dimensions := get_viewport_rect().size
	var buttons := {}
	var layout := {"viewport": [dimensions.x, dimensions.y], "dp_scale": _css_scale(), "controls": {}}
	for key: String in ["new_game", "load_game", "settings"]:
		var button: Button = {"new_game": _btn_new_game, "load_game": _btn_load_game,
			"settings": _btn_settings}[key]
		var center := button.get_global_rect().get_center() / dimensions
		buttons[key] = [center.x, center.y]
		layout["controls"][key] = _control_probe(button)
	for key: String in ["chapter", "title", "subtitle"]:
		var caption: Label = {"chapter": _chapter, "title": _title, "subtitle": _subtitle}[key]
		layout["controls"][key] = _control_probe(caption)
	JavaScriptBridge.eval("window.__sjrpgTitleButtons = " + JSON.stringify(buttons))
	JavaScriptBridge.eval("window.__sjrpgTitleLayout = " + JSON.stringify(layout))


func _control_probe(control: Control) -> Dictionary:
	var rect := control.get_global_rect()
	return {
		"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"font_size": control.get_theme_font_size("font_size")
	}


func _begin() -> void:
	_on_new_game_pressed()


func _on_new_game_pressed() -> void:
	if not _started:
		_started = true
		if _web_entry != null:
			_web_entry.hide()
		new_game_requested.emit()
		start_requested.emit()


func _on_load_game_pressed() -> void:
	load_game_requested.emit()


func _on_settings_pressed() -> void:
	settings_requested.emit()


func _gui_input(event: InputEvent) -> void:
	# 버튼 영역 외 배경 클릭 시 강제 진입 방지 (사용자가 명시적으로 3대 메뉴 버튼 중 하나를 선택하도록 함)
	pass


func _unhandled_input(event: InputEvent) -> void:
	if _web_entry != null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_begin()

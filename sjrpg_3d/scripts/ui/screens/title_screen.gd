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
var _time := 0.0
var _started := false
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
	_chapter = _label("제1장 · 숲의 부름", 23, EntryUi.BRONZE)
	_title = _label("자연의 수호자", 60, UiKit.TEXT, true)
	_subtitle = _label("어둠에 잠긴 숲, 당신의 여정이 시작됩니다", 24, EntryUi.MUTED)

	_btn_new_game = UiKit.button("새로운 모험", 26)
	_btn_new_game.custom_minimum_size = Vector2.ZERO
	EntryUi.style(_btn_new_game, true)
	_btn_new_game.pressed.connect(_on_new_game_pressed)
	add_child(_btn_new_game)
	_start = _btn_new_game

	_btn_load_game = UiKit.button("모험 불러오기", 22)
	_btn_load_game.custom_minimum_size = Vector2.ZERO
	EntryUi.style(_btn_load_game, false)
	_btn_load_game.pressed.connect(_on_load_game_pressed)
	add_child(_btn_load_game)

	_btn_settings = UiKit.button("모험 설정", 20)
	_btn_settings.custom_minimum_size = Vector2.ZERO
	EntryUi.style(_btn_settings, false)
	_btn_settings.pressed.connect(_on_settings_pressed)
	add_child(_btn_settings)

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
	if _btn_new_game == null or _btn_load_game == null or _btn_settings == null:
		return
	var margins := PanelFrame.safe_margins(get_viewport())
	var area := Rect2(Vector2(margins.x, margins.y), size - Vector2(margins.x + margins.z, margins.y + margins.w))
	var unit := minf(area.size.x / 720.0, area.size.y / 1280.0) if area.size.y > area.size.x else minf(area.size.x / 1080.0, area.size.y / 720.0)
	var width := minf(area.size.x - 64.0 * unit, 620.0 * unit) if area.size.y > area.size.x else minf(area.size.x * 0.44, 620.0 * unit)
	var left := area.get_center().x - width * 0.5 if area.size.y > area.size.x else area.position.x + area.size.x * 0.52
	var bottom := area.end.y - 48.0 * unit

	# 폰 및 데스크톱 모두 64px+ 이상의 안전한 터치 타깃 보장
	var btn_settings_h := maxf(64.0 * unit, 64.0)
	var btn_load_h := maxf(68.0 * unit, 66.0)
	var btn_new_h := maxf(76.0 * unit, 72.0)
	var gap := 12.0 * unit

	var settings_y := bottom - btn_settings_h
	var load_y := settings_y - gap - btn_load_h
	var new_y := load_y - gap - btn_new_h

	_btn_settings.position = Vector2(left, settings_y)
	_btn_settings.size = Vector2(width, btn_settings_h)
	_btn_settings.add_theme_font_size_override("font_size", roundi(20.0 * unit))

	_btn_load_game.position = Vector2(left, load_y)
	_btn_load_game.size = Vector2(width, btn_load_h)
	_btn_load_game.add_theme_font_size_override("font_size", roundi(22.0 * unit))

	_btn_new_game.position = Vector2(left, new_y)
	_btn_new_game.size = Vector2(width, btn_new_h)
	_btn_new_game.add_theme_font_size_override("font_size", roundi(26.0 * unit))

	var subtitle_bottom := new_y - 24.0 * unit
	_subtitle.position = Vector2(left, subtitle_bottom - 36.0 * unit)
	_subtitle.size = Vector2(width, 36.0 * unit)
	_subtitle.add_theme_font_size_override("font_size", roundi(24.0 * unit))

	var title_bottom := _subtitle.position.y - 12.0 * unit
	_title.position = Vector2(left, title_bottom - 76.0 * unit)
	_title.size = Vector2(width, 76.0 * unit)
	_title.add_theme_font_size_override("font_size", roundi(60.0 * unit))

	var chapter_bottom := _title.position.y - 8.0 * unit
	_chapter.position = Vector2(left, chapter_bottom - 34.0 * unit)
	_chapter.size = Vector2(width, 34.0 * unit)
	_chapter.add_theme_font_size_override("font_size", roundi(23.0 * unit))


func _process(delta: float) -> void:
	_time += delta
	if _start != null:
		_start.self_modulate = Color(1, 1, 1, 1.0 if Prefs.reduce_motion else 0.94 + 0.06 * sin(_time * 1.7))


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
	if _web_entry != null:
		_web_entry.hide()
	load_game_requested.emit()


func _on_settings_pressed() -> void:
	if _web_entry != null:
		_web_entry.hide()
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


func gamepad_accept() -> void:
	_begin()

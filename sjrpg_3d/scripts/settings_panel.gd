class_name SettingsPanel
extends PanelFrame
## 모험 설정 (원본 game_panels 'settings' + DeviceControls): 화면과 타격감 · 전투 효과음 ·
## 저장 · 타이틀 · 새 모험. 폰에서 누르기 쉬운 큰 스위치 행으로 구성합니다.

signal title_requested
signal restart_requested

var game: Node
var _feedback := ""
var _install_button: Button
var _install_hint: Label
var _fullscreen_button: Button
var _fullscreen_hint: Label
var _install_poll := 0.0
var _zoom_buttons: Array[Button] = []
var _zoom_grid: GridContainer
var _screen_orientation_buttons: Array[Button] = []
var _screen_orientation_hint: Label
var _version_buttons: Array[Button] = []


func setup(g: Node) -> SettingsPanel:
	game = g
	return self


func _ready() -> void:
	super._ready()
	set_header("모험 설정")
	_rebuild()
	add_footer("모험 계속하기", func(): closed.emit(), true)
	get_viewport().size_changed.connect(_fit_zoom_targets)


func _rebuild() -> void:
	clear_body()
	_zoom_buttons.clear()
	_zoom_grid = null
	_screen_orientation_buttons.clear()
	_version_buttons.clear()
	body.add_child(PanelFrame.section("화면"))
	_fullscreen_button = _action_row("전체화면 켜기", _request_fullscreen)
	_fullscreen_button.name = "FullscreenToggle"
	body.add_child(_fullscreen_button)
	_fullscreen_hint = PanelFrame.wrap_label("전체화면 상태를 확인하고 있습니다.", 15, UiKit.MUTED)
	_fullscreen_hint.name = "FullscreenHint"
	body.add_child(_fullscreen_hint)
	_refresh_fullscreen()
	body.add_child(_screen_orientation_card())
	_refresh_screen_orientation()
	body.add_child(UiKit.divider())
	if OS.has_feature("web"):
		body.add_child(_version_card())
		body.add_child(UiKit.divider())
		body.add_child(PanelFrame.section("기기에 설치"))
		_install_button = _action_row("이 기기에 설치", _request_install)
		body.add_child(_install_button)
		_install_hint = PanelFrame.wrap_label("브라우저의 설치 기능을 확인하고 있습니다.", 15, UiKit.MUTED)
		body.add_child(_install_hint)
		_refresh_install()
		body.add_child(UiKit.divider())
	body.add_child(PanelFrame.section("화면과 타격감"))
	body.add_child(_world_zoom_card())
	var fps_toggle := _toggle("FPS 표시", "화면 왼쪽 아래에 현재 프레임 수를 표시합니다.", Prefs.show_fps, func(on):
		Prefs.set_show_fps(on)
		_rebuild())
	fps_toggle.name = "ShowFps"
	body.add_child(fps_toggle)
	body.add_child(_toggle("절약 화질", "배경·캐릭터 해상도를 낮춰 속도를 높입니다. 글자·버튼은 선명하게 유지합니다.", Prefs.low_resolution, func(on):
		Prefs.set_low_resolution(on)
		_rebuild()))
	body.add_child(_toggle("타격 진동", "공격 적중 · 피격 · 스킬 사용" if Prefs.vibration_supported() else "이 기기에서는 진동을 지원하지 않습니다.", Prefs.haptics_enabled, func(on):
		Prefs.set_haptics(on)
		_rebuild()))
	body.add_child(_toggle("동작 줄이기", "HUD 장식 회전·맥박 대신 고정 표시", Prefs.reduce_motion, func(on):
		Prefs.set_reduce_motion(on)
		_rebuild()))
	body.add_child(_action_row("진동 확인", func(): Prefs.pulse("hurt", true), Prefs.vibration_supported() and Prefs.haptics_enabled))
	body.add_child(PanelFrame.wrap_label("진동은 지원되는 기기에서 동작하며, 선택한 설정은 이 기기에 저장됩니다.", 15, UiKit.MUTED))
	body.add_child(_toggle("배경 음악", "마을 · 들판 · 동굴", Prefs.music_enabled, func(on):
		Prefs.set_music(on)
		_rebuild()))
	body.add_child(_toggle("전투 효과음", "공격 · 피격 · 획득", Prefs.sound_enabled, func(on):
		Prefs.set_sound(on)
		if on:
			SoundFx.play("loot", true)
		_rebuild()))
	body.add_child(_action_row("효과음 확인", func(): SoundFx.play("impact", true), Prefs.sound_enabled))
	if game.dungeon.active:
		body.add_child(_action_row("동굴에서 나가기", func():
			closed.emit()
			game.dungeon.leave("동굴 입구로 돌아왔습니다")))
	body.add_child(UiKit.divider())
	body.add_child(PanelFrame.section("진행"))
	body.add_child(PanelFrame.wrap_label("5초마다 이 기기에 자동 저장합니다. 다음에 이어하기로 돌아올 수 있습니다. 직업을 고르고 새 모험 시작을 확인하면 이전 진행을 덮어씁니다.", 15, UiKit.MUTED))
	if _feedback != "":
		body.add_child(PanelFrame.wrap_label(_feedback, 16, Color(0.71, 1, 0.69)))
	body.add_child(_action_row("진행 상황 지금 저장", func():
		var saved := GameState.save_game()
		_feedback = "현재 모험 진행이 저장되었습니다." if saved else GameState.save_error
		_rebuild()))
	body.add_child(_action_row("저장하고 타이틀로", func(): title_requested.emit()))
	var danger := _action_row("새 모험 준비", func(): _confirm_restart())
	body.add_child(danger)
	body.add_child(PanelFrame.section("게임패드 조작"))
	body.add_child(PanelFrame.wrap_label("LS 이동 · RS 조준\nA 기본 공격 / 확인 · B 회피 / 뒤로\nX · Y · RB · RT 보조 기술 1–4\nLT 대화 / 상호작용 · LB 체력 물약 · ↑ 자원 물약\n← 가방 · → 의뢰 · ↓ 스킬\nMenu 설정 · View 지도\n메뉴에서는 LS / 방향키로 선택하고 A로 확인합니다.", 16, UiKit.MUTED))
	body.add_child(UiKit.divider())
	_fit_zoom_targets()
	_publish_version_buttons.call_deferred()


func _process(delta: float) -> void:
	_install_poll -= delta
	if _install_poll <= 0.0:
		_install_poll = 0.5
		_refresh_fullscreen()
		_refresh_screen_orientation()
		if OS.has_feature("web"):
			_refresh_install()
		_publish_version_buttons()


func _request_fullscreen() -> void:
	Prefs.toggle_fullscreen()
	_refresh_fullscreen()


func _refresh_fullscreen() -> void:
	if not is_instance_valid(_fullscreen_button) or _fullscreen_button.is_queued_for_deletion():
		return
	var state := Prefs.fullscreen_state()
	_fullscreen_button.text = str(state.get("title", "전체화면 켜기"))
	_fullscreen_button.disabled = not bool(state.get("supported", false)) or bool(state.get("pending", false))
	_fullscreen_hint.text = str(state.get("detail", ""))


func _publish_version_buttons() -> void:
	if not OS.has_feature("web") or not is_visible_in_tree():
		return
	var view := get_viewport().get_visible_rect().size
	var versions := {}
	var buttons: Array[Button] = _version_buttons.duplicate()
	if is_instance_valid(_fullscreen_button):
		buttons.append(_fullscreen_button)
	for button in buttons:
		if is_instance_valid(button) and not button.is_queued_for_deletion() and button.is_visible_in_tree():
			versions[str(button.name)] = {"point": button.get_global_rect().get_center() / view, "disabled": button.disabled}
	# Use plain arrays so test/browser clients receive actual clickable centres.
	for name: String in versions:
		var at: Vector2 = versions[name]["point"]
		versions[name]["point"] = [at.x, at.y]
	JavaScriptBridge.eval("window.__sjrpgVersionButtons = " + JSON.stringify(versions))


func _request_install() -> void:
	# Call synchronously from Button.pressed; the JS bridge invokes prompt before awaiting a result.
	JavaScriptBridge.eval("if (window.SjrpgInstall) window.SjrpgInstall.request();")
	_refresh_install()


func _refresh_install() -> void:
	if not is_instance_valid(_install_button) or _install_button.is_queued_for_deletion():
		return
	var raw: Variant = JavaScriptBridge.eval("JSON.stringify(window.SjrpgInstall ? window.SjrpgInstall.state() : {status:'manual',title:'설치 · 홈 화면 추가 안내',detail:'브라우저 메뉴에서 앱 설치 또는 홈 화면에 추가를 선택해 주세요.'})", true)
	if not raw is String:
		return
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		return
	_install_button.text = str(parsed.get("title", "이 기기에 설치"))
	_install_button.disabled = str(parsed.get("status", "manual")) in ["installed", "prompting"]
	_install_hint.text = str(parsed.get("detail", ""))


func _confirm_restart() -> void:
	_version_buttons.clear()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sjrpgVersionButtons = null")
	clear_body()
	body.add_child(PanelFrame.section("새 모험을 시작할까요?"))
	body.add_child(PanelFrame.wrap_label("직업 선택으로 이동합니다. 새 모험 시작을 확인하기 전까지 현재 진행은 유지됩니다.", 18))
	body.add_child(_action_row("직업 선택으로", func(): restart_requested.emit()))
	body.add_child(_action_row("취소", func(): _rebuild()))


func _action_row(text: String, on_press: Callable, enabled := true) -> Button:
	var b := UiKit.button(text, 21)
	b.custom_minimum_size = Vector2(0, 76)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = not enabled
	b.pressed.connect(on_press)
	return b


func _world_zoom_card() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.SURFACE, UiKit.EDGE, 12))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", PanelFrame.CARD_TEXT_GAP)
	card.add_child(column)
	column.add_child(UiKit.label("화면 확대", 22, UiKit.TEXT, true))
	column.add_child(PanelFrame.wrap_label("배경·캐릭터의 크기를 조절합니다. 글자·버튼 크기는 유지됩니다.", 15, UiKit.MUTED))
	_zoom_grid = GridContainer.new()
	_zoom_grid.columns = 3
	_zoom_grid.add_theme_constant_override("h_separation", 12)
	_zoom_grid.add_theme_constant_override("v_separation", 12)
	_zoom_grid.resized.connect(_fit_zoom_targets)
	column.add_child(_zoom_grid)
	var group := ButtonGroup.new()
	for amount: float in Prefs.WORLD_ZOOMS:
		var button := UiKit.button("%s×" % ("1" if is_equal_approx(amount, 1.0) else str(amount)), 22)
		button.custom_minimum_size = Vector2(0, 76)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = is_equal_approx(Prefs.world_zoom, amount)
		button.set_meta("world_zoom", amount)
		UiKit.style_button(button, false, button.button_pressed)
		button.pressed.connect(_choose_world_zoom.bind(amount))
		_zoom_grid.add_child(button)
		_zoom_buttons.append(button)
	return card


func _screen_orientation_card() -> Control:
	var card := PanelContainer.new()
	card.name = "ScreenOrientation"
	card.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.SURFACE, UiKit.EDGE, 12))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", PanelFrame.CARD_TEXT_GAP)
	card.add_child(column)
	column.add_child(UiKit.label("화면 방향", 22, UiKit.TEXT, true))
	_screen_orientation_hint = PanelFrame.wrap_label("", 15, UiKit.MUTED)
	_screen_orientation_hint.name = "ScreenOrientationHint"
	column.add_child(_screen_orientation_hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var group := ButtonGroup.new()
	var labels := {"auto": "자동", "landscape": "가로", "portrait": "세로"}
	for choice: String in Prefs.SCREEN_ORIENTATIONS:
		var button := UiKit.button(str(labels[choice]), 21)
		button.name = "Orientation_" + choice
		button.custom_minimum_size = Vector2(0, 76)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = Prefs.screen_orientation == choice
		button.set_meta("screen_orientation", choice)
		button.set_meta("gamepad_key", "screen_orientation:" + choice)
		UiKit.style_button(button, false, button.button_pressed)
		button.pressed.connect(_choose_screen_orientation.bind(choice))
		row.add_child(button)
		_screen_orientation_buttons.append(button)
	return card


func _choose_screen_orientation(choice: String) -> void:
	Prefs.set_screen_orientation(choice, true)
	_rebuild()


func _refresh_screen_orientation() -> void:
	if not is_instance_valid(_screen_orientation_hint) or _screen_orientation_hint.is_queued_for_deletion():
		return
	var state := Prefs.screen_orientation_state()
	_screen_orientation_hint.text = str(state.get("detail", ""))
	for button: Button in _screen_orientation_buttons:
		if is_instance_valid(button) and not button.is_queued_for_deletion():
			button.disabled = bool(state.get("pending", false))


func zoom_css_scale() -> float:
	if OS.has_feature("web"):
		var width: Variant = JavaScriptBridge.eval("window.innerWidth", true)
		if (width is float or width is int) and float(width) > 0.0:
			return get_viewport().get_visible_rect().size.x / float(width)
	if DisplayServer.get_name() == "headless":
		return 1.0
	return get_viewport().get_visible_rect().size.x / maxf(1.0, float(get_window().size.x))


func _fit_zoom_targets() -> void:
	var touch := 44.0 * zoom_css_scale()
	var minimum_width := touch
	for button: Button in _zoom_buttons + _screen_orientation_buttons:
		if is_instance_valid(button) and not button.is_queued_for_deletion():
			button.custom_minimum_size = Vector2(touch, maxf(76.0, touch))
			if button in _zoom_buttons:
				minimum_width = maxf(minimum_width, button.get_minimum_size().x)
	if is_instance_valid(_zoom_grid) and not _zoom_grid.is_queued_for_deletion():
		var gap := float(_zoom_grid.get_theme_constant("h_separation"))
		var fitting := maxi(1, floori((_zoom_grid.size.x + gap) / (minimum_width + gap)))
		# Five fit across a wide card; narrow phones use a balanced three/two split.
		_zoom_grid.columns = 5 if fitting >= 5 else mini(3, fitting)


func _choose_world_zoom(amount: float) -> void:
	Prefs.set_world_zoom(amount)
	_rebuild()


func _version_card() -> Control:
	var card := VBoxContainer.new()
	if OS.has_feature("android"):
		return card  # The edition chooser is a web page; the Android app ships the 3D adventure only.
	card.add_theme_constant_override("separation", PanelFrame.CARD_TEXT_GAP)
	card.add_child(PanelFrame.section("모험 선택"))
	card.add_child(PanelFrame.wrap_label("현재 모험을 저장한 뒤 선택 화면으로 돌아갑니다.", 15, UiKit.MUTED))
	if OS.has_feature("web"):
		var select := UiKit.button("저장하고 선택 화면으로", 20)
		select.name = "VersionSelect"
		select.custom_minimum_size.y = 76
		select.pressed.connect(func(): _open_edition(""))
		card.add_child(select)
		_version_buttons.append(select)
	return card


func _open_edition(edition: String) -> void:
	if not EditionNavigation.open(edition):
		_feedback = GameState.save_error
		_rebuild()


## A big switch row: label + hint on the left, ON/OFF pill on the right.
func _toggle(label: String, hint: String, on: bool, on_change: Callable) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.SURFACE, UiKit.EDGE if not on else UiKit.GOLD, 12))
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	card.add_child(holder)
	var hit := Button.new()
	hit.flat = true
	hit.set_meta("gamepad_key", "setting:" + label)
	hit.tooltip_text = label
	hit.focus_mode = Control.FOCUS_NONE
	hit.pressed.connect(func(): on_change.call(not on))
	holder.add_child(hit)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	holder.add_child(row)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", PanelFrame.CARD_TEXT_GAP)
	row.add_child(text)
	var l := UiKit.label(label, 22, Color(0.95, 0.92, 0.82), true)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(l)
	var h := UiKit.label(hint, 15, UiKit.MUTED)
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(h)
	var pill := Pill.new()
	pill.on = on
	pill.custom_minimum_size = Vector2(112, 58)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pill)
	return card


class Pill:
	extends Control
	var on := false

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var back := Color("56533a") if on else Color("24251f")
		var sb := StyleBoxFlat.new()
		sb.bg_color = back
		sb.set_corner_radius_all(int(size.y / 2.0))
		sb.border_color = Color("8c7651")
		sb.set_border_width_all(2)
		draw_style_box(sb, r)
		var knob := Vector2(size.x - size.y / 2.0 if on else size.y / 2.0, size.y / 2.0)
		draw_circle(knob + Vector2(0, 1), size.y / 2.0 - 4.0, Color("14120d"))
		draw_circle(knob, size.y / 2.0 - 6.0, UiKit.GOLD)
		draw_arc(knob, size.y / 2.0 - 8.0, PI * 1.1, TAU, 24, Color("e1cca0"), 1.0, true)
		var text := "ON" if on else "OFF"
		var width := UiKit.BOLD_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
		var left := 8.0 if on else size.y
		var right := size.x - size.y if on else size.x - 8.0
		draw_string(UiKit.BOLD_FONT, Vector2((left + right - width) / 2.0, size.y * 0.66), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, UiKit.TEXT)

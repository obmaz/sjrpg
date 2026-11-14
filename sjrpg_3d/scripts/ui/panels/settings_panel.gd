class_name SettingsPanel
extends PanelFrame
## 모험 설정 (원본 game_panels 'settings' + DeviceControls): 화면과 타격감 · 전투 효과음 ·
## 저장 · 타이틀 · 새 모험. 폰에서 누르기 쉬운 큰 스위치 행으로 구성합니다.

signal title_requested
signal restart_requested
signal load_requested(slot: int)

var game: Node
var _feedback := ""
var _feedback_error := false
var _install_button: Button
var _fullscreen_button: Button
var _haptics_test_button: Button
var _sound_test_button: Button
var _install_poll := 0.0
var _zoom_buttons: Array[Button] = []
var _zoom_grid: GridContainer
var _screen_orientation_buttons: Array[Button] = []
var _screen_orientation_grid: GridContainer
var _gamepad_help_button: Button
var _version_buttons: Array[Button] = []
var _toggle_widgets: Array[Dictionary] = []


func setup(g: Node) -> SettingsPanel:
	game = g
	return self


func _ready() -> void:
	super._ready()
	set_header("모험 설정")
	set_close_visible(false)
	_rebuild()
	var footer_text := "모험 계속하기" if game != null else "닫기"
	add_footer(footer_text, func(): closed.emit(), true)
	get_viewport().size_changed.connect(_fit_display_option_targets)
	Gamepad.input_mode_changed.connect(_refresh_gamepad_help)


func _rebuild() -> void:
	set_header("모험 설정")
	clear_body()
	_zoom_buttons.clear()
	_zoom_grid = null
	_screen_orientation_buttons.clear()
	_screen_orientation_grid = null
	_version_buttons.clear()
	_toggle_widgets.clear()
	_fullscreen_button = _action_row("전체화면 켜기", _request_fullscreen)
	_fullscreen_button.name = "FullscreenToggle"
	body.add_child(_fullscreen_button)
	_refresh_fullscreen()
	body.add_child(_screen_orientation_options())
	_refresh_screen_orientation()
	if OS.has_feature("web"):
		body.add_child(_version_card())
		_install_button = _action_row("이 기기에 설치", _request_install)
		body.add_child(_install_button)
		_refresh_install()
	body.add_child(_world_zoom_options())
	var fps_toggle := _toggle("FPS 표시", Prefs.show_fps, Prefs.set_show_fps)
	fps_toggle.name = "ShowFps"
	body.add_child(fps_toggle)
	body.add_child(_toggle("절약 화질", Prefs.low_resolution, Prefs.set_low_resolution))
	body.add_child(_toggle("타격 진동", Prefs.haptics_enabled, Prefs.set_haptics))
	body.add_child(_toggle("동작 줄이기", Prefs.reduce_motion, Prefs.set_reduce_motion))
	_haptics_test_button = _action_row("진동 확인", func(): Prefs.pulse("hurt", true))
	body.add_child(_haptics_test_button)
	body.add_child(_toggle("배경 음악", Prefs.music_enabled, Prefs.set_music))
	body.add_child(_toggle("전투 효과음", Prefs.sound_enabled, func(on):
		Prefs.set_sound(on)
		if on:
			SoundFx.play("loot", true)))
	_sound_test_button = _action_row("효과음 확인", func(): SoundFx.play("impact", true))
	body.add_child(_sound_test_button)
	_refresh_test_actions()
	if game != null and is_instance_valid(game) and "dungeon" in game and game.dungeon != null and game.dungeon.active:
		body.add_child(_action_row("동굴에서 나가기", func():
			closed.emit()
			game.dungeon.leave("동굴 입구로 돌아왔습니다")))
	if _feedback != "":
		var feedback := PanelFrame.wrap_label(_feedback, 16, Color(1.0, 0.69, 0.63) if _feedback_error else Color(0.71, 1, 0.69))
		feedback.name = "SaveFeedback"
		body.add_child(feedback)
	if game != null:
		body.add_child(_action_row("진행 상황 지금 저장", func():
			var saved := GameState.save_game()
			_feedback = "현재 모험 진행이 저장되었습니다." if saved else GameState.save_error
			_feedback_error = not saved
			_rebuild()))
	body.add_child(_action_row("모험 불러오기", func(): _open_save_load_dialog()))
	if game != null:
		body.add_child(_action_row("저장하고 타이틀로", func(): title_requested.emit()))
		var danger := _action_row("새 모험 준비", func(): _confirm_restart())
		body.add_child(danger)
	_gamepad_help_button = _action_row("게임패드 조작 안내", _show_gamepad_help)
	body.add_child(_gamepad_help_button)
	_refresh_gamepad_help(Gamepad.using_gamepad)
	body.add_child(_action_row("아트 출처 · 라이선스", _show_asset_credits))
	_fit_display_option_targets()
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


## Failed menu exits keep this same panel paused and offer the normal save retry.
func show_save_error(message: String) -> void:
	_feedback = message if not message.is_empty() else "저장하지 못했습니다. 다시 저장한 뒤 이동해 주세요."
	_feedback_error = true
	_rebuild()


func _request_fullscreen() -> void:
	Prefs.toggle_fullscreen()
	_refresh_fullscreen()


func _refresh_fullscreen() -> void:
	if not is_instance_valid(_fullscreen_button) or _fullscreen_button.is_queued_for_deletion():
		return
	var state := Prefs.fullscreen_state()
	_fullscreen_button.text = str(state.get("title", "전체화면 켜기"))
	_fullscreen_button.disabled = not bool(state.get("supported", false)) or bool(state.get("pending", false))
	_fullscreen_button.tooltip_text = str(state.get("detail", ""))


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
	if _install_button.text.contains("안내"):
		var help := _information_panel("기기에 설치")
		help.body.add_child(PanelFrame.wrap_label(_install_button.tooltip_text, 18))
		return
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
	_install_button.tooltip_text = str(parsed.get("detail", ""))


func _confirm_restart() -> void:
	_version_buttons.clear()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sjrpgVersionButtons = null")
	clear_body()
	set_header("새 모험을 시작할까요?")
	body.add_child(PanelFrame.wrap_label("현재 모험을 저장하고 슬롯 선택으로 이동합니다. 빈 슬롯에서 새 모험을 시작할 수 있으며 기존 모험은 그대로 유지됩니다.", 18))
	body.add_child(_action_row("저장하고 슬롯 선택으로", func(): restart_requested.emit()))
	body.add_child(_action_row("취소", func(): _rebuild()))


func _open_save_load_dialog() -> void:
	var load_panel := preload("res://scripts/ui/panels/save_load_panel.gd").new().setup(true)
	load_panel.slot_loaded.connect(func(slot: int):
		load_requested.emit(slot)
		# 게임에서는 저장 성공 뒤 Game.load_slot()이 패널을 닫는다.
		if game == null:
			closed.emit()
	)
	load_panel.closed.connect(load_panel.queue_free)
	add_child(load_panel)


func _action_row(text: String, on_press: Callable, enabled := true) -> Button:
	var b := UiKit.button(text, 21)
	b.custom_minimum_size = Vector2(0, 76)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.disabled = not enabled
	b.pressed.connect(on_press)
	return b


func _world_zoom_options() -> Control:
	_zoom_grid = GridContainer.new()
	_zoom_grid.columns = 3
	_zoom_grid.add_theme_constant_override("h_separation", 12)
	_zoom_grid.add_theme_constant_override("v_separation", 12)
	_zoom_grid.resized.connect(_fit_display_option_targets)
	var group := ButtonGroup.new()
	for amount: float in Prefs.WORLD_ZOOMS:
		var button := _option_button("%s×" % ("1" if is_equal_approx(amount, 1.0) else str(amount)))
		button.button_group = group
		button.set_meta("world_zoom", amount)
		button.pressed.connect(_choose_world_zoom.bind(amount))
		_zoom_grid.add_child(button)
		_zoom_buttons.append(button)
	_refresh_world_zoom()
	return _zoom_grid


func _screen_orientation_options() -> Control:
	_screen_orientation_grid = GridContainer.new()
	_screen_orientation_grid.name = "ScreenOrientation"
	_screen_orientation_grid.columns = 3
	_screen_orientation_grid.add_theme_constant_override("h_separation", 12)
	_screen_orientation_grid.add_theme_constant_override("v_separation", 12)
	_screen_orientation_grid.resized.connect(_fit_display_option_targets)
	var group := ButtonGroup.new()
	var labels := {"auto": "자동", "landscape": "가로", "portrait": "세로"}
	for choice: String in Prefs.SCREEN_ORIENTATIONS:
		var button := _option_button(str(labels[choice]))
		button.name = "Orientation_" + choice
		button.button_group = group
		button.button_pressed = Prefs.screen_orientation == choice
		button.set_meta("screen_orientation", choice)
		button.set_meta("gamepad_key", "screen_orientation:" + choice)
		button.pressed.connect(_choose_screen_orientation.bind(choice))
		_screen_orientation_grid.add_child(button)
		_screen_orientation_buttons.append(button)
	return _screen_orientation_grid


func _choose_screen_orientation(choice: String) -> void:
	Prefs.set_screen_orientation(choice, true)
	_refresh_screen_orientation()


func _refresh_screen_orientation() -> void:
	var state := Prefs.screen_orientation_state()
	for button: Button in _screen_orientation_buttons:
		if is_instance_valid(button) and not button.is_queued_for_deletion():
			_set_option_selected(button, str(button.get_meta("screen_orientation")) == Prefs.screen_orientation)
			button.disabled = bool(state.get("pending", false))


func _fit_display_option_targets() -> void:
	_fit_toggle_rows()
	var scale := display_pixel_scale()
	var touch := ceilf(UiKit.ACTION_TOUCH_DP * scale)
	for button: Button in _zoom_buttons + _screen_orientation_buttons:
		if is_instance_valid(button) and not button.is_queued_for_deletion():
			button.custom_minimum_size = Vector2(touch, maxf(76.0, touch))
			for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
				var skin := button.get_theme_stylebox(state)
				skin.content_margin_top = ceilf(4.0 * scale)
				skin.content_margin_bottom = ceilf(20.0 * scale)
				skin.content_margin_left = ceilf(4.0 * scale)
				skin.content_margin_right = ceilf(4.0 * scale)
			var mark := button.get_node("OptionSelected") as Label
			mark.add_theme_font_size_override("font_size", ceili(14.0 * scale))
			mark.offset_bottom = -4.0 * scale
	for grid: GridContainer in [_zoom_grid, _screen_orientation_grid]:
		if not is_instance_valid(grid) or grid.is_queued_for_deletion():
			continue
		var minimum_width := touch
		for button: Button in grid.get_children():
			minimum_width = maxf(minimum_width, button.get_combined_minimum_size().x)
		var gap := float(grid.get_theme_constant("h_separation"))
		var fitting := maxi(1, floori((grid.size.x + gap) / (minimum_width + gap)))
		# All five zooms can share a wide row; otherwise keep a balanced three/two split.
		grid.columns = 5 if grid == _zoom_grid and fitting >= 5 else mini(3, fitting)


func _choose_world_zoom(amount: float) -> void:
	Prefs.set_world_zoom(amount)
	_refresh_world_zoom()


func _refresh_world_zoom() -> void:
	for button: Button in _zoom_buttons:
		if is_instance_valid(button) and not button.is_queued_for_deletion():
			_set_option_selected(button, is_equal_approx(float(button.get_meta("world_zoom")), Prefs.world_zoom))


## 무테 옵션의 선택 표시는 고정된 아래 공간을 사용해 재배치를 막는다.
func _option_button(text: String) -> Button:
	var button := UiKit.button(text, 22)
	button.custom_minimum_size = Vector2(0, 76)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, UiKit.TEXT)
	var mark := Label.new()
	mark.name = "OptionSelected"
	mark.text = "선택"
	mark.add_theme_font_override("font", UiKit.BOLD_FONT)
	mark.add_theme_color_override("font_color", UiKit.TEXT)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(mark)
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return button


func _set_option_selected(button: Button, selected: bool) -> void:
	button.set_pressed_no_signal(selected)
	(button.get_node("OptionSelected") as Label).visible = selected


func _refresh_test_actions() -> void:
	if is_instance_valid(_haptics_test_button) and not _haptics_test_button.is_queued_for_deletion():
		_haptics_test_button.disabled = not Prefs.vibration_supported() or not Prefs.haptics_enabled
	if is_instance_valid(_sound_test_button) and not _sound_test_button.is_queued_for_deletion():
		_sound_test_button.disabled = not Prefs.sound_enabled


func _refresh_gamepad_help(using_gamepad: bool) -> void:
	if is_instance_valid(_gamepad_help_button) and not _gamepad_help_button.is_queued_for_deletion():
		_gamepad_help_button.visible = using_gamepad


func _version_card() -> Control:
	var card := VBoxContainer.new()
	if OS.has_feature("android"):
		return card  # The edition chooser is a web page; the Android app ships the 3D adventure only.
	card.add_theme_constant_override("separation", PanelFrame.CARD_TEXT_GAP)
	if OS.has_feature("web"):
		var select := UiKit.button("저장하고 선택 화면으로", 20)
		select.name = "VersionSelect"
		select.custom_minimum_size = Vector2(0, 76)
		select.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		select.pressed.connect(func(): _open_edition(""))
		card.add_child(select)
		_version_buttons.append(select)
	return card


func _open_edition(edition: String) -> void:
	if not EditionNavigation.open(edition):
		show_save_error(GameState.save_error)


## 설정 이름과 ON/OFF만 표시하며 좁은 폭에서는 스위치를 다음 줄로 배치한다.
func _toggle(label: String, on: bool, on_change: Callable) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	card.add_child(holder)
	var hit := Button.new()
	hit.name = "SwitchAction"
	hit.flat = true
	hit.set_meta("gamepad_key", "setting:" + label)
	hit.tooltip_text = "%s · %s" % [label, "켜짐" if on else "꺼짐"]
	hit.focus_mode = Control.FOCUS_ALL
	hit.toggle_mode = true
	hit.button_pressed = on
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		hit.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	holder.add_child(hit)
	var row := BoxContainer.new()
	row.name = "SwitchLayout"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(row)
	var text := VBoxContainer.new()
	text.name = "SwitchCopy"
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", PanelFrame.CARD_TEXT_GAP)
	row.add_child(text)
	var title := PanelFrame.wrap_label(label, 22)
	title.set_meta("ui_action_label", true)
	title.add_theme_font_override("font", UiKit.BOLD_FONT)
	title.custom_minimum_size.x = 0
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(title)
	var pill := Pill.new()
	pill.name = "SwitchPill"
	pill.on = on
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_horizontal = Control.SIZE_SHRINK_END
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.resized.connect(pill.queue_redraw)
	row.add_child(pill)
	# 같은 위젯을 갱신해 손가락이 있던 위치와 현재 스크롤을 유지한다.
	hit.pressed.connect(func():
		var next := not pill.on
		on_change.call(next)
		pill.on = next
		hit.set_pressed_no_signal(next)
		hit.tooltip_text = "%s · %s" % [label, "켜짐" if next else "꺼짐"]
		pill.queue_redraw()
		_refresh_test_actions())
	_toggle_widgets.append({"row": row, "pill": pill, "hit": hit, "title": title})
	row.resized.connect(_fit_toggle_rows)
	return card


func _fit_toggle_rows() -> void:
	var scale := display_pixel_scale()
	var gap := maxi(12, ceili(UiKit.ACTION_GAP_DP * scale))
	for widgets: Dictionary in _toggle_widgets:
		var row: BoxContainer = widgets["row"]
		var pill: Pill = widgets["pill"]
		var hit: Button = widgets["hit"]
		if not is_instance_valid(row) or row.is_queued_for_deletion():
			continue
		hit.custom_minimum_size = Vector2(0, ceilf(UiKit.ACTION_TOUCH_DP * scale))
		pill.font_pixels = maxi(21, ceili(16.0 * scale))
		pill.custom_minimum_size = Vector2(maxf(112.0, ceilf(88.0 * scale)), maxf(58.0, ceilf(48.0 * scale)))
		row.add_theme_constant_override("separation", gap)
		var title: Label = widgets["title"]
		var title_width := title.get_theme_font("font").get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title.get_theme_font_size("font_size")).x
		row.vertical = row.size.x < title_width + pill.custom_minimum_size.x + gap
		pill.queue_redraw()


class Pill:
	extends Control
	var on := false
	var font_pixels := 21

	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("56533a") if on else Color("24251f")
		sb.set_corner_radius_all(int(size.y / 2.0))
		sb.border_color = Color("8c7651")
		sb.set_border_width_all(2)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var knob := Vector2(size.x - size.y / 2.0 if on else size.y / 2.0, size.y / 2.0)
		draw_circle(knob + Vector2(0, 1), size.y / 2.0 - 4.0, Color("14120d"))
		draw_circle(knob, size.y / 2.0 - 6.0, UiKit.GOLD)
		draw_arc(knob, size.y / 2.0 - 8.0, PI * 1.1, TAU, 24, Color("e1cca0"), 1.0, true)
		var label := "ON" if on else "OFF"
		var font := UiKit.BOLD_FONT
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_pixels).x
		var left := 0.0 if on else size.y
		var right := size.x - size.y if on else size.x
		var baseline := (size.y - font.get_height(font_pixels)) * 0.5 + font.get_ascent(font_pixels)
		draw_string(font, Vector2((left + right - width) / 2.0, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_pixels, UiKit.TEXT)


## 채택한 자산의 저작자·원본·라이선스와 수정 표기를 설정에서 읽을 수 있게 한다.
func _show_asset_credits() -> void:
	var panel := _information_panel("아트 출처 · 라이선스")
	for kind: String in DirAccess.get_directories_at("res://assets/models/enemies"):
		var path := "res://assets/models/enemies/%s/asset.json" % kind
		if not FileAccess.file_exists(path):
			continue
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var credit: String = "%s: %s · %s\n원본: %s\n라이선스: %s\n게임용으로 수정해 사용했습니다." % [source["display_name"], source["author"], source["license"], source["source_url"], source["license_url"]]
		var label := PanelFrame.wrap_label(credit, 15, UiKit.MUTED)
		label.set_meta("asset_credit", true)
		panel.body.add_child(label)


func _information_panel(title: String) -> PanelFrame:
	var panel := PanelFrame.new()
	add_child(panel)
	panel.set_header(title)
	panel.add_footer("닫기", panel.queue_free, true)
	panel.closed.connect(panel.queue_free)
	return panel


func _show_gamepad_help() -> void:
	var panel := _information_panel("게임패드 조작")
	panel.body.add_child(PanelFrame.wrap_label("LS 이동 · RS 조준\nA 기본 공격 / 확인 · B 회피 / 뒤로\nX · Y · RB · RT 보조 기술 1–4\nLT 대화 / 상호작용 · LB 체력 물약 · ↑ 자원 물약\n← 가방 · → 의뢰 · ↓ 스킬\nMenu 설정 · View 지도\n메뉴에서는 LS / 방향키로 선택하고 A로 확인합니다.", 18))

class_name SettingsPanel
extends PanelFrame
## 모험 설정 (원본 game_panels 'settings' + DeviceControls): 화면과 타격감 · 전투 효과음 ·
## 저장 · 타이틀 · 새 모험. 폰에서 누르기 쉬운 큰 스위치 행으로 구성합니다.

signal title_requested
signal restart_requested

var game: Node
var _feedback := ""


func setup(g: Node) -> SettingsPanel:
	game = g
	return self


func _ready() -> void:
	super._ready()
	set_header("모험 설정")
	_rebuild()
	add_footer("모험 계속하기", func(): closed.emit(), true)


func _rebuild() -> void:
	clear_body()
	body.add_child(PanelFrame.section("화면과 타격감"))
	body.add_child(_action_row("전체화면 끄기" if Prefs.is_fullscreen() else "전체화면 켜기", func():
		Prefs.toggle_fullscreen()
		_rebuild()))
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
	body.add_child(PanelFrame.wrap_label("진동은 지원되는 기기에서 동작하며, 선택한 설정은 이 기기에 저장됩니다.", 15, Color(0.66, 0.78, 0.74)))
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
	body.add_child(HSeparator.new())
	body.add_child(PanelFrame.section("진행"))
	body.add_child(PanelFrame.wrap_label("5초마다 이 기기에 자동 저장합니다. 다음에 이어하기로 돌아올 수 있습니다. 직업을 고르고 새 모험 시작을 확인하면 이전 진행을 덮어씁니다.", 15, Color(0.73, 0.8, 0.74)))
	if _feedback != "":
		body.add_child(PanelFrame.wrap_label(_feedback, 16, Color(0.71, 1, 0.69)))
	body.add_child(_action_row("진행 상황 지금 저장", func():
		var saved := GameState.save_game()
		_feedback = "현재 모험 진행이 저장되었습니다." if saved else GameState.save_error
		_rebuild()))
	body.add_child(_action_row("저장하고 타이틀로", func(): title_requested.emit()))
	var danger := _action_row("새 모험 준비", func(): _confirm_restart())
	body.add_child(danger)


func _confirm_restart() -> void:
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


## A big switch row: label + hint on the left, ON/OFF pill on the right.
func _toggle(label: String, hint: String, on: bool, on_change: Callable) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.07, 0.15, 0.14, 0.95), Color(0.28, 0.42, 0.37) if not on else UiKit.GOLD, 12))
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	card.add_child(holder)
	var hit := Button.new()
	hit.flat = true
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
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	var l := UiKit.label(label, 22, Color(0.95, 0.92, 0.82), true)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(l)
	var h := UiKit.label(hint, 15, Color(0.7, 0.82, 0.77))
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(h)
	var pill := Pill.new()
	pill.on = on
	pill.custom_minimum_size = Vector2(112, 58)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pill)
	return card


class Pill:
	extends Control
	var on := false

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var back := Color(0.28, 0.62, 0.45) if on else Color(0.2, 0.25, 0.26)
		var sb := StyleBoxFlat.new()
		sb.bg_color = back
		sb.set_corner_radius_all(int(size.y / 2.0))
		sb.border_color = Color(0.1, 0.1, 0.1, 0.6)
		sb.set_border_width_all(2)
		draw_style_box(sb, r)
		var knob := Vector2(size.x - size.y / 2.0 if on else size.y / 2.0, size.y / 2.0)
		draw_circle(knob, size.y / 2.0 - 5.0, Color(0.96, 0.94, 0.88))
		var text := "ON" if on else "OFF"
		var width := UiKit.BOLD_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
		var left := 8.0 if on else size.y
		var right := size.x - size.y if on else size.x - 8.0
		draw_string(UiKit.BOLD_FONT, Vector2((left + right - width) / 2.0, size.y * 0.66), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(1, 1, 1, 0.9))

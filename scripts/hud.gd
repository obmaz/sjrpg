class_name Hud
extends CanvasLayer
## HUD: 체력/자원 바, 경험치, 물약, 토스트, 메뉴, 사망 화면, 터치 조작.

var game: Node
var _bars: Control
var _toast: Label
var _toast_time := 0.0
var _menu: Control
var _death: Control
var controls: TouchControls


func _ready() -> void:
	layer = 10
	_bars = Control.new()
	_bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.draw.connect(_draw_bars)
	add_child(_bars)

	controls = TouchControls.new()
	controls.game = game
	add_child(controls)

	var menu_button := UiKit.button("메뉴", 18)
	menu_button.custom_minimum_size = Vector2(72, 48)
	menu_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_button.offset_left = -88
	menu_button.offset_right = -16
	menu_button.offset_top = 16
	menu_button.offset_bottom = 64
	menu_button.pressed.connect(toggle_menu)
	add_child(menu_button)

	_toast = UiKit.label("", 26, UiKit.GOLD, true)
	_toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.offset_top = 150
	_toast.offset_bottom = 190
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)

	_build_menu()
	_build_death()


func _build_menu() -> void:
	_menu = ColorRect.new()
	_menu.color = Color(0, 0, 0, 0.55)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.visible = false
	_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_menu)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title := UiKit.label("일시 정지", 32, UiKit.GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var info := UiKit.label("", 20)
	info.name = "Info"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)
	var help := UiKit.label("이동: WASD/방향키 · 공격: J/스페이스\n기술: K · 물약: Q · 메뉴: Esc", 17, Color(0.8, 0.9, 0.85))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(help)
	var resume := UiKit.button("계속하기")
	resume.pressed.connect(toggle_menu)
	box.add_child(resume)
	var quit := UiKit.button("저장 후 타이틀로")
	quit.pressed.connect(func():
		get_tree().paused = false
		game.quit_to_title())
	box.add_child(quit)


func _build_death() -> void:
	_death = ColorRect.new()
	_death.color = Color(0.25, 0, 0, 0.45)
	_death.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_death.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death.visible = false
	add_child(_death)
	var l := UiKit.label("쓰러졌습니다…\n안식처에서 다시 일어납니다", 34, Color(1, 0.85, 0.8), true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_death.add_child(l)


func toggle_menu() -> void:
	_menu.visible = not _menu.visible
	get_tree().paused = _menu.visible
	if _menu.visible:
		var info: Label = _menu.find_child("Info", true, false)
		info.text = "%s Lv.%d · 처치 %d · 물약 %d" % [GameState.class_info()["name"], GameState.level, GameState.kills, GameState.potions]


func show_death() -> void:
	_death.visible = true


func hide_death() -> void:
	_death.visible = false


func toast(text: String) -> void:
	_toast.text = text
	_toast_time = 2.4


func _process(delta: float) -> void:
	_toast_time = maxf(0.0, _toast_time - delta)
	_toast.modulate.a = clampf(_toast_time / 0.5, 0.0, 1.0)
	_bars.queue_redraw()


func _bar(at: Vector2, size: Vector2, ratio: float, color: Color, text: String) -> void:
	_bars.draw_rect(Rect2(at - Vector2(2, 2), size + Vector2(4, 4)), Color(0, 0, 0, 0.6))
	_bars.draw_rect(Rect2(at, size), Color(0.12, 0.12, 0.12, 0.8))
	_bars.draw_rect(Rect2(at, Vector2(size.x * clampf(ratio, 0, 1), size.y)), color)
	_bars.draw_rect(Rect2(at, Vector2(size.x * clampf(ratio, 0, 1), size.y * 0.35)), Color(1, 1, 1, 0.18))
	var font := UiKit.BOLD_FONT
	_bars.draw_string_outline(font, at + Vector2(8, size.y - 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.9))
	_bars.draw_string(font, at + Vector2(8, size.y - 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


func _draw_bars() -> void:
	var p: Player = game.player
	if p == null:
		return
	var info := GameState.class_info()
	var font := UiKit.BOLD_FONT
	var origin := Vector2(18, 18)
	_bars.draw_string_outline(font, origin + Vector2(0, 20), "%s  Lv.%d" % [info["name"], GameState.level], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color(0, 0, 0, 0.9))
	_bars.draw_string(font, origin + Vector2(0, 20), "%s  Lv.%d" % [info["name"], GameState.level], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiKit.GOLD)
	_bar(origin + Vector2(0, 32), Vector2(300, 24), p.hp / p.max_hp, Color(0.8, 0.16, 0.16), "체력 %d / %d" % [roundi(p.hp), roundi(p.max_hp)])
	var res_color := Color(0.22, 0.45, 0.95) if p.is_mage else Color(0.95, 0.55, 0.12)
	_bar(origin + Vector2(0, 62), Vector2(300, 20), p.resource / p.resource_max, res_color, "%s %d" % [info["resource"], roundi(p.resource)])
	_bar(origin + Vector2(0, 88), Vector2(300, 14), float(GameState.xp) / GameState.xp_to_next(), Color(0.55, 0.85, 0.4), "")
	var xp_text := "경험치 %d / %d   처치 %d" % [GameState.xp, GameState.xp_to_next(), GameState.kills]
	_bars.draw_string_outline(font, origin + Vector2(0, 126), xp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.9))
	_bars.draw_string(font, origin + Vector2(0, 126), xp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.95, 0.85))

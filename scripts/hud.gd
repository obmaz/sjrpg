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
var minimap: Minimap
var _area: Control
var _area_name := ""
var _tree_panel: SkillTreePanel


func _ready() -> void:
	layer = 10
	_add_vignette()
	_bars = Control.new()
	_bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.draw.connect(_draw_bars)
	add_child(_bars)

	controls = TouchControls.new()
	controls.game = game
	add_child(controls)

	minimap = Minimap.new()
	minimap.game = game
	add_child(minimap)
	_area = Control.new()
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw_area_label)
	add_child(_area)

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
	var help := UiKit.label("이동: WASD/방향키 · 주 슬롯: J/스페이스\n보조 슬롯: 1–4 (K=1) · 구르기: Shift/L\n물약: Q · 스킬 트리: T · 메뉴: Esc", 17, Color(0.8, 0.9, 0.85))
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


func open_skill_tree() -> void:
	if _tree_panel or _menu.visible:
		return
	controls.release_all()
	get_tree().paused = true
	_tree_panel = SkillTreePanel.new()
	_tree_panel.closed.connect(close_skill_tree)
	add_child(_tree_panel)


func close_skill_tree() -> void:
	if _tree_panel == null:
		return
	_tree_panel.queue_free()
	_tree_panel = null
	get_tree().paused = false
	game.player.refresh_stats()
	GameState.save_game()


func show_death() -> void:
	_death.visible = true


func hide_death() -> void:
	_death.visible = false


func toast(text: String) -> void:
	_toast.text = text
	_toast_time = 2.4


func _process(delta: float) -> void:
	_update_layout()
	_toast_time = maxf(0.0, _toast_time - delta)
	_toast.modulate.a = clampf(_toast_time / 0.5, 0.0, 1.0)
	_bars.queue_redraw()


func unit() -> float:
	var size := get_viewport().get_visible_rect().size
	return clampf(minf(size.x, size.y) / 720.0, 0.75, 2.0)


func _update_layout() -> void:
	var u := unit()
	var size := get_viewport().get_visible_rect().size
	minimap.radius = 66.0 * u
	minimap.size = Vector2.ONE * (minimap.radius * 2.0 + 8.0)
	minimap.position = Vector2(size.x - 16.0 * u - minimap.size.x, 14.0 * u)
	_area.position = Vector2.ZERO
	_area.size = size
	_toast.offset_top = 112.0 * u
	_toast.offset_bottom = 152.0 * u
	var name := "숲 마을" if game.in_town(game.player.position) else "숲 가장자리"
	if game.village.river_band.grow(60.0).has_point(Iso.unproject(game.player.position)):
		name = "강가"
	if name != _area_name:
		_area_name = name
	_area.queue_redraw()


func _draw_area_label() -> void:
	var u := unit()
	var size := get_viewport().get_visible_rect().size
	var w := 150.0 * u
	var h := 34.0 * u
	var rect := Rect2(Vector2(size.x - 16.0 * u - 66.0 * u - w / 2.0, 14.0 * u + 66.0 * u * 2.0 + 14.0 * u), Vector2(w, h))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.05, 0.78)
	style.border_color = Color(0.55, 0.42, 0.24, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(7 * u))
	_area.draw_style_box(style, rect)
	HudArt.text_outlined(_area, "제1장 · " + _area_name, rect.position + Vector2(0, h * 0.68), w, int(16 * u), Color(0.95, 0.92, 0.82))


func _add_vignette() -> void:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv * vec2(1.0, 1.05));
	float v = smoothstep(0.30, 0.82, d);
	COLOR = vec4(0.015, 0.03, 0.025, v * 0.62);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	add_child(rect)


func _draw_bars() -> void:
	var p: Player = game.player
	if p == null:
		return
	var u := unit()
	var info := GameState.class_info()
	var center := Vector2(66.0, 64.0) * u
	var pr := 48.0 * u
	# Bars sit behind the portrait and run to the right with a slanted end.
	var x0 := center.x + 18.0 * u
	var w := 372.0 * u
	var hp_rect := Rect2(x0, 12.0 * u, w, 36.0 * u)
	var mp_rect := Rect2(x0, 48.0 * u, w - 6.0 * u, 28.0 * u)
	var xp_rect := Rect2(x0, 76.0 * u, w - 12.0 * u, 15.0 * u)
	HudArt.slanted_bar(_bars, hp_rect, p.hp / p.max_hp, Color(0.95, 0.30, 0.25), Color(0.66, 0.1, 0.1), Color(0.2, 0.05, 0.06), 12.0 * u)
	HudArt.text_outlined(_bars, "%s / %s" % [HudArt.fmt(p.hp), HudArt.fmt(p.max_hp)], hp_rect.position + Vector2(0, hp_rect.size.y * 0.72), hp_rect.size.x, int(21 * u))
	var is_mage: bool = p.is_mage
	var top := Color(0.35, 0.65, 1.0) if is_mage else Color(1.0, 0.7, 0.3)
	var bottom := Color(0.1, 0.32, 0.78) if is_mage else Color(0.8, 0.38, 0.08)
	var back := Color(0.04, 0.08, 0.2) if is_mage else Color(0.2, 0.1, 0.04)
	HudArt.slanted_bar(_bars, mp_rect, p.resource / p.resource_max, top, bottom, back, 10.0 * u)
	HudArt.text_outlined(_bars, "%s %s" % [info["resource"], HudArt.fmt(p.resource)], mp_rect.position + Vector2(0, mp_rect.size.y * 0.72), mp_rect.size.x, int(18 * u))
	var xp_ratio := float(GameState.xp) / GameState.xp_to_next()
	HudArt.slanted_bar(_bars, xp_rect, xp_ratio, Color(0.95, 0.8, 0.4), Color(0.72, 0.55, 0.22), Color(0.1, 0.09, 0.06, 0.9), 8.0 * u)
	HudArt.text_outlined(_bars, "EXP %d%%" % roundi(xp_ratio * 100.0), xp_rect.position + Vector2(0, xp_rect.size.y * 0.8), xp_rect.size.x, int(12 * u), Color(0.95, 0.9, 0.78))
	# Portrait with a bronze rim.
	_bars.draw_circle(center, pr + 4.0 * u, Color(0.06, 0.05, 0.04))
	var tex := HudArt.portrait(GameState.hero_class)
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var crop := Rect2(0.0, 0.0, 1.0, 1.0) if GameState.hero_class == "warrior" else Rect2(0.2, 0.1, 0.62, 0.55)
	for i in 40:
		var a := TAU * i / 40.0
		pts.append(center + Vector2.from_angle(a) * pr)
		uvs.append(crop.position + crop.size * (Vector2(0.5, 0.5) + Vector2.from_angle(a) * 0.5))
	_bars.draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, tex)
	_bars.draw_arc(center, pr + 2.0 * u, 0, TAU, 48, HudArt.BRONZE, 4.0 * u, true)
	_bars.draw_arc(center, pr - 1.0, 0, TAU, 48, Color(0.1, 0.07, 0.04, 0.8), 2.0, true)
	# Level badge.
	var badge := center + Vector2(-pr * 0.72, pr * 0.72)
	_bars.draw_circle(badge, 14.0 * u, Color(0.1, 0.08, 0.05))
	_bars.draw_arc(badge, 14.0 * u, 0, TAU, 28, HudArt.BRONZE, 2.5 * u, true)
	HudArt.text_outlined(_bars, str(GameState.level), badge + Vector2(-14.0 * u, 6.0 * u), 28.0 * u, int(15 * u), Color(1, 0.95, 0.75))

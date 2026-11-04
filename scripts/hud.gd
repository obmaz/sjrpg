class_name Hud
extends CanvasLayer
## HUD: 체력/자원 바, 경험치, 물약, 토스트, 메뉴, 사망 화면, 터치 조작.

var game: Node
var _bars: Control
var _toast: Label
var _toast_time := 0.0
var _death: Control
var controls: TouchControls
var minimap: Minimap
var _area: Control
var _area_name := ""
var _panel: PanelFrame
var _save_warning: Button


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
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)

	_build_death()
	_save_warning = UiKit.button("", 18)
	_save_warning.process_mode = Node.PROCESS_MODE_ALWAYS
	_save_warning.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_save_warning.offset_top = 165
	_save_warning.offset_bottom = 239
	_save_warning.pressed.connect(func(): GameState.save_game())
	add_child(_save_warning)
	GameState.save_finished.connect(_on_save_finished)
	_on_save_finished(GameState.save_error.is_empty(), GameState.save_error)


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


func panel_open() -> bool:
	return _panel != null


func _open(panel: PanelFrame) -> void:
	if _panel != null:
		panel.queue_free()
		return
	controls.release_all()
	get_tree().paused = true
	_panel = panel
	panel.closed.connect(close_panel)
	add_child(panel)


func close_panel() -> void:
	if _panel == null:
		return
	_panel.queue_free()
	_panel = null
	get_tree().paused = false
	game.player.refresh_stats()
	if GameState.claim_boss_heart():
		game.toast("파수꾼의 심장을 받았습니다")
	GameState.save_game()


func open_skill_tree() -> void:
	_open(SkillTreePanel.new())


func open_bag(shop := false) -> void:
	_open(BagPanel.new().setup(shop, game))


## Talk to / use the town NPC with this name.
func interact(npc: String) -> void:
	match npc:
		"숲의 파수꾼":
			_open(BossPanel.new().setup(game))
		"상인":
			open_bag(true)
		"대장장이":
			open_smith()
		"탈것 상인":
			game.toast("탈것은 아직 준비 중입니다")
		_:
			_open(DialoguePanel.new().setup(game, npc))


func open_victory() -> void:
	var panel := VictoryPanel.new()
	panel.restart_requested.connect(func():
		close_panel()
		game.restart_requested.emit())
	_open(panel)


func open_memory(i: int) -> void:
	_open(MemoryPanel.new().setup(i))


func open_journal() -> void:
	_open(JournalPanel.new())


func open_smith() -> void:
	_open(BlacksmithPanel.new().setup(game))


func open_settings() -> void:
	var panel := SettingsPanel.new().setup(game)
	panel.title_requested.connect(func():
		close_panel()
		game.quit_to_title())
	panel.restart_requested.connect(func():
		close_panel()
		game.restart_requested.emit())
	_open(panel)


## Esc: close whatever is open, otherwise open the settings.
func toggle_menu() -> void:
	if _panel != null:
		close_panel()
	else:
		open_settings()


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
	var center := Vector2(62.0, 62.0) * u
	var pr := 46.0 * u
	var x0 := center.x + 16.0 * u
	var w := 372.0 * u
	var hp_rect := Rect2(x0, 12.0 * u, w, 36.0 * u)
	var mp_rect := Rect2(x0, 48.0 * u, w - 6.0 * u, 28.0 * u)
	var xp_rect := Rect2(x0, 77.0 * u, w - 12.0 * u, 14.0 * u)
	# Dark metal plate that runs from the portrait under all three bars
	# (원본 _HeroStatusChrome: fill 0xe51c1b1c, rim 0xff6e6355).
	var slant := 16.0 * u
	var plate := PackedVector2Array([
		Vector2(center.x + pr * 0.0, 6.0 * u), Vector2(x0 + w + 4.0 * u, 6.0 * u),
		Vector2(x0 + w + 4.0 * u - slant, 100.0 * u), Vector2(center.x, 100.0 * u)])
	_bars.draw_colored_polygon(PackedVector2Array([plate[0] + Vector2(0, 2), plate[1] + Vector2(0, 2), plate[2] + Vector2(0, 2), plate[3] + Vector2(0, 2)]), Color(0, 0, 0, 0.67))
	_bars.draw_colored_polygon(plate, Color(0.11, 0.106, 0.11, 0.9))
	_bars.draw_polyline(PackedVector2Array([plate[0], plate[1], plate[2], plate[3], plate[0]]), Color(0.43, 0.39, 0.33), 1.4 * u, true)
	HudArt.slanted_bar(_bars, hp_rect, p.hp / p.max_hp, Color(0.95, 0.30, 0.25), Color(0.66, 0.1, 0.1), Color(0.2, 0.05, 0.06), 12.0 * u)
	HudArt.text_outlined(_bars, "%s / %s" % [HudArt.stat(p.hp), HudArt.stat(p.max_hp)], hp_rect.position + Vector2(0, hp_rect.size.y * 0.72), hp_rect.size.x, int(20 * u))
	var is_mage: bool = p.is_mage
	var top := Color(0.35, 0.65, 1.0) if is_mage else Color(1.0, 0.7, 0.3)
	var bottom := Color(0.1, 0.32, 0.78) if is_mage else Color(0.8, 0.38, 0.08)
	var back := Color(0.04, 0.08, 0.2) if is_mage else Color(0.2, 0.1, 0.04)
	HudArt.slanted_bar(_bars, mp_rect, p.resource / p.resource_max, top, bottom, back, 10.0 * u)
	HudArt.text_outlined(_bars, "%s %s / %s" % [info["resource"], HudArt.res(p.resource), HudArt.res(p.resource_max)], mp_rect.position + Vector2(0, mp_rect.size.y * 0.72), mp_rect.size.x, int(17 * u))
	var xp_ratio := float(GameState.xp) / GameState.xp_to_next()
	HudArt.slanted_bar(_bars, xp_rect, xp_ratio, Color(0.95, 0.8, 0.4), Color(0.72, 0.55, 0.22), Color(0.32, 0.27, 0.22), 8.0 * u)
	HudArt.text_outlined(_bars, "EXP %d%%" % floori(xp_ratio * 100.0), xp_rect.position + Vector2(0, xp_rect.size.y * 0.82), xp_rect.size.x, int(11 * u), Color(0.93, 0.89, 0.8))
	# 지금 할 일 (원본 mainObjective) under the plate.
	var obj := Quests.main_objective()
	HudArt.text_outlined(_bars, obj, Vector2(x0 - 6.0 * u, 124.0 * u), w + 20.0 * u, int(17 * u), Color(1, 0.93, 0.7), HORIZONTAL_ALIGNMENT_LEFT)
	# Portrait: 원본 art — 전사 hero-helmeted-portrait, 마법사 class-selection 얼굴.
	_bars.draw_circle(center + Vector2(0, 2.0), pr + 1.0, Color(0, 0, 0, 0.67))
	_bars.draw_circle(center, pr, Color(0.09, 0.114, 0.125))
	var tex := HudArt.portrait(GameState.hero_class)
	var uv_rect := HudArt.portrait_uv(GameState.hero_class)
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		pts.append(center + Vector2.from_angle(a) * pr)
		uvs.append(uv_rect.position + uv_rect.size * (Vector2(0.5, 0.5) + Vector2.from_angle(a) * 0.5))
	_bars.draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, tex)
	if p.hp / p.max_hp < 0.3:
		_bars.draw_circle(center, pr, Color(1.0, 0.165, 0.14, 0.12 + 0.1 * sin(Time.get_ticks_msec() / 150.0)))
	_bars.draw_arc(center, pr, 0, TAU, 56, Color(0.29, 0.263, 0.216), 3.0 * u, true)
	_bars.draw_arc(center, pr, -PI + 0.2, -PI + 2.9, 24, Color(0.765, 0.675, 0.51), 1.4 * u, true)
	_bars.draw_arc(center, pr - 3.0 * u, 0, TAU, 56, Color(0.61, 0.53, 0.38), 0.8 * u, true)
	# Crests (top / bottom) and rivets (left / right).
	for sy in [-1.0, 1.0]:
		var c := center + Vector2(0, sy * pr)
		var crest := PackedVector2Array([c + Vector2(0, -4) * u, c + Vector2(5, 0) * u, c + Vector2(0, 5) * u, c + Vector2(-5, 0) * u])
		_bars.draw_colored_polygon(crest, Color(0.16, 0.17, 0.17))
		_bars.draw_polyline(crest + PackedVector2Array([crest[0]]), Color(0.64, 0.56, 0.41), 1.0 * u)
	for sx in [-1.0, 1.0]:
		_bars.draw_circle(center + Vector2(sx * (pr - 2.0 * u), 0), 1.4 * u, Color(0.68, 0.59, 0.44))
	# Level badge (원본 level-badge.webp, 26px at the top-left corner).
	var badge := HudArt.level_badge()
	var bs := 30.0 * u
	var bpos := Vector2(2.0 * u, 2.0 * u)
	_bars.draw_texture_rect(badge, Rect2(bpos, Vector2(bs, bs)), false)
	HudArt.text_outlined(_bars, str(GameState.level), bpos + Vector2(0, bs * 0.7), bs, int(13 * u), Color(0.93, 0.89, 0.8))


func _on_save_finished(success: bool, message: String) -> void:
	_save_warning.visible = not success
	_save_warning.text = "저장 실패 · 눌러서 재시도"
	_save_warning.tooltip_text = message

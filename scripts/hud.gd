class_name Hud
extends CanvasLayer
## HUD: 체력/자원 바, 경험치, 물약, 토스트, 메뉴, 사망 화면, 터치 조작.

var game: Node
var _bars: Control
var _toast: Label
var _toast_plaque: PanelContainer
var _toast_queue: Array[Dictionary] = []
var _toast_clock := 0.0
var _toast_time := 0.0
const TOAST_PENDING_LIMIT := 4
const TOAST_MAX_AGE := 8.0
var _death: Control
var controls: TouchControls
var minimap: Minimap
var _area: Control
var _area_name := ""
var _panel: PanelFrame
var _save_warning: Button
var _status: Label
var _last_hp := -1.0
var _last_max_hp := -1.0
var _health_trail := 1.0
var _trail_hold := 0.0
var _hurt_feedback := 0.0
var _heal_feedback := 0.0


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
	minimap.open_requested.connect(open_map)
	add_child(minimap)
	_area = Control.new()
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw_area_label)
	add_child(_area)

	_toast_plaque = PanelContainer.new()
	_toast_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var toast_skin := UiKit.panel_style(Color("181914"), Color("8d7952"), 6)
	toast_skin.content_margin_left = 22
	toast_skin.content_margin_right = 22
	toast_skin.content_margin_top = 12
	toast_skin.content_margin_bottom = 12
	_toast_plaque.add_theme_stylebox_override("panel", toast_skin)
	_toast_plaque.hide()
	add_child(_toast_plaque)
	_toast = UiKit.label("", 20, Color("eee3c7"))
	_toast.add_theme_font_override("font", HudArt.FONT)
	_toast.add_theme_constant_override("outline_size", 0)
	_toast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toast.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.max_lines_visible = 3
	_toast.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_plaque.add_child(_toast)

	_status = UiKit.label("", 16, Color("d6e5e4"))
	_status.add_theme_font_override("font", HudArt.FONT)
	_status.add_theme_constant_override("outline_size", 1)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status)
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
		panel.free()
		return
	controls.release_all()
	_toast_plaque.hide()
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
	_toast_plaque.visible = _toast_time > 0.0
	game.player.refresh_stats()
	if GameState.claim_boss_heart():
		game.toast("파수꾼의 심장을 받았습니다")
	GameState.save_game()


func open_skill_tree() -> void:
	_open(SkillTreePanel.new())


func pause_for_background() -> void:
	# Keep an existing bag, map or settings panel exactly where the player left it.
	if panel_open():
		return
	var panel := PanelFrame.new()
	_open(panel)
	panel.set_compact()
	panel.set_header("잠시 멈췄습니다", "화면을 떠나 모험을 일시정지했습니다")
	panel.body.add_child(PanelFrame.wrap_label("준비되면 모험을 계속하세요. 전투와 남은 시간은 멈춰 있습니다.", 22))
	panel.add_footer("모험 계속하기", close_panel, true)


func open_bag(shop := false) -> void:
	_open(BagPanel.new().setup(shop, game))


## Talk to / use the town NPC with this name.
func interact(npc: String) -> void:
	match npc:
		"바람 동굴", "동굴 출구":
			_open(DungeonPanel.new().setup(game))
		"안식처":
			open_map(true)
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


## Confirmations wait briefly instead of replacing a reward/level-up delivered in the same frame.
func toast(text: String) -> void:
	text = text.strip_edges()
	if text.is_empty() or (_toast_time > 0.0 and _toast.text == text):
		return
	for pending in _toast_queue:
		if pending["text"] == text:
			return
	if _toast_queue.size() >= TOAST_PENDING_LIMIT:
		_toast_queue.pop_front()
	_toast_queue.append({"text": text, "expires": _toast_clock + TOAST_MAX_AGE})
	if _toast_time <= 0.0:
		_advance_toast()


func _advance_toast() -> void:
	while not _toast_queue.is_empty():
		var next: Dictionary = _toast_queue.pop_front()
		if float(next["expires"]) <= _toast_clock:
			continue
		_toast.text = next["text"]
		_toast_time = clampf(2.0 + _toast.text.length() * 0.025, 2.4, 3.6)
		_toast_plaque.visible = not panel_open()
		return
	_toast.text = ""
	_toast_plaque.hide()


func _tick_toasts(delta: float) -> void:
	_toast_clock += delta
	_toast_time = maxf(0.0, _toast_time - delta)
	_toast_queue = _toast_queue.filter(func(pending): return float(pending["expires"]) > _toast_clock)
	if _toast_time <= 0.0:
		_advance_toast()
	_toast_plaque.modulate.a = 1.0 if Prefs.reduce_motion else clampf(_toast_time / 0.35, 0.0, 1.0)


## Compact confirmation plaque below status/minimap labels and above the combat controls.
func toast_rect() -> Rect2:
	var u := unit()
	var margins := PanelFrame.safe_margins(get_viewport())
	var available := get_viewport().get_visible_rect().size - Vector2(margins.x + margins.z, margins.y + margins.w)
	var origin: Vector2 = status_geometry()["origin"]
	var width := minf(520.0 * u, available.x - 40.0 * u)
	var y := origin.y + (306.0 if _save_warning != null and _save_warning.visible else 194.0) * u
	var lines := clampi(_toast.get_line_count(), 1, 3)
	var height := clampf(lines * 25.0 * u + 24.0, 56.0 * u, 100.0 * u)
	return Rect2(Vector2(margins.x + (available.x - width) / 2.0, y), Vector2(width, height))


func _process(delta: float) -> void:
	_update_vital_feedback(delta)
	_tick_toasts(delta)
	_update_layout()
	_bars.queue_redraw()


## Vital feedback follows health changes, never a blocked hit or a button press.
func _update_vital_feedback(delta: float) -> void:
	var player: Player = game.player
	var ratio := player.hp / maxf(1.0, player.max_hp)
	_hurt_feedback = maxf(0.0, _hurt_feedback - delta)
	_heal_feedback = maxf(0.0, _heal_feedback - delta)
	if not is_equal_approx(_last_max_hp, player.max_hp):
		_health_trail = ratio
		_trail_hold = 0.0
	elif player.hp < _last_hp - 0.001:
		_health_trail = maxf(_health_trail, _last_hp / player.max_hp)
		_trail_hold = 0.16
		_hurt_feedback = 0.28
	elif player.hp > _last_hp + player.max_hp * 0.01:
		_heal_feedback = 0.35
	_trail_hold = maxf(0.0, _trail_hold - delta)
	if Prefs.reduce_motion or ratio > _health_trail:
		_health_trail = ratio
	elif _trail_hold <= 0.0:
		_health_trail = move_toward(_health_trail, ratio, delta * 0.9)
	_last_hp = player.hp
	_last_max_hp = player.max_hp


func unit() -> float:
	var size := get_viewport().get_visible_rect().size
	return clampf(minf(size.x, size.y) / 720.0, 0.75, 2.0)


## Geometry measured from the approved 714×1280 composition. Safe margins are
## added before scaling, so the header keeps its proportions through rotation.
func status_geometry() -> Dictionary:
	var u := unit()
	var m := PanelFrame.safe_margins(get_viewport())
	var available := get_viewport().get_visible_rect().size - Vector2(m.x + m.z, m.y + m.w)
	var origin := Vector2(m.x, m.y + available.y * 0.056)
	var width := minf(374.0 * u, available.x - 250.0 * u)
	var x := origin.x + 76.0 * u
	return {
		"origin": origin,
		"portrait": origin + Vector2(57.0, 53.0) * u,
		"radius": 50.0 * u,
		"hp": Rect2(Vector2(x, origin.y + 7.0 * u), Vector2(width, 29.0 * u)),
		"mp": Rect2(Vector2(x, origin.y + 40.0 * u), Vector2(width - 7.0 * u, 21.0 * u)),
		"xp": Rect2(Vector2(x, origin.y + 69.0 * u), Vector2(width - 15.0 * u, 12.0 * u)),
		"map": Rect2(Vector2(m.x + available.x - 144.0 * u, origin.y + 2.0 * u), Vector2.ONE * 136.0 * u),
	}


func _update_layout() -> void:
	var u := unit()
	var geometry := status_geometry()
	var origin: Vector2 = geometry["origin"]
	var map_rect: Rect2 = geometry["map"]
	minimap.radius = 64.0 * u
	minimap.size = map_rect.size
	minimap.position = map_rect.position
	_area.position = Vector2.ZERO
	_area.size = get_viewport().get_visible_rect().size
	_status.position = origin + Vector2(114.0, 137.0) * u
	_status.size = Vector2(340.0, 23.0) * u
	var statuses: Array[String] = []
	var names := {"shout": "방어 함성", "orders": "전투 지시", "armor": "원소 갑옷", "enchant": "화염 강화", "storm": "뇌우", "command": "전투 명령", "guard": "집중 방어", "berserk": "광폭", "sprint": "질주"}
	for key in game.player.buffs:
		statuses.append("%s %d초" % [names.get(key, key), ceili(game.player.buffs[key]["time"])])
	_status.text = " · ".join(statuses.slice(0, 3))
	var toast_font_size := roundi(20.0 * u)
	# Theme overrides invalidate shaping even when set to the same value.
	# Updating every frame can continually defer wrapped-label text rendering.
	if _toast.get_theme_font_size("font_size") != toast_font_size:
		_toast.add_theme_font_size_override("font_size", toast_font_size)
	var confirmation := toast_rect()
	_toast.custom_minimum_size.x = maxf(1.0, confirmation.size.x - 44.0)
	_toast_plaque.custom_minimum_size = Vector2.ZERO
	_toast_plaque.position = confirmation.position
	_toast_plaque.size = confirmation.size
	_save_warning.offset_top = origin.y + 220.0 * u
	_save_warning.offset_bottom = origin.y + 290.0 * u
	var name := "숲 마을" if game.in_town(game.player.position) else "숲 가장자리"
	if not game.dungeon.active and game.village.river_band.grow(60.0).has_point(Iso.unproject(game.player.position)):
		name = "강가"
	if game.dungeon.active:
		name = "바람 동굴"
	if name != _area_name:
		_area_name = name
	_area.queue_redraw()


func _draw_area_label() -> void:
	var u := unit()
	var map_rect: Rect2 = status_geometry()["map"]
	var rect := Rect2(map_rect.get_center().x - 60.0 * u, map_rect.end.y + 6.0 * u, 120.0 * u, 34.0 * u)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.075, 0.065, 0.86)
	style.border_color = Color(0.48, 0.42, 0.30, 0.88)
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(7 * u))
	_area.draw_style_box(style, rect)
	_area.draw_line(rect.position + Vector2(8, 1) * u, Vector2(rect.end.x - 8 * u, rect.position.y + u), Color(0.75, 0.66, 0.47, 0.14), u, true)
	HudArt.text_outlined(_area, _area_name, rect.position + Vector2(0, rect.size.y * 0.69), rect.size.x, int(18 * u), Color("d9cfb3"))


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


## Local fading scrims keep objective/buff text readable over bright paving without a solid HUD block.
func _draw_hint_backdrop(rect: Rect2) -> void:
	var clear := Color(0, 0, 0, 0)
	var shade := Color(0.02, 0.018, 0.014, 0.56)
	var fade := minf(16.0 * unit(), rect.size.x * 0.12)
	var middle := Rect2(rect.position + Vector2(fade, 0), rect.size - Vector2(fade * 2.0, 0))
	_bars.draw_rect(middle, shade)
	for left in [true, false]:
		var x := rect.position.x if left else rect.end.x - fade
		var points := PackedVector2Array([Vector2(x, rect.position.y), Vector2(x + fade, rect.position.y), Vector2(x + fade, rect.end.y), Vector2(x, rect.end.y)])
		_bars.draw_polygon(points, PackedColorArray([clear, shade, shade, clear]) if left else PackedColorArray([shade, clear, clear, shade]))


func _draw_bars() -> void:
	var p: Player = game.player
	if p == null:
		return
	var u := unit()
	var geometry := status_geometry()
	var origin: Vector2 = geometry["origin"]
	var center: Vector2 = geometry["portrait"]
	var pr: float = geometry["radius"]
	var hp_rect: Rect2 = geometry["hp"]
	var mp_rect: Rect2 = geometry["mp"]
	var xp_rect: Rect2 = geometry["xp"]
	# One joined gunmetal ribbon, with the portrait rim covering its left join.
	var plate := PackedVector2Array([
		origin + Vector2(55, 1) * u, Vector2(hp_rect.end.x + 5.0 * u, origin.y + u),
		Vector2(xp_rect.end.x + 5.0 * u, origin.y + 88.0 * u), origin + Vector2(55, 88) * u])
	_bars.draw_colored_polygon(plate, Color(0.055, 0.045, 0.045, 0.94))
	_bars.draw_polyline(PackedVector2Array([plate[0], plate[1], plate[2], plate[3], plate[0]]), Color("746b5e"), 1.3 * u, true)
	_bars.draw_line(plate[0] + Vector2(0, 2) * u, plate[1] + Vector2(-2, 2) * u, Color(0.7, 0.62, 0.48, 0.2), 0.8 * u, true)
	_bars.draw_line(plate[3] + Vector2(0, 3) * u, plate[2] + Vector2(0, 3) * u, Color(0, 0, 0, 0.45), 2.0 * u, true)
	HudArt.slanted_bar(_bars, hp_rect, p.hp / p.max_hp, Color("b43134"), Color("751719"), Color("432022"), 8.0 * u)
	var actual_ratio := p.hp / p.max_hp
	if _health_trail > actual_ratio + 0.001 and not Prefs.reduce_motion:
		var start := hp_rect.position.x + hp_rect.size.x * actual_ratio
		var end := minf(hp_rect.end.x - 8.0 * u, hp_rect.position.x + hp_rect.size.x * _health_trail)
		if end > start:
			_bars.draw_rect(Rect2(start, hp_rect.position.y + 2.0 * u, end - start, hp_rect.size.y - 4.0 * u), Color(0.84, 0.57, 0.32, 0.7))
	if _hurt_feedback > 0.0 or _heal_feedback > 0.0:
		var color := Color(1.0, 0.47, 0.34, _hurt_feedback / 0.28) if _hurt_feedback > 0.0 else Color(0.62, 0.91, 0.7, _heal_feedback / 0.35)
		var frame := HudArt._bar_poly(hp_rect, 1.0, 8.0 * u)
		_bars.draw_polyline(frame + PackedVector2Array([frame[0]]), color, 1.8 * u, true)

	# Labels start beyond the full portrait, not at the fluid's hidden left edge.
	var label_left := center.x + pr + 8.0 * u
	var label_width := hp_rect.end.x - label_left - 11.0 * u
	HudArt.text_outlined(_bars, "%s / %s" % [HudArt.stat(p.hp), HudArt.stat(p.max_hp)], Vector2(label_left, hp_rect.position.y + 23.0 * u), label_width, int(23 * u), Color("f4f1eb"))
	var top := Color("61bfe5") if p.is_mage else Color("cd9c4a")
	var bottom := Color("245d86") if p.is_mage else Color("895120")
	var back := Color("142e40") if p.is_mage else Color("39291a")
	HudArt.slanted_bar(_bars, mp_rect, p.resource / p.resource_max, top, bottom, back, 6.0 * u)
	var info := GameState.class_info()
	HudArt.text_outlined(_bars, "%s %s" % [info["resource"], HudArt.res(p.resource)], Vector2(label_left, mp_rect.position.y + 16.0 * u), label_width - 5.0 * u, int(18 * u), Color("e7f4f7"))
	if p.is_mage:
		var shimmer := 0.65 if Prefs.reduce_motion else 0.55 + 0.1 * sin(Time.get_ticks_msec() / 800.0)
		for fraction in [0.17, 0.78]:
			if p.resource / p.resource_max < fraction:
				continue
			var at := mp_rect.position + Vector2(mp_rect.size.x * fraction, 7.0 * u)
			_bars.draw_line(at - Vector2(4, 0) * u, at + Vector2(4, 0) * u, Color(0.8, 0.96, 1.0, shimmer), 0.8 * u, true)
			_bars.draw_line(at - Vector2(0, 4) * u, at + Vector2(0, 4) * u, Color(0.8, 0.96, 1.0, shimmer * 0.7), 0.8 * u, true)
	var xp_ratio := float(GameState.xp) / GameState.xp_to_next()
	HudArt.slanted_bar(_bars, xp_rect, xp_ratio, Color("bfa361"), Color("8d733f"), Color("393530"), 4.0 * u)
	HudArt.text_outlined(_bars, "EXP %d%%" % floori(xp_ratio * 100.0), Vector2(label_left, xp_rect.position.y + 10.0 * u), label_width - 11.0 * u, int(11 * u), Color("d9d0b9"))
	# A quiet single line keeps progression discoverable without dominating the scene.
	var obj: String = game.dungeon.objective() if game.dungeon.active else Quests.main_objective()
	var hint_width := minf(hp_rect.size.x + 10.0 * u, HudArt.FONT.get_string_size(obj, HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * u)).x + 30.0 * u)
	_draw_hint_backdrop(Rect2(origin + Vector2(103, 105) * u, Vector2(hint_width, 27.0 * u)))
	if not _status.text.is_empty():
		_draw_hint_backdrop(Rect2(_status.position - Vector2(11, 1) * u, Vector2(_status.size.x + 12.0 * u, 27.0 * u)))
	HudArt.text_outlined(_bars, obj, origin + Vector2(114, 125) * u, hp_rect.size.x - 28.0 * u, int(16 * u), Color("d5c9a5"), HORIZONTAL_ALIGNMENT_LEFT)
	_bars.draw_circle(center + Vector2(0, 2.0) * u, pr + 3.0 * u, Color(0, 0, 0, 0.62))
	_bars.draw_circle(center, pr + 1.0 * u, Color("181c1d"))
	var tex := HudArt.portrait(GameState.hero_class)
	var uv_rect := HudArt.portrait_uv(GameState.hero_class)
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in 80:
		var direction := Vector2.from_angle(TAU * i / 80.0)
		pts.append(center + direction * (pr - 3.0 * u))
		uvs.append(uv_rect.position + uv_rect.size * (Vector2.ONE + direction) * 0.5)
	_bars.draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, tex)
	if p.hp / p.max_hp < 0.3:
		_bars.draw_circle(center, pr - 3.0 * u, Color(1.0, 0.165, 0.14, 0.14 if Prefs.reduce_motion else 0.10 + 0.06 * sin(Time.get_ticks_msec() / 180.0)))
	_bars.draw_arc(center, pr, 0, TAU, 80, Color("302d27"), 4.0 * u, true)
	_bars.draw_arc(center, pr, -PI + 0.2, -PI + 2.9, 36, Color("a28d66"), 1.1 * u, true)
	_bars.draw_arc(center, pr - 3.0 * u, 0, TAU, 80, Color("81714e"), 0.8 * u, true)
	_bars.draw_arc(center, pr + 2.0 * u, 0.2, PI - 0.2, 36, Color(0.48, 0.42, 0.31, 0.75), 0.8 * u, true)
	for sy in [-1.0, 1.0]:
		var crest_center := center + Vector2(0, sy * (pr + 1.0 * u))
		var crest := PackedVector2Array([crest_center + Vector2(0, -5) * u, crest_center + Vector2(5, 0) * u, crest_center + Vector2(0, 5) * u, crest_center + Vector2(-5, 0) * u])
		_bars.draw_colored_polygon(crest, Color("292b29"))
		_bars.draw_polyline(crest + PackedVector2Array([crest[0]]), Color("a08b66"), 0.9 * u, true)
	for sx in [-1.0, 1.0]:
		_bars.draw_circle(center + Vector2(sx * (pr - 1.0 * u), 0), 1.1 * u, Color("ac9872"))


func _on_save_finished(success: bool, message: String) -> void:
	_save_warning.visible = not success
	_save_warning.text = "저장 실패 · 눌러서 재시도"
	_save_warning.tooltip_text = message


func open_map(travel := false) -> void:
	var panel := MapPanel.new().setup(game)
	panel._tab = 1 if travel else 0
	_open(panel)

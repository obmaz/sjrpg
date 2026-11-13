class_name Hud
extends CanvasLayer
## HUD: 체력/자원 바, 경험치, 물약, 토스트, 메뉴, 사망 화면, 터치 조작.

var game: Node
var _bars: Control
var _mana_shimmer: Control
var _bars_paint_state: Array = []
var _area_paint_state: Array = []
var bars_redraw_requests := 0
var area_redraw_requests := 0
var _level_badge: Label
var _level_up: LevelUpBanner
var _toast: Label
var _toast_plaque: PanelContainer
var _toast_queue: Array[Dictionary] = []
var _toast_clock := 0.0
var _toast_time := 0.0
var _toast_owner: WeakRef
const TOAST_PENDING_LIMIT := 4
const TOAST_MAX_AGE := 8.0
var _death: Control
var reward_trail: RewardHudTrail
var controls: TouchControls
var minimap: Minimap
var _area: Control
var _area_name := ""
var _panel: PanelFrame
var _save_warning: Button
var _status: Label
var _fps: FpsCounter
var _last_hp := -1.0
var _last_max_hp := -1.0
var _health_trail := 1.0
var _trail_hold := 0.0
var _hurt_feedback := 0.0
## JUICE #8: a red edge vignette for one large loss of health (>= 15% of max health in one hit).
const HEAVY_HIT_RATIO := 0.15
const HEAVY_HIT_TIME := 0.22
const HEAVY_HIT_ALPHA := 0.5
var _heavy_hit := 0.0
var _heavy_hit_vignette: TextureRect
var _heal_feedback := 0.0
var _critical_warning: ColorRect
var _critical_clock := 0.0
const CRITICAL_HEALTH := 0.3


func _ready() -> void:
	add_to_group("gamepad_hud")
	layer = 10
	_add_vignette()
	_bars = Control.new()
	_bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.draw.connect(_draw_bars)
	add_child(_bars)
	_level_badge = UiKit.label("", 12, Color("f2ead5"))
	_level_badge.name = "LevelBadge"
	_level_badge.add_theme_font_override("font", HudArt.FONT)
	_level_badge.add_theme_constant_override("outline_size", 1)
	_level_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.add_child(_level_badge)
	_mana_shimmer = Control.new()
	_mana_shimmer.name = "ManaShimmer"
	_mana_shimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mana_shimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mana_shimmer.draw.connect(_draw_mana_shimmer)
	_bars.add_child(_mana_shimmer)

	controls = TouchControls.new()
	controls.game = game
	add_child(controls)
	reward_trail = RewardHudTrail.new()
	reward_trail.game = game
	add_child(reward_trail)

	minimap = Minimap.new()
	minimap.game = game
	minimap.open_requested.connect(open_map)
	add_child(minimap)
	_area = Control.new()
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw_area_label)
	add_child(_area)
	_fps = FpsCounter.new()
	_fps.visibility_changed.connect(_fit_fps)
	add_child(_fps)

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
	_status.clip_text = true
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
	_critical_warning = ColorRect.new()
	_critical_warning.name = "CriticalHealthWarning"
	_critical_warning.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_critical_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_critical_warning.hide()
	add_child(_critical_warning)
	_build_heavy_hit_vignette()
	get_viewport().size_changed.connect(_on_viewport_resized)


## 표시만 다시 배치한다. 일시정지 중 회전에도 물약/스킬/알림의 시계를 진행시키지 않는다.
func _on_viewport_resized() -> void:
	_update_layout()
	_refresh_bar_drawing()
	controls.refresh_layout()
	minimap.refresh_layout()


## Radial gradient: clear centre, red edges. A texture rather than a shader keeps the web build light.
func _build_heavy_hit_vignette() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.55, 1.0])
	gradient.colors = PackedColorArray([Color(0.85, 0.05, 0.03, 0.0), Color(0.85, 0.05, 0.03, 1.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	_heavy_hit_vignette = TextureRect.new()
	_heavy_hit_vignette.name = "HeavyHitVignette"
	_heavy_hit_vignette.texture = texture
	_heavy_hit_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_heavy_hit_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_heavy_hit_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_heavy_hit_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heavy_hit_vignette.hide()
	add_child(_heavy_hit_vignette)


func _update_heavy_hit_vignette() -> void:
	if _heavy_hit <= 0.0 or game.player.dead:
		_heavy_hit_vignette.hide()
		return
	# Reduced motion keeps the cue but at 40% strength, since it is a flash rather than information.
	var strength := HEAVY_HIT_ALPHA * (0.4 if Prefs.reduce_motion else 1.0)
	_heavy_hit_vignette.modulate.a = strength * clampf(_heavy_hit / HEAVY_HIT_TIME, 0.0, 1.0)
	_heavy_hit_vignette.show()


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


func _announcement_banner() -> LevelUpBanner:
	if _level_up == null:
		_level_up = LevelUpBanner.new()
		_level_up.name = "LevelUpBanner"
		add_child(_level_up)
	return _level_up


func show_level_up(level: int) -> void:
	var banner := _announcement_banner()
	banner.show_level(level)
	banner.visible = not panel_open()


func show_waypoint_discovery(place: String) -> void:
	var banner := _announcement_banner()
	banner.show_waypoint(place)
	banner.visible = not panel_open()


func panel_open() -> bool:
	return _panel != null


func _open(panel: PanelFrame) -> void:
	Gamepad.require_neutral()
	if _panel != null:
		panel.free()
		return
	controls.release_all()
	reward_trail.clear()
	_toast_plaque.hide()
	if _level_up != null:
		_level_up.hide()
	get_tree().paused = true
	_panel = panel
	panel.closed.connect(close_panel)
	add_child(panel)


func close_panel(save_progress := true) -> void:
	Gamepad.require_neutral()
	if _panel == null:
		return
	_panel.queue_free()
	_panel = null
	get_tree().paused = false
	_toast_plaque.visible = _toast_time > 0.0
	if _level_up != null:
		_level_up.visible = _level_up.active
	if save_progress:
		apply_panel_changes()
		GameState.save_game()


## Apply pending equipment/reward changes before a checked save or ordinary close.
func apply_panel_changes() -> void:
	game.player.refresh_stats()
	if GameState.claim_boss_heart(false):
		game.toast("파수꾼의 심장을 받았습니다")


func open_skill_tree() -> void:
	if ExpeditionState.active() and GameState.available_skill_choices() > 0:
		open_expedition()
	else:
		_open(RunBuildPanel.new() if ExpeditionState.active() else SkillTreePanel.new())


func open_expedition() -> void:
	_open(ExpeditionPanel.new().setup(game))


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
		"워프게이트":
			_open(WarpGatePanel.new().setup(game))
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
	panel.restart_requested.connect(func(): game.return_to_selection())
	_open(panel)


func open_memory(i: int) -> void:
	_open(MemoryPanel.new().setup(i))


func open_journal() -> void:
	_open(JournalPanel.new().setup(game))


func open_smith() -> void:
	_open(BlacksmithPanel.new().setup(game))


func open_settings() -> void:
	var panel := SettingsPanel.new().setup(game)
	panel.title_requested.connect(func(): game.quit_to_title())
	panel.restart_requested.connect(func(): game.return_to_selection())
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
func toast(text: String, lifetime: Node = null) -> void:
	text = text.strip_edges()
	if (
		text.is_empty()
		or (_toast_time > 0.0 and _toast.text == text and _toast_owner_alive(_toast_owner))
	):
		return
	_toast_queue = _toast_queue.filter(_toast_pending_valid)
	for pending in _toast_queue:
		if pending["text"] == text:
			return
	if _toast_queue.size() >= TOAST_PENDING_LIMIT:
		_toast_queue.pop_front()
	_toast_queue.append(
		{
			"text": text,
			"expires": _toast_clock + TOAST_MAX_AGE,
			"owner": weakref(lifetime) if lifetime != null else null
		}
	)
	if _toast_time <= 0.0:
		_advance_toast()


## 알림이 속한 방문/장면이 끝나면 현재 표시와 대기 항목을 함께 버린다.
static func _toast_owner_alive(owner: WeakRef) -> bool:
	if owner == null:
		return true
	var node := owner.get_ref() as Node
	return is_instance_valid(node) and not node.is_queued_for_deletion()


func _toast_pending_valid(pending: Dictionary) -> bool:
	var owner: WeakRef = pending.get("owner")
	return float(pending["expires"]) > _toast_clock and _toast_owner_alive(owner)


func _advance_toast() -> void:
	while not _toast_queue.is_empty():
		var next: Dictionary = _toast_queue.pop_front()
		if not _toast_pending_valid(next):
			continue
		_toast.text = next["text"]
		_toast_owner = next.get("owner")
		_toast_time = clampf(2.0 + _toast.text.length() * 0.025, 2.4, 3.6)
		_toast_plaque.visible = not panel_open()
		return
	_toast.text = ""
	_toast_owner = null
	_toast_plaque.hide()


func _tick_toasts(delta: float) -> void:
	_toast_clock += delta
	_toast_time = maxf(0.0, _toast_time - delta) if _toast_owner_alive(_toast_owner) else 0.0
	_toast_queue = _toast_queue.filter(_toast_pending_valid)
	if _toast_time <= 0.0:
		_advance_toast()
	_toast_plaque.modulate.a = 1.0 if Prefs.reduce_motion else clampf(_toast_time / 0.35, 0.0, 1.0)


## Wide screens have an empty top gap; other layouts retain the lower confirmation plaque.
func toast_rect() -> Rect2:
	var u := unit()
	var margins := PanelFrame.safe_margins(get_viewport())
	var view := get_viewport().get_visible_rect().size
	var available := view - Vector2(margins.x + margins.z, margins.y + margins.w)
	var geometry := status_geometry()
	var origin: Vector2 = geometry["origin"]
	var width := minf(520.0 * u, available.x - 40.0 * u)
	var save_warning := _save_warning != null and _save_warning.visible
	var y := origin.y + (306.0 if save_warning else 194.0) * u
	var lines := clampi(_toast.get_line_count(), 1, 3)
	var height := clampf(lines * 25.0 * u + 24.0, 56.0 * u, 100.0 * u)
	if view.x > view.y and not save_warning:
		var status_ink: Rect2 = geometry["paint_bounds"]
		var map_rect: Rect2 = geometry["map"]
		var map_ink := Minimap.painted_bounds(64.0 * u, map_rect.size)
		map_ink.position += map_rect.position
		var gap_left := status_ink.end.x + 20.0 * u
		var gap_right := map_ink.position.x - 20.0 * u
		if gap_right - gap_left >= 320.0 * u:
			width = minf(width, gap_right - gap_left)
			var top := margins.y + 16.0 * u
			return Rect2(Vector2((gap_left + gap_right - width) * 0.5, top), Vector2(width, height))
	return Rect2(Vector2(margins.x + (available.x - width) / 2.0, y), Vector2(width, height))


func _process(delta: float) -> void:
	_update_vital_feedback(delta)
	_update_critical_warning(delta)
	_update_heavy_hit_vignette()
	_tick_toasts(delta)
	_update_layout()
	_refresh_bar_drawing()


## Keep static canvas commands, including their GPU polygons, until painted data changes.
## The mana glints animate by modulation on a child instead of rebuilding the whole HUD.
func _refresh_bar_drawing() -> void:
	var p: Player = game.player
	var objective: String = game.dungeon.objective() if game.dungeon.active else Quests.main_objective()
	var state: Array = [get_viewport().get_visible_rect().size, PanelFrame.safe_margins(get_viewport()),
		p.hp, p.max_hp, p.resource, p.resource_max, p.is_mage,
		GameState.hero_class, GameState.level, GameState.xp, GameState.xp_to_next(),
		_health_trail if not Prefs.reduce_motion else p.hp / maxf(1.0, p.max_hp),
		_hurt_feedback, _heal_feedback, Prefs.reduce_motion, objective,
		_status.text, _status.position, _status.size]
	if state != _bars_paint_state:
		_bars_paint_state = state
		bars_redraw_requests += 1
		_bars.queue_redraw()
	_update_mana_shimmer()


func _update_mana_shimmer() -> void:
	_mana_shimmer.visible = game.player.is_mage
	_mana_shimmer.self_modulate.a = 0.65 if Prefs.reduce_motion else 0.55 + 0.1 * sin(Time.get_ticks_msec() / 800.0)


func _draw_mana_shimmer() -> void:
	var p: Player = game.player
	if not p.is_mage:
		return
	var geometry := status_geometry()
	var u: float = geometry["unit"]
	var mp_rect: Rect2 = geometry["mp"]
	var center: Vector2 = geometry["portrait"]
	var join_radius: float = geometry["join_radius"]
	var slope: float = geometry["slope"]
	for fraction in [0.17, 0.78]:
		if p.resource / p.resource_max < fraction:
			continue
		var at := HudArt.fill_point(mp_rect, fraction, 7.0 * u / mp_rect.size.y, mp_rect.size.y * slope, center, join_radius)
		_mana_shimmer.draw_line(at - Vector2(4, 0) * u, at + Vector2(4, 0) * u, Color(0.8, 0.96, 1.0), 0.8 * u, true)
		_mana_shimmer.draw_line(at - Vector2(0, 4) * u, at + Vector2(0, 4) * u, Color(0.8, 0.96, 1.0, 0.7), 0.8 * u, true)


## A slow, translucent full-screen warning leaves the scene and controls readable.
## Its game-time clock pauses with menus/background; reduced motion uses a steady tint.
func _update_critical_warning(delta: float) -> void:
	var player: Player = game.player
	var ratio := player.hp / maxf(1.0, player.max_hp)
	if player.dead or player.hp <= 0.0 or ratio >= CRITICAL_HEALTH:
		_critical_clock = 0.0
		_critical_warning.hide()
		return
	_critical_clock = fmod(_critical_clock + delta, 1.0 / 0.9)
	var severity := clampf((CRITICAL_HEALTH - ratio) / CRITICAL_HEALTH, 0.0, 1.0)
	var strength := 0.055 + severity * 0.025
	if not Prefs.reduce_motion:
		strength += (0.025 + severity * 0.04) * (0.5 + 0.5 * cos(_critical_clock * TAU * 0.9))
	_critical_warning.color = Color(0.82, 0.035, 0.02, strength)
	_critical_warning.show()


## Vital feedback follows health changes, never a blocked hit or a button press.
func _update_vital_feedback(delta: float) -> void:
	var player: Player = game.player
	var ratio := player.hp / maxf(1.0, player.max_hp)
	_hurt_feedback = maxf(0.0, _hurt_feedback - delta)
	_heavy_hit = maxf(0.0, _heavy_hit - delta)
	_heal_feedback = maxf(0.0, _heal_feedback - delta)
	if not is_equal_approx(_last_max_hp, player.max_hp):
		_health_trail = ratio
		_trail_hold = 0.0
	elif player.hp < _last_hp - 0.001:
		_health_trail = maxf(_health_trail, _last_hp / player.max_hp)
		_trail_hold = 0.16
		_hurt_feedback = 0.28
		if _last_hp - player.hp >= player.max_hp * HEAVY_HIT_RATIO:
			_heavy_hit = HEAVY_HIT_TIME
	elif player.hp > _last_hp + player.max_hp * 0.01:
		_heal_feedback = 0.35
	_trail_hold = maxf(0.0, _trail_hold - delta)
	if Prefs.reduce_motion or ratio > _health_trail:
		_health_trail = ratio
	elif _trail_hold <= 0.0:
		_health_trail = move_toward(_health_trail, ratio, delta * 0.9)
	_last_hp = player.hp
	_last_max_hp = player.max_hp


static func header_unit(view: Vector2, margins: Vector4) -> float:
	var available := view - Vector2(margins.x + margins.z, margins.y + margins.w)
	return clampf(minf(available.x, available.y) / 720.0, 0.75, 2.0)


func unit() -> float:
	return header_unit(get_viewport().get_visible_rect().size, PanelFrame.safe_margins(get_viewport()))


## Reference proportions are anchored to the safe top; tall phones must not push the HUD down.
func status_geometry() -> Dictionary:
	var view := get_viewport().get_visible_rect().size
	return header_geometry(view, PanelFrame.safe_margins(get_viewport()), TouchControls.mobile_layout(view))


static func header_geometry(view: Vector2, m: Vector4, mobile := false) -> Dictionary:
	var screen_unit := header_unit(view, m)
	var u := screen_unit * 0.902  # 10% larger than the previous 82% header; map/controls retain their scale.
	var available := view - Vector2(m.x + m.z, m.y + m.w)
	var top_gap := 6.0 if mobile or view.y > view.x else 16.0
	var safe_top := m.y + top_gap * screen_unit
	# The portrait crest extends five header units above its origin. Align painted
	# outlines at the safe top instead of pushing both groups down with screen height.
	var map_size := Vector2.ONE * 136.0 * screen_unit
	var map_ink := Minimap.painted_bounds(64.0 * screen_unit, map_size)
	var side_padding := 144.0 * screen_unit - map_ink.end.x
	# 실제로 그린 초상화 테두리와 미니맵 테두리의 안전 영역 여백을 맞춘다.
	var portrait_left := (57.0 - 50.0 - 4.5) * u
	var origin := Vector2(m.x + side_padding - portrait_left, safe_top + 5.0 * u)
	var center := origin + Vector2(57, 53) * u
	var radius := 50.0 * u
	var right := origin.x + minf(455.0 * u, available.x - 169.0 * screen_unit)
	var slope := 0.28
	var rows := {}
	for spec in [["hp", 7.0, 29.0], ["mp", 40.0, 21.0], ["xp", 69.0, 12.0]]:
		var top: float = spec[1]
		var height: float = spec[2]
		var left := origin.x + 76.0 * u
		var end := right - 5.0 * u - (top - 1.0) * u * slope
		rows[spec[0]] = Rect2(left, origin.y + top * u, end - left, height * u)
	var plate := HudArt.joined_ribbon(center, radius + 2.0 * u, origin.y + u, right, origin.y + 88.0 * u, slope, 1.5 * u)
	var label_left := center.x + radius + 8.0 * u
	var geometry := {
		"unit": u, "origin": origin, "portrait": center, "radius": radius,
		"plate": plate, "slope": slope, "join_radius": radius + 3.0 * u,
		"hp": rows["hp"], "mp": rows["mp"], "xp": rows["xp"],
		"map_unit": screen_unit,
		"map": Rect2(Vector2(m.x + available.x - 144.0 * screen_unit, safe_top - map_ink.position.y), map_size),
		"level_badge": Rect2(origin + Vector2(4, 0) * u, Vector2.ONE * 32.0 * u),
	}
	var badge_rect: Rect2 = geometry["level_badge"]
	geometry["level_label"] = badge_rect.grow(-4.0 * u)
	for key in ["hp", "mp", "xp"]:
		var rect: Rect2 = rows[key]
		var slant := rect.size.y * slope
		geometry[key + "_label"] = Rect2(label_left, rect.position.y, rect.end.x - slant - label_left - 5.0 * u, rect.size.y)
	var portrait_bounds := Rect2(center - Vector2(radius + 4.5 * u, radius + 8.0 * u), Vector2(2.0 * (radius + 4.5 * u), 2.0 * (radius + 8.0 * u)))
	geometry["portrait_bounds"] = portrait_bounds
	var plate_bounds := Rect2(plate[0], Vector2(right - plate[0].x, 92.0 * u)).grow(2.0 * u)
	geometry["paint_bounds"] = portrait_bounds.merge(plate_bounds).merge(badge_rect)
	return geometry


func _fit_fps() -> void:
	if is_instance_valid(_fps) and _fps.visible:
		_fps.fit(get_viewport().get_visible_rect().size, PanelFrame.safe_margins(get_viewport()), unit())


func _update_layout() -> void:
	var u := unit()
	_fit_fps()
	var geometry := status_geometry()
	var h: float = geometry["unit"]
	var origin: Vector2 = geometry["origin"]
	var level_rect: Rect2 = geometry["level_label"]
	_level_badge.text = str(GameState.level)
	_level_badge.position = level_rect.position
	_level_badge.size = level_rect.size
	var level_size := HudArt.fit_text_size(_level_badge.text, level_rect, roundi(16.0 * h))
	if _level_badge.get_theme_font_size("font_size") != level_size:
		_level_badge.add_theme_font_size_override("font_size", level_size)
	var map_rect: Rect2 = geometry["map"]
	minimap.radius = 64.0 * u
	minimap.size = map_rect.size
	minimap.position = map_rect.position
	_area.position = Vector2.ZERO
	_area.size = get_viewport().get_visible_rect().size
	_status.position = origin + Vector2(114.0, 137.0) * h
	var hp_bounds: Rect2 = geometry["hp"]
	_status.size = Vector2(minf(340.0 * h, hp_bounds.end.x - _status.position.x - 8.0 * h), 23.0 * h)
	var status_font_size := roundi(16.0 * h)
	if _status.get_theme_font_size("font_size") != status_font_size:
		_status.add_theme_font_size_override("font_size", status_font_size)
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
	var name := "숲 마을" if game.in_town(game.player.position) else ForestRegion.area_name(game.player.position)
	if not game.dungeon.active and game.village.river_band.grow(60.0).has_point(Iso.unproject(game.player.position)):
		name = "강가"
	if game.dungeon.active:
		name = "바람 동굴"
	var area_state: Array = [name, map_rect, u]
	if area_state != _area_paint_state:
		_area_paint_state = area_state
		_area_name = name
		area_redraw_requests += 1
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
	# Explicit refreshes from transitions/settings also update the retained child.
	_update_mana_shimmer()
	_mana_shimmer.queue_redraw()
	var geometry := status_geometry()
	var u: float = geometry["unit"]
	var origin: Vector2 = geometry["origin"]
	var center: Vector2 = geometry["portrait"]
	var pr: float = geometry["radius"]
	var hp_rect: Rect2 = geometry["hp"]
	var mp_rect: Rect2 = geometry["mp"]
	var xp_rect: Rect2 = geometry["xp"]
	# One joined gunmetal ribbon, with the portrait rim covering its left join.
	var plate: PackedVector2Array = geometry["plate"]
	var slope: float = geometry["slope"]
	var join_radius: float = geometry["join_radius"]
	_bars.draw_colored_polygon(plate, Color(0.055, 0.045, 0.045, 0.94))
	_bars.draw_polyline(plate + PackedVector2Array([plate[0]]), Color("746b5e"), 1.3 * u, true)
	_bars.draw_line(plate[0] + Vector2(0, 2) * u, plate[1] + Vector2(-2, 2) * u, Color(0.7, 0.62, 0.48, 0.2), 0.8 * u, true)
	_bars.draw_line(plate[3] + Vector2(0, 3) * u, plate[2] + Vector2(0, 3) * u, Color(0, 0, 0, 0.45), 2.0 * u, true)
	var actual_ratio := p.hp / maxf(1.0, p.max_hp)
	HudArt.slanted_bar(_bars, hp_rect, actual_ratio, Color("b43134"), Color("751719"), Color("432022"), hp_rect.size.y * slope, center, join_radius, _health_trail if not Prefs.reduce_motion else actual_ratio)
	if _hurt_feedback > 0.0 or _heal_feedback > 0.0:
		var color := Color(1.0, 0.47, 0.34, _hurt_feedback / 0.28) if _hurt_feedback > 0.0 else Color(0.62, 0.91, 0.7, _heal_feedback / 0.35)
		var frame := HudArt._bar_poly(hp_rect, 1.0, hp_rect.size.y * slope, center, join_radius)
		_bars.draw_polyline(HudArt.bar_outline(frame), color, 1.8 * u, true)

	# Number baselines use the actual font metrics, clear of the portrait and sloped edge.
	HudArt.text_in_rect(_bars, "%s / %s" % [HudArt.stat(p.hp), HudArt.stat(p.max_hp)], geometry["hp_label"], roundi(23 * u), Color("f4f1eb"))
	var top := Color("61bfe5") if p.is_mage else Color("cd9c4a")
	var bottom := Color("245d86") if p.is_mage else Color("895120")
	var back := Color("142e40") if p.is_mage else Color("39291a")
	HudArt.slanted_bar(_bars, mp_rect, p.resource / maxf(1.0, p.resource_max), top, bottom, back, mp_rect.size.y * slope, center, join_radius)
	var info := GameState.class_info()
	HudArt.text_in_rect(_bars, "%s %s" % [info["resource"], HudArt.res(p.resource)], geometry["mp_label"], roundi(18 * u), Color("e7f4f7"))
	var xp_ratio := float(GameState.xp) / GameState.xp_to_next()
	HudArt.slanted_bar(_bars, xp_rect, xp_ratio, Color("bfa361"), Color("8d733f"), Color("393530"), xp_rect.size.y * slope, center, join_radius)
	HudArt.text_in_rect(_bars, "EXP %d%%" % floori(xp_ratio * 100.0), geometry["xp_label"], roundi(11 * u), Color("d9d0b9"))
	# A quiet single line keeps progression discoverable without dominating the scene.
	var obj: String = game.dungeon.objective() if game.dungeon.active else Quests.main_objective()
	obj = HudArt.elide(obj, hp_rect.end.x - origin.x - 114.0 * u, roundi(16 * u))
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
	_bars.draw_arc(center, pr, 0, TAU, 80, Color("302d27"), 4.0 * u, true)
	_bars.draw_arc(center, pr, -PI + 0.2, -PI + 2.9, 36, UiToneArt.BRONZE, 1.1 * u, true)
	_bars.draw_arc(center, pr - 3.0 * u, 0, TAU, 80, UiToneArt.BRONZE.darkened(0.18), 0.8 * u, true)
	_bars.draw_arc(center, pr + 2.0 * u, 0.2, PI - 0.2, 36, Color(0.48, 0.42, 0.31, 0.75), 0.8 * u, true)
	for sy in [-1.0, 1.0]:
		var crest_center := center + Vector2(0, sy * (pr + 1.0 * u))
		var crest := PackedVector2Array([crest_center + Vector2(0, -5) * u, crest_center + Vector2(5, 0) * u, crest_center + Vector2(0, 5) * u, crest_center + Vector2(-5, 0) * u])
		_bars.draw_colored_polygon(crest, Color("292b29"))
		_bars.draw_polyline(crest + PackedVector2Array([crest[0]]), UiToneArt.BRONZE, 0.9 * u, true)
	for sx in [-1.0, 1.0]:
		_bars.draw_circle(center + Vector2(sx * (pr - 1.0 * u), 0), 1.1 * u, Color("ac9872"))
	_bars.draw_texture_rect(HudArt.level_badge(), geometry["level_badge"], false)


func _on_save_finished(success: bool, message: String) -> void:
	_save_warning.visible = not success
	_save_warning.text = "저장 실패 · 눌러서 재시도"
	_save_warning.tooltip_text = message


func open_map(travel := false) -> void:
	var panel := MapPanel.new().setup(game)
	panel._tab = 1 if travel else 0
	_open(panel)

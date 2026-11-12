class_name TouchControls
extends Control
## Reference-style controls: 마법진 조이스틱 (left), 주 슬롯 + 보조 슬롯 4 + 구르기 ring
## (right), 체력/마나 포션 above it and the bottom icon bar (가방 · 스킬 · 퀘스트 · 설정).
## Multi-touch plus clickable HUD buttons. Empty slots open the skill tree.

var game: Node
var _paint_state: Array = []
var _stick_paint_state: Array = []
var _overlay_paint_state: Array = []
var _hints_paint_state: Array = []
var _stick_layer: Control
var _overlay_layer: Control
var _hints_layer: Control
var redraw_requests := 0
var base_redraw_requests := 0
var stick_redraw_requests := 0
var overlay_redraw_requests := 0
var hints_redraw_requests := 0
var _stick_center := Vector2.ZERO
var _stick_knob := Vector2.ZERO
var _stick_index := -2  # -2 none, -1 mouse
var _held := {}  # touch index -> button name
var _buttons := {}  # name -> {center, radius}
var _unit := 1.0
var _near_name := ""
var last_drawn_gamepad_hints: Array[Dictionary] = []
var _feedback := {}
var _success_feedback := {}
var _denied_feedback := {}
var _cooldown_samples := {}
var _last_potions := Vector2i(-1, -1)
var _interaction_normal: StyleBox
var _interaction_pressed: StyleBox
static var _reference_buttons: Texture2D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_layer = _draw_layer("MovementStick", _draw_stick_layer, true)
	_overlay_layer = _draw_layer("ActionFeedback", _draw_overlay_layer)
	_hints_layer = _draw_layer("XboxHints", _draw_hints_layer)


## 화면 크기 변경용: 피드백·쿨다운을 진행시키지 않고 그림과 터치 범위를 함께 옮긴다.
func refresh_layout() -> void:
	_layout()
	_refresh_drawing()


func _draw_layer(layer_name: String, callback: Callable, behind := false) -> Control:
	var canvas := Control.new()
	canvas.name = layer_name
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.show_behind_parent = behind
	canvas.draw.connect(callback)
	add_child(canvas)
	return canvas


func stick_radius() -> float:
	return 90.0 * _unit


func _button(center: Vector2, radius: float, visual_radius := -1.0) -> Dictionary:
	return {"center": center, "radius": maxf(32.0, radius), "visual_radius": radius if visual_radius < 0.0 else visual_radius}


func slot_visual_radius(index: int) -> float:
	var radius: float = _buttons["slot%d" % index]["visual_radius"]
	return radius * 0.82 if str(GameState.slots[index]).is_empty() else radius


func css_scale() -> float:
	if OS.has_feature("web"):
		var width: Variant = JavaScriptBridge.eval("window.innerWidth", true)
		if (width is float or width is int) and float(width) > 0.0:
			return get_viewport().get_visible_rect().size.x / float(width)
	if DisplayServer.get_name() == "headless":
		return 1.0
	return get_viewport().get_visible_rect().size.x / maxf(1.0, float(get_window().size.x))


static func mobile_layout(view: Vector2) -> bool:
	return view.y > view.x or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()


func _layout() -> void:
	var margins := PanelFrame.safe_margins(get_viewport())
	var safe_origin := Vector2(margins.x, margins.y)
	var size := get_viewport().get_visible_rect().size - Vector2(margins.x + margins.z, margins.y + margins.w)
	_unit = clampf(minf(size.x, size.y) / 720.0, 0.75, 2.0)
	var u := _unit
	var portrait := size.y > size.x
	# 모바일에서는 전투 부채꼴과 조이스틱을 아래로 옮겨 중앙 시야를 넓힌다.
	# 메뉴 위의 터치 여백과 안전 영역은 유지하고 그림/입력이 같은 좌표를 쓴다.
	var combat_bottom := 144.0 if mobile_layout(size) else 178.0
	var main := Vector2(size.x - 156.0 * u, size.y * 0.790) if portrait else Vector2(size.x - 156.0 * u, size.y - combat_bottom * u)
	var stick_left := 128.0 if portrait else 136.0 if mobile_layout(size) else 112.0
	var stick_anchor := Vector2(stick_left * u, size.y * 0.780 if portrait else size.y - combat_bottom * u)
	_buttons = {"slot0": _button(main, 67.0 * u)}
	var offsets := [Vector2(-119, 0), Vector2(-85, -84), Vector2(-4, -121), Vector2(79, -84)]
	var radii := [44.0, 42.0, 42.0, 42.0]
	for i in 4:
		_buttons["slot%d" % (i + 1)] = _button(main + offsets[i] * u, radii[i] * u, radii[i] * 0.92 * u)
	_buttons["roll"] = _button(main + Vector2(114, 0) * u, 32.0 * u, 31.0 * u)
	# Keep visible art compact while giving both vials independent 44-CSS-pixel targets.
	var potion_touch := maxf(32.0 * u, 22.0 * css_scale())
	var potion_gap := maxf(77.0 * u, potion_touch * 2.0 + 8.0 * u)
	var potion_y := main.y - maxf(198.0 * u, 163.0 * u + potion_touch + 12.0 * u)
	var potion_right := maxf(41.0 * u, potion_touch + 8.0 * u)
	var potion_visual := maxf(30.0 * u, 20.0 * css_scale())
	_buttons["potion_hp"] = _button(Vector2(size.x - potion_right - potion_gap, potion_y), potion_touch, potion_visual)
	_buttons["potion_mp"] = _button(Vector2(size.x - potion_right, potion_y), potion_touch, potion_visual)
	var bar_y := size.y * 0.902 if portrait else size.y - 44.0 * u
	var names := ["bar_bag", "bar_skills", "bar_quests", "bar_gear"]
	var menu_visual := maxf((34.1 if portrait else 31.0) * u, 20.0 * css_scale())
	var menu_touch := maxf((35.0 if portrait else 32.0) * u, 22.0 * css_scale())
	var menu_gap := maxf(79.0 * u, menu_touch * 2.0 + 8.0 * u)
	bar_y = minf(bar_y, size.y - menu_touch - 8.0 * u)
	for i in 4:
		_buttons[names[i]] = _button(Vector2(size.x / 2.0 + (i - 1.5) * menu_gap, bar_y), menu_touch, menu_visual)
	var npc: String = game.near_npc()
	_near_name = npc
	if npc != "" and npc != "탈것 상인":
		var text_width := HudArt.FONT.get_string_size(interaction_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, interaction_font_size()).x
		var folded := portrait and size.x / size.y > 0.8
		var half := Vector2(maxf((90.0 if folded else 94.0) * u, text_width * 0.5 + 20.0 * u), maxf(32.0, 38.0 * u))
		half.y = maxf(half.y, 22.0 * css_scale())
		var rise := maxf(78.0 * u, half.y + menu_touch + 10.0 * u)
		var stick := stick_anchor
		if _stick_index != -2:
			stick = _stick_center - safe_origin
		var center := _clear_interaction_center(Vector2(size.x / 2.0, bar_y - rise), half, stick, u, size)
		var interaction := _button(center, 32.0 * u)
		interaction["half_size"] = half
		_buttons["near_shop"] = interaction
	for button in _buttons.values():
		button["center"] += safe_origin
	if _stick_index == -2:
		_stick_center = stick_anchor
		_stick_center += safe_origin
		_stick_knob = _stick_center


func _hit_button(pos: Vector2) -> String:
	var best := ""
	var best_d := INF
	for name in _buttons:
		var b: Dictionary = _buttons[name]
		var d := pos.distance_to(b["center"])
		var inside := false
		if b.has("half_size"):
			var half: Vector2 = b["half_size"]
			inside = Rect2(b["center"] - half, half * 2.0).has_point(pos)
		else:
			inside = d <= float(b["radius"])
		if inside and d < best_d:
			best = name
			best_d = d
	return best


func _press(index: int, pos: Vector2) -> bool:
	var button := _hit_button(pos)
	var player: Player = game.player
	if player.dead:
		return true
	if button != "":
		_feedback[button] = 0.16
	if button.begins_with("slot"):
		var slot := int(button.substr(4))
		_held[index] = button
		player.held_slots[slot] = true
		var id: String = GameState.slots[slot]
		var insufficient := id != "" and player.resource < SkillDefs.cost(GameState.skill(id), GameState.effective_rank(id))
		var cast := player.cast_slot(slot)
		if not cast and insufficient:
			_denied_feedback[button] = 0.32
		return true
	match button:
		"roll":
			player.try_roll()
			return true
		"potion_hp":
			if GameState.potions <= 0:
				_denied_feedback[button] = 0.32
			player.use_potion()
			return true
		"potion_mp":
			if GameState.mana_potions <= 0:
				_denied_feedback[button] = 0.32
			player.use_mana_potion()
			return true
		"bar_skills":
			game.hud.open_skill_tree()
			return true
		"bar_gear":
			game.hud.open_settings()
			return true
		"bar_bag":
			game.hud.open_bag(false)
			return true
		"near_shop":
			# A map transition or movement can invalidate the last painted button.
			# Match the keyboard interaction by resolving the live target at press time.
			var nearby: String = game.near_npc()
			if nearby != "" and nearby != "탈것 상인":
				game.hud.interact(nearby)
			return true
		"bar_quests":
			game.hud.open_journal()
			return true
	if game.hud.minimap.get_global_rect().has_point(pos):
		game.hud.open_map()
		return true
	# Desktop world clicks belong to primary attack; only fingers move the virtual stick.
	if index >= 0 and pos.x < get_viewport().get_visible_rect().size.x * 0.5 and _stick_index == -2:
		_stick_index = index
		_stick_center = pos
		_stick_knob = pos
		return true
	return false


## Called after GUI handling, so clicking a panel or HUD action cannot also attack.
func hold_mouse_primary() -> void:
	if game.player.dead:
		return
	_feedback["slot0"] = 0.16
	_held[-1] = "slot0"
	game.player.held_slots[0] = true
	game.player.cast_slot(0)


func _release(index: int) -> void:
	if index == -1:
		game.player.clear_pointer_aim()
	if _held.has(index):
		var slot_name := str(_held[index])
		_held.erase(index)
		game.player.held_slots[int(slot_name.substr(4))] = _held.values().has(slot_name)
	if index == _stick_index:
		_stick_index = -2
		game.player.move_input = Vector2.ZERO
		_layout()


func _drag(index: int, pos: Vector2) -> void:
	if index != _stick_index:
		return
	var d := pos - _stick_center
	var r := stick_radius()
	if d.length() > r:
		d = d.normalized() * r
	_stick_knob = _stick_center + d
	game.player.move_input = d / r


func release_all() -> void:
	game.player.clear_pointer_aim()
	game.player.action_buffer.clear()
	_feedback.clear()
	game.player.clear_move_target()
	for index in _held.keys():
		_release(index)
	if _stick_index != -2:
		_release(_stick_index)


func _input(event: InputEvent) -> void:
	if get_tree().paused or not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _press(event.index, event.position):
				get_viewport().set_input_as_handled()
		else:
			_release(event.index)
	elif event is InputEventScreenDrag:
		_drag(event.index, event.position)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _press(-1, event.position):
				get_viewport().set_input_as_handled()
		else:
			_release(-1)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		_drag(-1, event.position)


func _process(delta: float) -> void:
	for timers in [_feedback, _success_feedback, _denied_feedback]:
		for key in timers.keys():
			timers[key] -= delta
			if timers[key] <= 0.0:
				timers.erase(key)
	_update_action_feedback()
	_layout()
	_refresh_drawing()


## Each retained canvas owns a different update frequency. Holding a cooling spell
## no longer recreates static socket, potion, menu and joystick polygons every frame.
func _refresh_drawing() -> void:
	var player: Player = game.player
	var pressed: Array[String] = []
	var held_names := _held.values()
	for name: String in _buttons:
		if held_names.has(name) or float(_feedback.get(name, 0.0)) > 0.0:
			pressed.append(name)
	var base_state: Array = [_unit, _buttons, _near_name, pressed,
		GameState.potions, GameState.mana_potions, GameState.skill_points,
		Gamepad.using_gamepad, css_scale()]
	var overlay_state: Array = [_unit, _buttons, _success_feedback.duplicate(),
		_denied_feedback.duplicate(), Prefs.reduce_motion]
	for slot in GameState.slots.size():
		var id: String = GameState.slots[slot]
		var affordable := id == "" or player.resource >= SkillDefs.cost(GameState.skill(id), GameState.effective_rank(id))
		base_state.append([id, affordable])
		overlay_state.append([id, player.slot_cooldown_ratio(slot), slot_cooldown_remaining(slot)])
	var stick_state: Array = [_unit, _stick_center, _stick_knob, _stick_index != -2, Gamepad.using_gamepad]
	var hints_state: Array = [_unit, _buttons, Gamepad.using_gamepad, css_scale()]
	var changed := false
	if base_state != _paint_state:
		_paint_state = base_state
		base_redraw_requests += 1
		queue_redraw()
		changed = true
	if stick_state != _stick_paint_state:
		_stick_paint_state = stick_state
		stick_redraw_requests += 1
		_stick_layer.queue_redraw()
		changed = true
	if overlay_state != _overlay_paint_state:
		_overlay_paint_state = overlay_state
		overlay_redraw_requests += 1
		_overlay_layer.queue_redraw()
		changed = true
	if hints_state != _hints_paint_state:
		_hints_paint_state = hints_state
		hints_redraw_requests += 1
		_hints_layer.queue_redraw()
		changed = true
	_stick_layer.visible = not Gamepad.using_gamepad
	if changed:
		redraw_requests += 1


func _draw_stick_layer() -> void:
	if not Gamepad.using_gamepad:
		_draw_joystick(_stick_layer)


func _draw_overlay_layer() -> void:
	for name: String in _buttons:
		var button: Dictionary = _buttons[name]
		var center: Vector2 = button["center"]
		var radius: float = button["visual_radius"]
		if name.begins_with("slot"):
			var slot := int(name.substr(4))
			if str(GameState.slots[slot]).is_empty():
				continue
			_draw_cooldown(center, radius, game.player.slot_cooldown_ratio(slot), slot_cooldown_remaining(slot), slot == 0, _overlay_layer)
		_draw_action_feedback(name, center, radius, _overlay_layer)


func _draw_hints_layer() -> void:
	_draw_gamepad_hints(_hints_layer)


## Observe real state changes, including keyboard casts and potions; pressing alone is not success.
func _update_action_feedback() -> void:
	var player: Player = game.player
	for slot in GameState.slots.size():
		var id: String = GameState.slots[slot]
		var key := "slot%d" % slot
		var ready := player.slot_cooldown_ratio(slot)
		if _cooldown_samples.has(key):
			var previous: Array = _cooldown_samples[key]
			if previous[0] != id:
				_success_feedback.erase(key)
				_denied_feedback.erase(key)
			elif float(previous[1]) < 1.0 and ready >= 1.0:
				_success_feedback[key] = 0.38
		_cooldown_samples[key] = [id, ready]
	var counts := Vector2i(GameState.potions, GameState.mana_potions)
	if _last_potions.x >= 0:
		if counts.x < _last_potions.x:
			_success_feedback["potion_hp"] = 0.45
		if counts.y < _last_potions.y:
			_success_feedback["potion_mp"] = 0.45
	_last_potions = counts


func _draw_action_feedback(name: String, center: Vector2, radius: float, canvas: CanvasItem = null) -> void:
	var target: CanvasItem = self if canvas == null else canvas
	var denied: float = _denied_feedback.get(name, 0.0)
	var success: float = _success_feedback.get(name, 0.0)
	if denied > 0.0:
		target.draw_arc(center, radius + 2.0 * _unit, 0, TAU, 64, Color(0.95, 0.33, 0.22, denied / 0.32), 2.0 * _unit, true)
	elif success > 0.0:
		var life := 0.45 if name.begins_with("potion") else 0.38
		var progress := 1.0 - success / life
		var expansion := 0.0 if Prefs.reduce_motion else progress * 8.0 * _unit
		var color := Color(0.93, 0.58, 0.45) if name == "potion_hp" else Color(0.65, 0.87, 1.0)
		target.draw_arc(center, radius + 2.0 * _unit + expansion, 0, TAU, 64, Color(color, success / life * 0.8), 1.5 * _unit, true)


## Read the equipped skill every frame, so moving a cooling spell cannot bypass
## its timer or leave another slot displaying the old spell's remaining time.
func slot_cooldown_remaining(index: int) -> float:
	var id: String = GameState.slots[index]
	return maxf(0.0, float(game.player.cooldowns.get(id, 0.0))) if id != "" else 0.0


static func cooldown_text(remaining: float) -> String:
	if remaining <= 0.0:
		return ""
	# Never say zero while the authoritative timer still rejects the cast.
	return "%.1f" % (ceilf(remaining * 10.0) / 10.0) if remaining < 1.0 else str(ceili(remaining))


func _draw_cooldown(center: Vector2, radius: float, ready: float, remaining: float, primary: bool, canvas: CanvasItem = null) -> void:
	var target: CanvasItem = self if canvas == null else canvas
	if remaining <= 0.0:
		return
	var u := _unit
	var inner := radius - 3.0 * u
	# A dim base keeps the countdown readable on bright fire/lightning icons. The
	# darker remaining sector recedes clockwise; the thin metal bezel stays clear.
	target.draw_circle(center, inner, Color(0.015, 0.02, 0.03, 0.28))
	if ready <= 0.001:
		target.draw_circle(center, inner, Color(0.005, 0.01, 0.02, 0.52))
	elif ready < 0.999:
		var sector := PackedVector2Array([center])
		var segments := maxi(2, ceili((1.0 - ready) * 64.0))
		for i in segments + 1:
			var angle := -PI / 2.0 + TAU * (ready + (1.0 - ready) * float(i) / segments)
			sector.append(center + Vector2.from_angle(angle) * inner)
		target.draw_colored_polygon(sector, Color(0.005, 0.01, 0.02, 0.52))
	if ready > 0.001:
		target.draw_arc(center, radius - u, -PI / 2.0, -PI / 2.0 + TAU * ready, 64, Color(0.9, 0.96, 1.0, 0.95), 2.0 * u, true)
	var font_size := int((32.0 if primary else 26.0) * u)
	HudArt.text_outlined(target, cooldown_text(remaining), center + Vector2(-inner, 4.0 * u), inner * 2.0, font_size, Color(0.97, 0.96, 0.9))
	HudArt.text_outlined(target, "초", center + Vector2(-inner, (20.0 if primary else 18.0) * u), inner * 2.0, int(12.0 * u), Color(0.78, 0.83, 0.88))


# ───────── drawing ─────────

func _draw_joystick(canvas: CanvasItem = null) -> void:
	var target: CanvasItem = self if canvas == null else canvas
	var u := _unit
	var c := _stick_center
	var r := stick_radius()
	var active := _stick_index != -2
	var bronze := Color(0.62, 0.57, 0.42, 0.72 if active else 0.44)
	target.draw_circle(c, r + 2.0 * u, Color(0.0, 0.0, 0.0, 0.12))
	target.draw_circle(c, r, Color(0.025, 0.028, 0.023, 0.27 if active else 0.12))
	target.draw_arc(c, r, 0, TAU, 96, bronze, 1.5 * u, true)
	target.draw_arc(c, r - 4.0 * u, 0, TAU, 96, Color(bronze, 0.4), 1.0 * u, true)
	target.draw_arc(c, r - 14.0 * u, 0, TAU, 72, Color(bronze, 0.42), 1.1 * u, true)
	target.draw_arc(c, r * 0.54, 0, TAU, 64, Color(bronze, 0.28), 1.0 * u, true)
	# Fine etched triangles and ticks stay still, like the translucent seal in the reference.
	for rotation in [0.0, PI]:
		var seal := PackedVector2Array()
		for i in 4:
			seal.append(c + Vector2.from_angle(rotation - PI / 2.0 + i * TAU / 3.0) * r * 0.77)
		target.draw_polyline(seal, Color(bronze, 0.32), 1.0 * u, true)
	for i in 16:
		var direction := Vector2.from_angle(TAU * i / 16.0)
		target.draw_line(c + direction * r * 0.79, c + direction * r * 0.84, Color(bronze, 0.42), 1.0 * u, true)
	for i in 4:
		var direction := Vector2.from_angle(i * PI / 2.0)
		var tip := c + direction * (r - 8.0 * u)
		var base := c + direction * (r - 19.0 * u)
		var side := direction.orthogonal() * 5.0 * u
		target.draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), Color(0.68, 0.63, 0.46, 0.48))
	var kr := 30.5 * u
	target.draw_circle(_stick_knob, kr + 2.0 * u, Color(0, 0, 0, 0.22))
	target.draw_circle(_stick_knob, kr, Color(0.1, 0.092, 0.067, 0.7 if active else 0.42))
	target.draw_arc(_stick_knob, kr, 0, TAU, 64, Color(0.62, 0.56, 0.4, 0.72), 1.1 * u, true)
	target.draw_arc(_stick_knob, kr - 4.0 * u, 0, TAU, 56, Color(0.62, 0.56, 0.4, 0.25), 0.8 * u, true)
	target.draw_arc(_stick_knob, kr - 7.0 * u, PI * 1.12, PI * 1.88, 24, Color(0.8, 0.75, 0.57, 0.2), 0.8 * u, true)


func _draw_skill_bezel(center: Vector2, radius: float, pressed: bool) -> void:
	var u := _unit
	PresentationArt.draw_ui(self, "active", center, radius + 3.0 * u, Color.WHITE if pressed else Color(0.9, 0.94, 0.98))
	if pressed:
		draw_arc(center, radius + 2.0 * u, 0, TAU, 96, Color(0.68, 0.88, 1.0, 0.4), 1.2 * u, true)


func _draw_empty_socket(center: Vector2, radius: float) -> void:
	var u := _unit
	draw_circle(center, radius, Color(0.035, 0.039, 0.044, 0.56))
	PresentationArt.draw_ui(self, "empty", center, radius + u, Color(0.8, 0.79, 0.74, 0.72))
	var etching := Color(0.61, 0.58, 0.45, 0.32)
	draw_arc(center, radius * 0.3, 0, TAU, 32, etching, 0.8 * u, true)
	for i in 4:
		var direction := Vector2.from_angle(PI / 4.0 + PI / 2.0 * i)
		var tip := center + direction * radius * 0.47
		var base := center + direction * radius * 0.35
		var side := direction.orthogonal() * radius * 0.08
		draw_polyline(PackedVector2Array([base - side, tip, base + side]), etching, 0.8 * u, true)


func _draw_reference_button(index: int, center: Vector2, radius: float, tint := Color.WHITE) -> void:
	if _reference_buttons == null:
		_reference_buttons = load("res://assets/art/hud/reference-buttons.webp")
	var source := Rect2(float(index) * 256.0, 0, 256, 256)
	draw_texture_rect_region(_reference_buttons, Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), source, tint)


func interaction_text() -> String:
	return ("LT · " if Gamepad.using_gamepad else "") + {"워프게이트": "워프 이동", "바람 동굴": "동굴 탐험", "동굴 출구": "동굴 나가기", "안식처": "안식처", "숲의 파수꾼": "도전하기", "상인": "상점", "대장장이": "대장간", "촌장": "대화", "보급원 미라": "대화"}.get(_near_name, "대화")


## Shared type and plaque metrics for every contextual action, independent of world zoom.
func interaction_font_size() -> int:
	return roundi(maxf(22.0 * _unit, 18.0 * css_scale()))


func interaction_visual_rect(center: Vector2, half: Vector2) -> Rect2:
	var text_width := HudArt.FONT.get_string_size(interaction_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, interaction_font_size()).x
	var size := Vector2(minf(half.x * 2.0, maxf(184.0 * _unit, text_width + 32.0 * _unit)), minf(half.y * 2.0, maxf(56.0 * _unit, 44.0 * css_scale())))
	return Rect2(center - size * 0.5, size)


## Reuse the potion family's measured type/contrast, mirrored to the book's upper-right.
static func skill_points_geometry(center: Vector2, radius: float, points: int, scale: float, hit_radius: float) -> Dictionary:
	var geometry := PotionArt.count_geometry(center, radius, points, scale, hit_radius)
	var rect: Rect2 = geometry["rect"]
	rect.position.y = center.y * 2.0 - rect.end.y
	geometry["rect"] = rect
	return geometry


func _draw_skill_points(center: Vector2, radius: float, hit_radius: float) -> void:
	var geometry := skill_points_geometry(center, radius, GameState.skill_points, css_scale(), hit_radius)
	var rect: Rect2 = geometry["rect"]
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(UiToneArt.CHARCOAL, 0.96)
	skin.border_color = Color(UiToneArt.BRONZE, 0.7)
	skin.set_border_width_all(1)
	skin.set_corner_radius_all(3)
	draw_style_box(skin, rect)
	HudArt.text_in_rect(self, str(geometry["text"]), rect.grow(-radius / 30.0), int(geometry["font_size"]), UiToneArt.IVORY)


func _draw_menu(name: String, center: Vector2, radius: float, pressed: bool) -> void:
	var u := _unit
	var draw_radius := radius - (0.7 * u if pressed else 0.0)
	var tint := Color(0.86, 0.84, 0.8) if pressed else Color.WHITE
	draw_circle(center + Vector2(0, 0.5 * u), radius + 0.2 * u, Color(0, 0, 0, 0.3))
	match name:
		"bar_bag":
			MobileMenuArt.draw(self, "bag", center, draw_radius, tint)
		"bar_quests":
			MobileMenuArt.draw(self, "quests", center, draw_radius, tint)
		"bar_gear":
			MobileMenuArt.draw(self, "settings", center, draw_radius, tint)
		"bar_skills":
			MobileMenuArt.draw(self, "skills", center, draw_radius, tint)
	# The painted atlas owns its single bevel; avoid adding a second etched rim.


func _draw_interaction(center: Vector2, half: Vector2, pressed: bool) -> void:
	var rect := interaction_visual_rect(center, half)
	# Keep skins alive between frames: their gradient textures are submitted by RID.
	# A temporary StyleBox would free those resources before the canvas renders.
	if _interaction_normal == null:
		_interaction_normal = UiKit.panel_style(Color(0.065, 0.06, 0.048, 0.72), Color(0.51, 0.44, 0.29, 0.7), 21)
		_interaction_pressed = UiKit.panel_style(Color(0.13, 0.105, 0.075, 0.92), Color(0.62, 0.53, 0.36, 0.9), 21)
	draw_style_box(_interaction_pressed if pressed else _interaction_normal, rect)
	HudArt.text_in_rect(self, interaction_text(), rect.grow(-5.0 * _unit), interaction_font_size(), Color(0.89, 0.85, 0.73))


func _draw() -> void:
	var player: Player = game.player
	if player == null:
		return
	var u := _unit
	# Explicit redraws from paused transitions also refresh the retained children.
	_stick_layer.visible = not Gamepad.using_gamepad
	_stick_layer.queue_redraw()
	_overlay_layer.queue_redraw()
	_hints_layer.queue_redraw()
	var held_names := _held.values()
	for name in _buttons:
		var b: Dictionary = _buttons[name]
		var c: Vector2 = b["center"]
		var r: float = b["visual_radius"]
		var pressed: bool = held_names.has(name) or float(_feedback.get(name, 0.0)) > 0.0
		if name.begins_with("slot"):
			var slot := int(name.substr(4))
			var id: String = GameState.slots[slot]
			if id == "":
				_draw_empty_socket(c, slot_visual_radius(slot))
				continue
			draw_circle(c, r + 3.0 * u, Color(0.0, 0.0, 0.0, 0.38))
			draw_circle(c, r, Color(0.025, 0.028, 0.04, 0.98))
			var skill := GameState.skill(id)
			var affordable := player.resource >= SkillDefs.cost(skill, GameState.effective_rank(id))
			var inner := r - 3.0 * u
			SkillIcons.draw_round(self, id, c, inner, Color.WHITE if affordable else Color(0.42, 0.42, 0.5))
			_draw_skill_bezel(c, r, pressed)
		elif name == "roll":
			HudArt.round_plaque(self, "dodge", c, r, Color(0.82, 0.81, 0.75, 1.0 if pressed else 0.88))
		elif name == "potion_hp":
			PotionArt.draw(self, c, r, false, GameState.potions, pressed, float(b["radius"]))
		elif name == "potion_mp":
			PotionArt.draw(self, c, r, true, GameState.mana_potions, pressed, float(b["radius"]))
		elif name == "near_shop":
			_draw_interaction(c, b["half_size"], pressed)
		elif name.begins_with("bar_"):
			_draw_menu(name, c, r, pressed)
			if name == "bar_skills" and GameState.skill_points > 0:
				_draw_skill_points(c, r, float(b["radius"]))



## Compact Xbox cues follow the existing buttons; keyboard/touch art is unchanged.
func _draw_gamepad_hints(canvas: CanvasItem = null) -> void:
	var target: CanvasItem = self if canvas == null else canvas
	last_drawn_gamepad_hints.clear()
	if not Gamepad.using_gamepad:
		return
	var labels := {"slot0": "A", "slot1": "X", "slot2": "Y", "slot3": "RB", "slot4": "RT",
		"roll": "B", "potion_hp": "LB", "potion_mp": "↑", "bar_bag": "←",
		"bar_skills": "↓", "bar_quests": "→", "bar_gear": "Menu"}
	var font_size := ceili(maxf(14.0 * _unit, 12.0 * css_scale()))
	for key: String in labels:
		if not _buttons.has(key):
			continue
		var button: Dictionary = _buttons[key]
		var center: Vector2 = button["center"]
		var radius: float = button["visual_radius"]
		var text: String = labels[key]
		var width := HudArt.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 12.0 * _unit
		var height := maxf(23.0 * _unit, font_size + 5.0)
		var at := center + Vector2(radius * 0.62, radius * 0.62)
		if key.begins_with("bar_"):
			var view := get_viewport_rect().size
			at = center + Vector2(0, radius + height * 0.58) if view.y > view.x else center + Vector2(radius * 0.6, -radius * 0.7)
		elif key.begins_with("potion_"):
			at = center - Vector2(radius * 0.58, radius * 0.58)
		var rect := Rect2(at - Vector2(width, height) * 0.5, Vector2(width, height))
		var skin := StyleBoxFlat.new()
		skin.bg_color = Color("151916")
		skin.border_color = Color("8d7958")
		skin.set_border_width_all(1)
		skin.set_corner_radius_all(4)
		target.draw_style_box(skin, rect)
		var ink := Color("b8cfab") if text == "A" else Color("dba49a") if text == "B" else Color("a4bdd7") if text == "X" else Color("dec38a") if text == "Y" else UiToneArt.IVORY
		HudArt.text_in_rect(target, text, rect, font_size, ink)
		last_drawn_gamepad_hints.append({"name": key, "text": text, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "font_size": font_size, "css_scale": css_scale()})
	var move_width := HudArt.FONT.get_string_size("LS 이동 · RS 조준", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 8.0 * _unit
	var move_left := maxf(8.0 * _unit, _stick_center.x - move_width * 0.5)
	var move_rect := Rect2(Vector2(move_left, _stick_center.y), Vector2(move_width, maxf(34.0 * _unit, font_size + 4.0)))
	var move_skin := StyleBoxFlat.new()
	move_skin.bg_color = Color(0.06, 0.08, 0.06, 0.88)
	move_skin.set_corner_radius_all(4)
	target.draw_style_box(move_skin, move_rect)
	HudArt.text_in_rect(target, "LS 이동 · RS 조준", move_rect, font_size, UiToneArt.IVORY)
	last_drawn_gamepad_hints.append({"name": "move_aim", "text": "LS 이동 · RS 조준", "rect": [move_rect.position.x, move_rect.position.y, move_rect.size.x, move_rect.size.y], "font_size": font_size})


func gamepad_hint_snapshot() -> Dictionary:
	return {"visible": is_visible_in_tree() and not last_drawn_gamepad_hints.is_empty(), "glyphs": last_drawn_gamepad_hints.duplicate(true)}

## Foldable screens have a wider skill fan. Keep the whole input rectangle clear.
func _clear_interaction_center(preferred: Vector2, half: Vector2, stick: Vector2, unit: float, canvas_size: Vector2) -> Vector2:
	# Keep the prompt below the player when a horizontal lane fits between thumbs.
	var folded := canvas_size.y > canvas_size.x and canvas_size.x / canvas_size.y > 0.8
	var horizontal_gap := (1.0 if folded else 6.0) * unit
	var left := half.x + horizontal_gap
	var right := canvas_size.x - half.x - horizontal_gap
	var obstacles: Array[Rect2] = []
	for other: Dictionary in _buttons.values():
		var radius: float = other["radius"]
		obstacles.append(Rect2(other["center"] - Vector2.ONE * radius, Vector2.ONE * radius * 2.0))
	obstacles.append(Rect2(stick - Vector2.ONE * stick_radius(), Vector2.ONE * stick_radius() * 2.0))
	for bounds: Rect2 in obstacles:
		if preferred.y + half.y + horizontal_gap <= bounds.position.y or preferred.y - half.y - horizontal_gap >= bounds.end.y:
			continue
		if bounds.get_center().x < preferred.x:
			left = maxf(left, bounds.end.x + half.x + horizontal_gap)
		else:
			right = minf(right, bounds.position.x - half.x - horizontal_gap)
	if left <= right:
		return Vector2(clampf(preferred.x, left, right), preferred.y)
	var center := preferred
	var gap := 8.0 * unit
	for iteration in 12:
		var target := Rect2(center - half, half * 2.0).grow(gap)
		var next_y := center.y
		for other: Dictionary in _buttons.values():
			var radius: float = other["radius"]
			var bounds := Rect2(other["center"] - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
			if target.intersects(bounds):
				next_y = minf(next_y, bounds.position.y - half.y - gap)
		var stick_bounds := Rect2(stick - Vector2.ONE * stick_radius(), Vector2.ONE * stick_radius() * 2.0)
		if target.intersects(stick_bounds):
			next_y = minf(next_y, stick_bounds.position.y - half.y - gap)
		next_y = maxf(half.y + gap, next_y)
		if is_equal_approx(next_y, center.y):
			break
		center.y = next_y
	return center


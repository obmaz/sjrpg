class_name TouchControls
extends Control
## Reference-style controls: 마법진 조이스틱 (left), 주 슬롯 + 보조 슬롯 4 + 구르기 ring
## (right), 체력/마나 포션 above it and the bottom icon bar (가방 · 스킬 · 퀘스트 · 설정).
## Multi-touch; the mouse works too. Empty slots open the skill tree.

var game: Node
var _stick_center := Vector2.ZERO
var _stick_knob := Vector2.ZERO
var _stick_index := -2  # -2 none, -1 mouse
var _held := {}  # touch index -> button name
var _buttons := {}  # name -> {center, radius}
var _unit := 1.0
var _near_name := ""
var _feedback := {}
var _interaction_normal: StyleBox
var _interaction_pressed: StyleBox
static var _reference_buttons: Texture2D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func stick_radius() -> float:
	return 90.0 * _unit


func _button(center: Vector2, radius: float, visual_radius := -1.0) -> Dictionary:
	return {"center": center, "radius": maxf(32.0, radius), "visual_radius": radius if visual_radius < 0.0 else visual_radius}


func _layout() -> void:
	var margins := PanelFrame.safe_margins(get_viewport())
	var safe_origin := Vector2(margins.x, margins.y)
	var size := get_viewport().get_visible_rect().size - Vector2(margins.x + margins.z, margins.y + margins.w)
	_unit = clampf(minf(size.x, size.y) / 720.0, 0.75, 2.0)
	var u := _unit
	var portrait := size.y > size.x
	# The 714×1280 reference has the primary skill at (559, 948). Keep its fan
	# together at a fixed scale, then adapt the anchor to the available height.
	var main := Vector2(size.x - 156.0 * u, size.y * 0.741) if portrait else Vector2(size.x - 156.0 * u, size.y - 178.0 * u)
	_buttons = {"slot0": _button(main, 67.0 * u)}
	var offsets := [Vector2(-119, 0), Vector2(-85, -84), Vector2(-4, -121), Vector2(79, -84)]
	var radii := [44.0, 42.0, 42.0, 42.0]
	for i in 4:
		_buttons["slot%d" % (i + 1)] = _button(main + offsets[i] * u, radii[i] * u)
	_buttons["roll"] = _button(main + Vector2(114, 0) * u, 32.0 * u, 31.0 * u)
	var potion_y := main.y - 198.0 * u
	_buttons["potion_hp"] = _button(Vector2(size.x - 118.0 * u, potion_y), 32.0 * u, 30.0 * u)
	_buttons["potion_mp"] = _button(Vector2(size.x - 41.0 * u, potion_y), 32.0 * u, 30.0 * u)
	var bar_y := size.y * 0.902 if portrait else size.y - 44.0 * u
	var names := ["bar_bag", "bar_skills", "bar_quests", "bar_gear"]
	for i in 4:
		_buttons[names[i]] = _button(Vector2(size.x / 2.0 + (i - 1.5) * 79.0 * u, bar_y), 32.0 * u, 31.0 * u)
	var npc: String = game.near_npc()
	_near_name = npc
	if npc != "" and npc != "탈것 상인":
		var interaction := _button(Vector2(size.x / 2.0, bar_y - 78.0 * u), 32.0 * u)
		interaction["half_size"] = Vector2(78.0 * u, 32.0 * u)
		_buttons["near_shop"] = interaction
	for button in _buttons.values():
		button["center"] += safe_origin
	if _stick_index == -2:
		_stick_center = Vector2(104.0 * u, size.y * 0.72) if portrait else Vector2(112.0 * u, size.y - 178.0 * u)
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
	if button != "":
		_feedback[button] = 0.16
	if button.begins_with("slot"):
		var slot := int(button.substr(4))
		_held[index] = button
		player.held_slots[slot] = true
		player.cast_slot(slot)
		return true
	match button:
		"roll":
			player.try_roll()
			return true
		"potion_hp":
			player.use_potion()
			return true
		"potion_mp":
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
			game.hud.interact(_near_name)
			return true
		"bar_quests":
			game.hud.open_journal()
			return true
	if game.hud.minimap.get_global_rect().has_point(pos):
		game.hud.open_map()
		return true
	if pos.x < get_viewport().get_visible_rect().size.x * 0.5 and _stick_index == -2:
		_stick_index = index
		_stick_center = pos
		_stick_knob = pos
		return true
	return false


func _release(index: int) -> void:
	if _held.has(index):
		game.player.held_slots[int(String(_held[index]).substr(4))] = false
		_held.erase(index)
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
	_feedback.clear()
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
	for key in _feedback.keys():
		_feedback[key] -= delta
		if _feedback[key] <= 0.0:
			_feedback.erase(key)
	_layout()
	queue_redraw()


# ───────── drawing ─────────

func _draw_joystick() -> void:
	var u := _unit
	var c := _stick_center
	var r := stick_radius()
	var active := _stick_index != -2
	var bronze := Color(0.62, 0.57, 0.42, 0.8 if active else 0.65)
	draw_circle(c, r + 2.0 * u, Color(0.0, 0.0, 0.0, 0.2))
	draw_circle(c, r, Color(0.025, 0.028, 0.023, 0.34 if active else 0.26))
	draw_arc(c, r, 0, TAU, 96, bronze, 1.5 * u, true)
	draw_arc(c, r - 4.0 * u, 0, TAU, 96, Color(bronze, 0.4), 1.0 * u, true)
	draw_arc(c, r - 14.0 * u, 0, TAU, 72, Color(bronze, 0.42), 1.1 * u, true)
	draw_arc(c, r * 0.54, 0, TAU, 64, Color(bronze, 0.28), 1.0 * u, true)
	# Fine etched triangles and ticks stay still, like the translucent seal in the reference.
	for rotation in [0.0, PI]:
		var seal := PackedVector2Array()
		for i in 4:
			seal.append(c + Vector2.from_angle(rotation - PI / 2.0 + i * TAU / 3.0) * r * 0.77)
		draw_polyline(seal, Color(bronze, 0.32), 1.0 * u, true)
	for i in 16:
		var direction := Vector2.from_angle(TAU * i / 16.0)
		draw_line(c + direction * r * 0.79, c + direction * r * 0.84, Color(bronze, 0.42), 1.0 * u, true)
	for i in 4:
		var direction := Vector2.from_angle(i * PI / 2.0)
		var tip := c + direction * (r - 8.0 * u)
		var base := c + direction * (r - 19.0 * u)
		var side := direction.orthogonal() * 5.0 * u
		draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), Color(0.68, 0.63, 0.46, 0.48))
	var kr := 30.5 * u
	draw_circle(_stick_knob, kr + 2.0 * u, Color(0, 0, 0, 0.22))
	draw_circle(_stick_knob, kr, Color(0.1, 0.092, 0.067, 0.8 if active else 0.64))
	draw_arc(_stick_knob, kr, 0, TAU, 64, Color(0.62, 0.56, 0.4, 0.72), 1.1 * u, true)
	draw_arc(_stick_knob, kr - 4.0 * u, 0, TAU, 56, Color(0.62, 0.56, 0.4, 0.25), 0.8 * u, true)
	draw_arc(_stick_knob, kr - 7.0 * u, PI * 1.12, PI * 1.88, 24, Color(0.8, 0.75, 0.57, 0.2), 0.8 * u, true)


func _draw_skill_bezel(center: Vector2, radius: float, pressed: bool) -> void:
	var u := _unit
	var strength := 1.15 if pressed else 1.0
	draw_arc(center, radius + 6.0 * u, 0, TAU, 96, Color(0.27, 0.7, 1.0, 0.08 * strength), 6.0 * u, true)
	draw_arc(center, radius + 3.0 * u, 0, TAU, 96, Color(0.45, 0.8, 1.0, 0.25 * strength), 3.0 * u, true)
	draw_arc(center, radius + 1.2 * u, 0, TAU, 96, Color(0.65, 0.86, 1.0, 0.95), 1.5 * u, true)
	draw_arc(center, radius - 0.8 * u, 0, TAU, 96, Color(0.9, 0.94, 0.94, 0.9), 1.0 * u, true)
	draw_arc(center, radius - 2.2 * u, 0, TAU, 96, Color(0.11, 0.15, 0.18, 0.92), 1.4 * u, true)
	draw_arc(center, radius + 0.4 * u, PI * 1.03, PI * 1.59, 32, Color(0.95, 0.99, 1.0, 0.95), 1.1 * u, true)


func _draw_empty_socket(center: Vector2, radius: float) -> void:
	var u := _unit
	draw_circle(center, radius, Color(0.035, 0.039, 0.044, 0.88))
	draw_arc(center, radius + 1.0 * u, 0, TAU, 72, Color(0.12, 0.14, 0.15, 0.8), 2.0 * u, true)
	draw_arc(center, radius - 0.5 * u, 0, TAU, 72, Color(0.48, 0.45, 0.36, 0.55), 0.9 * u, true)
	draw_arc(center, radius - 3.0 * u, 0, TAU, 64, Color(0.52, 0.56, 0.59, 0.18), 0.7 * u, true)
	var etching := Color(0.61, 0.58, 0.45, 0.23)
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


func _draw_interaction(center: Vector2, half: Vector2, pressed: bool) -> void:
	var rect := Rect2(center - half, half * 2.0)
	# Keep skins alive between frames: their gradient textures are submitted by RID.
	# A temporary StyleBox would free those resources before the canvas renders.
	if _interaction_normal == null:
		_interaction_normal = UiKit.panel_style(Color(0.065, 0.06, 0.048, 0.88), Color(0.51, 0.44, 0.29, 0.85), 5)
		_interaction_pressed = UiKit.panel_style(Color(0.13, 0.105, 0.075, 0.95), Color(0.62, 0.53, 0.36, 0.9), 5)
	draw_style_box(_interaction_pressed if pressed else _interaction_normal, rect)
	var text: String = {"바람 동굴": "동굴 탐험", "동굴 출구": "동굴 나가기", "안식처": "안식처", "숲의 파수꾼": "도전하기", "상인": "상점", "대장장이": "대장간", "촌장": "대화", "보급원 미라": "대화"}.get(_near_name, "대화")
	HudArt.text_outlined(self, text, center + Vector2(-half.x, 7.0 * _unit), half.x * 2.0, int(20.0 * _unit), Color(0.89, 0.85, 0.73))


func _draw() -> void:
	var player: Player = game.player
	if player == null:
		return
	var u := _unit
	_draw_joystick()
	var held_names := _held.values()
	for name in _buttons:
		var b: Dictionary = _buttons[name]
		var c: Vector2 = b["center"]
		var r: float = b["visual_radius"]
		var pressed: bool = held_names.has(name) or float(_feedback.get(name, 0.0)) > 0.0
		if name.begins_with("slot"):
			var slot := int(name.substr(4))
			var id: String = GameState.slots[slot]
			draw_circle(c, r + 3.0 * u, Color(0.0, 0.0, 0.0, 0.38))
			if id == "":
				_draw_empty_socket(c, r)
				continue
			draw_circle(c, r, Color(0.025, 0.028, 0.04, 0.98))
			var skill := GameState.skill(id)
			var affordable := player.resource >= SkillDefs.cost(skill, GameState.effective_rank(id))
			var inner := r - 3.0 * u
			SkillIcons.draw_round(self, id, c, inner, Color.WHITE if affordable else Color(0.42, 0.42, 0.5))
			_draw_skill_bezel(c, r, pressed)
			var ready := player.slot_cooldown_ratio(slot)
			if ready < 1.0:
				draw_circle(c, inner, Color(0, 0, 0, 0.55))
				draw_arc(c, r - 1.0 * u, -PI / 2, -PI / 2 + TAU * ready, 64, Color(0.9, 0.96, 1.0, 0.85), 1.6 * u, true)
		elif name == "roll":
			HudArt.round_plaque(self, "dodge", c, r, Color(0.82, 0.81, 0.75, 1.0 if pressed else 0.88))
		elif name == "potion_hp":
			PotionArt.draw(self, c, r, false, GameState.potions, pressed)
		elif name == "potion_mp":
			PotionArt.draw(self, c, r, true, GameState.mana_potions, pressed)
		elif name == "near_shop":
			_draw_interaction(c, b["half_size"], pressed)
		elif name.begins_with("bar_"):
			var tint := Color.WHITE if pressed else Color(0.87, 0.83, 0.75)
			match name:
				"bar_bag":
					_draw_reference_button(2, c, r, tint)
				"bar_quests":
					_draw_reference_button(3, c, r, tint)
				"bar_gear":
					_draw_reference_button(1, c, r, tint)
				"bar_skills":
					HudArt.round_plaque(self, "book", c, r, tint)
			if name == "bar_skills" and GameState.skill_points > 0:
				var bc := c + Vector2(r * 0.72, -r * 0.72)
				draw_circle(bc, 8.0 * u, Color(0.12, 0.095, 0.06, 0.95))
				draw_arc(bc, 8.0 * u, 0, TAU, 24, Color(0.65, 0.54, 0.33), 0.8 * u, true)
				HudArt.text_outlined(self, str(GameState.skill_points), bc + Vector2(-8.0 * u, 4.0 * u), 16.0 * u, int(11 * u), Color(0.94, 0.86, 0.65))

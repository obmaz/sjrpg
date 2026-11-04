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
var _time := 0.0
var _near_name := ""

const BAR_ICONS := {"bar_bag": "backpack", "bar_skills": "book", "bar_quests": "scroll", "bar_gear": "gear"}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func stick_radius() -> float:
	return 88.0 * _unit


func _layout() -> void:
	var margins := PanelFrame.safe_margins(get_viewport())
	var safe_origin := Vector2(margins.x, margins.y)
	var size := get_viewport().get_visible_rect().size - Vector2(margins.x + margins.z, margins.y + margins.w)
	_unit = clampf(minf(size.x, size.y) / 720.0, 0.75, 2.0)
	var u := _unit
	var portrait := size.y > size.x
	var main := Vector2(size.x - 160.0 * u, size.y * 0.745) if portrait else Vector2(size.x - 170.0 * u, size.y - 190.0 * u)
	var R := 62.0 * u
	_buttons = {"slot0": {"center": main, "radius": R}}
	# Auxiliary slots arc over the main button's left/top; dodge sits to its right.
	var arc := [[180.0, 2.45], [226.0, 2.0], [266.0, 1.95], [308.0, 2.0]]
	for i in 4:
		_buttons["slot%d" % (i + 1)] = {"center": main + Vector2.from_angle(deg_to_rad(arc[i][0])) * R * arc[i][1], "radius": 40.0 * u}
	var roll_center := main + Vector2(1.55 * R, 1.45 * R)
	roll_center.x = minf(roll_center.x, size.x - 40.0 * u)
	_buttons["roll"] = {"center": roll_center, "radius": 33.0 * u}
	# 원본 PotionBelt: two 44px potions side by side with a 6px gap, right side above the controls.
	var potion_y := main.y - 3.25 * R
	_buttons["potion_hp"] = {"center": Vector2(size.x - 112.0 * u, potion_y), "radius": 32.0 * u}
	_buttons["potion_mp"] = {"center": Vector2(size.x - 40.0 * u, potion_y), "radius": 32.0 * u}
	var bar_y := size.y - (60.0 * u if portrait else 44.0 * u)
	var names := ["bar_bag", "bar_skills", "bar_quests", "bar_gear"]
	for i in 4:
		_buttons[names[i]] = {"center": Vector2(size.x / 2.0 + (i - 1.5) * 84.0 * u, bar_y), "radius": 33.0 * u}
	var npc: String = game.near_npc()
	_near_name = npc
	if npc != "" and npc != "탈것 상인":
		_buttons["near_shop"] = {"center": Vector2(size.x / 2.0, bar_y - 86.0 * u), "radius": 42.0 * u}
	for button in _buttons.values():
		button["center"] += safe_origin
	if _stick_index == -2:
		_stick_center = Vector2(112.0 * u, size.y * 0.725) if portrait else Vector2(140.0 * u, size.y - 150.0 * u)
		_stick_center += safe_origin
		_stick_knob = _stick_center


func _hit_button(pos: Vector2) -> String:
	var best := ""
	var best_d := INF
	for name in _buttons:
		var b: Dictionary = _buttons[name]
		var d := pos.distance_to(b["center"])
		if d <= b["radius"] * 1.15 and d < best_d:
			best = name
			best_d = d
	return best


func _press(index: int, pos: Vector2) -> bool:
	var button := _hit_button(pos)
	var player: Player = game.player
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
	_time += delta
	_layout()
	queue_redraw()


# ───────── drawing ─────────

func _draw_joystick() -> void:
	var u := _unit
	var c := _stick_center
	var r := stick_radius()
	var active := _stick_index != -2
	draw_circle(c, r + 4.0 * u, Color(0.0, 0.0, 0.0, 0.28))
	draw_circle(c, r, Color(0.05, 0.07, 0.08, 0.5))
	draw_arc(c, r, 0, TAU, 64, Color(0.78, 0.74, 0.62, 0.6 if active else 0.42), 2.5 * u, true)
	draw_arc(c, r - 7.0 * u, 0, TAU, 64, Color(0.78, 0.74, 0.62, 0.3), 1.5 * u, true)
	draw_arc(c, r * 0.62, 0, TAU, 48, Color(0.78, 0.74, 0.62, 0.28), 1.5 * u, true)
	# Rotating rune marks between the rings.
	for i in 12:
		var a := TAU * i / 12.0 + (0.0 if Prefs.reduce_motion else _time * 0.15)
		var p := c + Vector2.from_angle(a) * r * 0.81
		draw_circle(p, 2.0 * u, Color(0.85, 0.8, 0.6, 0.35))
	# Direction arrows.
	for i in 4:
		var dir := Vector2.from_angle(i * PI / 2.0)
		var tip := c + dir * (r - 14.0 * u)
		var base := c + dir * (r - 26.0 * u)
		var side := dir.orthogonal() * 7.0 * u
		draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), Color(0.82, 0.78, 0.62, 0.55))
	# Knob.
	var kr := 34.0 * u
	draw_circle(_stick_knob, kr + 3.0 * u, Color(0.0, 0.0, 0.0, 0.35))
	draw_circle(_stick_knob, kr, Color(0.1, 0.1, 0.1, 0.92 if active else 0.78))
	draw_arc(_stick_knob, kr, 0, TAU, 40, Color(0.7, 0.66, 0.55, 0.75), 2.5 * u, true)
	draw_arc(_stick_knob, kr * 0.7, PI * 1.1, PI * 1.9, 16, Color(1, 1, 1, 0.35), 3.0 * u, true)


func _draw() -> void:
	var player: Player = game.player
	if player == null:
		return
	var u := _unit
	_draw_joystick()
	var is_mage: bool = player.is_mage
	var glow := Color(0.45, 0.78, 1.0) if is_mage else Color(1.0, 0.68, 0.3)
	var held_names := _held.values()
	for name in _buttons:
		var b: Dictionary = _buttons[name]
		var c: Vector2 = b["center"]
		var r: float = b["radius"]
		var pressed: bool = held_names.has(name)
		if name.begins_with("slot"):
			var slot := int(name.substr(4))
			var id: String = GameState.slots[slot]
			draw_circle(c, r + 2.0, Color(0.0, 0.0, 0.0, 0.4))
			draw_circle(c, r, Color(0.03, 0.04, 0.06, 0.94))
			if id == "":
				HudArt.glow_ring(self, c, r, Color(0.7, 0.7, 0.7), 0.35)
				HudArt.text_outlined(self, "+", c + Vector2(-r, r * 0.32), r * 2.0, int(r * 0.9), Color(1, 1, 1, 0.5))
				continue
			var s := GameState.skill(id)
			var affordable := player.resource >= SkillDefs.cost(s, GameState.effective_rank(id))
			var inner := r * 0.94
			SkillIcons.draw_round(self, id, c, inner, Color.WHITE if affordable else Color(0.42, 0.42, 0.5))
			var pulse := 1.0 if Prefs.reduce_motion else 0.85 + 0.15 * sin(_time * 3.0 + slot)
			HudArt.glow_ring(self, c, r, glow, (1.15 if pressed else 1.0) * pulse)
			var ready := player.slot_cooldown_ratio(slot)
			if ready < 1.0:
				draw_circle(c, inner, Color(0, 0, 0, 0.55))
				draw_arc(c, r - 3.0, -PI / 2, -PI / 2 + TAU * ready, 32, Color(1, 1, 1, 0.9), 4.0, true)
		elif name == "roll":
			HudArt.plaque(self, "dodge", c, r, Color(1, 1, 1, 0.78 if not pressed else 1.0))
		elif name == "potion_hp":
			PotionArt.draw(self, c, r, false, GameState.potions, pressed)
		elif name == "potion_mp":
			PotionArt.draw(self, c, r, true, GameState.mana_potions, pressed)
		elif name == "near_shop":
			draw_circle(c, r + 2.0, Color(0, 0, 0, 0.4))
			draw_circle(c, r, Color(0.17, 0.12, 0.05, 0.95))
			draw_arc(c, r, 0, TAU, 40, UiKit.GOLD, 4.0, true)
			HudArt.text_outlined(self, {"바람 동굴": "동굴", "동굴 출구": "귀환", "안식처": "이동", "숲의 파수꾼": "도전", "상인": "상점", "대장장이": "대장간", "촌장": "대화", "보급원 미라": "대화"}.get(_near_name, "대화"), c + Vector2(-r, 8.0 * u), r * 2.0, int(22 * u), Color(1, 0.92, 0.7))
		elif name.begins_with("bar_"):
			HudArt.plaque(self, BAR_ICONS[name], c, r, Color(0.92, 0.9, 0.88) if not pressed else Color.WHITE)
			if name == "bar_skills" and GameState.skill_points > 0:
				var bc := c + Vector2(r * 0.7, -r * 0.7)
				draw_circle(bc, 12.0 * u, Color(0.96, 0.84, 0.52))
				HudArt.text_outlined(self, "+%d" % GameState.skill_points, bc + Vector2(-14.0 * u, 5.0 * u), 28.0 * u, int(13 * u), Color(0.1, 0.07, 0.03))

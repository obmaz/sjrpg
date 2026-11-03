class_name TouchControls
extends Control
## Multi-touch joystick and combat buttons: 주 슬롯 1개 · 보조 슬롯 4개 · 구르기 · 물약.
## Mouse works too on desktop. Empty slots open the skill tree.

var game: Node
var _stick_center := Vector2.ZERO
var _stick_knob := Vector2.ZERO
var _stick_index := -2  # -2 none, -1 mouse
var _held := {}  # touch index -> button name
var _buttons := {}  # name -> {center, radius}

const STICK_RADIUS := 78.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _layout() -> void:
	var size := get_viewport_rect().size
	var unit := clampf(minf(size.x, size.y) / 720.0, 0.75, 2.0)
	var main := size - Vector2(120, 130) * unit
	_buttons = {"slot0": {"center": main, "radius": 62.0 * unit}}
	# Auxiliary slots fan around the main button, like the original layout.
	var angles := [182.0, 210.0, 238.0, 266.0]
	for i in 4:
		_buttons["slot%d" % (i + 1)] = {"center": main + Vector2.from_angle(deg_to_rad(angles[i])) * 158.0 * unit, "radius": 35.0 * unit}
	_buttons["roll"] = {"center": main + Vector2(-270, 62) * unit, "radius": 30.0 * unit}
	_buttons["potion"] = {"center": main + Vector2(48, -232) * unit, "radius": 30.0 * unit}
	if _stick_index == -2:
		_stick_center = Vector2(150 * unit, size.y - 150 * unit)
		_stick_knob = _stick_center


func _hit_button(pos: Vector2) -> String:
	var best := ""
	var best_d := INF
	for name in _buttons:
		var b: Dictionary = _buttons[name]
		var d := pos.distance_to(b["center"])
		if d <= b["radius"] * 1.12 and d < best_d:
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
	elif button == "roll":
		player.try_roll()
		return true
	elif button == "potion":
		player.use_potion()
		return true
	elif pos.x < get_viewport_rect().size.x * 0.5 and _stick_index == -2:
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
	if d.length() > STICK_RADIUS:
		d = d.normalized() * STICK_RADIUS
	_stick_knob = _stick_center + d
	game.player.move_input = d / STICK_RADIUS


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


func _process(_delta: float) -> void:
	_layout()
	queue_redraw()


func _draw() -> void:
	var font := UiKit.BOLD_FONT
	draw_circle(_stick_center, STICK_RADIUS, Color(0, 0, 0, 0.22))
	draw_arc(_stick_center, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
	draw_circle(_stick_knob, 34.0, Color(1, 1, 1, 0.35 if _stick_index != -2 else 0.22))
	var player: Player = game.player
	var held_names := _held.values()
	for name in _buttons:
		var b: Dictionary = _buttons[name]
		var c: Vector2 = b["center"]
		var r: float = b["radius"]
		var pressed: bool = held_names.has(name)
		draw_circle(c, r, Color(0.05, 0.12, 0.11, 0.78 if not pressed else 0.95))
		if name.begins_with("slot"):
			var slot := int(name.substr(4))
			var id: String = GameState.slots[slot]
			if id == "":
				draw_string(font, c + Vector2(-r, r * 0.25), "+", HORIZONTAL_ALIGNMENT_CENTER, r * 2, int(r * 0.8), Color(1, 1, 1, 0.55))
			else:
				var s := GameState.skill(id)
				var affordable := player.resource >= SkillDefs.cost(s, GameState.effective_rank(id))
				var inner := r * 0.86
				SkillIcons.draw(self, id, Rect2(c - Vector2(inner, inner), Vector2(inner, inner) * 2.0),
					Color(1, 1, 1) if affordable else Color(0.45, 0.45, 0.5))
				var ready := player.slot_cooldown_ratio(slot)
				if ready < 1.0:
					draw_circle(c, inner, Color(0, 0, 0, 0.5))
					draw_arc(c, r - 3, -PI / 2, -PI / 2 + TAU * ready, 32, Color(1, 1, 1, 0.85), 4.0, true)
		else:
			var label := "구르기" if name == "roll" else "물약 %d" % GameState.potions
			var fs := 15
			while fs > 10 and font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r * 2.0 - 8.0:
				fs -= 1
			draw_string(font, c + Vector2(-r, fs * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2, fs, Color.WHITE)
		draw_arc(c, r, 0, TAU, 48, Color(0.96, 0.84, 0.52), 4.0 if name == "slot0" else 3.0, true)

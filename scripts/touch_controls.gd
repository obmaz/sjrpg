class_name TouchControls
extends Control
## Multi-touch virtual joystick and combat buttons (mouse also works on desktop).

var game: Node
var _stick_center := Vector2.ZERO
var _stick_knob := Vector2.ZERO
var _stick_index := -2  # -2 none, -1 mouse
var _attack_index := -2
var _buttons := {}  # name -> {center, radius}

const STICK_RADIUS := 78.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _layout() -> void:
	var size := get_viewport_rect().size
	var unit := clampf(minf(size.x, size.y) / 720.0, 0.75, 2.0)
	_buttons = {
		"attack": {"center": size - Vector2(120, 130) * unit, "radius": 62.0 * unit},
		"skill": {"center": size - Vector2(250, 92) * unit, "radius": 44.0 * unit},
		"potion": {"center": size - Vector2(110, 270) * unit, "radius": 36.0 * unit},
	}
	if _stick_index == -2:
		_stick_center = Vector2(150 * unit, size.y - 150 * unit)
		_stick_knob = _stick_center


func _hit_button(pos: Vector2) -> String:
	for name in _buttons:
		var b: Dictionary = _buttons[name]
		if pos.distance_to(b["center"]) <= b["radius"] * 1.15:
			return name
	return ""


func _press(index: int, pos: Vector2) -> bool:
	var button := _hit_button(pos)
	var player: Player = game.player
	if button == "attack":
		_attack_index = index
		player.attack_held = true
		return true
	elif button == "skill":
		player.try_skill()
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
	if index == _attack_index:
		_attack_index = -2
		game.player.attack_held = false
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


func _input(event: InputEvent) -> void:
	if get_tree().paused:
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
	var info := GameState.class_info()
	var labels := {"attack": info["basic"], "skill": info["skill"], "potion": "물약 %d" % GameState.potions}
	for name in _buttons:
		var b: Dictionary = _buttons[name]
		var c: Vector2 = b["center"]
		var r: float = b["radius"]
		var pressed: bool = name == "attack" and _attack_index != -2
		var base := Color(0.96, 0.84, 0.52, 0.85) if name == "attack" else Color(0.1, 0.25, 0.22, 0.8)
		if name == "skill" and player.skill_ready_ratio() < 1.0:
			base = base.darkened(0.4)
		if pressed:
			base = base.darkened(0.2)
		draw_circle(c, r, base)
		draw_arc(c, r, 0, TAU, 48, Color(0.96, 0.84, 0.52), 3.0, true)
		if name == "skill" and player.skill_ready_ratio() < 1.0:
			draw_arc(c, r - 5, -PI / 2, -PI / 2 + TAU * player.skill_ready_ratio(), 32, Color(1, 1, 1, 0.8), 5.0, true)
		var text: String = labels[name]
		var fs := 18 if name != "attack" else 22
		while fs > 11 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r * 2.0 - 12.0:
			fs -= 1
		var text_color := UiKit.INK if name == "attack" else Color.WHITE
		draw_string(font, c + Vector2(-r, fs * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, r * 2, fs, text_color)

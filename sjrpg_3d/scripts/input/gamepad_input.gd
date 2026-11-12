extends Node
## Device-owned pad state. Combat never enters keyboard/touch InputMap actions.

signal action_pressed(action: String)
signal input_mode_changed(gamepad: bool)
signal device_changed(device: int)

const DEADZONE := 0.2
const TRIGGER_PRESS := 0.55
const TRIGGER_RELEASE := 0.35
const NEUTRAL_POLL_SAMPLES := 2
const BUTTON_ACTIONS := {
	JOY_BUTTON_A: "primary", JOY_BUTTON_B: "roll",
	JOY_BUTTON_X: "aux1", JOY_BUTTON_Y: "aux2",
	JOY_BUTTON_LEFT_SHOULDER: "health", JOY_BUTTON_RIGHT_SHOULDER: "aux3",
	JOY_BUTTON_BACK: "map", JOY_BUTTON_START: "settings",
	JOY_BUTTON_DPAD_UP: "mana", JOY_BUTTON_DPAD_DOWN: "skills",
	JOY_BUTTON_DPAD_LEFT: "bag", JOY_BUTTON_DPAD_RIGHT: "quests",
}
const DPAD_NAV := {
	JOY_BUTTON_DPAD_UP: "nav_up", JOY_BUTTON_DPAD_DOWN: "nav_down",
	JOY_BUTTON_DPAD_LEFT: "nav_left", JOY_BUTTON_DPAD_RIGHT: "nav_right",
}

var active_device := -1
var using_gamepad := false
var _connected: Array[int] = []
var _buttons: Dictionary = {}
var _axes: Dictionary = {}
var _armed := false
var _neutral_samples := 0
var _neutral_frame := -1
var _focused := true
var _combat := false
var _left_trigger := false
var _right_trigger := false
var _nav_direction := ""
var _nav_repeat := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_connection_changed)
	_connected = Input.get_connected_joypads()
	if not _connected.is_empty():
		_select_device(_connected[0])
	var navigation := preload("res://scripts/input/gamepad_navigation.gd").new()
	navigation.name = "Navigation"
	add_child(navigation)


func _select_device(device: int) -> void:
	active_device = device
	_buttons.clear()
	_axes.clear()
	_left_trigger = false
	_right_trigger = false
	_sample_hardware()
	require_neutral()
	device_changed.emit(device)


func _sample_hardware() -> void:
	if active_device < 0 or not _connected.has(active_device):
		return
	for button in range(JOY_BUTTON_MAX):
		_buttons[button] = Input.is_joy_button_pressed(active_device, button)
	for axis in range(JOY_AXIS_MAX):
		_axes[axis] = Input.get_joy_axis(active_device, axis)
	_left_trigger = float(_axes.get(JOY_AXIS_TRIGGER_LEFT, 0.0)) >= TRIGGER_PRESS
	_right_trigger = float(_axes.get(JOY_AXIS_TRIGGER_RIGHT, 0.0)) >= TRIGGER_PRESS


func _connection_changed(device: int, connected: bool) -> void:
	if connected and not _connected.has(device):
		_connected.append(device)
	elif not connected:
		_connected.erase(device)
	if connected and active_device < 0:
		_select_device(device)
	elif not connected and device == active_device:
		_select_device(-1)
		_set_input_mode(false)
		if not _connected.is_empty():
			_select_device(_connected[0])


func require_neutral() -> void:
	_armed = false
	_neutral_samples = 0
	_neutral_frame = -1
	_nav_direction = ""
	_nav_repeat = 0.0


func set_combat_enabled(enabled: bool) -> void:
	if _combat != enabled:
		_combat = enabled
		require_neutral()


func navigation_scope() -> bool:
	var navigation := get_node_or_null("Navigation")
	return is_instance_valid(navigation) and navigation.has_method("has_scope") and bool(navigation.call("has_scope"))


func loading_blocked() -> bool:
	if not is_inside_tree():
		return false
	for overlay: Node in get_tree().get_nodes_in_group("entry_loading"):
		if not overlay.is_queued_for_deletion():
			return true
	var navigation := get_node_or_null("Navigation")
	return is_instance_valid(navigation) and navigation.has_method("loading_blocked") and bool(navigation.call("loading_blocked"))


func combat_enabled() -> bool:
	return is_inside_tree() and _combat and _armed and _focused and using_gamepad and not get_tree().paused and not loading_blocked() and not navigation_scope()


static func radial_axis(raw: Vector2) -> Vector2:
	var magnitude: float = minf(raw.length(), 1.0)
	if magnitude <= DEADZONE:
		return Vector2.ZERO
	return raw.normalized() * (magnitude - DEADZONE) / (1.0 - DEADZONE)


func _stick(x_axis: int, y_axis: int) -> Vector2:
	return radial_axis(Vector2(float(_axes.get(x_axis, 0.0)), float(_axes.get(y_axis, 0.0))))


func move_vector() -> Vector2:
	return _stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y) if combat_enabled() else Vector2.ZERO


func aim_vector() -> Vector2:
	return _stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y) if combat_enabled() else Vector2.ZERO


## Menus can scroll text-only content without leaking the right stick into combat aim.
func ui_scroll_vector() -> Vector2:
	if not _focused or not _armed or not using_gamepad or loading_blocked() or not navigation_scope():
		return Vector2.ZERO
	return _stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)


func held_slots() -> Array[int]:
	var slots: Array[int] = []
	if not combat_enabled():
		return slots
	for pair: Array in [[JOY_BUTTON_A, 0], [JOY_BUTTON_X, 1], [JOY_BUTTON_Y, 2], [JOY_BUTTON_RIGHT_SHOULDER, 3]]:
		if bool(_buttons.get(pair[0], false)):
			slots.append(int(pair[1]))
	if _right_trigger:
		slots.append(4)
	return slots


func _all_neutral() -> bool:
	if _stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y) != Vector2.ZERO or _stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y) != Vector2.ZERO:
		return false
	if absf(float(_axes.get(JOY_AXIS_TRIGGER_LEFT, 0.0))) > 0.15 or absf(float(_axes.get(JOY_AXIS_TRIGGER_RIGHT, 0.0))) > 0.15:
		return false
	for pressed: bool in _buttons.values():
		if pressed:
			return false
	return true


func _process(delta: float) -> void:
	if active_device < 0 or not _focused:
		return
	if not _armed:
		_sample_hardware()
		if not _all_neutral():
			_neutral_samples = 0
			_neutral_frame = -1
			return
		# Web connection notifications clear Input state before the first physical
		# gamepad poll is flushed. One reset-zero sample is not a release.
		var frame := Engine.get_process_frames()
		if frame != _neutral_frame:
			_neutral_frame = frame
			_neutral_samples += 1
		if _neutral_samples >= NEUTRAL_POLL_SAMPLES:
			_armed = true
		return
	var stick := _stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	var direction := ""
	if stick.length() >= 0.55:
		direction = ("nav_right" if stick.x > 0.0 else "nav_left") if absf(stick.x) > absf(stick.y) else ("nav_down" if stick.y > 0.0 else "nav_up")
	if direction != _nav_direction:
		_nav_direction = direction
		_nav_repeat = 0.34
		if not direction.is_empty():
			action_pressed.emit(direction)
	elif not direction.is_empty():
		_nav_repeat -= delta
		if _nav_repeat <= 0.0:
			_nav_repeat = 0.13
			action_pressed.emit(direction)


func _set_input_mode(gamepad: bool) -> void:
	if using_gamepad != gamepad:
		using_gamepad = gamepad
		if not gamepad:
			require_neutral()
		input_mode_changed.emit(gamepad)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
		if not _connected.has(event.device):
			return
		if active_device < 0:
			_select_device(event.device)
		if event.device != active_device:
			return
		var action := ""
		var navigation := ""
		if event is InputEventJoypadButton:
			var previous: bool = bool(_buttons.get(event.button_index, false))
			_buttons[event.button_index] = event.pressed
			if event.pressed and not previous:
				action = str(BUTTON_ACTIONS.get(event.button_index, ""))
				navigation = str(DPAD_NAV.get(event.button_index, ""))
				_set_input_mode(true)
		else:
			_axes[event.axis] = event.axis_value
			if absf(event.axis_value) > DEADZONE:
				_set_input_mode(true)
			if event.axis == JOY_AXIS_TRIGGER_LEFT:
				var pressed: bool = event.axis_value >= (TRIGGER_RELEASE if _left_trigger else TRIGGER_PRESS)
				if pressed and not _left_trigger:
					action = "interact"
				_left_trigger = pressed
			elif event.axis == JOY_AXIS_TRIGGER_RIGHT:
				var pressed: bool = event.axis_value >= (TRIGGER_RELEASE if _right_trigger else TRIGGER_PRESS)
				if pressed and not _right_trigger:
					action = "aux4"
				_right_trigger = pressed
		if not _armed and not _all_neutral():
			# A held raw sample arriving after reset-zero invalidates the candidate.
			_neutral_samples = 0
			_neutral_frame = -1
		if not _focused or not _armed:
			return
		if not navigation.is_empty():
			action_pressed.emit(navigation)
		if not action.is_empty() and _armed:
			action_pressed.emit(action)
	elif (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_set_input_mode(false)
	elif event is InputEventMouseMotion and event.relative.length() > 2.0:
		_set_input_mode(false)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_focused = false
		require_neutral()
	elif what in [NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		_focused = true
		_sample_hardware()
		require_neutral()


func review_snapshot() -> Dictionary:
	var move: Vector2 = move_vector()
	var aim: Vector2 = aim_vector()
	return {
		"active_device": active_device, "using_gamepad": using_gamepad, "armed": _armed,
		"neutral_samples": _neutral_samples, "neutral_sample_frame": _neutral_frame,
		"focused": _focused, "combat_enabled": combat_enabled(),
		"move": {"x": move.x, "y": move.y}, "aim": {"x": aim.x, "y": aim.y},
		"held_slots": held_slots(), "buttons": _buttons.duplicate(), "axes": _axes.duplicate(),
	}

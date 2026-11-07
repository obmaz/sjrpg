extends TestCase
## Web reconnect clears Input state before the held hardware sample is delivered.
const DEVICE := 17


func _button(down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = DEVICE
	event.button_index = JOY_BUTTON_A
	event.pressed = down
	Input.parse_input_event(event)


func _axis(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = DEVICE
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	Input.parse_input_event(event)


func run() -> void:
	var old_device: int = Gamepad.active_device
	var old_combat: bool = Gamepad._combat
	var old_mode: bool = Gamepad.using_gamepad
	if old_device >= 0:
		Input.joy_connection_changed.emit(old_device, false)
	Gamepad.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	Gamepad.set_combat_enabled(true)
	Input.joy_connection_changed.emit(DEVICE, true)
	_button(false)
	_axis(0.0)
	var actions: Array[String] = []
	var record := func(action: String): actions.append(action)
	Gamepad.action_pressed.connect(record)
	# This is the connection-reset zero state, before the first held poll flush.
	Gamepad._process(0.016)
	check("one reset-zero sample cannot arm a reconnected device", not bool(Gamepad.review_snapshot()["armed"]))
	for index in 3:
		Gamepad._process(0.016)
	check("repeated sampling in the same engine epoch cannot fake a release", not bool(Gamepad.review_snapshot()["armed"]))
	# The real first sample arrives later: already-held A and LS must be ignored.
	_button(true)
	_axis(0.7)
	Input.flush_buffered_events()
	await _frames(4)
	check("first held sample invalidates stale neutral and emits no primary action",
		not bool(Gamepad.review_snapshot()["armed"]) and not actions.has("primary")
		and Gamepad.held_slots().is_empty() and Gamepad.move_vector() == Vector2.ZERO)
	_button(false)
	_axis(0.0)
	Input.flush_buffered_events()
	Gamepad._process(0.016)
	check("a genuine release still needs another complete input epoch", not bool(Gamepad.review_snapshot()["armed"]))
	await _frames(4)
	check("consecutive real neutral epochs arm the selected device", bool(Gamepad.review_snapshot()["armed"]))
	_button(true)
	Input.flush_buffered_events()
	await _frames(1)
	check("fresh A after verified release emits exactly one primary edge",
		actions.count("primary") == 1 and Gamepad.held_slots().has(0))
	_button(false)
	_axis(0.0)
	Gamepad.action_pressed.disconnect(record)
	Input.joy_connection_changed.emit(DEVICE, false)
	Gamepad.set_combat_enabled(old_combat)
	Gamepad._set_input_mode(old_mode)
	if old_device >= 0:
		Input.joy_connection_changed.emit(old_device, true)
	Gamepad.require_neutral()
	await _frames(2)

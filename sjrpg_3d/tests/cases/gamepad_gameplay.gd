extends TestCase
## Virtual Godot joypad events exercise the real game. No skill/roll/interaction methods are called.
const DEVICE := 17


func _button(index: JoyButton, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = DEVICE
	event.button_index = index
	event.pressed = down
	Input.parse_input_event(event)


func _axis(index: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = DEVICE
	event.axis = index
	event.axis_value = value
	Input.parse_input_event(event)


func _neutral() -> void:
	for button: JoyButton in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_BACK, JOY_BUTTON_START, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		_button(button, false)
	for axis: JoyAxis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		_axis(axis, 0.0)


func _tap(index: JoyButton) -> void:
	_button(index, true)
	await _frames(2)
	_button(index, false)
	await _frames(4)


func _until(condition: Callable, milliseconds := 2500) -> bool:
	var deadline: int = Time.get_ticks_msec() + milliseconds
	while Time.get_ticks_msec() < deadline:
		if bool(condition.call()):
			return true
		await _frames(1)
	return bool(condition.call())


func _key(key: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = down
	Input.parse_input_event(event)


func run() -> void:
	var game: Node = await make_game("mage")
	var player: Player = game.player
	GameState.level = 12
	GameState.ranks = {"firebolt": 1, "sorceressAttack": 1, "chargedBolt": 1, "staticField": 1, "frostNova": 1, "fireball": 1, "nova": 1, "lightning": 1}
	GameState.slots = ["firebolt", "fireball", "frostNova", "nova", "lightning"]
	player.refresh_stats(true)
	if Gamepad.active_device >= 0:
		Input.joy_connection_changed.emit(Gamepad.active_device, false)
	Gamepad.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	Input.joy_connection_changed.emit(DEVICE, true)
	_neutral()
	await _frames(6)
	check("virtual native joypad is selected and neutral-armed", Gamepad.active_device == DEVICE and bool(Gamepad.review_snapshot()["armed"]))

	var origin: Vector2 = player.position
	_axis(JOY_AXIS_LEFT_X, 0.1)
	_axis(JOY_AXIS_LEFT_Y, -0.1)
	await get_tree().create_timer(0.16, false).timeout
	check("stick drift does not move the real player", player.position.distance_to(origin) < 0.2)
	_axis(JOY_AXIS_LEFT_X, 0.8)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	check("real left-stick events move through spatial physics", await _until(func(): return player.position.distance_to(origin) > 8.0))
	_neutral()
	await _frames(3)
	_axis(JOY_AXIS_RIGHT_X, 0.0)
	_axis(JOY_AXIS_RIGHT_Y, -0.85)
	await _frames(3)
	check("real right stick aims the player upward", absf(angle_difference(player.facing, -PI / 2.0)) < 0.05)
	_neutral()
	await _frames(3)

	var serial: int = player._action_serial
	_button(JOY_BUTTON_A, true)
	check("holding A repeats actual primary casts", await _until(func(): return player._action_serial >= serial + 2, 3000))
	_button(JOY_BUTTON_A, false)
	await _until(func(): return player._attack_time <= 0.0)
	for pair: Array in [[JOY_BUTTON_X, "fireball"], [JOY_BUTTON_Y, "frostNova"], [JOY_BUTTON_RIGHT_SHOULDER, "nova"]]:
		var button: JoyButton = pair[0]
		var skill: String = str(pair[1])
		_button(button, true)
		await _frames(2)
		check("native joypad casts equipped " + skill, float(player.cooldowns.get(skill, 0.0)) > 0.0)
		_button(button, false)
		await _until(func(): return player._attack_time <= 0.0)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.9)
	await _frames(2)
	check("right trigger casts actual fourth auxiliary spell", float(player.cooldowns.get("lightning", 0.0)) > 0.0)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await _until(func(): return player._attack_time <= 0.0)
	var before_roll: Vector2 = player.position
	_button(JOY_BUTTON_B, true)
	await _frames(2)
	check("B starts the actual dodge", player._roll_time > 0.0)
	_button(JOY_BUTTON_B, false)
	await _until(func(): return player._roll_time <= 0.0)
	check("dodge changes actual spatial position", player.position.distance_to(before_roll) > 10.0)
	await _frames(4)

	player.hp = player.max_hp * 0.4
	var health_count: int = GameState.potions
	await _tap(JOY_BUTTON_LEFT_SHOULDER)
	check("LB consumes one actual health potion", GameState.potions == health_count - 1 and player.hp > player.max_hp * 0.4)
	player.resource = 1.0
	var mana_count: int = GameState.mana_potions
	await _tap(JOY_BUTTON_DPAD_UP)
	check("D-pad up consumes one actual resource potion", GameState.mana_potions == mana_count - 1 and player.resource > 40.0)

	await _tap(JOY_BUTTON_START)
	check("Menu opens actual settings and pauses the world", get_tree().paused and game.hud.panel_open() and game.hud._panel is SettingsPanel)
	origin = player.position
	serial = player._action_serial
	_axis(JOY_AXIS_LEFT_X, 0.85)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.9)
	await _frames(10)
	check("paused settings blocks combat and movement", player.position.distance_to(origin) < 0.2 and player._action_serial == serial and Gamepad.held_slots().is_empty())
	_neutral()
	await _frames(5)
	await _tap(JOY_BUTTON_B)
	check("B closes actual settings", not get_tree().paused and not game.hud.panel_open())

	_button(JOY_BUTTON_A, true)
	_axis(JOY_AXIS_LEFT_X, 0.7)
	await _frames(2)
	Input.joy_connection_changed.emit(DEVICE, false)
	origin = player.position
	await _frames(4)
	check("disconnect clears held pad movement and attacks", Gamepad.active_device < 0 and Gamepad.move_vector() == Vector2.ZERO and Gamepad.held_slots().is_empty())
	Input.joy_connection_changed.emit(DEVICE, true)
	_button(JOY_BUTTON_A, true)
	_axis(JOY_AXIS_LEFT_X, 0.7)
	await _frames(4)
	serial = player._action_serial
	origin = player.position
	await _frames(8)
	check("reconnect while held requires release before actions", player._action_serial == serial and player.position.distance_to(origin) < 0.2)
	_neutral()
	await _frames(5)

	_button(JOY_BUTTON_A, true)
	_axis(JOY_AXIS_LEFT_X, 0.7)
	await _frames(2)
	Gamepad.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(3)
	check("real game focus notification pauses and clears pad actions", get_tree().paused and game.hud.panel_open() and Gamepad.move_vector() == Vector2.ZERO and Gamepad.held_slots().is_empty())
	Gamepad.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	_neutral()
	await _frames(6)
	await _tap(JOY_BUTTON_B)
	check("pad resumes after focus return and neutral release", not get_tree().paused and not game.hud.panel_open())

	origin = player.position
	_key(KEY_D, true)
	check("keyboard still moves after pad use", await _until(func(): return player.position.distance_to(origin) > 5.0))
	_key(KEY_D, false)
	check("keyboard switches modality without deleting pad support", not Gamepad.using_gamepad)
	_neutral()
	await _frames(5)

	# A live enemy's ordinary wind-up/contact causes death. Damage is fixture data,
	# not a direct call to take_damage(), cast_slot(), roll(), or a gamepad action.
	var field: Vector2 = game.village.point(Vector2(0.5, 1.15))
	var placed := false
	var foe_position := Vector2.ZERO
	for offset: Vector2 in [Vector2.ZERO, Vector2(120, 0), Vector2(-120, 0), Vector2(0, 120)]:
		var point: Vector2 = field + offset
		for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var candidate: Vector2 = point + direction * 52.0
			if not game._blocked(point, Player.RADIUS) and not game._blocked(candidate, Enemy.radius_for("goblin")) and game.can_melee_reach(candidate, point):
				field = point
				foe_position = candidate
				placed = true
				break
		if placed:
			break
	check("death-boundary fixture has a legal physical enemy approach", placed)
	if placed:
		player.position = field
		var enemy := Enemy.new()
		enemy.setup(game, "goblin", 1)
		enemy.position = foe_position
		enemy.hp = 10000.0
		enemy.max_hp = 10000.0
		enemy.damage = player.max_hp * 5.0
		enemy._state = "chase"
		game.world.add_child(enemy)
		game.enemies.append(enemy)
		await get_tree().physics_frame
		await _frames(3)
		_button(JOY_BUTTON_A, true)
		check("actual enemy contact kills the held-input player", await _until(func(): return player.dead, 5000))
		check("death immediately blocks pad holds", Gamepad.held_slots().is_empty() and Gamepad.move_vector() == Vector2.ZERO)
		check("existing automatic respawn completes", await _until(func(): return not player.dead, 4500))
		serial = player._action_serial
		await get_tree().create_timer(0.8, false).timeout
		check("held pre-death A cannot restart attacks after revival", player._action_serial == serial and Gamepad.held_slots().is_empty())
	_neutral()
	Input.joy_connection_changed.emit(DEVICE, false)
	_key(KEY_D, false)
	get_tree().paused = false
	game.queue_free()
	await _frames(3)

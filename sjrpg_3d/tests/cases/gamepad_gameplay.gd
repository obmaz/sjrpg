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


	# Add a real focus scope between navigation polls, without Hud._open's own gate.
	# Flush the raw event now so an old-context edge cannot be hidden by the next poll.
	var external := PanelFrame.new()
	game.hud.add_child(external)
	external.set_header("외부 이벤트")
	var activations: Array[int] = [0]
	var external_action := UiKit.button("실제 동작")
	external_action.pressed.connect(func(): activations[0] += 1)
	external.body.add_child(external_action)
	_button(JOY_BUTTON_A, true)
	Input.flush_buffered_events()
	await _frames(2)
	check("external menu before raw A discards old-context edge", activations[0] == 0)
	_button(JOY_BUTTON_A, false)
	await _frames(5)
	_button(JOY_BUTTON_A, true)
	await _frames(2)
	check("external menu accepts fresh real A after neutral release", activations[0] == 1)
	_button(JOY_BUTTON_A, false)
	external.free()
	await _frames(6)

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

	# 입력 전환 검사는 커진 우물/주민에 막히지 않는 광장 바닥에서 수행한다.
	game.spatial_world.teleport_source_actor(player, game.village.spawn_point + Vector2(0, 180), Player.RADIUS)
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

	# A second real world regresses targeted leap impact while RS keeps overwriting facing.
	# The target is 40 degrees off-axis but inside the real manual acquisition cone.
	var warrior_game: Node = await make_game("warrior")
	warrior_game.encounters.set_process(false)
	warrior_game._spawn_timer = 3600.0
	for ambient: Enemy in warrior_game.enemies:
		ambient.queue_free()
	warrior_game.enemies.clear()
	await get_tree().physics_frame
	await _frames(2)
	var warrior: Player = warrior_game.player
	GameState.level = 18
	GameState.ranks = {"cleave": 1, "howl": 1, "leap": 1, "leapAttack": 1}
	GameState.slots = ["cleave", "leapAttack", "", "", ""]
	warrior.refresh_stats(true)
	warrior.resource = warrior.resource_max
	Input.joy_connection_changed.emit(DEVICE, true)
	_neutral()
	await _frames(6)
	var leap_origin: Vector2 = warrior_game.village.point(Vector2(0.5, 1.15))
	var leap_target_point := Vector2.ZERO
	var leap_legal := false
	for offset: Vector2 in [Vector2.ZERO, Vector2(180, 0), Vector2(-180, 0), Vector2(0, 200)]:
		var point: Vector2 = leap_origin + offset
		var direction: Vector2 = Vector2.from_angle(deg_to_rad(40.0))
		var candidate: Vector2 = point + direction * 180.0
		var intended_landing: Vector2 = candidate - direction * 36.0
		if not warrior_game._blocked(point, Player.RADIUS) and not warrior_game._blocked(candidate, Enemy.radius_for("goblin")) and not warrior_game._blocked(intended_landing, Player.RADIUS) and warrior_game.can_melee_reach(point, candidate):
			leap_origin = point
			leap_target_point = candidate
			leap_legal = true
			break
	check("off-axis leap fixture has legal actual terrain and approach", leap_legal)
	if leap_legal:
		warrior.position = leap_origin
		var target := Enemy.new()
		target.setup(warrior_game, "goblin", 1)
		target.position = leap_target_point
		target.hp = 500.0
		target.max_hp = 500.0
		target.damage = 0.0
		target.speed = 0.0
		target._timer = 100.0
		warrior_game.world.add_child(target)
		warrior_game.enemies.append(target)
		await get_tree().physics_frame
		await _frames(5)
		_axis(JOY_AXIS_RIGHT_X, 0.9)
		_axis(JOY_AXIS_RIGHT_Y, 0.0)
		await _frames(3)
		check("targeted leap fixture has only the intended attackable body", warrior_game.enemies.size() == 1 and warrior_game.enemies[0] == target)
		var target_hp: float = target.hp
		var leap_serial: int = warrior._action_serial
		_button(JOY_BUTTON_X, true)
		await _frames(2)
		_button(JOY_BUTTON_X, false)
		check("off-axis X leap reaches actual impact damage with RS held", await _until(func(): return is_instance_valid(target) and target.hp < target_hp, 2500), JSON.stringify({"serial_before": leap_serial, "serial_after": warrior._action_serial, "cooldowns": warrior.cooldowns, "from": [leap_origin.x, leap_origin.y], "landing": [warrior.position.x, warrior.position.y], "target": [leap_target_point.x, leap_target_point.y]}))
		if is_instance_valid(target):
			var landing_distance: float = warrior.position.distance_to(target.position)
			check("off-axis leap lands within physical target plus slam reach", landing_distance <= target.radius + 70.0, str(landing_distance))
			check("off-axis leap traveled toward selected body rather than raw RS", absf(angle_difference((warrior.position - leap_origin).angle(), deg_to_rad(40.0))) < deg_to_rad(12.0))
	_neutral()
	Input.joy_connection_changed.emit(DEVICE, false)
	warrior_game.queue_free()
	await _frames(3)

extends TestCase
## Real mouse dispatch must share mobile casts, respect GUI, and undo both render transforms.

var _received_mouse := Vector2.ZERO


func run() -> void:
	var previous_quality := Prefs.low_resolution
	Prefs.set_low_resolution(false)
	var game := await make_game("mage")
	var player: Player = game.player
	var controls: TouchControls = game.hud.controls
	player.set_process(false)
	# Sanctuary recovery has its own tick; isolate cast costs from both recovery sources.
	game.exploration.set_process(false)
	game.camera.position_smoothing_enabled = false
	var point := get_viewport().get_visible_rect().size * Vector2(0.42, 0.44)
	player.resource = player.resource_max
	_mouse(MOUSE_BUTTON_LEFT, point, true)
	await _frames(2)
	check("world left-click casts the equipped primary and holds it", player.cooldowns.get("firebolt", 0.0) > 0.0 and player.held_slots.get(0, false))
	check("desktop world click cannot start the virtual joystick", controls._stick_index == -2 and player.move_input == Vector2.ZERO)
	_mouse(MOUSE_BUTTON_LEFT, point, false)
	await _frames(1)
	check("mouse release stops held primary attack", not player.held_slots.get(0, false))
	var resource := player.resource
	var reuse: float = player.cooldowns["firebolt"]
	_mouse(MOUSE_BUTTON_LEFT, point, true)
	await _frames(1)
	_mouse(MOUSE_BUTTON_LEFT, point, false)
	await _frames(1)
	check("mouse recast cannot bypass cooldown or spend resource", player.resource == resource and player.cooldowns["firebolt"] == reuse, "resource %s→%s reuse %s→%s processing=%s mouse=%s expected=%s" % [resource, player.resource, reuse, player.cooldowns["firebolt"], player.is_processing(), _received_mouse, point])
	player._cancel_actions()
	player.cooldowns.clear()
	player.resource = 0.0
	_mouse(MOUSE_BUTTON_LEFT, point, true)
	await _frames(1)
	_mouse(MOUSE_BUTTON_LEFT, point, false)
	await _frames(1)
	check("mouse primary preserves the mana check", player.cooldowns.is_empty() and player._attack_time == 0.0)
	player.resource = player.resource_max
	for slot in range(1, 5):
		GameState.assign_slot(slot, "firebolt")
		player._cancel_actions()
		player.cooldowns.clear()
		_key(KEY_0 + slot, true)
		await _frames(1)
		_key(KEY_0 + slot, false)
		await _frames(1)
		check("number key casts auxiliary slot %d" % slot, player.cooldowns.get("firebolt", 0.0) > 0.0)
		var serial := player._action_serial
		player._attack_time = 0.0
		player.cooldowns.clear()
		_key(KEY_0 + slot, true, true)
		await _frames(1)
		_key(KEY_0 + slot, false)
		await _frames(1)
		check("number-key echo cannot cast again %d" % slot, player._action_serial == serial)
	player._cancel_actions()
	player.cooldowns.clear()
	for economy in [false, true]:
		Prefs.set_low_resolution(economy)
		await _frames(3)
		game.camera.force_update_scroll()
		# Camera framing can place a fixed world offset beneath a real skill button.
		# Exercise world input at a clear rendered point; GUI interception is tested below.
		var target := Vector2.ZERO
		var screen := Vector2.ZERO
		var found := false
		for offset: Vector2 in [Vector2(110, 25), Vector2(-90, 15), Vector2(70, -45), Vector2(-70, -45)]:
			var painted: Vector2 = player.get_global_transform_with_canvas() * offset
			var candidate: Vector2 = painted * get_viewport().get_visible_rect().size / game.scene_view.get_visible_rect().size
			if controls._hit_button(candidate) == "" and not game._blocked(player.position + offset, Player.RADIUS):
				target = player.position + offset
				screen = candidate
				found = true
				break
		check("mouse destination is visible world rather than a HUD button", found)
		check("mouse projection agrees with actual rendered hero at quality %s" % economy, game.screen_to_world(screen).distance_to(target) < 0.01)
		_mouse(MOUSE_BUTTON_RIGHT, screen, true)
		await _frames(1)
		_mouse(MOUSE_BUTTON_RIGHT, screen, false)
		await _frames(1)
		check("right-click retains the correct world destination %s" % economy, player.has_move_target and player.move_target.distance_to(target) < 0.01, "active=%s target=%s expected=%s sent=%s received=%s hit=%s" % [player.has_move_target, player.move_target, target, screen, _received_mouse, controls._hit_button(_received_mouse)])
		var from := player.position
		player._process(0.05)
		check("point movement approaches its destination %s" % economy, player.position.distance_to(target) < from.distance_to(target))
		Input.action_press("move_left")
		player._process(0.05)
		Input.action_release("move_left")
		check("WASD overrides and cancels point movement %s" % economy, not player.has_move_target)
	player.set_move_target(player.position + Vector2(100, 0))
	var serial := player._action_serial
	controls._layout()
	_mouse(MOUSE_BUTTON_LEFT, controls._buttons["bar_bag"]["center"], true)
	await _frames(2)
	check("HUD mouse click opens its panel without a world attack", game.hud.panel_open() and player._action_serial == serial and not player.has_move_target)
	_mouse(MOUSE_BUTTON_LEFT, point, false)
	_mouse(MOUSE_BUTTON_RIGHT, point, true)
	await _frames(1)
	check("modal blocks right-click destination input", not player.has_move_target)
	_mouse(MOUSE_BUTTON_RIGHT, point, false)
	game.hud.close_panel()
	await _frames(2)
	_mouse(MOUSE_BUTTON_RIGHT, controls._buttons["bar_bag"]["center"], true)
	await _frames(1)
	check("right-click over a drawn HUD button cannot move the hero", not player.has_move_target, "target=%s sent=%s received=%s hit=%s" % [player.move_target, controls._buttons["bar_bag"]["center"], _received_mouse, controls._hit_button(_received_mouse)])
	_mouse(MOUSE_BUTTON_RIGHT, point, false)
	# A small real collision directly ahead exercises the same sub-stepped movement as walls.
	player._cancel_actions()
	var origin := player.position
	game.village.circles.append([origin + Vector2(40, 0), 10.0])
	player.set_move_target(origin + Vector2(160, 0))
	player._process(0.5)
	check("point movement stops at collision without tunnelling", not player.has_move_target and player.position.x < origin.x + 30.0)
	game.village.circles.pop_back()
	for delta in [0.01, 0.1, 0.5]:
		player.position = origin
		player.set_move_target(origin + Vector2(0, 15))
		player._process(delta)
		check("near destinations advance without overshooting at delta %s" % delta, player.position.y > origin.y and player.position.y <= origin.y + 15.01)
		if delta >= 0.1:
			check("long frames arrive rather than abandoning a nearby point", not player.has_move_target and player.position.distance_to(player.move_target) <= 3.0)
	player.set_move_target(player.position)
	player._process(0.01)
	check("arrival clears point movement", not player.has_move_target)
	player.set_move_target(player.position + Vector2(100, 0))
	player._cancel_actions()
	check("death/revive cancellation also discards the old destination", not player.has_move_target)
	GameState.assign_slot(0, "firebolt")
	controls.hold_mouse_primary()
	controls._press(51, controls._buttons["slot0"]["center"])
	player._invulnerable = 0.0
	player.take_damage(player.max_hp * 100.0)
	check("mage death clears combined mouse and touch holds", player.dead and controls._held.is_empty() and player.held_slots.is_empty())
	controls.hold_mouse_primary()
	controls._press(52, controls._buttons["slot0"]["center"])
	check("dead mage cannot register a new primary hold", controls._held.is_empty() and player.held_slots.is_empty())
	player.revive(player.position)
	for pointer in [-1, 51, 52]:
		controls._release(pointer)
	check("old pointer releases cannot restart the revived mage", player.held_slots.is_empty())
	game.queue_free()
	await _frames(2)
	Prefs.set_low_resolution(previous_quality)


func _mouse(button: MouseButton, at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	event.pressed = down
	# Positions above are logical viewport units, not headless window pixels.
	# Keep GUI and unhandled dispatch while avoiding a second window stretch transform.
	get_viewport().push_input(event, true)


func _key(code: int, down: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	event.echo = echo
	Input.parse_input_event(event)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_received_mouse = event.position

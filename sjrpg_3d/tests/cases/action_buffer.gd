extends TestCase


func run() -> void:
	for cls: String in ["warrior", "mage"]:
		var game := await make_game(cls)
		var player: Player = game.player
		player.set_process(false)
		game.set_process(false)
		var id: String = GameState.slots[0]
		for fps: int in [30, 60]:
			player._cancel_actions()
			player.cooldowns.clear()
			player.resource = player.resource_max
			player._attack_time = 0.09
			player._attack_duration = 0.4
			var serial := player._action_serial
			var resource := player.resource
			check(
				"late tap waits without spending or starting a new action " + cls,
				(
					not player.cast_slot(0)
					and player.action_buffer.slot == 0
					and player.resource == resource
					and player._action_serial == serial
				)
			)
			for frame: int in fps / 10:
				player._process(1.0 / fps)
			check(
				"last tap starts exactly once at the first free frame %s/%d" % [cls, fps],
				(
					player._action_serial == serial + 1
					and player.action_buffer.slot < 0
					and player._attack_time > 0.0
				)
			)
			player._pending = Callable()
		player._cancel_actions()
		player.cooldowns.clear()
		player._attack_time = 0.095
		player._attack_duration = 0.4
		player.resource = player.resource_max
		var late_serial := player._action_serial
		player.cast_slot(0)
		for frame in 3:
			player._process(0.04)
		check(
			"a deadline between frames executes at its first available frame",
			player._action_serial == late_serial + 1
		)
		player._cancel_actions()
		player.cooldowns[id] = 0.09
		player.resource = player.resource_max
		var serial := player._action_serial
		player.cast_slot(0)
		check(
			"held repeat cannot overwrite a pending tap",
			not player.cast_slot(0, true) and player.action_buffer.skill == id
		)
		for frame in 6:
			player._process(1.0 / 60.0)
		check(
			"reuse expiry executes the queued command without early cooldown changes " + cls,
			player._action_serial == serial + 1
		)
		player._cancel_actions()
		player.cooldowns.clear()
		player._attack_time = 0.25
		player.cast_slot(0)
		check("early mash does not create a delayed attack", player.action_buffer.slot < 0)
		player._attack_time = 0.08
		player.cast_slot(0)
		player.action_buffer.advance(0.2)
		player._attack_time = 0.0
		serial = player._action_serial
		player._consume_buffered_action()
		check(
			"an expired tap never fires later",
			player.action_buffer.slot < 0 and serial == player._action_serial
		)
		player._attack_time = 0.08
		player.cast_slot(0)
		GameState.slots[0] = ""
		player._attack_time = 0.0
		player._consume_buffered_action()
		check(
			"slot replacement drops the old command",
			player.action_buffer.slot < 0 and serial == player._action_serial
		)
		GameState.slots[0] = id
		var key := InputEventAction.new()
		key.action = "attack"
		key.pressed = true
		player._attack_time = 0.08
		game._unhandled_input(key)
		check("single keyboard action reaches the same buffer", player.action_buffer.slot == 0)
		player._attack_time = 0.08
		player.cast_slot(0)
		game.hud.controls.release_all()
		check("menu and region input release clear queued taps", player.action_buffer.slot < 0)
		player.cast_slot(0)
		player.warp_locked = true
		player._process(0.01)
		check("warp cannot carry an old command to arrival", player.action_buffer.slot < 0)
		player.warp_locked = false
		player.cast_slot(0)
		player.try_roll()
		check("a dodge replaces the attack intent", player.action_buffer.slot < 0)
		player._cancel_actions()
		player._attack_time = 0.08
		player.cast_slot(0)
		player._cancel_actions()
		check("death and action cancellation clear intent", player.action_buffer.slot < 0)
		if cls == "mage":
			player._attack_time = 0.08
			player.resource = 0.0
			player.cast_slot(0)
			player.resource = player.resource_max
			player._attack_time = 0.0
			serial = player._action_serial
			player._consume_buffered_action()
			check(
				"insufficient mana does not queue a future surprise cast",
				player.action_buffer.slot < 0 and serial == player._action_serial
			)
		game.queue_free()
		await _frames(3)

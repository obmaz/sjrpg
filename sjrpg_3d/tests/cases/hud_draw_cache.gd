extends TestCase
## Retained HUD commands must update for real state changes without idle rebuilds.


func _tick(hud: Hud, controls: TouchControls, delta := 0.1) -> void:
	hud._process(delta)
	controls._process(delta)


func run() -> void:
	var old_motion := Prefs.reduce_motion
	var old_pad := Gamepad.using_gamepad
	var game := await make_game("mage")
	var player: Player = game.player
	var hud: Hud = game.hud
	var controls: TouchControls = hud.controls
	# Keep gameplay outside this rendering test; timers below remain authoritative player state.
	game.set_process(false)
	player.set_process(false)
	hud.set_process(false)
	controls.set_process(false)
	player.hp = player.max_hp
	player.resource = player.resource_max
	player.cooldowns.clear()
	GameState.potions = 3
	Gamepad.using_gamepad = false
	_tick(hud, controls, 1.0)
	var bars := hud.bars_redraw_requests
	var area := hud.area_redraw_requests
	var buttons := controls.redraw_requests
	for frame in 120:
		_tick(hud, controls)
	check("full-health mana HUD retains bar and area commands through idle frames",
		hud.bars_redraw_requests == bars and hud.area_redraw_requests == area)
	check("idle control art retains its draw commands", controls.redraw_requests == buttons)
	check("mana glints have their own retained canvas and ignore pointer input",
		hud._mana_shimmer != null and hud._mana_shimmer.get_parent() == hud._bars
		and hud._mana_shimmer.mouse_filter == Control.MOUSE_FILTER_IGNORE)

	player.hp = player.max_hp * 0.6
	_tick(hud, controls, 0.0)
	check("damage invalidates visible health and starts feedback", hud.bars_redraw_requests > bars and hud._hurt_feedback > 0.0)
	bars = hud.bars_redraw_requests
	_tick(hud, controls, 0.1)
	check("health trail and hit feedback keep animating", hud.bars_redraw_requests > bars)
	for frame in 6:
		_tick(hud, controls, 0.5)
	bars = hud.bars_redraw_requests
	for frame in 30:
		_tick(hud, controls)
	check("settled health retains its last commands again", hud.bars_redraw_requests == bars)

	bars = hud.bars_redraw_requests
	buttons = controls.redraw_requests
	player.resource = 0.0
	_tick(hud, controls)
	check("resource changes update gauges and skill affordability",
		hud.bars_redraw_requests > bars and controls.redraw_requests > buttons)
	player.resource = player.resource_max
	_tick(hud, controls)
	buttons = controls.redraw_requests
	player.cooldowns["firebolt"] = 0.5
	_tick(hud, controls)
	check("authoritative cooldown start redraws its wedge and text", controls.redraw_requests > buttons)
	buttons = controls.redraw_requests
	player.cooldowns["firebolt"] = 0.35
	_tick(hud, controls)
	check("continuous cooldown progress remains visible", controls.redraw_requests > buttons)
	buttons = controls.redraw_requests
	GameState.assign_slot(4, "firebolt")
	_tick(hud, controls)
	check("moving a cooling skill invalidates both equipped slots",
		controls.redraw_requests > buttons and controls.slot_cooldown_remaining(0) == 0.0
		and is_equal_approx(controls.slot_cooldown_remaining(4), 0.35))
	player.cooldowns.clear()
	_tick(hud, controls)
	_tick(hud, controls, 1.0)
	buttons = controls.redraw_requests
	_tick(hud, controls)
	check("the ready flash expires and returns to retained drawing", controls.redraw_requests == buttons)

	buttons = controls.redraw_requests
	GameState.potions -= 1
	_tick(hud, controls)
	check("keyboard or external potion use updates count and feedback",
		controls.redraw_requests > buttons and controls._success_feedback.has("potion_hp"))
	_tick(hud, controls, 1.0)
	_tick(hud, controls)

	buttons = controls.redraw_requests
	var stick := controls._stick_center
	check("a real touch can still acquire the movement stick", controls._press(51, stick))
	controls._drag(51, stick + Vector2.RIGHT * 30.0)
	_tick(hud, controls)
	check("finger movement redraws the displaced knob", controls.redraw_requests > buttons and player.move_input.x > 0.0)
	buttons = controls.redraw_requests
	for frame in 30:
		_tick(hud, controls)
	check("a steady movement finger retains the same joystick commands", controls.redraw_requests == buttons)
	controls._drag(51, stick + Vector2.DOWN * 35.0)
	_tick(hud, controls)
	check("a changed movement direction redraws the knob", controls.redraw_requests > buttons)
	buttons = controls.redraw_requests
	controls._release(51)
	_tick(hud, controls)
	check("finger release repaints the resting stick and clears movement",
		controls.redraw_requests > buttons and player.move_input == Vector2.ZERO)

	buttons = controls.redraw_requests
	Gamepad.using_gamepad = true
	_tick(hud, controls)
	check("input mode changes invalidate joystick visibility and Xbox hints", controls.redraw_requests > buttons)
	Gamepad.using_gamepad = false
	_tick(hud, controls)
	buttons = controls.redraw_requests
	player.position = game.village.npc_points["대장장이"]
	_tick(hud, controls)
	check("live NPC proximity updates the interaction prompt",
		controls.redraw_requests > buttons and controls._near_name == "대장장이" and controls._buttons.has("near_shop"))
	buttons = controls.redraw_requests
	player.position = game.village.portal_point
	_tick(hud, controls)
	check("changing to a warp target updates its larger prompt",
		controls.redraw_requests > buttons and controls._near_name == "워프게이트")

	area = hud.area_redraw_requests
	player.position = Vector2(100000.0, 100000.0)
	_tick(hud, controls)
	check("a changed world area invalidates its label", hud.area_redraw_requests > area and hud._area_name == "숲 가장자리")
	area = hud.area_redraw_requests
	_tick(hud, controls)
	check("an unchanged area label keeps its commands", hud.area_redraw_requests == area)
	bars = hud.bars_redraw_requests
	Prefs.reduce_motion = not old_motion
	_tick(hud, controls)
	check("motion preference changes invalidate the HUD without removing the cue",
		hud.bars_redraw_requests > bars and hud._mana_shimmer.visible)
	if Prefs.reduce_motion:
		check("reduced motion uses the original steady shimmer strength", is_equal_approx(hud._mana_shimmer.self_modulate.a, 0.65))
	GameState.xp += 1
	bars = hud.bars_redraw_requests
	_tick(hud, controls)
	check("experience progress updates its retained gauge", hud.bars_redraw_requests > bars)

	Prefs.reduce_motion = old_motion
	Gamepad.using_gamepad = old_pad
	game.queue_free()
	await _frames(2)

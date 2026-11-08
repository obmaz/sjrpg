extends TestCase
## Continuous reuse feedback must not rebuild static controls or the movement seal.


func run() -> void:
	var old_pad := Gamepad.using_gamepad
	var old_motion := Prefs.reduce_motion
	var game := await make_game("mage")
	var player: Player = game.player
	var controls: TouchControls = game.hud.controls
	game.set_process(false)
	player.set_process(false)
	game.hud.set_process(false)
	controls.set_process(false)
	Gamepad.using_gamepad = false
	Prefs.reduce_motion = false
	player.resource = player.resource_max
	player.cooldowns.clear()
	GameState.potions = 3
	controls._process(1.0)
	controls._process(1.0)
	check("movement stays below button art and Xbox cues stay above action overlays",
		controls._stick_layer.show_behind_parent
		and controls._overlay_layer.get_index() < controls._hints_layer.get_index())
	check("retained drawing layers do not intercept input",
		controls._stick_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and controls._overlay_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and controls._hints_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE)

	var reuse := SkillDefs.cooldown(GameState.skill("firebolt"))
	check("the test uses a real reusable equipped spell", reuse > 0.0 and GameState.slots[0] == "firebolt")
	player.cooldowns["firebolt"] = reuse
	controls._process(0.0)
	var base := controls.base_redraw_requests
	var stick := controls.stick_redraw_requests
	var hints := controls.hints_redraw_requests
	var overlay := controls.overlay_redraw_requests
	for frame in 120:
		player.cooldowns["firebolt"] = reuse * (1.0 - float(frame + 1) * 0.99 / 120.0)
		controls._process(0.0)
	check("120 continuous cooldown changes retain static button, joystick and hint commands",
		controls.base_redraw_requests == base and controls.stick_redraw_requests == stick
		and controls.hints_redraw_requests == hints)
	check("the cooldown overlay still repaints every changed wedge and countdown",
		controls.overlay_redraw_requests == overlay + 120)

	var main: Dictionary = controls._buttons["slot0"]
	check("a cooling skill still accepts a real held pointer", controls._press(61, main["center"]))
	controls._process(0.0)
	check("pressed art invalidates once on the actual press", controls.base_redraw_requests > base)
	base = controls.base_redraw_requests
	for frame in 20:
		controls._process(0.01)
	check("held pressed art stays retained while its input-feedback timer changes",
		controls.base_redraw_requests == base)
	controls._release(61)
	controls._process(1.0)
	check("releasing the final pointer repaints the resting art",
		controls.base_redraw_requests > base and not player.held_slots.get(0, false))

	base = controls.base_redraw_requests
	overlay = controls.overlay_redraw_requests
	stick = controls.stick_redraw_requests
	var center := controls._stick_center
	check("the floating movement stick remains usable", controls._press(62, center))
	controls._drag(62, center + Vector2.RIGHT * 30.0)
	controls._process(0.0)
	check("dragging only rebuilds the movement layer",
		controls.stick_redraw_requests > stick and controls.base_redraw_requests == base
		and controls.overlay_redraw_requests == overlay)
	stick = controls.stick_redraw_requests
	controls._drag(62, center + Vector2.DOWN * 35.0)
	controls._process(0.0)
	check("direction changes repaint only the knob canvas",
		controls.stick_redraw_requests > stick and controls.base_redraw_requests == base)
	stick = controls.stick_redraw_requests
	for frame in 30:
		controls._process(0.0)
	check("a steady movement finger retains its last seal and knob", controls.stick_redraw_requests == stick)
	controls._release(62)
	controls._process(0.0)
	check("releasing movement restores the stick without rebuilding buttons",
		controls.base_redraw_requests == base and player.move_input == Vector2.ZERO)

	base = controls.base_redraw_requests
	overlay = controls.overlay_redraw_requests
	GameState.potions -= 1
	controls._process(0.0)
	check("external potion use updates both count and success cue",
		controls.base_redraw_requests > base and controls.overlay_redraw_requests > overlay)
	base = controls.base_redraw_requests
	overlay = controls.overlay_redraw_requests
	controls._process(0.1)
	check("success-ring fading only rebuilds action feedback",
		controls.base_redraw_requests == base and controls.overlay_redraw_requests > overlay)
	player.resource = 0.0
	controls._process(0.0)
	check("an affordability change still invalidates the painted skill tint", controls.base_redraw_requests > base)
	base = controls.base_redraw_requests
	overlay = controls.overlay_redraw_requests
	var remaining := controls.slot_cooldown_remaining(0)
	GameState.assign_slot(4, "firebolt")
	controls._process(0.0)
	check("moving a cooling skill updates static icons and its overlay without resetting reuse",
		controls.base_redraw_requests > base and controls.overlay_redraw_requests > overlay
		and controls.slot_cooldown_remaining(0) == 0.0
		and is_equal_approx(controls.slot_cooldown_remaining(4), remaining))

	base = controls.base_redraw_requests
	overlay = controls.overlay_redraw_requests
	Prefs.reduce_motion = true
	controls._process(0.0)
	check("motion preference updates animated rings without rebuilding static icons",
		controls.base_redraw_requests == base and controls.overlay_redraw_requests > overlay)
	hints = controls.hints_redraw_requests
	Gamepad.using_gamepad = true
	controls._process(0.0)
	check("switching to Xbox cues invalidates hints and hides only the movement canvas",
		controls.hints_redraw_requests > hints and not controls._stick_layer.visible
		and controls._hints_layer.visible)

	Gamepad.using_gamepad = old_pad
	Prefs.reduce_motion = old_motion
	game.queue_free()
	await _frames(2)

extends TestCase
## Full-screen danger feedback must be readable, input-transparent and tied to live health.


func run() -> void:
	var old_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var game := await make_game()
	game.set_process(false)
	game.player.set_process(false)
	var hud: Hud = game.hud
	hud.set_process(false)
	var player: Player = game.player
	hud._update_critical_warning(0.0)
	check("healthy heroes have no danger tint", not hud._critical_warning.visible)
	player.hp = player.max_hp * 0.29
	hud._update_critical_warning(0.0)
	check("low health warns across the entire viewport", hud._critical_warning.visible and hud._critical_warning.get_global_rect() == get_viewport().get_visible_rect())
	check("warning never intercepts controls", hud._critical_warning.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var bright := hud._critical_warning.color.a
	hud._update_critical_warning(0.5)
	check("danger tint pulses slowly while remaining translucent", bright > hud._critical_warning.color.a + 0.015 and bright < 0.16 and hud._critical_warning.color.a > 0.04)
	Prefs.reduce_motion = true
	hud._update_critical_warning(0.0)
	var steady := hud._critical_warning.color
	hud._update_critical_warning(0.4)
	check("reduced motion retains a steady warning without blinking", hud._critical_warning.color == steady)
	Prefs.reduce_motion = false
	hud._update_critical_warning(0.0)
	var phase := hud._critical_clock
	var paused_color := hud._critical_warning.color
	hud.set_process(true)
	get_tree().paused = true
	await get_tree().create_timer(0.06).timeout
	check("pause freezes the danger pulse", hud._critical_clock == phase and hud._critical_warning.color == paused_color)
	get_tree().paused = false
	hud.set_process(false)
	player.dead = true
	hud._update_critical_warning(0.0)
	check("death stops the low-health blink", not hud._critical_warning.visible)
	player.dead = false
	player.hp = 0.0
	hud._update_critical_warning(0.0)
	check("zero health cannot pulse between death updates", not hud._critical_warning.visible)
	player.hp = player.max_hp * 0.3
	hud._update_critical_warning(0.0)
	check("recovering to the threshold clears the warning and its clock", not hud._critical_warning.visible and hud._critical_clock == 0.0)
	# The explicit browser audit keeps actors still without freezing the genuine HUD clock.
	hud.set_process(true)
	await game._hud_preview("danger")
	var audit_hp := player.hp
	var audit_clock := hud._critical_clock
	await get_tree().create_timer(0.08).timeout
	check("danger preview holds genuine low-health state", not player.is_processing() and player.hp == audit_hp and audit_hp / player.max_hp < 0.3, str([player.is_processing(), player.hp, audit_hp, player.max_hp]))
	check("danger preview keeps the real HUD pulse running", hud._critical_clock != audit_clock and not get_tree().paused)
	Prefs.reduce_motion = old_reduce
	game.queue_free()
	await _frames(2)

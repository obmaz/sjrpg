extends TestCase
## Reuse time is gameplay state, not a separate HUD countdown.

func run() -> void:
	var game := await make_game("mage")
	var player: Player = game.player
	var controls: TouchControls = game.hud.controls
	player.set_process(false)
	for skill in GameState.skills():
		var id: String = skill["id"]
		var reuse := SkillDefs.cooldown(skill)
		if skill["passive"] and not skill["basic"]:
			check("passives have no reuse timer: " + id, reuse == 0.0)
		elif id != "sorceressAttack":
			check("every active spell has a reuse timer: " + id, reuse > 0.0)
		if float(skill["cooldown"]) > 0.0:
			check("positive source cooldown stays intact: " + id, reuse == float(skill["cooldown"]))
	check("source spell catalog remains unmodified", GameState.skill("firebolt")["cooldown"] == 0.0)
	player.resource = player.resource_max
	check("first magic cast succeeds", player.cast_slot(0))
	var remaining: float = player.cooldowns.get("firebolt", 0.0)
	var resource: float = player.resource
	check("successful cast starts authoritative reuse timer", remaining == SkillDefs.cooldown(GameState.skill("firebolt")))
	player._attack_time = 0.0
	check("magic cannot be cast again during reuse", not player.cast_slot(0))
	check("rejected recast spends no mana and does not restart cooldown", player.resource == resource and player.cooldowns["firebolt"] == remaining)
	player.cooldowns["firebolt"] = 0.35
	controls._update_action_feedback()
	check("main slot reads remaining game seconds", is_equal_approx(controls.slot_cooldown_remaining(0), 0.35))
	check("main sweep uses same reuse duration", is_equal_approx(player.slot_cooldown_ratio(0), 0.65))
	GameState.assign_slot(4, "firebolt")
	controls._update_action_feedback()
	check("moving a spell keeps its cooldown on the auxiliary button", controls.slot_cooldown_remaining(0) == 0.0 and is_equal_approx(controls.slot_cooldown_remaining(4), 0.35))
	check("slot replacement creates no false ready flash", not controls._success_feedback.has("slot0") and not controls._success_feedback.has("slot4"))
	player._tick_timers(0.4)
	controls._update_action_feedback()
	check("reuse expiration clears display and confirms ready", controls.slot_cooldown_remaining(4) == 0.0 and controls._success_feedback.has("slot4"))
	check("magic becomes usable when timer expires", player.cast_slot(4))
	player._attack_time = 0.0
	player.cooldowns.clear()
	player.resource = 0.0
	check("failed mana check starts no reuse timer", not player.cast_slot(4) and player.cooldowns.is_empty() and player.resource == 0.0)
	check("sub-second countdown never displays zero while unavailable", TouchControls.cooldown_text(0.001) == "0.1" and TouchControls.cooldown_text(0.35) == "0.4")
	check("whole-second display rounds remaining time up", TouchControls.cooldown_text(1.001) == "2" and TouchControls.cooldown_text(5.0) == "5")
	check("ready and empty slots show no countdown", TouchControls.cooldown_text(0.0) == "" and controls.slot_cooldown_remaining(1) == 0.0)
	GameState.assign_slot(0, "firebolt")
	controls._update_action_feedback()
	check("ready flash is cleared when its spell leaves the slot", not controls._success_feedback.has("slot4"))
	player.cooldowns["firebolt"] = 0.5
	player.set_process(true)
	game.hud.open_settings()
	await _frames(3)
	check("pause preserves the authoritative cooldown", player.cooldowns["firebolt"] == 0.5)
	game.hud.close_panel()
	game.queue_free()
	await _frames(2)

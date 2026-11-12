extends TestCase


func run() -> void:
	var reduced := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var game := await make_game("mage")
	game.player.set_process(false)
	game.set_process(false)
	var trail: RewardHudTrail = game.hud.reward_trail
	trail.set_process(false)
	check(
		"the overlay covers the real HUD viewport",
		trail.size.is_equal_approx(game.get_viewport_rect().size)
	)
	var at: Vector2 = game.player.position
	var gold: int = GameState.gold
	var xp: int = GameState.xp
	trail.offer("gold", at)
	trail.offer("gear", at)
	check(
		"one chest bundle shares one flying marker",
		trail.flights.size() == 1 and trail.flights[0]["kind"] == "gear"
	)
	trail._process(0.3)
	check("animation is display only", GameState.gold == gold and GameState.xp == xp)
	trail._process(0.4)
	check(
		"arriving never grants or saves a second reward",
		(
			trail.flights.is_empty()
			and trail.arrived == 1
			and GameState.gold == gold
			and GameState.xp == xp
		)
	)
	check("arrival survives the first slow frame", not trail.pulses.is_empty())
	var bar: Rect2 = game.hud.status_geometry()["xp"]
	check(
		"XP lands on the actual responsive XP bar",
		trail.destination("xp").is_equal_approx(bar.get_center())
	)
	check(
		"gold and gear land on the actual bag control",
		trail.destination("gold").is_equal_approx(game.hud.controls._buttons["bar_bag"]["center"])
	)
	trail.clear()
	game.grant_xp(5)
	check(
		"a confirmed XP grant creates its trail",
		GameState.xp == xp + 5 and trail.flights.size() == 1 and trail.flights[0]["kind"] == "xp"
	)
	trail._process(0.1)
	for index in 30:
		trail.offer("gold", at + Vector2((index % 3 - 1) * 35, (index / 3) * 3))
		trail._process(0.09)
	check(
		"dense rewards retain a fixed cosmetic bound",
		trail.flights.size() <= RewardHudTrail.LIMIT and trail.pulses.size() <= 3
	)
	trail.clear()
	trail.offer("gold", at)
	game.dungeon.active = true
	trail._process(0.01)
	check("changing region removes the previous flight", trail.flights.is_empty())
	game.dungeon.active = false
	trail.offer("gold", at)
	game.hud.open_settings()
	check("opening a menu discards old reward motion", trail.flights.is_empty())
	game.hud.close_panel(false)
	Prefs.reduce_motion = true
	trail.offer("gold", at)
	check(
		"reduced motion keeps a destination cue without flight",
		trail.flights.is_empty() and not trail.pulses.is_empty()
	)
	Prefs.reduce_motion = reduced
	game.queue_free()
	await _frames(3)

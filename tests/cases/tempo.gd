extends TestCase

func run() -> void:
	var game := await make_game()
	var player: Player = game.player
	player.set_process(false)
	var old_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = false
	check("movement is fifty percent faster without speeding the engine clock", is_equal_approx(player.speed(), player.base_speed * 1.5) and Engine.time_scale == 1.0)
	var weapon: Gear = GameState.equipped["weapon"]
	var original_interval := maxf(0.12, float(weapon.base["tempo"]) / (1.0 + float(weapon.base["haste"])))
	check("weapon action speed and reported interval share the same tempo", is_equal_approx(player.weapon_melee()["tempo"], original_interval / 1.5))
	check("roll is quicker but keeps its authored distance", is_equal_approx(Player.ROLL_TIME, 0.32 / 1.5) and Player.ROLL_DISTANCE == 170.0)
	var projectile := Effect.new()
	projectile.kind = "proj"
	projectile.velocity = Vector2(600, 0)
	projectile.life = 0.8
	game._add_effect(projectile)
	projectile.set_process(false)
	check("projectile flight is faster without increasing range", is_equal_approx(projectile.velocity.length(), 900) and is_equal_approx(projectile.velocity.length() * projectile.life, 480))
	var foe := Enemy.new()
	foe.setup(game, "goblin", 1)
	foe.position = player.position + Vector2(50, 0)
	game.world.add_child(foe)
	game.enemies.append(foe)
	foe.set_process(false)
	foe.take_damage(1, player)
	foe._knockback = Vector2.ZERO
	foe._state = "windup"
	foe._windup_duration = GameTempo.duration(0.55)
	foe._timer = foe._windup_duration
	var timer := foe._timer
	foe._process(0.015)
	check("a confirmed victim hit really stops its attack clock briefly", foe._hitstop.remaining > 0 and foe._timer == timer)
	foe._process(0.1)
	check("actor simulation resumes after bounded local hitstop", foe._hitstop.remaining == 0 and foe._timer < timer)
	player._resolving_melee_contact = true
	player._attack_time = 0.2
	player.confirm_melee_contact(true)
	player._resolving_melee_contact = false
	player.cooldowns["cleave"] = 0.5
	var clock := player._attack_time
	player._process(0.015)
	check("melee attacker hitstop pauses its attack but not real cooldowns", player._attack_time == clock and player.cooldowns["cleave"] < 0.5)
	var remaining := player._hitstop.remaining
	for i in 50:
		player._hitstop.trigger(0.055)
	check("area and repeated contacts cannot stack endless hitstop", player._hitstop.remaining == remaining)
	Prefs.reduce_motion = true
	player._process(0.015)
	check("reduced motion immediately releases real actor hitstop", player._hitstop.remaining == 0 and player._attack_time < clock)
	Prefs.reduce_motion = false
	player._hitstop.clear()
	player._hitstop.trigger(0.05)
	player.try_roll()
	check("dodge input cancels actor hitstop immediately", player._hitstop.remaining == 0 and player._roll_time > 0)
	game.queue_free()
	await _frames(2)
	Prefs.reduce_motion = old_reduce

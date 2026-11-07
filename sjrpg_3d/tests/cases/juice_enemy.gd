extends TestCase
## JUICE #13 and later enemy-side presentation: pure display state that never changes damage.


func run() -> void:
	var old_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var game := await make_game()
	var foe := Enemy.new()
	foe.setup(game, "goblin", 1)
	foe.position = game.player.position + Vector2(300, 0)
	foe.hp = 100.0
	foe.max_hp = 100.0
	game.world.add_child(foe)
	game.enemies.append(foe)
	game.player.set_process(false)
	foe.take_damage(40.0, game.player)
	check("health bar keeps a trailing segment at the pre-hit value", is_equal_approx(foe.hp, 60.0) and is_equal_approx(foe.ghost_hp, 100.0))
	foe._process(0.2)
	check("the trail holds before it drains", is_equal_approx(foe.ghost_hp, 100.0))
	foe._process(0.3)
	check("the trail then drains toward the real health", foe.ghost_hp < 100.0 and foe.ghost_hp > foe.hp)
	foe._process(2.0)
	check("the trail never goes below the real health", is_equal_approx(foe.ghost_hp, foe.hp))
	foe.take_damage(10.0, game.player)
	foe.take_damage(10.0, game.player)
	check("rapid hits keep the trail at the largest recent value", is_equal_approx(foe.ghost_hp, 60.0) and is_equal_approx(foe.hp, 40.0))
	Prefs.reduce_motion = true
	foe._process(0.0)
	check("reduced motion removes the trail at once", is_equal_approx(foe.ghost_hp, foe.hp))
	Prefs.reduce_motion = old_reduce
	game.queue_free()
	await _frames(2)
	await _check_boss_slam()


## JUICE #10: a boss slam shakes the camera even when the hero stands outside its reach.
func _check_boss_slam() -> void:
	var old_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var game := await make_game()
	game.player.set_process(false)
	var boss := Enemy.new()
	boss.setup(game, "goblin", 1)
	boss.position = game.player.position + Vector2(400, 0)
	game.world.add_child(boss)
	game.enemies.append(boss)
	boss.make_boss()
	boss._state = "windup"
	boss._windup_duration = 1.0
	boss._timer = 0.01
	game._impact_offset = Vector2.ZERO
	var hp: float = game.player.hp
	boss._process(0.05)
	check("slam completes and enters recovery", boss._state == "recover")
	check("a dodged slam still reaches the camera", game._impact_offset.length() > 0.0 and game._impact_offset.length() <= 7.0)
	check("the hero outside its reach takes no damage", game.player.hp == hp)
	Prefs.reduce_motion = true
	game._impact_offset = Vector2.ZERO
	game.combat_feedback(boss.position, 1.0)
	check("reduced motion suppresses the slam shake", game._impact_offset == Vector2.ZERO)
	Prefs.reduce_motion = old_reduce
	game.queue_free()
	await _frames(2)

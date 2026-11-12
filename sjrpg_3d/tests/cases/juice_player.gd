extends TestCase
## JUICE #8 and later player-side presentation: display state driven by real health changes.


func run() -> void:
	var old_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var game := await make_game()
	var hero: Player = game.player
	var hud = game.hud
	hud._update_vital_feedback(0.01)
	hero._invulnerable = 0.0
	hero.hp = hero.max_hp
	hud._update_vital_feedback(0.01)
	hero.take_damage(1.0)
	hud._update_vital_feedback(0.01)
	hud._update_heavy_hit_vignette()
	check("a small hit does not raise the vignette", hud._heavy_hit == 0.0 and not hud._heavy_hit_vignette.visible)
	hero._invulnerable = 0.0
	hero.take_damage(hero.max_hp * 0.6)
	hud._update_vital_feedback(0.01)
	hud._update_heavy_hit_vignette()
	check("a large hit raises the vignette", hud._heavy_hit > 0.0 and hud._heavy_hit_vignette.visible and hud._heavy_hit_vignette.modulate.a > 0.0)
	var strength: float = hud._heavy_hit_vignette.modulate.a
	check("the vignette never covers more than half-opaque red", strength <= Hud.HEAVY_HIT_ALPHA + 0.001)
	check("the vignette ignores input", hud._heavy_hit_vignette.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	hud._update_vital_feedback(Hud.HEAVY_HIT_TIME)
	hud._update_heavy_hit_vignette()
	check("the vignette fades out within its duration", hud._heavy_hit == 0.0 and not hud._heavy_hit_vignette.visible)
	hero.revive(hero.position)
	hero._invulnerable = 0.0
	hud._update_vital_feedback(0.01)
	Prefs.reduce_motion = true
	hero.take_damage(hero.max_hp * 0.4)
	hud._update_vital_feedback(0.01)
	hud._update_heavy_hit_vignette()
	check("reduced motion keeps a weaker vignette", hud._heavy_hit_vignette.visible and hud._heavy_hit_vignette.modulate.a < strength)
	Prefs.reduce_motion = old_reduce
	game.queue_free()
	await _frames(2)
	await _check_lunge()


## JUICE #7: a basic melee swing steps toward a target before contact, never past the stop gap.
func _check_lunge() -> void:
	var old_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var game := await make_game()
	var hero: Player = game.player
	hero.set_process(false)
	var foe := Enemy.new()
	foe.setup(game, "goblin", 1)
	foe.position = hero.position + Vector2(100, 0)
	hero.facing = 0.0
	foe.hp = 100000.0
	foe.max_hp = 100000.0
	game.world.add_child(foe)
	game.enemies.append(foe)
	foe.set_process(false)
	check("a basic melee swing starts", hero.cast_slot(0))
	check("the basic swing is a lunging attack", hero._attack_lunges)
	var start := hero.position
	var duration: float = hero._attack_duration
	hero._process(duration * 0.2)
	var after_early := hero.position
	check("the hero steps toward the target during wind-up", after_early.distance_to(foe.position) < start.distance_to(foe.position) - 1.0)
	hero._process(duration * 0.2)
	check("the total step stays within the lunge distance", hero.position.distance_to(start) <= Player.LUNGE_DISTANCE + 0.5)
	hero._process(duration * 0.5)
	var after_contact := hero.position
	hero._process(0.0)
	check("no lunge continues after contact", after_contact.distance_to(hero.position) < 0.01)
	check("the lunge never reaches the target", hero.position.distance_to(foe.position) > Player.LUNGE_STOP_GAP * 0.5)

	hero._attack_time = 0.0
	hero._pending = Callable()
	hero.position = foe.position - Vector2(Player.LUNGE_STOP_GAP - 10.0, 0.0)
	hero.cooldowns.clear()
	hero.cast_slot(0)
	var close := hero.position
	hero._process(hero._attack_duration * 0.2)
	check("a target already in front prevents any lunge", close.distance_to(hero.position) < 0.5)

	hero._attack_time = 0.0
	hero._pending = Callable()
	hero.cooldowns.clear()
	hero.position = foe.position - Vector2(300.0, 0.0)
	hero.cast_slot(0)
	var far := hero.position
	hero._process(hero._attack_duration * 0.2)
	check("a swing with no target nearby does not drift forward", far.distance_to(hero.position) < 0.5)

	hero._attack_time = 0.0
	hero._pending = Callable()
	hero.cooldowns.clear()
	hero.position = foe.position - Vector2(100.0, 0.0)
	Prefs.reduce_motion = true
	hero.cast_slot(0)
	var calm := hero.position
	hero._process(hero._attack_duration * 0.2)
	check("reduced motion removes the lunge", calm.distance_to(hero.position) < 0.5)
	Prefs.reduce_motion = old_reduce
	game.queue_free()
	await _frames(2)

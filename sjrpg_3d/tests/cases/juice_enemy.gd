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
	await _check_telegraph()
	await _check_kill()


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


## JUICE #9: an ordinary enemy flashes when its swing begins; a boss uses its danger ring instead.
func _check_telegraph() -> void:
	var old_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var game := await make_game()
	game.player.set_process(false)
	var foe := Enemy.new()
	foe.setup(game, "goblin", 1)
	foe.position = game.player.position + Vector2(40, 0)
	game.world.add_child(foe)
	game.enemies.append(foe)
	foe._state = "chase"
	foe._process(0.02)
	check("an enemy in reach begins its swing", foe._state == "windup")
	check("the swing start shows a warning flash in the telegraph colour", foe.sprite.flash > 0.0 and foe.sprite.flash_tint == Enemy.TELEGRAPH_COLOR)
	check("the warning is weaker than a real hit flash", foe.sprite.flash < 1.0)
	check("the warning differs from the hurt and hit flashes", Enemy.TELEGRAPH_COLOR != Color(1.0, 0.45, 0.4) and Enemy.TELEGRAPH_COLOR != Effect.contact_flash_color(null))
	var boss := Enemy.new()
	boss.setup(game, "goblin", 1)
	boss.position = game.player.position + Vector2(40, 0)
	game.world.add_child(boss)
	game.enemies.append(boss)
	boss.make_boss()
	boss._state = "chase"
	boss._process(0.02)
	check("a boss keeps its danger ring and gets no extra flash", boss._state == "windup" and boss.sprite.flash == 0.0)
	Prefs.reduce_motion = old_reduce
	game.queue_free()
	await _frames(2)


## JUICE #5: a killing blow gets a longer attacker pause, a white flash, a burst ring and a bigger recoil.
func _check_kill() -> void:
	var old_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var game := await make_game()
	var hero: Player = game.player
	hero.set_process(false)
	var heavy_foe := _foe(game, 300.0)
	hero._resolving_melee_contact = true
	heavy_foe.take_damage(35.0, hero)
	check("a heavy non-lethal blow keeps the usual pause ceiling", heavy_foe.last_hit_tier == HitTier.HEAVY and hero._hitstop.remaining <= 0.055 + 0.0001)
	hero._hitstop.clear()
	var foe := _foe(game, 340.0)
	var novas_before: int = game.cosmetic_effects.filter(func(e: Effect) -> bool: return e.kind == "nova").size()
	foe.take_damage(foe.hp + 1.0, hero)
	hero._resolving_melee_contact = false
	check("a killing blow pauses the attacker slightly longer", foe.dead and is_equal_approx(hero._hitstop.remaining, HitTier.KILL_STOP))
	check("the pause stays under the kill ceiling", hero._hitstop.remaining <= HitTier.KILL_STOP_LIMIT)
	check("a killing blow flashes white", foe.sprite.flash_tint == Color.WHITE)
	check("a killing blow throws off one burst ring", game.cosmetic_effects.filter(func(e: Effect) -> bool: return e.kind == "nova").size() == novas_before + 1)
	check("a killing blow recoils further", foe._recoil_size == HitTier.KILL_RECOIL)
	Prefs.reduce_motion = true
	hero._hitstop.clear()
	var calm := _foe(game, 380.0)
	var novas_calm: int = game.cosmetic_effects.filter(func(e: Effect) -> bool: return e.kind == "nova").size()
	calm.take_damage(calm.hp + 1.0, hero)
	check("reduced motion adds no burst ring", game.cosmetic_effects.filter(func(e: Effect) -> bool: return e.kind == "nova").size() == novas_calm)
	Prefs.reduce_motion = old_reduce
	game.queue_free()
	await _frames(2)


func _foe(game: Node, distance: float) -> Enemy:
	var foe := Enemy.new()
	foe.setup(game, "goblin", 1)
	foe.position = game.player.position + Vector2(distance, 0)
	foe.hp = 100.0
	foe.max_hp = 100.0
	game.world.add_child(foe)
	game.enemies.append(foe)
	foe.set_process(false)
	return foe

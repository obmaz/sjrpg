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
	await _check_squash()
	await _check_zoom_punch()
	await _check_boss_defeat()


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
	check("a dodged slam still reaches the camera", game._impact_offset.length() > 0.0 and game._impact_offset.length() <= game.IMPACT_LIMIT)
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
	check("a heavy non-lethal blow applies distinct bounded actor pauses", heavy_foe.last_hit_tier == HitTier.HEAVY and is_equal_approx(hero._hitstop.remaining, HitTier.HEAVY_ATTACKER_STOP) and is_equal_approx(heavy_foe._hitstop.remaining, HitTier.HEAVY_VICTIM_STOP))
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


## JUICE #4: the struck body squashes at contact and recovers, in both the sprite and its 3D model.
func _check_squash() -> void:
	var old_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var game := await make_game()
	game.player.set_process(false)
	var foe := _foe(game, 300.0)
	check("an untouched body is not squashed", foe.sprite.squash_scale() == Vector2.ONE)
	foe.take_damage(4.0, game.player)
	var squash: Vector2 = foe.sprite.squash_scale()
	check("contact squashes wider and shorter by the tier amount", squash.x > 1.0 and squash.y < 1.0 and is_equal_approx(squash.x - 1.0, HitTier.squash(HitTier.LIGHT)))
	foe.sprite._process(0.05)
	check("the squash eases back toward normal", foe.sprite.squash_scale().x < squash.x and foe.sprite.squash_scale().x > 1.0)
	foe.sprite._process(0.5)
	check("the squash ends", foe.sprite.squash_scale() == Vector2.ONE)
	foe.take_damage(40.0, game.player)
	check("a heavier hit squashes more", foe.sprite.squash_scale().x - 1.0 > HitTier.squash(HitTier.LIGHT))
	check("squash only grows with the tier", HitTier.squash(HitTier.LIGHT) < HitTier.squash(HitTier.MEDIUM) and HitTier.squash(HitTier.MEDIUM) < HitTier.squash(HitTier.HEAVY) and HitTier.squash(HitTier.HEAVY) <= HitTier.squash(HitTier.KILL))
	foe.sprite._process(0.5)
	foe.sprite.trigger_squash(0.1)
	foe.sprite.trigger_squash(0.02)
	check("a weaker hit cannot cut a stronger squash short", is_equal_approx(foe.sprite.squash_amount, 0.1))
	foe.sprite._process(0.5)
	var renderer = game.world_renderer
	if renderer != null and renderer._enemy_renderer != null:
		var rest := _foe(game, 340.0)
		renderer._enemy_renderer.sync()
		var rest_model: Dictionary = renderer._enemy_renderer.entries[rest.get_instance_id()]
		var rest_scale: Vector3 = (rest_model["root"] as Node3D).scale
		check("an unstruck 3D body keeps its uniform scale", is_equal_approx(rest_scale.x, rest_scale.y) and is_equal_approx(rest_scale.x, rest_scale.z))
		rest.take_damage(40.0, game.player)
		renderer._enemy_renderer.sync()
		var hit_scale: Vector3 = (rest_model["root"] as Node3D).scale
		check("a struck 3D body is wider and shorter, with depth matching width", hit_scale.x > rest_scale.x and hit_scale.y < rest_scale.y and is_equal_approx(hit_scale.x, hit_scale.z))
	Prefs.reduce_motion = true
	var calm := _foe(game, 380.0)
	calm.take_damage(40.0, game.player)
	check("reduced motion removes the squash", calm.sprite.squash_scale() == Vector2.ONE)
	Prefs.reduce_motion = old_reduce
	game.queue_free()
	await _frames(2)


## JUICE #14: heavy contact punches the camera in a little, multiplied onto the selected zoom, then settles.
func _check_zoom_punch() -> void:
	var old_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var game := await make_game()
	game.player.set_process(false)
	game._update_zoom()
	var base: Vector2 = game.camera.zoom
	check("combat zoom cap stays at two tenths of one percent",game.ZOOM_PUNCH_LIMIT<=0.002)
	var foe := _foe(game, 300.0)
	foe.take_damage(4.0, game.player)
	check("a light hit does not punch the zoom", game.camera.zoom.is_equal_approx(base))
	foe.take_damage(35.0, game.player)
	check("a heavy hit zooms in slightly", game.camera.zoom.x > base.x and game.camera.zoom.x <= base.x * (1.0 + game.ZOOM_PUNCH_LIMIT) + 0.0001)
	for i in 20:
		game.zoom_punch(0.05)
	check("stacked punches stay under the cap", game.camera.zoom.x <= base.x * (1.0 + game.ZOOM_PUNCH_LIMIT) + 0.0001)
	game._update_zoom_punch(0.3)
	game._update_zoom_punch(0.3)
	check("the punch settles back to the selected zoom", game.camera.zoom.is_equal_approx(base))
	game.zoom_punch(0.02, game.player.position + Vector2(2000, 0))
	check("a distant hit does not punch the camera", game.camera.zoom.is_equal_approx(base))
	game.zoom_punch(0.02)
	game._update_zoom()
	check("resizing mid-punch keeps the punch on top of the new base", game.camera.zoom.x > base.x)
	game._update_zoom_punch(1.0)
	game._update_zoom_punch(1.0)
	Prefs.reduce_motion = true
	game.zoom_punch(0.03)
	game._update_zoom_punch(0.0)
	check("reduced motion removes the zoom punch", game.camera.zoom.is_equal_approx(base))
	Prefs.reduce_motion = old_reduce
	game.queue_free()
	await _frames(2)


## JUICE #6: defeating the boss pauses the world briefly and adds a burst, a punch and a second pulse.
func _check_boss_defeat() -> void:
	var old_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var game := await make_game()
	game.player.set_process(false)
	var boss := _foe(game, 300.0)
	boss.make_boss()
	var bystander := _foe(game, 380.0)
	game._update_zoom()
	var base: Vector2 = game.camera.zoom
	var novas_before: int = game.cosmetic_effects.filter(func(e: Effect) -> bool: return e.kind == "nova" and e.radius >= 260.0).size()
	boss.take_damage(boss.hp + 1.0, game.player)
	check("the boss is defeated", boss.dead and GameState.boss_defeated)
	check("the player pauses briefly", game.player._hitstop.remaining > 0.0 and game.player._hitstop.remaining <= game.BOSS_DEFEAT_PAUSE_LIMIT)
	check("surviving enemies pause with the world", bystander._hitstop.remaining > 0.0)
	check("a large burst marks the defeat", game.cosmetic_effects.filter(func(e: Effect) -> bool: return e.kind == "nova" and e.radius >= 260.0).size() == novas_before + 1)
	check("the camera punches in on the defeat", game.camera.zoom.x > base.x)
	check("the camera shakes on the defeat", game._impact_offset.length() > 0.0 and game._impact_offset.length() <= game.IMPACT_LIMIT)
	GameState.boss_defeated = false
	Prefs.reduce_motion = true
	game._update_zoom_punch(1.0)
	game._update_zoom_punch(1.0)
	game.player._hitstop.clear()
	var calm := _foe(game, 300.0)
	calm.make_boss()
	calm.take_damage(calm.hp + 1.0, game.player)
	check("reduced motion drops the pause and the zoom", game.player._hitstop.remaining == 0.0 and game.camera.zoom.is_equal_approx(base))
	Prefs.reduce_motion = old_reduce
	game.queue_free()
	await _frames(2)

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

extends TestCase

func run() -> void:
	var game := await make_game()
	var old_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var enemy := Enemy.new()
	enemy.setup(game, "goblin", 1)
	enemy.position = game.player.position + Vector2(50, 0)
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	var before: float = enemy.hp
	var effects: int = game.cosmetic_effects.size()
	enemy.take_damage(0, game.player)
	check("zero damage has no phantom hit", enemy.hp == before and game.cosmetic_effects.size() == effects)
	enemy.take_damage(2, game.player)
	check("confirmed hit preserves exact damage", is_equal_approx(enemy.hp, before - 2))
	check("confirmed hit creates an impact", game.cosmetic_effects.any(func(e): return e.kind == "impact"))
	check("camera impact stays bounded", game._impact_offset.length() > 0 and game._impact_offset.length() <= 6.0)
	var hp: float = game.player.hp
	game.player.take_damage(5, enemy)
	var hurt_hp: float = game.player.hp
	game.player.take_damage(5, enemy)
	check("invulnerability still rejects duplicate damage", hurt_hp < hp and game.player.hp == hurt_hp)
	game.hud._update_vital_feedback(0.01)
	check("actual damage drives HUD loss feedback", game.hud._hurt_feedback > 0)
	var potions: int = GameState.potions
	game.player.use_potion()
	game.hud._update_vital_feedback(0.01)
	game.hud.controls._update_action_feedback()
	check("successful healing drives HUD confirmation", game.player.hp > hurt_hp and game.hud._heal_feedback > 0)
	check("consumed potion drives action feedback", GameState.potions == potions - 1 and game.hud.controls._success_feedback.has("potion_hp"))
	Prefs.reduce_motion = true
	game._process(0.1)
	game.combat_feedback(enemy.position, 1)
	check("reduced motion suppresses camera displacement", game._impact_offset == Vector2.ZERO and game.camera.offset == Vector2.ZERO)
	for i in 100:
		Effect.spawn_impact(game, enemy.position, game.player)
	check("impact spam respects cosmetic budget", game.cosmetic_effects.size() <= 64)
	Prefs.reduce_motion = old_reduce
	game.queue_free()
	await _frames(2)

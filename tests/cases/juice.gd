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
	var ground_position := enemy.position
	enemy.take_damage(2, game.player)
	check("confirmed hit preserves exact damage", is_equal_approx(enemy.hp, before - 2))
	check("confirmed hit creates an impact", game.cosmetic_effects.any(func(e): return e.kind == "impact"))
	check("camera impact stays bounded", game._impact_offset.length() > 0 and game._impact_offset.length() <= 6.0)
	check("contact pose and recoil are visual only", enemy.sprite.contact_hold > 0.0 and enemy.position == ground_position and enemy.sprite.position.length() <= 8.0)
	var contact_frame := enemy.sprite.frame
	enemy.sprite.set_frame(enemy.atlas, (contact_frame + 1) % enemy.atlas.regions.size())
	check("confirmed contact retains the struck pose", enemy.sprite.frame == contact_frame)
	enemy.sprite._process(0.8)
	check("slow first frame still presents contact", enemy.sprite.contact_hold > 0.0)
	enemy.sprite._process(0.8)
	check("contact pose expires without rendering", enemy.sprite.contact_hold == 0.0)
	enemy.sprite.hold_contact(0.045)
	enemy.sprite._process(0.02)
	var hold_remaining := enemy.sprite.contact_hold
	for i in 20:
		enemy.sprite.hold_contact(0.065)
	check("rapid hits do not extend a contact pose indefinitely", is_equal_approx(enemy.sprite.contact_hold, hold_remaining))
	enemy.sprite._process(0.12)
	enemy.hp = 1000.0
	enemy.max_hp = 1000.0
	check("real melee attack starts", game.player.cast_slot(0))
	enemy.take_damage(1.0, game.player)  # Storm/retaliation also use the player as their source.
	check("passive damage during windup does not consume the contact hold", game.player.sprite.contact_hold == 0.0 and game.player.sprite._contact_recovery == 0.0)
	var attack_time: float = game.player._attack_time
	var before_contact: float = enemy.hp
	game.player._process(game.player._attack_duration * 0.46)
	check("actual pending melee hit arms contact presentation", enemy.hp < before_contact and game.player.sprite.contact_hold > 0.0)
	check("contact hold captures the actual impact frame", game.player.sprite.frame == game.player.attack_atlas.action_frame(game.player.facing, 0.46))
	check("contact presentation does not delay the attack clock", game.player.sprite.contact_hold > 0.0 and game.player._attack_time < attack_time)
	game.player.try_roll()
	check("rolling immediately releases a contact pose", game.player.sprite.contact_hold == 0.0 and game.player._roll_time > 0.0)
	game.player._roll_time = 0.0
	game.player._invulnerable = 0.0
	var projectile := Effect.new()
	projectile.velocity = Vector2(320, -80)
	projectile.owner_node = game.player
	check("projectile recoil follows travel rather than its owner", Effect.contact_direction(projectile, enemy.position).is_equal_approx(projectile.velocity.normalized()))
	projectile.queue_free()
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
	enemy.take_damage(1, game.player)
	check("reduced motion suppresses contact holds", enemy.sprite.contact_hold == 0.0 and game.player.sprite.contact_hold == 0.0)
	game._process(0.1)
	game.combat_feedback(enemy.position, 1)
	check("reduced motion suppresses camera displacement", game._impact_offset == Vector2.ZERO and game.camera.offset == Vector2.ZERO)
	for i in 100:
		Effect.spawn_impact(game, enemy.position, game.player)
	check("impact spam respects cosmetic budget", game.cosmetic_effects.size() <= 64)
	var burst := Effect.spawn_impact(game, enemy.position, game.player)
	burst._process(0.8)
	check("slow frame retains first cosmetic impact", not burst.is_queued_for_deletion() and burst.age < burst.life)
	burst._process(0.8)
	check("unrendered impact still expires after its first update", burst.is_queued_for_deletion())
	Prefs.reduce_motion = false
	enemy.sprite.hold_contact(0.045)
	enemy.take_damage(enemy.hp + 1.0, game.player)
	check("death immediately releases the hit pose", enemy.dead and enemy.sprite.contact_hold == 0.0)
	Prefs.reduce_motion = old_reduce
	game.queue_free()
	await _frames(2)

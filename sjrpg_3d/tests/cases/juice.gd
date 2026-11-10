extends TestCase
const NativeFixture := preload("res://tests/native_combat_fixture.gd")

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
	check("camera impact stays bounded", game._impact_offset.length() > 0 and game._impact_offset.length() <= 7.0)
	var first_pulse: float = game._impact_offset.length()
	check("confirmed contact reaches the camera in its actual frame", game.camera.offset == game._impact_offset)
	game._update_impact_camera(0.4)
	check("slow next frame preserves the first contact pulse", game.camera.offset.length() >= first_pulse * 0.8)
	game._update_impact_camera(0.4)
	check("camera impulse still decays after its first presentation", game.camera.offset.length() < first_pulse * 0.01)
	for impact in 20:
		game.combat_feedback(enemy.position, 1.0)
	check("stacked impacts stay below the small seven-pixel limit", game.camera.offset.length() <= 7.0)
	game._update_impact_camera(0.02)
	check("short lateral contact ripple stays bounded too", game.camera.offset.length() <= 7.0)
	check("contact pose and recoil are visual only", enemy.sprite.contact_hold > 0.0 and enemy.position == ground_position and enemy.sprite.position.length() <= 8.0)
	var contact_frame := enemy.sprite.frame
	enemy.sprite.set_frame(enemy.atlas, (contact_frame + 1) % enemy.atlas.regions.size())
	check("confirmed contact retains the struck pose", enemy.sprite.frame == contact_frame)
	enemy.sprite._process(0.8)
	check("slow first frame still presents contact", enemy.sprite.contact_hold > 0.0)
	check("slow first frame still presents a confirmed hit flash", enemy.sprite.flash > 0.0)
	enemy.sprite._process(0.8)
	check("contact pose expires without rendering", enemy.sprite.contact_hold == 0.0)
	check("hit flash still expires after first presentation", enemy.sprite.flash == 0.0)
	enemy.sprite.trigger_flash(Color.WHITE)
	Prefs.reduce_motion = true
	enemy.sprite._process(0.0)
	check("enabling reduced motion immediately dims an existing contact flash", enemy.sprite.flash <= 0.35)
	Prefs.reduce_motion = false
	enemy.sprite.clear_flash()
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
	game.queue_free()
	await _frames(2)
	await _check_generated_fx_blending()
	await _check_cast_presentation()
	await _check_impact_animation_clock()
	await _check_projectile_sweep()
	await _check_death_cancellation()
	await _check_chain_target_lifetime()
	await _check_leap_target_lifetime()
	check("outgoing contact flash is distinct from incoming hurt red", Effect.contact_flash_color(null) != Color(1.0, 0.45, 0.4))
	Prefs.reduce_motion = old_reduce


func _check_generated_fx_blending() -> void:
	var game := await make_game()
	var generated: Array[Effect] = [
		Effect.spawn_cast(game, game.player, SkillDefs.LIGHT),
		Effect.spawn_release(game, game.player, SkillDefs.LIGHT),
		Effect.spawn_impact(game, game.player.position, game.player),
	]
	for kind in ["nova", "slash", "orb", "proj"]:
		var effect := Effect.new()
		effect.kind = kind
		game._add_effect(effect)
		generated.append(effect)
	for effect in generated:
		var blend := effect.material as CanvasItemMaterial
		check("generated %s art uses additive blending so black remains invisible" % effect.kind, blend != null and blend.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD)
		effect.queue_free()
	var thrown := Effect.new()
	thrown.kind = "proj"
	thrown.params["throw"] = true
	game._add_effect(thrown)
	check("solid thrown projectiles keep their original material", thrown.material == null)
	game.queue_free()
	await _frames(2)


func _check_impact_animation_clock() -> void:
	Prefs.reduce_motion = false
	var game := await make_game()
	var enemy := _fixture_enemy(game, game.player.position + Vector2(75, 0))
	enemy.take_damage(1.0, game.player)
	var impacts: Array = game.cosmetic_effects.filter(func(effect: Effect) -> bool: return effect.kind == "impact")
	check("confirmed contact supplies the authored impact animation", not impacts.is_empty())
	if impacts.is_empty():
		game.queue_free()
		await _frames(2)
		return
	var impact: Effect = impacts[0]
	var hp := enemy.hp
	impact._process(0.01)
	var contact_phase := impact.visual_phase()
	impact._process(0.04)
	check("impact art advances from contact toward the later frames", impact.visual_phase() > contact_phase and impact.visual_phase() < 1.0)
	game.hud.open_settings()
	var paused_age := impact.age
	var paused_phase := impact.visual_phase()
	await _frames(3)
	check("pause freezes both impact lifetime and authored frame progression", impact.age == paused_age and impact.visual_phase() == paused_phase)
	game.hud.close_panel()
	Prefs.reduce_motion = true
	var still_phase := impact.visual_phase()
	var before := impact.age
	impact._process(0.025)
	check("reduced motion holds one artwork pose while its fade clock advances", impact.visual_phase() == still_phase and impact.age > before)
	impact._process(impact.life + 0.1)
	check("frozen artwork still expires without extra damage", impact.is_queued_for_deletion() and enemy.hp == hp)
	Prefs.reduce_motion = false
	game.queue_free()
	await _frames(2)


func _check_cast_presentation() -> void:
	Prefs.reduce_motion = false
	var game := await make_game("mage")
	var mage: Player = game.player
	mage.set_process(false)
	check("real magic cast starts its hand preparation", mage.cast_slot(0))
	check("elemental discharge sound waits for real release", mage._release_sound == "fire")
	var glows: Array = game.cosmetic_effects.filter(func(effect: Effect) -> bool: return effect.kind == "cast")
	check("successful cast creates one generated preparation glow", glows.size() == 1)
	if glows.is_empty():
		game.queue_free()
		await _frames(2)
		return
	var glow: Effect = glows[0]
	var resource := mage.resource
	var attack_time := mage._attack_time
	var effect_count: int = game.cosmetic_effects.size()
	check("blocked recast creates no false preparation", not mage.cast_slot(0) and game.cosmetic_effects.size() == effect_count)
	mage.position += Vector2(13, 8)
	glow._process(0.025)
	check("hand light follows the actor instead of staying on the floor", glow.position.is_equal_approx(mage.position + Effect.cast_hand_offset(mage.facing, mage.sprite.body_height)))
	check("preparation light does not advance attacks or spend more mana", mage._attack_time == attack_time and mage.resource == resource and mage._pending.is_valid())

	game.hud.open_settings()
	var age := glow.age
	await _frames(3)
	check("pause freezes the preparation light", glow.age == age)
	game.hud.close_panel()
	Prefs.reduce_motion = true
	var calm := Effect.spawn_cast(game, mage, SkillDefs.LIGHT)
	calm._process(0.04)
	check("reduced motion keeps a short gameplay-free cast confirmation", not calm.is_queued_for_deletion() and calm.damage == 0.0 and mage._attack_time == attack_time)
	Prefs.reduce_motion = false
	mage._process(mage._attack_duration * 0.46)
	check("actual release consumes the queued discharge sound", mage._release_sound.is_empty())
	check("actual spell release emits one short directional pulse", game.cosmetic_effects.filter(func(e: Effect) -> bool: return e.kind == "release").size() == 1 and not mage._pending.is_valid())
	mage.try_roll()
	glow._process(0.01)
	check("rolling cancels the hand light immediately", glow.is_queued_for_deletion())
	check("cancelled casts cannot leave a queued discharge sound", mage._release_sound.is_empty())
	game.queue_free()
	await _frames(2)


func _fixture_enemy(game: Node, at: Vector2) -> Enemy:
	var foe := Enemy.new()
	foe.setup(game, "goblin", 1)
	foe.position = at
	foe.hp = 100.0
	foe.max_hp = 100.0
	game.world.add_child(foe)
	game.enemies.append(foe)
	foe.set_process(false)
	return foe


func _fixture_projectile(game: Node, at: Vector2, piercing := false, lifetime := 1.0) -> Effect:
	var shot := Effect.new()
	shot.kind = "proj"
	shot.position = at - Vector2(0, 34)
	shot.velocity = Vector2(600, 0)
	shot.damage = 3.0
	shot.life = lifetime
	shot.params["pierce"] = piercing
	game._add_effect(shot)
	shot.set_process(false)
	return shot


func _check_projectile_sweep() -> void:
	var game := await make_game()
	game.set_process(false)
	game.player.set_process(false)
	game.encounters.set_process(false)
	game.exploration.set_process(false)
	# Timing/ordering must not depend on changing scenery around the town spawn.
	NativeFixture.box(game.spatial_world, NativeFixture.remote_at(Vector3(120, -0.5, 120)), Vector3(40, 1, 40), SpatialWorld3D.FLOOR)
	await NativeFixture.settle(get_tree())
	var base := SpatialWorld3D.projected(NativeFixture.remote_at(Vector3(120, 0, 120)))
	var far := _fixture_enemy(game, base + Vector2(130, 0))
	# 커진 실제 캡슐과 투사체 반경 바깥에 수명 제한 검사용 빈 거리를 남긴다.
	var near := _fixture_enemy(game, base + Vector2(Enemy.radius_for("goblin") + SpatialCombat3D.PROJECTILE_RADIUS + 18.0, 0))
	var shot := _fixture_projectile(game, base)
	shot._process(0.35)
	check("slow projectile frame hits nearest enemy regardless of array order", near.hp == 97.0 and far.hp == 100.0 and shot.is_queued_for_deletion())
	var overlap := _fixture_enemy(game, near.position)
	near.hp = 100.0
	var piercing := _fixture_projectile(game, base, true)
	piercing._process(0.35)
	check("piercing sweep reaches stacked and farther enemies exactly once", near.hp == 97.0 and overlap.hp == 97.0 and far.hp == 97.0 and piercing._hit.size() == 3)
	piercing.position = base - Vector2(0, 34)
	piercing._process(0.1)
	check("piercing reentry cannot damage a previous target twice", near.hp == 97.0 and overlap.hp == 97.0)
	var short_lived := _fixture_projectile(game, base, false, 0.01)
	var allowed_travel := short_lived.velocity.length() * short_lived.life
	check("lifetime fixture has a genuine native gap before the first target", is_inf(SpatialCombat3D.target_fraction(game, base, base + Vector2.RIGHT * allowed_travel, short_lived.spatial_height, near)))
	short_lived._process(0.35)
	check("projectile travel is bounded by remaining lifetime", near.hp == 97.0 and short_lived.position.x <= base.x + 6.01 and short_lived.is_queued_for_deletion())
	var expired := _fixture_projectile(game, near.position)
	expired.age = expired.life
	expired._process(0.1)
	check("expired projectile cannot strike a target already under it", near.hp == 97.0 and expired.is_queued_for_deletion())
	var zone := Effect.new()
	zone.kind = "zone"
	zone.position = near.position
	zone.radius = 50.0
	zone.damage = 2.0
	zone.color = SkillDefs.FIRE
	zone.owner_node = game.player
	game._add_effect(zone)
	zone.set_process(false)
	near._knockback = Vector2.ZERO
	var before_tick := near.hp
	zone._update_zone(0.01)
	var impacts: Array = game.cosmetic_effects.filter(func(e: Effect) -> bool: return e.kind == "impact")
	check("zone damage keeps elemental contact art without changing damage or adding knockback", near.hp == before_tick - 2.0 and near._knockback == Vector2.ZERO and impacts[-1].params["cell"] == 1 and near.sprite.flash_tint.is_equal_approx(Effect.contact_flash_color(zone)))
	game.queue_free()
	await _frames(2)


func _check_death_cancellation() -> void:
	var game := await make_game("mage")
	var hero: Player = game.player
	hero.set_process(false)
	check("death regression begins a real spell windup", hero.cast_slot(0))
	var glow: Effect = game.cosmetic_effects.filter(func(e: Effect) -> bool: return e.kind == "cast")[0]
	var called := {"value": false}
	var queued_action := hero._pending
	hero._pending = func():
		called["value"] = true
		queued_action.call()
	hero.held_slots[0] = true
	hero.move_input = Vector2.RIGHT
	hero._invulnerable = 0.0
	hero.take_damage(1000000.0)
	check("lethal damage discards queued skills and held input", hero.dead and not hero._pending.is_valid() and hero._release_sound.is_empty() and hero._attack_time == 0.0 and hero.held_slots.is_empty() and hero.move_input == Vector2.ZERO)
	var sanctuary := hero.position + Vector2(200, 40)
	hero.revive(sanctuary)
	check("revival clears the previous damage flash", hero.sprite.flash == 0.0)
	hero._process(0.8)
	glow._process(0.01)
	check("revival cannot resume old spell or leave a stale preparation light", not called["value"] and hero.position.is_equal_approx(sanctuary) and glow.is_queued_for_deletion() and not game.world.get_children().any(func(node: Node) -> bool: return node is Effect and node.kind == "proj"))
	hero.try_roll()
	check("successful dodge produces a small cosmetic echo", game.cosmetic_effects.any(func(e: Effect) -> bool: return e.kind == "dodge_echo"))
	hero._invulnerable = 0.0
	hero.take_damage(1000000.0)
	hero.revive(sanctuary)
	hero._process(0.2)
	check("revival cannot inherit residual roll movement", hero._roll_time == 0.0 and hero.position.is_equal_approx(sanctuary))
	Prefs.reduce_motion = true
	check("reduced motion suppresses dodge echoes", Effect.spawn_dodge_echo(game, hero) == null)
	Prefs.reduce_motion = false
	game.queue_free()
	await _frames(2)


func _check_chain_target_lifetime() -> void:
	var game := await make_game("mage")
	# 연쇄 대상 수명 회귀는 확대된 우물 뒤의 차폐와 분리해 열린 광장에서 검사한다.
	game.spatial_world.teleport_source_actor(game.player, game.village.spawn_point + Vector2(0, 180), Player.RADIUS)
	game.player.set_process(false)
	var at: Vector2 = game.player.position
	var first := _fixture_enemy(game, at + Vector2(100, 0))
	var replacement := _fixture_enemy(game, at + Vector2(200, 0))
	var action: Callable = game.player._prepare("chainLightning", SkillDefs.get_def("chainLightning"), 1)
	check("chain regression captures a real target", action.is_valid())
	game.enemies.erase(first)
	first.free()
	action.call()
	check("delayed chain reacquires within range after captured target is freed", replacement.hp < 100.0)
	var before := replacement.hp
	var cosmetics: int = game.cosmetic_effects.size()
	game.chain_lightning(at, null, 4, 230.0, 10.0, game.player)
	var dead_target := _fixture_enemy(game, at + Vector2(90, 0))
	dead_target.dead = true
	game.chain_lightning(at, dead_target, 4, 230.0, 10.0, game.player)
	check("public chain helper rejects null and dead anchors without false hits", replacement.hp == before and game.cosmetic_effects.size() == cosmetics)
	var pending: Callable = game.player._prepare("chainLightning", SkillDefs.get_def("chainLightning"), 1)
	replacement.position = at + Vector2(1000, 0)
	var before_moved := replacement.hp
	pending.call()
	check("delayed chain does not retain an anchor that left its original range", replacement.hp == before_moved)
	game.queue_free()
	await _frames(2)


func _check_leap_target_lifetime() -> void:
	var game := await make_game("warrior")
	var hero: Player = game.player
	hero.set_process(false)
	var start := Iso.project(Vector2(-2800, -2800))
	hero.position = start
	var target := _fixture_enemy(game, start + Vector2(100, 0))
	var definition := {"distance": 200.0, "to_enemy": true, "radius": 40.0}
	var pending := hero._prepare_leap("leapAttack", definition, 1, 1.0)
	target.free()
	game.enemies.clear()
	pending.call()
	check("a removed leap target cancels safely without movement", hero.position == start)
	var distant := _fixture_enemy(game, start + Vector2(100, 0))
	pending = hero._prepare_leap("leapAttack", definition, 1, 1.0)
	distant.position = start + Vector2(2000, 0)
	pending.call()
	check("target movement cannot extend leap beyond its original range", hero.position.distance_to(start) <= 200.01)
	game.queue_free()
	await _frames(2)

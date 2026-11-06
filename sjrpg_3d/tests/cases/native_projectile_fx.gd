extends TestCase
const Fixture := preload("res://tests/native_combat_fixture.gd")

func _cast(game: Node, skill: String, equip := false) -> Effect:
	var hero: Player = game.player
	hero._cancel_actions()
	hero.cooldowns.clear()
	hero.resource = hero.resource_max
	if equip:
		GameState.ranks[skill] = 1
		GameState.slots[0] = skill
	check("real equipped projectile action begins: " + skill, hero.cast_slot(0))
	hero._process(hero._attack_duration * 0.51)
	for child in game.world.get_children():
		if child is Effect and child.kind == "proj" and not child.is_queued_for_deletion():
			child.set_process(false)
			return child
	return null

func run() -> void:
	var old_motion := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var game := await make_game("mage")
	game.set_process(false)
	game.player.set_process(false)
	game.encounters.set_process(false)
	game.quest_runtime.set_process(false)
	game.exploration.set_process(false)
	var preview: Ortho3DPreview = game.ortho_preview
	var fx: NativeCombatFx3D = preview._combat_fx
	var floor_body := Fixture.box(game.spatial_world, Vector3(120, 2.5, 120), Vector3(30, 1, 30), SpatialWorld3D.FLOOR)
	await Fixture.settle(get_tree())
	game.spatial_world.teleport_source_actor(game.player, SpatialWorld3D.projected(Vector3(120, 3, 120)), Player.RADIUS)
	game.player.facing = 0.0
	check("fresh mage actually equips starter firebolt", str(GameState.slots[0]) == "firebolt")
	var shot := _cast(game, "firebolt")
	check("starter creates the previously skipped generic nonthrow effect", shot != null and NativeCombatFx3D.supports(shot))
	if shot == null:
		game.queue_free()
		await _frames(2)
		return
	var id := shot.get_instance_id()
	fx.sync()
	check("real firebolt now has native body without joining the authored-card path", fx._entries.has(id) and not preview._cards.has(id) and not game.field_root.visible)
	var entry: Dictionary = fx._entries[id]
	var body: MeshInstance3D = entry["body"]
	shot._process(0.08)
	fx.sync()
	check("native fire body follows actual raised source trajectory", body.global_position.is_equal_approx(shot.native_position()) and body.global_position.y > 3.0 and int(entry["cell"]) == 1)
	check("native shot uses generated fire pixels with depth testing", (body.material_override as ShaderMaterial).get_shader_parameter("atlas_rect") == Vector4(0.25, 0.25, 0.25, 0.25) and "depth_test_disabled" not in (body.material_override as ShaderMaterial).shader.code)
	check("moving source has a short bounded native tail", (entry["tail"] as MeshInstance3D).visible and (entry["tail"] as MeshInstance3D).global_position.distance_to(body.global_position) <= 0.321)
	var resource_before: float = game.player.resource
	var age_before := shot.age
	for repeat in 4:
		fx.sync()
	check("renderer never advances combat age or spends resources", shot.age == age_before and game.player.resource == resource_before)
	var held := body.global_transform
	var held_age := shot.age
	shot.set_process(true)
	get_tree().paused = true
	await _frames(3)
	fx.sync()
	check("pause holds the source age and native projectile picture", shot.age == held_age and body.global_transform.is_equal_approx(held))
	get_tree().paused = false
	shot.set_process(false)
	Prefs.reduce_motion = true
	fx.sync()
	check("reduced motion removes tail/flicker while preserving the real body", not (entry["tail"] as MeshInstance3D).visible and body.visible and is_equal_approx((body.mesh as QuadMesh).size.x, 44.0 / (65.0 * Ortho3DPreview.PROJECTION_FACTOR)))
	Prefs.reduce_motion = false
	shot._process(shot.life + 0.1)
	fx.sync()
	check("source expiry removes native picture without a second clock", not fx._entries.has(id))
	await _frames(2)
	var ball := _cast(game, "fireball", true)
	check("actual fireball shares the repaired native path", ball != null and NativeCombatFx3D.supports(ball) and float(ball.params["explode"]) > 0.0)
	fx.sync()
	check("actual fireball creates its own body/tail pair", ball != null and fx._entries.has(ball.get_instance_id()))
	if ball != null:
		ball.queue_free()
	await _frames(2)
	var bolt := _cast(game, "iceBolt", true)
	preview._sync_cards()
	fx.sync()
	check("existing authored ice bolt is rendered once in its original path", bolt != null and not NativeCombatFx3D.supports(bolt) and preview._cards.has(bolt.get_instance_id()) and not fx._entries.has(bolt.get_instance_id()))
	if bolt != null:
		bolt.queue_free()
	await _frames(2)
	var forest_world: Node = game.world
	# Real spawning remains gameplay-owned even when the render cap is exceeded.
	for index in NativeCombatFx3D.MAX_PROJECTILES + 3:
		game.spawn_projectile({"pos": game.player.position + Vector2(index, -34), "dir": Vector2.RIGHT, "speed": 620.0, "damage": 1.0, "color": SkillDefs.FIRE}, game.player)
	fx.sync()
	check("native projectile pictures are bounded without deleting gameplay shots", fx._entries.size() == NativeCombatFx3D.MAX_PROJECTILES and game.world.get_children().filter(func(node): return node is Effect and node.kind == "proj" and not node.is_queued_for_deletion()).size() == NativeCombatFx3D.MAX_PROJECTILES + 3)
	game.player.position = game.dungeon.entry_point()
	check("projectile ownership fixture enters the actual cave", game.dungeon.enter())
	fx.sync()
	check("actual cave transition removes every forest projectile picture", game.world != forest_world and fx._entries.is_empty())
	game.dungeon.leave("")
	await Fixture.settle(get_tree())
	fx.sync()
	check("actual forest return observes only still-existing source projectiles", game.world == forest_world and fx._entries.size() > 0 and fx._entries.size() <= NativeCombatFx3D.MAX_PROJECTILES)
	floor_body.queue_free()
	Prefs.reduce_motion = old_motion
	game.queue_free()
	await _frames(2)

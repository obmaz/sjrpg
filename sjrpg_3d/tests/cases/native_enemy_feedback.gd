extends TestCase
## Hidden source Canvas must not remove monster HP or the boss's authored hit warning.


func _enemy(game: Node, kind: String, at: Vector2) -> Enemy:
	var enemy := Enemy.new()
	enemy.setup(game, kind, 1)
	enemy.position = at
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	enemy.set_process(false)
	return enemy


func _visible(feedback: EnemyHitFeedback3D, id: int, key: String) -> bool:
	if not feedback.entries.has(id):
		return false
	var entry: Dictionary = feedback.entries[id]
	var mesh: MeshInstance3D = entry[key]
	return mesh != null and mesh.visible


func run() -> void:
	var reduced := Prefs.reduce_motion
	Prefs.set_reduce_motion(false)
	var game := await make_game("warrior")
	game._spawn_timer = 10000.0
	game.player.set_process(false)
	var renderer: WorldRenderer3D = game.world_renderer
	renderer.set_process(false)
	var feedback: EnemyHitFeedback3D = renderer._enemy_feedback
	var enemy := _enemy(game, "goblin", game.player.position + Vector2(90, 30))
	var enemy_id := enemy.get_instance_id()
	feedback.sync()
	check("healthy enemies allocate no feedback meshes", not feedback.entries.has(enemy_id))
	enemy.take_damage(5.0, null)
	feedback.sync()
	if check("real native damage shows a monster health bar", _visible(feedback, enemy_id, "bar")):
		var entry: Dictionary = feedback.entries[enemy_id]
		var bar: MeshInstance3D = entry["bar"]
		var mesh := bar.mesh
		var ink := bar.material_override as ShaderMaterial
		var ratios: Vector2 = ink.get_shader_parameter("health_ratios")
		check("health and recent-loss fractions read the real damaged enemy", is_equal_approx(ratios.x, enemy.hp / enemy.max_hp) and is_equal_approx(ratios.y, 1.0))
		check("health bar is a single shared quad without a texture or light", mesh is QuadMesh and bar.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		var hp := enemy.hp
		var ghost := enemy.ghost_hp
		var timer := enemy._timer
		get_tree().paused = true
		for sample in 8:
			feedback.sync()
		check("paused feedback has no gameplay clock or health mutation", enemy.hp == hp and enemy.ghost_hp == ghost and enemy._timer == timer)
		get_tree().paused = false
		Prefs.set_reduce_motion(true)
		feedback.sync()
		ratios = ink.get_shader_parameter("health_ratios")
		check("reduced motion removes only the displayed ghost segment", is_equal_approx(ratios.x, ratios.y) and enemy.ghost_hp == ghost)
		Prefs.set_reduce_motion(false)
		enemy.ghost_hp = enemy.hp + 1.0
		feedback.sync()
		ratios = ink.get_shader_parameter("health_ratios")
		check("ghost drain uses the source fraction without rebuilding its mesh", is_equal_approx(ratios.y, enemy.ghost_hp / enemy.max_hp) and bar.mesh == mesh)
		var basis: Basis = renderer.camera.global_transform.basis
		var factor := WorldRenderer3D.GROUND_PER_METER * WorldRenderer3D.PROJECTION_FACTOR
		var anchor := renderer.actor_foot(enemy) + basis.y * ((enemy.sprite.body_height + 11.0) / factor)
		check("health bar follows authoritative feet and camera-plane head offset", bar.global_position.distance_to(anchor) < 0.00001)
		enemy.hp = enemy.max_hp
		feedback.sync()
		check("fully healed monsters hide their health bar", not _visible(feedback, enemy_id, "bar"))
		enemy.hp = hp

	var boss := _enemy(game, "golem", game.player.position + Vector2(-120, 50))
	boss.make_boss()
	boss._state = "windup"
	boss._windup_duration = 1.0
	boss._timer = 0.75
	var boss_id := boss.get_instance_id()
	feedback.sync()
	if check("boss windup restores its ground telegraph", _visible(feedback, boss_id, "ring")):
		var entry: Dictionary = feedback.entries[boss_id]
		var ring: MeshInstance3D = entry["ring"]
		var ink := ring.material_override as ShaderMaterial
		check("boss warning samples actual attack progress", is_equal_approx(float(ink.get_shader_parameter("progress")), 0.25))
		var radius := boss.attack_range + 60.0
		var arrays: Array = ring.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var matches := vertices.size() == 4
		for index in 16:
			var angle := TAU * index / 16.0
			var uv := Vector2(cos(angle), sin(angle)) * 0.5 + Vector2.ONE * 0.5
			var local := vertices[0].lerp(vertices[1], uv.x).lerp(vertices[3].lerp(vertices[2], uv.x), uv.y)
			var actual := SpatialWorld3D.projected(ring.global_transform * local)
			matches = matches and absf(boss.attack_distance(actual) - radius) < 0.001
		check("all warning edges match the real y/0.55 boss hit ellipse", matches)
		var foot: Vector3 = renderer.actor_foot(boss)
		check("boss warning lies on its native floor without depth bypass", absf(ring.global_position.y - foot.y - EnemyHitFeedback3D.RING_LIFT) < 0.00001 and not EnemyHitFeedback3D.RING_CODE.contains("depth_test_disabled"))
		var body: CharacterBody3D = game.spatial_world.actor_bodies[boss_id]
		var before := ring.global_position
		body.position.y += 0.28
		boss.hp = boss.max_hp * 0.5
		feedback.sync()
		var bar: MeshInstance3D = entry["bar"]
		check("raised native actor feet lift the ground warning by the same amount", absf(ring.global_position.y - before.y - 0.28) < 0.00001)
		check("boss and ordinary health bars share immutable quad geometry", bar.mesh == (feedback.entries[enemy_id]["bar"] as MeshInstance3D).mesh)
		body.position.y -= 0.28
		boss._timer = 0.25
		feedback.sync()
		check("warning progress follows the source timer without a second clock", is_equal_approx(float(ink.get_shader_parameter("progress")), 0.75))
		boss._state = "recover"
		feedback.sync()
		check("boss recovery removes the warning immediately", not _visible(feedback, boss_id, "ring"))
		boss.dead = true
		feedback.sync()
		check("dead enemies remove every feedback node before corpse expiry", not feedback.entries.has(boss_id))

	feedback.sync()
	check("damaged forest monster bar remains before cave entry", _visible(feedback, enemy_id, "bar"))
	game.player.position = game.dungeon.entry_point()
	if check("feedback scope fixture enters the actual cave", game.dungeon.enter()):
		game.spatial_world.sync_scope()
		for current: Enemy in game.enemies:
			current.set_process(false)
		await get_tree().physics_frame
		await _frames(1)
		feedback.sync()
		check("forest health bars cannot leak into the cave", not feedback.entries.has(enemy_id))
		var cave_enemy: Enemy = game.enemies[0]
		cave_enemy.take_damage(1.0, null)
		var cave_id := cave_enemy.get_instance_id()
		feedback.sync()
		check("cave damage uses the same native health presentation", _visible(feedback, cave_id, "bar"))
		game.dungeon.leave("검수 종료")
		game.spatial_world.sync_scope()
		await get_tree().physics_frame
		await _frames(1)
		feedback.sync()
		check("cave health bars are removed on actual forest return", not feedback.entries.has(cave_id))
		check("returning forest restores its live damaged monster bar", _visible(feedback, enemy_id, "bar"))
	enemy.dead = true
	feedback.sync()
	check("source death removes the ordinary bar rather than leaving a corpse HUD", not feedback.entries.has(enemy_id))
	Prefs.set_reduce_motion(reduced)
	game.queue_free()
	await _frames(2)

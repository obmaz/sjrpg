extends TestCase
## Species footprints must remain authoritative through native routing and realm changes.
func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _frames(2)

func _clear_body(backend: SpatialWorld3D, enemy: Enemy) -> bool:
	var body: CharacterBody3D = backend.actor_bodies[enemy.get_instance_id()]
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = (body.get_child(0) as CollisionShape3D).shape
	query.transform = body.global_transform
	query.collision_mask = SpatialWorld3D.SOLID | SpatialWorld3D.PROP | SpatialWorld3D.MONSTER_BOUNDARY
	query.exclude = [body.get_rid()]
	return backend.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func run() -> void:
	var game := await make_game("mage")
	game.set_process(false)
	game.player.set_process(false)
	game.encounters.set_process(false)
	game.town_gates.set_process(false)
	var backend: SpatialWorld3D = game.spatial_world
	var gate: Vector2 = game.village.gate_points[0]
	var outside: Vector2 = gate + (gate - game.village.spawn_point).normalized() * 200.0
	game.town_gates.closed[0] = false
	backend.sync_scope()
	await _settle()
	for kind: String in EnemyRenderer3D.KINDS:
		var enemy := Enemy.new()
		enemy.setup(game, kind, 1)
		enemy.position = outside
		game.world.add_child(enemy)
		game.enemies.append(enemy)
		enemy.set_process(false)
		await _settle()
		backend.teleport_source_actor(enemy, outside, enemy.radius, true)
		backend.move_source_actor(enemy, game.village.spawn_point, enemy.radius, true)
		check("species cannot cross an open gate into the safe town " + kind, not game.in_town(enemy.position) and _clear_body(backend, enemy))
		check("native body metadata retains the species footprint " + kind, is_equal_approx(float(backend.actor_bodies[enemy.get_instance_id()].get_meta("radius_pixels")), Enemy.radius_for(kind)))
		var bridge: Vector2 = game.village.bridge.axis_point(0.5)
		var bridge_blocked: bool = backend.blocked(bridge, enemy.radius, true)
		if game.in_town(bridge):
			check("bridge never bypasses the town monster boundary " + kind, bridge_blocked)
		elif not bridge_blocked:
			backend.teleport_source_actor(enemy, bridge, enemy.radius, true)
			backend.move_source_actor(enemy, bridge + Vector2(4, 0), enemy.radius, true)
			check("legal bridge step preserves support and full capsule clearance " + kind, _clear_body(backend, enemy) and absf(backend.actor_foot(enemy).y - backend.height_at(enemy.position)) < 0.001)
		print("PASS SPECIES_BRIDGE_CLEARANCE ", JSON.stringify({"kind": kind, "radius": enemy.radius, "blocked_by_native_rules": bridge_blocked}))
		game.enemies.erase(enemy)
		enemy.queue_free()
		await _settle()
	# The authored clearing must accept the complete golem capsule, without bypass rules.
	for id: String in ["roots", "moon", "sun"]:
		Quests.state(id)["phase"] = "completed"
	backend.teleport_source_actor(game.player, game.village.boss_point + Vector2(0, 130), Player.RADIUS)
	if check("real boss start accepts its enlarged species footprint", game.quest_runtime.start_boss()):
		await _settle()
		var boss: Enemy = game.quest_runtime._boss
		check("boss uses the same golem body and projectile radius policy", boss.radius == Enemy.radius_for("golem") and _clear_body(backend, boss) and is_equal_approx(float(backend.actor_bodies[boss.get_instance_id()].get_meta("radius_pixels")), boss.radius))
		game.quest_runtime.reset_boss()
		await _settle()
	backend.teleport_source_actor(game.player, game.dungeon.entry_point(), Player.RADIUS)
	if check("real cave entry remains available with species footprints", game.dungeon.enter()):
		backend.sync_scope()
		for enemy: Enemy in game.enemies:
			enemy.set_process(false)
		await _settle()
		var boar: Enemy
		for enemy: Enemy in game.enemies:
			var body: CharacterBody3D = backend.actor_bodies[enemy.get_instance_id()]
			check("actual cave spawn preserves species capsule and free placement " + enemy.kind, is_equal_approx(float(body.get_meta("radius_pixels")), enemy.radius) and _clear_body(backend, enemy))
			if enemy.kind == "boar":
				boar = enemy
		if check("cave contains a large quadruped corridor fixture", boar != null):
			var start: Vector2 = Iso.project(Vector2(700, -500))
			var target: Vector2 = Iso.project(Vector2(1450, -500))
			backend.teleport_source_actor(boar, start, boar.radius, true)
			var clear := true
			for step: int in 80:
				backend.move_source_actor(boar, boar.position + (target - boar.position).limit_length(16.0), boar.radius, true)
				clear = clear and _clear_body(backend, boar) and absf(backend.actor_foot(boar).y - backend.height_at(boar.position)) < 0.001
			check("large boar traverses the actual narrow cave branch without clipping", clear and boar.position.distance_to(target) < 3.0)
		game.dungeon.leave("species footprint fixture")
		backend.sync_scope()
		await _settle()
	game.queue_free()
	await _frames(2)

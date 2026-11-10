extends TestCase
const NativeFixture := preload("res://tests/native_combat_fixture.gd")
## Real casts and actor movement query the same native World3D floors/capsules/walls.


func _box(parent: Node3D, at: Vector3, size: Vector3, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	body.position = at
	return body


func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame


func _target(game: Node, at: Vector3) -> Enemy:
	var enemy := Enemy.new()
	enemy.setup(game, "goblin", 1)
	enemy.position = SpatialWorld3D.projected(at)
	enemy.hp = 100000.0
	enemy.max_hp = enemy.hp
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	enemy.set_process(false)
	game.spatial_world.teleport_source_actor(enemy, enemy.position, Enemy.RADIUS, true)
	return enemy


func _cast(game: Node, skill: String) -> bool:
	var hero: Player = game.player
	hero._cancel_actions()
	hero.cooldowns.clear()
	hero.resource = hero.resource_max
	GameState.ranks[skill] = 1
	GameState.slots[0] = skill
	var started := hero.cast_slot(0)
	hero._process(hero._attack_duration * 0.51)
	return started


func _bolt(game: Node) -> Effect:
	check("native spell starts through the real equipped slot", _cast(game, "iceBolt"))
	var shot: Effect
	for child in game.world.get_children():
		if child is Effect and child.kind == "proj" and not child.is_queued_for_deletion():
			shot = child
	if shot != null:
		shot.set_process(false)
	return shot


func run() -> void:
	var game := await make_game("mage")
	game.set_process(false)
	game.player.set_process(false)
	game.encounters.set_process(false)
	game.quest_runtime.set_process(false)
	game.exploration.set_process(false)
	var backend: SpatialWorld3D = game.spatial_world
	check("native combat uses the game's persistent physics backend", backend != null)
	if backend == null:
		game.queue_free()
		await _frames(2)
		return
	# An isolated native arena avoids relying on decorative map geometry for the fixture.
	var arena := Node3D.new()
	backend.add_child(arena)
	_box(arena, NativeFixture.remote_at(Vector3(120, -0.5, 120)), Vector3(40, 1, 40), SpatialWorld3D.FLOOR)
	var wall := _box(arena, NativeFixture.remote_at(Vector3(120, 1.5, 120)), Vector3(0.12, 3, 5), SpatialWorld3D.SOLID)
	await _settle()
	var hero: Player = game.player
	var origin := SpatialWorld3D.projected(NativeFixture.remote_at(Vector3(118, 0, 120)))
	backend.teleport_source_actor(hero, origin, Player.RADIUS)
	var target := _target(game, NativeFixture.remote_at(Vector3(122, 0, 120)))
	var before := target.hp
	var shot := _bolt(game)
	check("native spell creates its actual projectile", shot != null)
	if shot == null:
		game.queue_free()
		await _frames(2)
		return
	shot._process(0.60)
	check("slow projectile sphere sweep stops at the native wall before a monster", shot.is_queued_for_deletion() and target.hp == before and shot.native_position().x < wall.position.x)
	game.spawn_beam(origin, (target.position - origin).angle(), 560.0, 10.0, SkillDefs.LIGHT, hero)
	check("real beam cannot deal damage through the same native wall", target.hp == before)
	check("native wall also blocks actual melee reach", not game.can_melee_reach(origin, target.position))
	wall.collision_layer = 0
	await _settle()
	shot = _bolt(game)
	var exact_damage := shot.damage
	shot._process(0.60)
	check("open native path deals the original projectile amount exactly once", is_equal_approx(before - target.hp, exact_damage) and shot.is_queued_for_deletion())
	var dimensions := backend.actor_dimensions(target, Enemy.RADIUS)
	var body: CharacterBody3D = backend.actor_bodies[target.get_instance_id()]
	var capsule := (body.get_child(0) as CollisionShape3D).shape as CapsuleShape3D
	check("projectile contacts use the registered actor's exact capsule dimensions", is_equal_approx(capsule.radius, dimensions.x) and is_equal_approx(capsule.height, dimensions.y))
	_box(arena, NativeFixture.remote_at(Vector3(118.9, 3.9, 120)), Vector3(0.6, 0.2, 0.6), SpatialWorld3D.FLOOR)
	await _settle()
	var upper := _target(game, NativeFixture.remote_at(Vector3(118.9, 4, 120)))
	var lower := _target(game, NativeFixture.remote_at(Vector3(118.7, 0, 120.7)))
	check("height fixture comes from actual native floor ray hits", is_equal_approx(backend.height_at(upper.position), 4.0) and is_equal_approx(backend.height_at(lower.position), 0.0))
	var upper_hp := upper.hp
	var lower_hp := lower.hp
	check("real frost nova starts through its equipped slot", _cast(game, "frostNova"))
	check("native area range hits the nearby floor but excludes the upper storey", upper.hp == upper_hp and lower.hp < lower_hp)
	var fixed_y := SpatialCombat3D.launch_height(game, origin, hero)
	check("projectile capsule sweep cannot jump onto another storey", is_inf(SpatialCombat3D.target_fraction(game, origin, upper.position, fixed_y, upper)))
	wall.collision_layer = SpatialWorld3D.SOLID
	await _settle()
	backend.teleport_source_actor(hero, SpatialWorld3D.projected(NativeFixture.remote_at(Vector3(118, 0, 121))), Player.RADIUS)
	var hero_body: CharacterBody3D = backend.actor_bodies[hero.get_instance_id()]
	hero._move(SpatialWorld3D.projected(NativeFixture.remote_at(Vector3(124, 0, 121))) - hero.position)
	var moved_foot := backend.actor_foot(hero)
	check("actual player movement resolves through its persistent native capsule", backend.actor_bodies[hero.get_instance_id()] == hero_body and moved_foot.x < wall.position.x and SpatialWorld3D.projected(moved_foot).is_equal_approx(hero.position))
	var direction := (origin - target.position).normalized()
	var walk_cycle := target._walk_cycle
	target._step(direction, 1.0)
	check("actual enemy movement uses native wall collision and preserves walking animation", backend.actor_foot(target).x > wall.position.x and SpatialWorld3D.projected(backend.actor_foot(target)).is_equal_approx(target.position) and target._walk_cycle > walk_cycle)
	game.queue_free()
	await _frames(2)

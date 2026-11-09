extends TestCase
## Native species metres must agree across visible models, source UI, corpses and combat.
func _bounds(root: Node3D, align_axes := true) -> AABB:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	var orientation: Basis = root.global_transform.basis.orthonormalized().inverse() if align_axes else Basis.IDENTITY
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		for surface: int in instance.mesh.get_surface_count():
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				var point: Vector3 = orientation * (instance.global_transform * vertex - root.global_transform.origin)
				minimum = minimum.min(point)
				maximum = maximum.max(point)
	return AABB(minimum, maximum - minimum)


func _stance_radius(root: Node3D, height: float) -> float:
	var radius: float = 0.0
	var orientation: Basis = root.global_transform.basis.orthonormalized().inverse()
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		for surface: int in instance.mesh.get_surface_count():
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				var point: Vector3 = orientation * (instance.global_transform * vertex - root.global_transform.origin)
				if point.y <= height * 0.15:
					radius = maxf(radius, Vector2(point.x, point.z).length())
	return radius

func run() -> void:
	var game := await make_game("warrior")
	game.set_process(false)
	game.encounters.set_process(false)
	var preview: Ortho3DPreview = game.ortho_preview
	var backend: SpatialWorld3D = game.spatial_world
	# Use the real outside-town spawn search, including the enlarged radius margin.
	for attempt: int in 30:
		game._spawn_enemy(true)
		if not game.enemies.is_empty():
			break
	if not check("larger enemy footprint still finds a legal actual forest spawn", not game.enemies.is_empty()):
		game.queue_free()
		await _frames(2)
		return
	var seed_enemy := game.enemies[0] as Enemy
	var spawn: Vector2 = seed_enemy.position
	for old_enemy in game.enemies:
		old_enemy.queue_free()
	game.enemies.clear()
	await _frames(2)
	for kind: String in NativeEnemyModels.KINDS:
		var enemy := Enemy.new()
		enemy.setup(game, kind, 1)
		enemy.position = spawn
		enemy.facing = 0.0
		game.world.add_child(enemy)
		game.enemies.append(enemy)
		enemy.set_process(false)
		await _frames(2)
		preview._enemy_models.sync()
		var model: Dictionary = preview._enemy_models.entries[enemy.get_instance_id()]
		var root: Node3D = model["root"]
		var metres: float = Enemy.NATIVE_HEIGHT_METRES[kind]
		var old_heights := {"goblin": 1.30, "wolf": 1.13, "boar": 1.22, "skeleton": 1.70, "golem": 2.85}
		var old_radii := {"goblin": 25.0, "wolf": 36.0, "boar": 38.0, "skeleton": 25.0, "golem": 44.0}
		check("all species grow by thirty percent in height and footprint " + kind, is_equal_approx(metres / float(old_heights[kind]), 1.30) and is_equal_approx(enemy.radius / float(old_radii[kind]), 1.30))
		check("larger body retains its previous melee reach from the rim " + kind, is_equal_approx(enemy.attack_range - enemy.radius, float(Enemy.KINDS[kind]["range"]) - float(old_radii[kind])))
		var dimensions: Vector2 = SpatialWorld3D.actor_dimensions(enemy, enemy.radius)
		var body: CharacterBody3D = backend.actor_bodies[enemy.get_instance_id()]
		var shape := (body.get_child(0) as CollisionShape3D).shape as CapsuleShape3D
		var bounds: AABB = _bounds(root)
		var stance_radius: float = _stance_radius(root, metres)
		check("species source, mesh and capsule share native metres " + kind,
			is_equal_approx(enemy.sprite.body_height / SpatialWorld3D.VERTICAL, metres)
			and is_equal_approx(dimensions.y, metres)
			and is_equal_approx(shape.height, metres)
			and absf(bounds.end.y - metres) < 0.001
			and absf(bounds.position.y) < 0.001)
		check("movement and attack use the same footprint " + kind,
			is_equal_approx(shape.radius, SpatialWorld3D.radius_metres(enemy.radius))
			and is_equal_approx(float(body.get_meta("radius_pixels")), enemy.radius)
			and not backend.blocked(spawn, enemy.radius, true)
			and stance_radius + SpatialWorld3D.SKIN <= shape.radius)
		check("custom target radii remain explicit " + kind,
			is_equal_approx(SpatialWorld3D.actor_dimensions(enemy, 7.0).x, SpatialWorld3D.radius_metres(7.0)))
		var foot: Vector3 = preview.actor_foot(enemy)
		var from: Vector2 = enemy.position + Vector2(-100, 10)
		var to: Vector2 = enemy.position + Vector2(100, 10)
		var chest_y: float = foot.y + metres * 0.5
		var default_contact: float = SpatialCombat3D.target_fraction(game, from, to, chest_y, enemy, 0.0)
		var actual_contact: float = SpatialCombat3D.target_fraction(game, from, to, chest_y, enemy, 0.0, enemy.radius)
		var small_contact: float = SpatialCombat3D.target_fraction(game, from, to, chest_y, enemy, 0.0, 7.0)
		check("default projectile target follows enlarged capsule but explicit radius is preserved " + kind,
			is_finite(default_contact) and is_equal_approx(default_contact, actual_contact) and is_inf(small_contact))
		enemy.force_chase()
		enemy._step(Vector2.RIGHT, 0.04)
		preview._enemy_models.sync()
		check("walking keeps native feet and canonical collider size " + kind,
			root.position.is_equal_approx(preview.actor_foot(enemy) + Ortho3DPreview.ground_position(enemy.sprite.position))
			and is_equal_approx(shape.height, metres)
			and not backend.blocked(enemy.position, enemy.radius, true))
		enemy.take_damage(1.0, null)
		preview._enemy_models.sync()
		var ratio: float = metres / float(model["base_height"])
		var squash: Vector2 = enemy.sprite.squash_scale()
		check("hit squash retains shared base ratio and native feet " + kind,
			root.scale.is_equal_approx(Vector3(ratio * squash.x, ratio * squash.y, ratio * squash.x))
			and root.position.is_equal_approx(preview.actor_foot(enemy) + Ortho3DPreview.ground_position(enemy.sprite.position)))
		enemy.take_damage(enemy.max_hp * 2.0, null)
		preview._enemy_models.sync()
		check("death retains native model without rescaling canonical height " + kind,
			enemy.dead and not game.enemies.has(enemy) and preview._enemy_models.entries.has(enemy.get_instance_id())
			and is_equal_approx(enemy.sprite.body_height / SpatialWorld3D.VERTICAL, metres))
		var corpse: Dictionary = game.corpses.back()
		game._tick_corpses(0.2)
		preview._world_environment._sync_corpses()
		var visual: Node = corpse["visual"]
		var fallen: Dictionary = preview._world_environment._corpses[visual.get_instance_id()]
		var fallen_root: Node3D = fallen["root"]
		var fallen_bounds: AABB = _bounds(fallen_root, false)
		check("corpse uses same native size and rests on actual floor " + kind,
			is_equal_approx(float(corpse["height"]), enemy.sprite.body_height)
			and fallen_root.scale.is_equal_approx(Vector3.ONE * ratio)
			and absf(fallen_root.position.y + fallen_bounds.position.y - preview.surface_height(corpse["pos"]) - 0.012) < 0.01)
		print("PASS NATIVE_SIZE_METRES ", JSON.stringify({"kind": kind, "height": metres, "mesh_bounds": [bounds.size.x, bounds.size.y, bounds.size.z], "low_stance_radius": stance_radius, "capsule_radius": shape.radius, "capsule_height": shape.height, "hero_reference_m": 1.8}))
		game.remove_corpse(corpse)
		game.enemies.erase(enemy)
		enemy.queue_free()
		await _frames(2)
		preview._enemy_models.sync()
		preview._world_environment._sync_corpses()
	game.queue_free()
	await _frames(2)

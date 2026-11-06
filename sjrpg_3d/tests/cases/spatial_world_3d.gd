extends TestCase
## Native physics fixtures prove body sweeps, floor rays and realm boundaries.


func _physics_frames(count: int) -> void:
	for index in count:
		await get_tree().physics_frame


func run() -> void:
	var game := await make_game("mage")
	await _frames(4)
	await _physics_frames(2)
	var spatial: SpatialWorld3D = game.spatial_world
	check("3D edition creates a native physics world", is_instance_valid(spatial))
	if not is_instance_valid(spatial):
		game.queue_free()
		return
	game.set_process(false)
	game.player.set_process(false)
	game.town_gates.set_process(false)
	check("physics shares the actual native rendering World3D", spatial.get_world_3d() == spatial.get_parent().get_world_3d() and spatial.physics_ticks > 0)
	var valid_faces := true
	for collision: CollisionShape3D in spatial._geometry.find_children("*", "CollisionShape3D", true, false):
		var concave := collision.shape as ConcavePolygonShape3D
		if concave == null:
			continue
		var faces := concave.get_faces()
		for index in range(0, faces.size(), 3):
			valid_faces = valid_faces and (faces[index + 1] - faces[index]).cross(faces[index + 2] - faces[index]).length_squared() > 0.0000000001
	check("all native floor and cliff collision triangles have nonzero area", valid_faces)
	var source: Player = game.player
	var body := spatial.register_actor(source, Player.RADIUS)
	var dimensions := SpatialWorld3D.actor_dimensions(source, Player.RADIUS)
	var edge := SpatialWorld3D.projected(Vector3(dimensions.x, 0, -dimensions.x) / sqrt(2.0))
	check("native capsule horizontal silhouette preserves the authored pixel radius", absf(edge.x - Player.RADIUS) < 0.001)
	check("hero owns a persistent real CharacterBody3D capsule", body is CharacterBody3D and body.collision_layer == SpatialWorld3D.ACTOR and ((body.get_child(0) as CollisionShape3D).shape as CapsuleShape3D).radius == dimensions.x)
	# Isolated inside-field arena: no source polygon or 2D pushing function is
	# involved in this thin native obstacle, so tunnelling cannot pass silently.
	var wall := BoxShape3D.new()
	wall.size = Vector3(3.0, 3.0, 0.08)
	spatial._shape_body(wall, Transform3D(Basis.IDENTITY, Vector3(-43, 1.5, -42)), SpatialWorld3D.SOLID, "NativeSweepFixture")
	await _physics_frames(2)
	var start := SpatialWorld3D.projected(Vector3(-43, 0, -44))
	var target := SpatialWorld3D.projected(Vector3(-43, 0, -40))
	spatial.teleport_source_actor(source, start, Player.RADIUS)
	spatial.move_source_actor(source, target, Player.RADIUS)
	var foot := spatial.actor_foot(source)
	check("a long native capsule sweep cannot overlap or tunnel through a thin3D wall", foot.z + dimensions.x <= -42.04 + 0.006 and foot.z > -44.1, "foot=%s radius=%s wallNear=-42.04" % [foot, dimensions.x])
	check("native body remains authoritative and its source adapter follows", spatial.register_actor(source, Player.RADIUS) == body and source.position.distance_to(SpatialWorld3D.projected(body.position)) < 0.001)
	check("native wall blocks melee line of sight", not spatial.can_melee(start, target))
	var fraction := spatial.projectile_fraction(Vector3(-43, 0.8, -44), Vector3(-43, 0.8, -40), 0.06)
	check("native swept sphere reports the first wall contact", fraction > 0.1 and fraction < 0.75)
	check("native overlap detects solid destination", spatial.blocked(SpatialWorld3D.projected(Vector3(-43, 0, -42)), Player.RADIUS))
	var floor_faces := PackedVector3Array([Vector3(-47, 1.2, -45), Vector3(-45, 1.2, -45), Vector3(-45, 1.2, -43), Vector3(-47, 1.2, -45), Vector3(-45, 1.2, -43), Vector3(-47, 1.2, -43)])
	spatial._triangle_body(floor_faces, SpatialWorld3D.FLOOR, "NativeRaisedFixture")
	await _physics_frames(2)
	var raised := SpatialWorld3D.projected(Vector3(-46, 0, -44))
	check("height comes from a real3D floor added without TerrainLevels data", absf(spatial.height_at(raised) - 1.2) < 0.001)
	check("different actual native heights prevent melee", not spatial.can_melee(raised, SpatialWorld3D.projected(Vector3(-48, 0, -44))))
	for surface in SpatialWorld3D.terrain_surfaces(game.village):
		if str(surface["id"]) == "chapel":
			check("native chapel threshold replaces the illustrated high yard", absf(float(surface["rise"]) / SpatialWorld3D.VERTICAL - 0.28) < 0.0001)
			# Polygon edge order is not a height datum: the merged outline can
			# begin at the actual ramp's ground-level entrance. Sample strictly
			# inside the flat native foundation, away from triangle boundaries.
			var flat_point := Iso.poly_bounds(surface["building"]).get_center() + Vector2(3, -2)
			check("native chapel top collider has the actual .28m height", absf(spatial.height_at(flat_point) - 0.28) < 0.01)
		if str(surface["id"]) == "landmark_3":
			var bottom: Vector2 = surface["bottom"]
			var upper: Vector2 = surface["upper"]
			var along := upper - bottom
			check("irregular native stair entrance begins at the real ground floor", absf(spatial.height_at(bottom)) < 0.001)
			for distance in [1.0, 10.0, 35.0]:
				var point: Vector2 = bottom + along.normalized() * float(distance)
				var expected: float = float(surface["rise"]) / SpatialWorld3D.VERTICAL * distance / along.length()
				check("native ramp ray preserves continuous rise at %spx" % distance, absf(spatial.height_at(point) - expected) < 0.002)
	# Props retain movement blocking while projectile walls exclude first-hit targets.
	var prop := BoxShape3D.new()
	prop.size = Vector3(0.5, 1.0, 0.5)
	spatial._shape_body(prop, Transform3D(Basis.IDENTITY, Vector3(-40, 0.5, -45)), SpatialWorld3D.PROP, "AttackablePropFixture")
	await _physics_frames(2)
	check("native attackable props still block actor movement", spatial.blocked(SpatialWorld3D.projected(Vector3(-40, 0, -45)), Player.RADIUS))
	check("projectile wall cast leaves prop contacts to ordered damage", spatial.projectile_fraction(Vector3(-40, 0.5, -46), Vector3(-40, 0.5, -44), 0.02) == 1.0)
	var gate: Vector2 = game.village.gate_points[0]
	game.town_gates.closed[0] = true
	spatial.sync_scope()
	await _physics_frames(2)
	check("real closed gate state controls actual3D collision", spatial.blocked(gate, Player.RADIUS))
	game.town_gates.closed[0] = false
	spatial.sync_scope()
	await _physics_frames(2)
	check("open gate removes its native closed collision", not spatial.blocked(gate, Player.RADIUS))
	var enemy := Enemy.new()
	enemy.setup(game, "goblin", 1)
	enemy.position = gate + (gate - game.village.spawn_point).normalized() * 100.0
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	enemy.set_process(false)
	var monster := spatial.register_actor(enemy, Enemy.RADIUS, true)
	check("native monster body includes the permanent safe-zone boundary", (monster.collision_mask & SpatialWorld3D.MONSTER_BOUNDARY) != 0)
	spatial.teleport_source_actor(source, game.dungeon.entry_point(), Player.RADIUS)
	Quests.state("sun")["started"] = false
	check("actual cave transition enters", game.dungeon.enter())
	spatial.sync_scope()
	await _physics_frames(2)
	check("cave transition rebuilds a native3D realm", spatial.realm == "cave" and spatial.get_node_or_null("CavePhysics") != null)
	check("native cave floors preserve room interiors and branch holes", not spatial.blocked(Iso.project(Vector2(700, 0)), Player.RADIUS) and spatial.blocked(Iso.project(Vector2(1100, 0)), Player.RADIUS))
	spatial.teleport_source_actor(source, Iso.project(Vector2(700, 0)), Player.RADIUS)
	spatial.move_source_actor(source, Iso.project(Vector2(1100, 0)), Player.RADIUS)
	check("actual cave boundary sweeps stop departure through a missing corridor", Iso.unproject(source.position).x < 1000.0)
	game.dungeon.leave("native physics test")
	spatial.sync_scope()
	await _physics_frames(2)
	check("leaving cave restores native forest physics", spatial.realm == "forest" and spatial.get_node_or_null("ForestPhysics") != null)
	game.queue_free()
	await _frames(2)

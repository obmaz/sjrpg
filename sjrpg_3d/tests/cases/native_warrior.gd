extends TestCase
## Hero conversion observes the real Player action and distance clocks.
func run() -> void:
	var game := await make_game("warrior")
	var renderer: WorldRenderer3D = game.world_renderer
	var hero := renderer.actor as WarriorRenderer3D
	if not check("warrior uses actual native articulated geometry", hero != null):
		return
	check("native warrior has no hero billboard", hero.find_children("*", "MeshInstance3D", true, false).all(func(node: Node): return not (node as MeshInstance3D).mesh is QuadMesh))
	check("warrior keeps baked native root scale", hero.scale.is_equal_approx(Vector3.ONE))
	var total := 0
	var envelope := AABB()
	var first := true
	for mesh in hero.meshes:
		var bounds := hero.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		envelope = bounds if first else envelope.merge(bounds)
		first = false
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			total += (indices.size() if not indices.is_empty() else points.size()) / 3
	check("adult warrior has volumetric sides and grounded soles", absf(envelope.position.y) < 0.001 and envelope.size.y > 1.78 and envelope.size.y < 1.9 and envelope.size.x > 0.5 and envelope.size.z > 0.8)
	check("warrior stays below hero geometry budget", total < 7000 and hero.meshes.size() <= 40)
	print("ART_AUDIT native_warrior " + JSON.stringify({"triangles": total, "parts": hero.meshes.size(), "bounds": str(envelope)}))
	var player: Player = game.player
	player._run_distance = 23.0
	hero.sync(player)
	var leg := hero.legs[0].rotation.x
	check("actual moved distance drives the native walking legs", absf(leg) > 0.1)
	player._hitstop.remaining = 0.04
	player._run_distance = 40.0
	hero.sync(player)
	check("real contact stop freezes the actual native pose", is_equal_approx(hero.legs[0].rotation.x, leg))
	player._hitstop.clear()
	hero.sync(player)
	check("pose resumes from source movement rather than an independent clock", not is_equal_approx(hero.legs[0].rotation.x, leg))
	player._attack_time = player._attack_duration * 0.7
	hero.sync(player)
	var windup := hero.arms[1].rotation
	player._attack_time = player._attack_duration * 0.3
	hero.sync(player)
	check("real attack progress moves the sword shoulder in three dimensions", windup.distance_to(hero.arms[1].rotation) > 0.5)
	player.sprite.trigger_flash(Color(1.0, 0.5, 0.3))
	renderer._sync_actor(0.0)
	check("warrior follows actual spatial actor foot and source recoil", hero.position.is_equal_approx(renderer.actor_foot(player) + WorldRenderer3D.ground_position(player.sprite.position)))
	check("actual warrior injury state reaches all native surfaces", hero.meshes.all(func(mesh: MeshInstance3D): return mesh.material_overlay != null))
	player.sprite.flash = 0.0
	hero.sync(player)
	check("cleared source flash removes native injury overlays", hero.meshes.all(func(mesh: MeshInstance3D): return mesh.material_overlay == null))
	var before := hero.arms[1].rotation
	get_tree().paused = true
	player._attack_time = player._attack_duration * 0.9
	hero.sync(player)
	check("game pause freezes actual pose transforms", before.is_equal_approx(hero.arms[1].rotation))
	get_tree().paused = false
	player.dead = true
	hero.sync(player)
	check("death lays the volume down and removes the held sword", is_equal_approx(hero.torso.rotation.x, PI * 0.5) and not hero.weapon.visible)

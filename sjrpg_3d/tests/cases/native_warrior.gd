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
	check("warrior imports a real shared skin and animator", hero.skeleton != null and hero.skeleton.get_bone_count() == 65 and hero._animator != null)
	check("renderer reports the actual warrior skeleton instead of a class-name assumption", renderer._hero_skeleton == hero.skeleton)
	for mesh in hero.meshes:
		var bounds := hero.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		if mesh.name == "WarriorBody":
			envelope = bounds
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			total += (indices.size() if not indices.is_empty() else points.size()) / 3
	check("adult warrior has volumetric sides and grounded soles", absf(envelope.position.y) < 0.001 and envelope.size.y > 1.78 and envelope.size.y < 1.9 and envelope.size.x > 0.5 and envelope.size.z > 0.3)
	check("warrior stays below hero geometry budget", total < 24000 and hero.meshes.size() == 2)
	print("ART_AUDIT native_warrior " + JSON.stringify({"triangles": total, "parts": hero.meshes.size(), "bounds": str(envelope)}))
	var player: Player = game.player
	player._run_distance = 23.0
	hero.sync(player)
	var leg := hero.joint_rotation("thigh_l")
	check("actual moved distance drives the native walking legs", leg.angle_to(Quaternion.IDENTITY) > 0.1)
	var snapshot := hero.review_snapshot()
	check("warrior exposes actual skeletal animation through the shared probe contract", snapshot["bone_count"] == 65 and str(snapshot["active_clip"]).to_lower().contains("run") and snapshot["pose_updates"] > 0 and is_equal_approx(snapshot["run_distance"], player._run_distance) and snapshot["bones"].has("thigh_l"))
	player._hitstop.remaining = 0.04
	player._run_distance = 40.0
	hero.sync(player)
	check("real contact stop freezes the actual native pose", hero.joint_rotation("thigh_l").is_equal_approx(leg))
	player._hitstop.clear()
	hero.sync(player)
	check("pose resumes from source movement rather than an independent clock", not hero.joint_rotation("thigh_l").is_equal_approx(leg))
	player._attack_time = player._attack_duration * 0.7
	hero.sync(player)
	var windup := hero.joint_rotation("upperarm_r")
	player._attack_time = player._attack_duration * 0.3
	hero.sync(player)
	check("real attack progress moves the sword shoulder in three dimensions", windup.angle_to(hero.joint_rotation("upperarm_r")) > 0.5)
	player.sprite.trigger_flash(Color(1.0, 0.5, 0.3))
	renderer._sync_actor(0.0)
	check("warrior follows actual spatial actor foot and source recoil", hero.position.is_equal_approx(renderer.actor_foot(player) + WorldSpace3D.projected_to_world(player.sprite.position)))
	check("actual warrior injury state reaches all native surfaces", hero.meshes.all(func(mesh: MeshInstance3D): return mesh.material_overlay != null))
	player.sprite.flash = 0.0
	hero.sync(player)
	check("cleared source flash removes native injury overlays", hero.meshes.all(func(mesh: MeshInstance3D): return mesh.material_overlay == null))
	var before := hero.joint_rotation("upperarm_r")
	get_tree().paused = true
	player._attack_time = player._attack_duration * 0.9
	hero.sync(player)
	check("game pause freezes actual pose transforms", before.is_equal_approx(hero.joint_rotation("upperarm_r")))
	get_tree().paused = false
	player.dead = true
	hero.sync(player, 3.0)
	check("death samples the actual skeletal clip and hides the held sword", hero._animator.current_animation.to_lower().contains("death") and hero.last_pose["death_time"] > 0.0 and not hero.weapon.visible)
	var dead_leg := hero.joint_rotation("thigh_l")
	player.dead = false
	player._attack_time = 0.0
	hero.sync(player, 0.1)
	check("reviving the same actor resumes its live idle instead of seeking the death clip", hero._animator.current_animation.to_lower().contains("idle") and not hero.joint_rotation("thigh_l").is_equal_approx(dead_leg) and hero.weapon.visible and is_zero_approx(hero.last_pose["death_time"]))

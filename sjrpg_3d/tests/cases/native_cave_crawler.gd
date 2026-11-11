extends TestCase


## 잠복자의 실체·관절·기존 전투/시체 수명이 하나의 입체 모델을 따른다.
func run() -> void:
	var game := await make_game("mage")
	game.set_process(false)
	game.encounters.set_process(false)
	var enemy := Enemy.new()
	enemy.setup(game, "goblin", 1)
	enemy.set_meta("visual_variant", NativeEnemyModels.CRAWLER)
	enemy.position = game.village.boss_point
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	enemy.set_process(false)
	game.camera.position = enemy.position
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	await _frames(2)
	var renderer: NativeEnemyModels = game.ortho_preview._enemy_models
	renderer.sync()
	var model: Dictionary = renderer.entries[enemy.get_instance_id()]
	var root: Node3D = model["root"]
	check(
		"real encounter variant owns its own native volume",
		(
			model["kind"] == NativeEnemyModels.CRAWLER
			and not root.find_children("*", "MeshInstance3D", true, false).is_empty()
		)
	)
	check(
		"crawler is actually presented at its physical foot",
		root.visible and root.position.distance_to(game.ortho_preview.actor_foot(enemy)) < .001
	)
	var body: CharacterBody3D = game.spatial_world.actor_bodies[enemy.get_instance_id()]
	var capsule := (body.get_child(0) as CollisionShape3D).shape as CapsuleShape3D
	var visual: NativeEnemyVisual = model["visual"]
	visual.skeleton.force_update_all_bone_transforms()
	var core_radius := 0.0
	for name: String in visual.manifest["body_core_bones"]:
		var index := visual.skeleton.find_bone(name)
		var point := (
			visual.skeleton.global_transform * visual.skeleton.get_bone_global_pose(index).origin
			- root.global_position
		)
		core_radius = maxf(core_radius, Vector2(point.x, point.z).length())
	check(
		"crawler body core and height agree with the existing capsule",
		(
			core_radius + SpatialWorld3D.SKIN <= capsule.radius
			and is_equal_approx(capsule.height, float(visual.manifest["height_m"]))
		)
	)
	var lit := true
	for mesh in visual.meshes:
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as StandardMaterial3D
			lit = (
				lit
				and material != null
				and material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL
			)
	check("crawler uses lit skinned GLB geometry", lit and visual.skeleton.get_bone_count() > 30)
	var foot := root.position
	var jaw := visual.skeleton.find_bone(visual.manifest["attack_bone"])
	NativeEnemyModels.pose(model, 0, 0, .35)
	visual.skeleton.force_update_all_bone_transforms()
	var open := visual.skeleton.get_bone_global_pose(jaw)
	NativeEnemyModels.pose(model, 0, 0, .60)
	visual.skeleton.force_update_all_bone_transforms()
	check(
		"real jaw closes on the source damage phase",
		(
			not open.is_equal_approx(visual.skeleton.get_bone_global_pose(jaw))
			and root.position == foot
		)
	)
	var other := NativeEnemyModels.build(NativeEnemyModels.CRAWLER)
	check(
		"crawler instances own skeleton and hit materials",
		(
			other["root"] != root
			and (other["visual"] as NativeEnemyVisual).skeleton != visual.skeleton
			and other["materials"][0] != model["materials"][0]
		)
	)
	(other["root"] as Node3D).free()
	enemy.take_damage(enemy.max_hp * 2.0, null)
	var corpse: Dictionary = game.corpses.back()
	game.ortho_preview._world_environment._sync_corpses()
	var id: int = (corpse["visual"] as Node).get_instance_id()
	var fallen: Dictionary = game.ortho_preview._world_environment._corpses[id]
	check(
		"real death retains crawler volume and original lifetime",
		(
			fallen["kind"] == NativeEnemyModels.CRAWLER
			and NativeEnemyModels.corpse_kind(corpse) == NativeEnemyModels.CRAWLER
			and float(corpse["lifetime"]) > 0
		)
	)
	game.remove_corpse(corpse)
	game.ortho_preview._world_environment._sync_corpses()
	check(
		"consumption removes the actual corpse model",
		not game.ortho_preview._world_environment._corpses.has(id)
	)
	game.queue_free()
	await _frames(2)

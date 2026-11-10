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
	await _frames(2)
	var renderer: NativeEnemyModels = game.ortho_preview._enemy_models
	renderer.sync()
	var model: Dictionary = renderer.entries[enemy.get_instance_id()]
	var root: Node3D = model["root"]
	check("real encounter variant owns its own native volume", model["kind"] == NativeEnemyModels.CRAWLER and not root.find_children("*", "MeshInstance3D", true, false).is_empty())
	var lit := true
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		lit = lit and not mesh.mesh is QuadMesh and mesh.material_override is StandardMaterial3D and (mesh.material_override as StandardMaterial3D).shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED
	check("every crawler piece is a lit 3D surface", lit)
	var foot := root.position
	NativeEnemyModels.pose(model, 0, 0, 0.35)
	var open: Transform3D = (model["joints"]["jaw"] as Node3D).transform
	NativeEnemyModels.pose(model, 0, 0, 0.60)
	check("bite closes its real jaw on the damage phase", not open.is_equal_approx((model["joints"]["jaw"] as Node3D).transform) and root.position == foot)
	var other := NativeEnemyModels.build(NativeEnemyModels.CRAWLER)
	check("cached rigs own independent joints and share only geometry", other["root"] != root and other["joints"]["jaw"] != model["joints"]["jaw"] and other["materials"][0] != model["materials"][0])
	(other["root"] as Node3D).free()
	enemy.take_damage(enemy.max_hp * 2.0, null)
	var corpse: Dictionary = game.corpses.back()
	game.ortho_preview._world_environment._sync_corpses()
	var id: int = (corpse["visual"] as Node).get_instance_id()
	var fallen: Dictionary = game.ortho_preview._world_environment._corpses[id]
	check("real death retains crawler volume and original lifetime", fallen["kind"] == NativeEnemyModels.CRAWLER and NativeEnemyModels.corpse_kind(corpse) == NativeEnemyModels.CRAWLER and float(corpse["lifetime"]) > 0)
	game.remove_corpse(corpse)
	game.ortho_preview._world_environment._sync_corpses()
	check("consumption removes the actual corpse model", not game.ortho_preview._world_environment._corpses.has(id))
	game.queue_free()
	await _frames(2)

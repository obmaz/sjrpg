extends TestCase


## 실제 공격 준비 시각과 표시의 수명·접지 기준·재사용을 검증한다.
func run() -> void:
	var reduced := Prefs.reduce_motion
	Prefs.set_reduce_motion(false)
	var game := await make_game("warrior")
	game.set_process(false)
	game.player.set_process(false)
	for other: Enemy in game.enemies:
		other.set_process(false)
		other._state = "idle"
	var renderer: WorldRenderer3D = game.world_renderer
	renderer.set_process(false)
	var feedback: EnemyHitFeedback3D = renderer._enemy_feedback
	var foe := Enemy.new()
	foe.setup(game, "wolf", 1)
	foe.position = game.player.position + Vector2(40, 0)
	game.world.add_child(foe)
	game.enemies.append(foe)
	foe.set_process(false)
	var id := foe.get_instance_id()
	feedback.sync()
	check("idle healthy enemies still allocate no feedback", not feedback.entries.has(id))
	foe.force_chase()
	foe._process(.01)
	check("the ordinary AI enters its actual preparation", foe._state == "windup")
	feedback.sync()
	var entry: Dictionary = feedback.entries.get(id, {})
	if not check("healthy preparing enemies get a compact warning", not entry.is_empty()):
		game.queue_free()
		Prefs.set_reduce_motion(reduced)
		await _frames(2)
		return
	var cue: MeshInstance3D = entry["preparation"]
	check(
		"preparation is separate from damage and boss feedback",
		cue != null and cue.visible and entry["bar"] == null and entry["ring"] == null
	)
	var material := cue.material_override as ShaderMaterial
	var hp: float = game.player.hp
	foe._timer = foe._windup_duration * .75
	feedback.sync()
	var ratios: Vector2 = material.get_shader_parameter("health_ratios")
	check(
		"the bar reads the real attack timer",
		ratios.distance_to(Vector2.ONE * .25) < .0001 and material.get_shader_parameter("preparing")
	)
	var factor := WorldSpace3D.GROUND_UNITS_PER_METER * WorldSpace3D.GROUND_PROJECTION_FACTOR
	var anchor := (
		renderer.actor_foot(foe)
		+ (
			renderer.camera.global_basis.y
			* ((foe.sprite.body_height + EnemyHitFeedback3D.PREPARATION_LIFT) / factor)
		)
	)
	check(
		"warning follows actual feet and leaves room above health bars",
		cue.global_position.distance_to(anchor) < .0001
	)
	check(
		"warning needs only a shared quad and no light or texture",
		cue.mesh is QuadMesh and cue.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	get_tree().paused = true
	var timer := foe._timer
	for frame in 6:
		feedback.sync()
	check(
		"presentation never advances attacks or damages the hero",
		foe._timer == timer and game.player.hp == hp
	)
	get_tree().paused = false
	Prefs.set_reduce_motion(true)
	feedback.sync()
	ratios = material.get_shader_parameter("health_ratios")
	check(
		"reduced motion retains essential preparation information",
		cue.visible and ratios.distance_to(Vector2.ONE * .25) < .0001
	)
	# 같은 적을 우두머리로 전환해도 두 종류의 표시가 서로의 재질 캐시를 빌려 쓰지 않는다.
	foe.make_boss()
	foe._state = "windup"
	foe._timer = foe._windup_duration * .75
	feedback.sync()
	var ring: MeshInstance3D = entry["ring"]
	var ring_material := ring.material_override as ShaderMaterial
	check(
		"promotion starts the boss warning at its actual progress",
		(
			not cue.visible
			and ring.visible
			and absf(float(ring_material.get_shader_parameter("progress")) - .25) < .0001
		)
	)
	foe._timer = foe._windup_duration * .25
	feedback.sync()
	foe.is_boss = false
	feedback.sync()
	ratios = material.get_shader_parameter("health_ratios")
	check(
		"ordinary preparation has its own progress cache after promotion",
		cue.visible and not ring.visible and ratios.distance_to(Vector2.ONE * .75) < .0001
	)
	foe._state = "recover"
	feedback.sync()
	check("contact recovery removes the warning immediately", not cue.visible)
	foe._state = "windup"
	foe._timer = foe._windup_duration * .25
	feedback.sync()
	ratios = material.get_shader_parameter("health_ratios")
	check(
		"later attacks reuse the same mesh and material",
		(
			entry["preparation"] == cue
			and cue.material_override == material
			and ratios.distance_to(Vector2.ONE * .75) < .0001
		)
	)
	foe.freeze(1)
	feedback.sync()
	check("an actual interruption removes the warning", not cue.visible and foe._state != "windup")
	foe._freeze_time = 0
	foe._state = "windup"
	feedback.sync()
	game.player.position = game.dungeon.entry_point()
	check("the active source can enter the actual cave", game.dungeon.enter())
	feedback.sync()
	check("forest preparation never follows the hero into a cave", not feedback.entries.has(id))
	game.dungeon.leave("", false)
	feedback.sync()
	check(
		"returning shows the still-paused forest source state",
		feedback.entries.has(id) and feedback.entries[id]["preparation"].visible
	)
	foe.take_damage(foe.hp + 1, game.player)
	feedback.sync()
	check("death removes the warning before corpse expiry", not feedback.entries.has(id))
	game.spatial_world.teleport_source_actor(
		game.player, foe.position - Vector2(40, 0), Player.RADIUS
	)
	game.camera.position = game.player.position
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	renderer._sync_camera()
	var jumper := Enemy.new()
	jumper.setup(game, "skeleton", 1)
	jumper.position = foe.position + Vector2(-60, 0)
	game.world.add_child(jumper)
	game.enemies.append(jumper)
	jumper.set_process(false)
	jumper._state = "windup"
	jumper._windup_duration = .55
	jumper._timer = .55 * .35
	jumper.take_damage(1, null)
	var old_camera_size := renderer.camera.size
	renderer.camera.size = 2.0
	renderer._enemy_renderer.sync(0)
	# 도약의 크기를 특정 납품 클립에 고정하지 않고 실제 골격 입력으로 가장자리를 검사한다.
	var jumping_model: Dictionary = renderer._enemy_renderer.entries[jumper.get_instance_id()]
	var visual: EnemyVisual = jumping_model["visual"]
	var hips := visual.skeleton.find_bone("ORG-hips")
	visual.skeleton.set_bone_pose_position(
		hips, visual.skeleton.get_bone_pose_position(hips) + Vector3.UP * 2
	)
	var physical_foot: Vector3 = game.spatial_world.actor_foot(jumper)
	feedback.sync()
	var jumping_entry: Dictionary = feedback.entries[jumper.get_instance_id()]
	var above: MeshInstance3D = jumping_entry["preparation"]
	var health: MeshInstance3D = jumping_entry["bar"]
	var screen := renderer.camera.unproject_position(above.global_position)
	var health_screen := renderer.camera.unproject_position(health.global_position)
	check("an animated leap exposes its actual rise", renderer.enemy_pose_lift(jumper) > 1.0)
	check(
		"visual lift never moves the physical actor",
		game.spatial_world.actor_foot(jumper).distance_to(physical_foot) < .0001
	)
	check(
		"a visible jumping enemy keeps its warning within the camera",
		screen.y >= 0 and screen.y < renderer.viewport.size.y
	)
	check("health and preparation remain separate at the top edge", health_screen.y > screen.y + 1)
	renderer.camera.size = old_camera_size
	Prefs.set_reduce_motion(reduced)
	game.queue_free()
	await _frames(2)

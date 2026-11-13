extends TestCase
## 실제 GLB 발의 보폭과 물리 이동·투영 방향·충돌·공격의 연결을 검사한다.
const MeasureStride := preload("res://tools/assets/enemies/measure_stride.gd")
const Fixture := preload("res://tests/native_combat_fixture.gd")


func run() -> void:
	for kind: String in EnemyRenderer3D.KINDS + [EnemyRenderer3D.CRAWLER]:
		var model := EnemyRenderer3D.build(kind)
		var visual: EnemyVisual = model["visual"]
		add_child(visual)
		var gait: Dictionary = visual.manifest["locomotion"]
		var actual := MeasureStride.measure(visual)
		print("STRIDE_RECHECK ", kind, " ", JSON.stringify(actual))
		check(
			"stride measures the current GLB contact feet " + kind,
			(
				actual["contact_bones"] == gait["contact_bones"]
				and _curves_near(actual["distance_curve"], gait["distance_curve"])
				and actual["model_sha256"] == gait["model_sha256"]
				and int(actual["contact_samples"]) == int(gait["contact_samples"])
				and (
					absf(float(actual["distance_per_clip_m"]) - float(gait["distance_per_clip_m"]))
					< 0.00001
				)
			)
		)
		var distance: float = gait["distance_per_clip_m"]
		for scale_factor: float in [1.0, 1.4]:
			var phase := visual.travel_cycle(distance * scale_factor * 0.37, scale_factor)
			EnemyRenderer3D.pose(model, 0.7, phase, 0.0)
			check(
				"scaled body uses the same contact-distance clock " + kind,
				absf(_curve_at(gait["distance_curve"], fposmod(phase, 1.0)) - .37) < .00001
			)

		_check_foot_slide(kind, visual)
		visual.free()
	var game := await make_game("mage")
	game.set_process(false)
	game.player.set_process(false)
	game.exploration.set_process(false)
	game.encounters.set_process(false)
	var backend: SpatialWorld3D = game.spatial_world
	var centre := Fixture.remote_at(Vector3(120, 0, 120))
	var floor_body := Fixture.box(
		backend, centre + Vector3(0, -0.25, 0), Vector3(40, 0.5, 40), SpatialWorld3D.FLOOR
	)
	var wall := Fixture.box(
		backend, centre + Vector3(3.0, 2, 0), Vector3(0.5, 4, 15), SpatialWorld3D.SOLID
	)
	var enemy := Enemy.new()
	enemy.setup(game, "wolf", 1)
	enemy.position = WorldSpace3D.world_to_projected(centre)
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	enemy.set_process(false)
	await Fixture.settle(get_tree())
	game.camera.position = enemy.position
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	for axis in [Vector2.RIGHT, Vector2.DOWN, Vector2(1, 1).normalized()]:
		backend.teleport_source_actor(enemy, WorldSpace3D.world_to_projected(centre), enemy.radius, true)
		var start := enemy._run_distance_m
		var walked := 0.0
		for step in 10:
			var before := backend.actor_foot(enemy)
			enemy._step(Iso.project(axis).normalized(), 0.01)
			var after := backend.actor_foot(enemy)
			walked += Vector2(after.x - before.x, after.z - before.z).length()
		check(
			"gait follows real metres in every camera direction " + str(axis),
			walked > 0.05 and absf(enemy._run_distance_m - start - walked) < 0.0001
		)
	# 벽에 닿아 추적을 계속해도 이동하지 못하면 보행 위상이 늘지 않는다.
	for step in 80:
		enemy._step(Iso.project(Vector2.RIGHT).normalized(), 0.02)
	var stopped := enemy._run_distance_m
	for step in 5:
		enemy._step(Iso.project(Vector2.RIGHT).normalized(), 0.02)
	check("blocked pursuit never pedals in place", absf(enemy._run_distance_m - stopped) < 0.0001)
	backend.teleport_source_actor(enemy, WorldSpace3D.world_to_projected(centre), enemy.radius, true)
	check("teleport does not count as a stride", is_equal_approx(enemy._run_distance_m, stopped))
	enemy._state = "chase"
	game.world_renderer._enemy_renderer.sync()
	var live: Dictionary = game.world_renderer._enemy_renderer.entries[enemy.get_instance_id()]
	var rendered: EnemyVisual = live["visual"]
	check(
		"production presenter uses measured metres instead of the old 70px cycle",
		is_equal_approx(
			rendered.sample_time,
			(
				fposmod(rendered.travel_cycle(stopped, 1.0), 1.0)
				* float(rendered.manifest["clips"]["run"]["length"])
			)
		)
	)
	var held := rendered.sample_time
	get_tree().paused = true
	game.world_renderer._enemy_renderer.sync(1.0)
	check("pause holds gait pose", is_equal_approx(rendered.sample_time, held))
	get_tree().paused = false
	enemy._state = "windup"
	enemy._timer = enemy._windup_duration * 0.3
	game.world_renderer._enemy_renderer.sync()
	check("distance never overrides attack timing", rendered.active_clip == "attack")
	Fixture.remove([floor_body, wall])
	game.queue_free()
	await _frames(2)


func _curve_at(curve: Array, phase: float) -> float:
	var index := phase * (curve.size() - 1)
	var first := mini(floori(index), curve.size() - 2)
	return lerpf(float(curve[first]), float(curve[first + 1]), index - first)


func _check_foot_slide(kind: String, visual: EnemyVisual) -> void:
	var gait: Dictionary = visual.manifest["locomotion"]
	var names: Array = gait["contact_bones"]
	var curve: Array = gait["distance_curve"]
	var frames := curve.size() - 1
	var poses: Array[PackedVector3Array] = []
	var lows := PackedFloat64Array()
	var spans := PackedFloat64Array()
	for name: String in names:
		poses.append(PackedVector3Array())
	for frame in frames + 1:
		visual.sample("run", float(visual.manifest["clips"]["run"]["length"]) * frame / frames)
		visual.skeleton.force_update_all_bone_transforms()
		for foot in names.size():
			poses[foot].append(
				visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone(names[foot])).origin
			)
	for track in poses:
		var low := INF
		var high := -INF
		for p in track:
			low = minf(low, p.y)
			high = maxf(high, p.y)
		lows.append(low)
		spans.append(maxf(.05, high - low))
	var residual := 0.0
	var samples := 0
	for frame in frames:
		var lowest := INF
		var foot_delta := 0.0
		for foot in names.size():
			var a := poses[foot][frame]
			var b := poses[foot][frame + 1]
			var height := ((a.y + b.y) * .5 - lows[foot]) / spans[foot]
			if height < .25 and (a.z - b.z) * frames > .05 and height < lowest:
				lowest = height
				foot_delta = b.z - a.z
		if is_finite(lowest):
			var body_delta: float = (
				(float(curve[frame + 1]) - float(curve[frame])) * float(gait["distance_per_clip_m"])
			)
			# 지면에 둔 발의 월드 변위: 몸체 이동 + 실제 골격의 로컬 이동.
			residual += absf(body_delta + foot_delta) / body_delta
			samples += 1
	print("GROUNDED_FOOT_SLIDE ", kind, " ", residual / samples)
	check(
		"grounded feet stay within 10 percent longitudinal slip " + kind,
		samples >= 12 and residual / samples < .10
	)


func _curves_near(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if absf(float(a[i]) - float(b[i])) > .000001:
			return false
	return true

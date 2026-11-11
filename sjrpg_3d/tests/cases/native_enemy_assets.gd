extends TestCase
## 실제 GLB의 스킨·클립·인스턴스 소유권과 기존 게임 시계의 연결을 확인한다.


func _different(a: PackedVector3Array, b: PackedVector3Array) -> bool:
	for i in mini(a.size(), b.size()):
		if a[i].distance_to(b[i]) > .001:
			return true
	return false


func run() -> void:
	for kind: String in NativeEnemyModels.KINDS + [NativeEnemyModels.CRAWLER]:
		check(
			"species uses its independently editable imported scene " + kind,
			NativeEnemyAssets.uses_asset(kind)
		)
		var model := NativeEnemyModels.build(kind)
		var visual: NativeEnemyVisual = model["visual"]
		add_child(visual)
		await _frames(2)
		NativeEnemyModels.pose(model, 0, 0, 0)
		var idle := visual.posed_vertices()
		check(
			"imported model has actual weighted geometry and a skeleton " + kind,
			(
				idle.size() > 500
				and visual.skeleton.get_bone_count() >= 8
				and visual.meshes.size() == 1
				and visual.materials.size() <= 4
			)
		)
		var root_at := visual.position
		for role in ["idle", "run", "attack", "hit", "death"]:
			check(
				"authored clip exists " + kind + "/" + role,
				(
					visual.animator.has_animation(role)
					and visual.animator.get_animation(role).length > 0.0
				)
			)
		NativeEnemyModels.pose(model, 0, .24, 0)
		var running := visual.posed_vertices()
		check("locomotion deforms real skin vertices " + kind, _different(idle, running))
		NativeEnemyModels.pose(model, 0, 0, .42)
		var prepared := visual.posed_vertices()
		NativeEnemyModels.pose(model, 0, 0, .60)
		var impact := visual.posed_vertices()
		check(
			"source hit phase selects the authored contact frame " + kind,
			(
				is_equal_approx(
					visual.sample_time, float(visual.manifest["clips"]["attack"]["contact_time"])
				)
				and _different(prepared, impact)
				and visual.position == root_at
			)
		)
		for phase in [.2, .42, .60, .8]:
			NativeEnemyModels.pose(model, 0, 0, phase)
			var minimum := INF
			for point in visual.posed_vertices():
				minimum = minf(minimum, point.y)
			check("attack skin stays above the floor " + kind + "/" + str(phase), minimum >= -.01)
			if kind == "skeleton":
				check("the grounded axe strike stays near its feet " + str(phase), minimum < .12)
		if kind == "skeleton":
			# 공격 앞뒤의 idle 블렌드와 별도 피격 FBX도 같은 발 기준이어야 한다.
			for role in ["attack", "hit"]:
				for fraction in [0.0, .05, .95, 1.0]:
					visual.sample(role, float(visual.manifest["clips"][role]["length"]) * fraction)
					var bottom := INF
					for point in visual.posed_vertices():
						bottom = minf(bottom, point.y)
					check(
						(
							"source clip blends preserve the shared floor "
							+ role
							+ "/"
							+ str(fraction)
						),
						bottom >= -.01 and bottom < .12
					)
		NativeEnemyModels.pose(model, 0, 0, 1.0)
		check(
			"recovery returns to the same idle without shifting physics " + kind,
			not _different(idle, visual.posed_vertices()) and visual.position == root_at
		)
		var second := NativeEnemyModels.build(kind)
		var other: NativeEnemyVisual = second["visual"]
		add_child(other)
		await _frames(2)
		var untouched := other.posed_vertices()
		NativeEnemyModels.pose(model, .8, .35, .55)
		NativeEnemyModels.tint(model, Color.WHITE, .6, Color.RED, .3)
		check(
			"instances share immutable mesh and clip resources " + kind,
			(
				visual.meshes[0].mesh == other.meshes[0].mesh
				and visual.animator.get_animation("run") == other.animator.get_animation("run")
			)
		)
		check(
			"bones, playback and hit materials remain actor-owned " + kind,
			(
				visual.skeleton != other.skeleton
				and visual.animator != other.animator
				and visual.materials[0] != other.materials[0]
				and not _different(untouched, other.posed_vertices())
				and other.materials[0].albedo_color == other.colors[0]
			)
		)
		NativeEnemyModels.pose(model, 0, 0, 0, true)
		var dead := visual.posed_vertices()
		var lowest := INF
		for vertex in dead:
			lowest = minf(lowest, vertex.y)
		check("death skin rests on its actual ground contact " + kind, absf(lowest) < .005)
		var corpse_bounds := AABB(dead[0], Vector3.ZERO)
		for point in dead:
			corpse_bounds = corpse_bounds.expand(point)
		if kind in ["boar", "cave_crawler"]:
			var standing := AABB(idle[0], Vector3.ZERO)
			for point in idle:
				standing = standing.expand(point)
			check(
				"death falls onto the ground rather than yawing upright " + kind,
				corpse_bounds.size.y < standing.size.y * .75
			)
		var center := corpse_bounds.get_center()
		check(
			"corpse remains centered on the actual death location " + kind,
			Vector2(center.x, center.z).length() < .005
		)
		check(
			"death is an actual frozen skinned pose " + kind,
			_different(idle, dead) and visual.active_clip == "death" and visual.rotation.z == 0
		)
		visual.free()
		other.free()
	await _frames(2)

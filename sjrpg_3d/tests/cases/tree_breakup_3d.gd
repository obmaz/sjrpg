extends TestCase
## 실제 원본 삼각형과 파괴 자세, 불 부착점, 동시 표시 예산을 확인한다.


func run() -> void:
	var root := Node3D.new()
	add_child(root)
	var fx := TreeBreakup3D.new().setup(root)
	var previous_motion := Prefs.reduce_motion
	Prefs.reduce_motion = false
	for variant in TreeGeometry3D.PATHS.size():
		var anchors := TreeDamageGeometry3D.fire_anchors(variant)
		var wood := TreeDamageGeometry3D.mesh(variant, "charred")
		var low := INF
		var high := -INF
		for point in anchors:
			check("flame anchor lies on the original wood", TreeGeometry3D._points(wood).has(point))
			low = minf(low, point.y)
			high = maxf(high, point.y)
		check(
			"flames reach branches above the trunk base", high - low > wood.get_aabb().size.y * 0.25
		)
		for kind in ["charred", "frozen"]:
			var source := TreeDamageGeometry3D.mesh(variant, kind)
			var parts := TreeDamageGeometry3D.fragments(variant, kind)
			var triangles := 0
			var occupied := 0
			for part: Mesh in parts:
				if part != null:
					occupied += 1
					triangles += TreeGeometry3D._triangle_count(part)
			check(
				"breakup preserves every original triangle",
				triangles == TreeGeometry3D._triangle_count(source)
			)
			check("each family has several moving wood/crown pieces", occupied >= 4)
			var frame := Transform3D(
				Basis(Vector3.UP, 0.8).scaled(Vector3(0.8, 1.1, 0.8)), Vector3(3, 2, 1)
			)
			fx.burst({"variant": variant, "transform": frame}, kind)
			var slot: Dictionary = fx._slots[(fx._serial - 1) % TreeBreakup3D.LIMIT]
			var draw: MeshInstance3D
			for candidate: MeshInstance3D in slot["draws"]:
				if candidate.visible:
					draw = candidate
					check(
						"replacement starts in the exact original pose",
						candidate.transform.is_equal_approx(frame)
					)
			fx.sync(0.24)
			check(
				"hit makes actual tree geometry separate and rotate",
				not draw.transform.is_equal_approx(frame)
			)
			var stopped := draw.transform
			fx.sync(0.0)
			check("paused breakup keeps its pose", draw.transform.is_equal_approx(stopped))
	for hit in 20:
		fx.burst({"variant": 0, "transform": Transform3D.IDENTITY}, "charred")
	check("mass destruction reuses only three tree slots", fx.active_count() == TreeBreakup3D.LIMIT)
	fx.sync(TreeBreakup3D.SECONDS)
	check("all actual mesh fragments retire on time", fx.active_count() == 0)
	for slot in fx._slots:
		for draw: MeshInstance3D in slot["draws"]:
			check("expired fragments stop drawing", not draw.visible)
	Prefs.reduce_motion = true
	fx.burst({"variant": 0, "transform": Transform3D.IDENTITY}, "frozen")
	check("reduce motion omits flying tree pieces", fx.active_count() == 0)
	Prefs.reduce_motion = false
	fx.burst({"variant": 0, "transform": Transform3D.IDENTITY}, "frozen")
	fx.clear()
	check("region change clears the entire animation pool", fx.active_count() == 0)
	var embers := TreeDebris3D.new().setup(root)
	var burning: Array[Dictionary] = []
	for tree in 20:
		burning.append(
			{"variant": tree % TreeGeometry3D.PATHS.size(), "transform": Transform3D.IDENTITY}
		)
	embers.sync(0.1, burning)
	check(
		"mass fire stays inside the branch flame budget",
		(
			embers.embers.multimesh.visible_instance_count
			== TreeDebris3D.FIRE_LIMIT * TreeDamageGeometry3D.FLAMES_PER_TREE
		)
	)
	embers.sync(0.1, [])
	check(
		"burnout or region change retires every flame",
		embers.embers.multimesh.visible_instance_count == 0 and not embers.embers.visible
	)
	Prefs.reduce_motion = previous_motion
	root.queue_free()
	await _frames(2)

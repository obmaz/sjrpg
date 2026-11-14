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
		var crown: Mesh = TreeGeometry3D.mesh_library()[variant]["mesh"]
		var toward := Vector3(1.0, 1.0, 1.0).normalized()
		for index in anchors.size():
			var point := anchors[index]
			var source := wood if index < 2 else crown
			check(
				"fire sits on the first visible wood or crown surface",
				_on_visible_surface(source, point, toward)
			)
			low = minf(low, point.y)
			high = maxf(high, point.y)
		check(
			"flames reach the upper crown rather than the trunk base",
			high > crown.get_aabb().end.y * 0.75 and high - low > wood.get_aabb().size.y * 0.45
		)
		var turned := Transform3D(Basis(Vector3.UP, PI), Vector3(3, 2, 1))
		var view := Basis(Vector3.RIGHT, -0.6154797) * Basis(Vector3.UP, PI / 4.0)
		var original_sector := TreeDamageGeometry3D.fire_view_sector(Transform3D.IDENTITY, view)
		check(
			"rotated trees select the opposite exposed crown instead of hidden wood",
			TreeDamageGeometry3D.fire_view_sector(turned, view)
			== posmod(original_sector + 4, TreeDamageGeometry3D.FIRE_VIEW_SECTORS)
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
	var stable_writes := embers.fire_buffer_writes
	var advancing_clock: float = embers.fire_material.get_shader_parameter("fire_time")
	embers.sync(0.2, burning)
	check("steady burning advances density flow without rewriting any GPU instance buffers", embers.fire_buffer_writes == stable_writes and float(embers.fire_material.get_shader_parameter("fire_time")) > advancing_clock)
	embers.sync(0.0, burning, Basis(Vector3.UP, PI * 0.5))
	check("a changed camera direction updates the exposed branch slots", embers.fire_buffer_writes > stable_writes)
	embers.sync(0.0, burning)
	stable_writes = embers.fire_buffer_writes
	var old_frame: Transform3D = burning[0]["transform"]
	var old_fire_position := embers.fire_poses[0].origin
	burning[0]["transform"] = Transform3D(Basis.IDENTITY, Vector3(2, 1, 3))
	embers.sync(0.0, burning)
	check("a different tree in a reused slot submits its actual new transform", embers.fire_buffer_writes > stable_writes and embers.fire_poses[0].origin.is_equal_approx(old_fire_position + Vector3(2, 1, 3)))
	burning[0]["transform"] = old_frame
	embers.sync(0.0, burning)
	var previous_quality := Prefs.low_resolution
	Prefs.low_resolution = true
	embers.sync(0.0, burning)
	check("low quality caps fire density work at six steps", int(embers.fire_material.get_shader_parameter("density_steps")) == 6)
	Prefs.low_resolution = false
	embers.sync(0.0, burning)
	check("high quality keeps ten fire density steps", int(embers.fire_material.get_shader_parameter("density_steps")) == 10)
	Prefs.low_resolution = previous_quality
	embers.sync(0.0, burning)
	var broad := embers.fire_poses[3].basis
	var tip := embers.fire_poses[7].basis
	check("branch fires form broad overlapping clusters and slimmer upper wisps", broad.x.length() / broad.y.length() > 1.3 and tip.x.length() / tip.y.length() < 1.1)
	var fire_aabb := embers.embers.multimesh.custom_aabb
	var bounds_cover_motion := true
	for index in embers.embers.multimesh.visible_instance_count:
		var pose := embers.fire_poses[index]
		bounds_cover_motion = bounds_cover_motion and fire_aabb.has_point(pose * Vector3(0, 2.45, 0))
	check("explicit fire bounds retain rising embers during continuous transform updates", bounds_cover_motion)
	var fire_mesh := embers.embers.multimesh.mesh
	check(
		"fire shares one density volume proxy and two small embers within its geometry budget",
		fire_mesh.get_aabb().size.z > 0.45 and TreeGeometry3D._triangle_count(fire_mesh) == 20
	)
	var fire_arrays := fire_mesh.surface_get_arrays(0)
	var fire_vertices: PackedVector3Array = fire_arrays[Mesh.ARRAY_VERTEX]
	var fire_normals: PackedVector3Array = fire_arrays[Mesh.ARRAY_NORMAL]
	var fire_colors: PackedColorArray = fire_arrays[Mesh.ARRAY_COLOR] if fire_arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var explicit_white := fire_colors.size() == fire_vertices.size()
	for color in fire_colors:
		explicit_white = explicit_white and color.is_equal_approx(Color.WHITE)
	check("fire alpha has explicit white vertex colors independent of previously drawn actors", explicit_white)
	var winding_valid := true
	var volume := 0.0
	for triangle in range(0, fire_vertices.size(), 3):
		var a := fire_vertices[triangle]
		var b := fire_vertices[triangle + 1]
		var c := fire_vertices[triangle + 2]
		winding_valid = winding_valid and (b - a).cross(c - a).dot(fire_normals[triangle]) < -0.000001
		volume += a.dot(b.cross(c)) / 6.0
	check("density proxy has outward normals and clockwise exterior faces", winding_valid and volume < -0.01)
	var stopped_fire := embers.fire_poses[3]
	var stopped_clock: float = embers.fire_material.get_shader_parameter("fire_time")
	embers.sync(0.0, burning)
	check(
		"paused fire keeps its surface attachment and animation pose",
		embers.fire_poses[3].is_equal_approx(stopped_fire)
		and is_equal_approx(float(embers.fire_material.get_shader_parameter("fire_time")), stopped_clock)
	)
	Prefs.reduce_motion = true
	embers.sync(0.1, burning)
	stopped_fire = embers.fire_poses[3]
	stopped_clock = embers.fire_material.get_shader_parameter("fire_time")
	embers.sync(1.0, burning)
	check(
		"reduce motion keeps crown fire visible and steady",
		embers.embers.visible
		and embers.fire_poses[3].is_equal_approx(stopped_fire)
		and is_equal_approx(float(embers.fire_material.get_shader_parameter("fire_time")), stopped_clock)
	)
	embers.sync(0.1, [])
	check(
		"burnout or region change retires every flame",
		embers.embers.multimesh.visible_instance_count == 0 and not embers.embers.visible
	)
	Prefs.reduce_motion = previous_motion
	root.queue_free()
	await _frames(2)


## 원본 삼각형의 첫 표면에 붙는지 확인해 잎 안쪽 가지로 되돌아가는 회귀를 잡는다.
func _on_visible_surface(source: Mesh, point: Vector3, toward: Vector3) -> bool:
	var faces := source.get_faces()
	var start := point + toward * source.get_aabb().size.length() * 2.0
	var nearest := INF
	for index in range(0, faces.size(), 3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(
			start, point - toward * 0.01, faces[index], faces[index + 1], faces[index + 2]
		)
		if hit != null:
			var at: Vector3 = hit
			nearest = minf(nearest, start.distance_to(at))
	return is_finite(nearest) and absf(start.distance_to(point) - nearest) < 0.002

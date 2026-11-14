class_name TreeDebris3D
extends RefCounted
## 작은 불투명 파편48개를 한 MultiMesh로 재사용한다. 물리/그림자/광원 없음.

const LIMIT := 48
const PER_BREAK := 6
const FIRE_LIMIT := 8
var root: Node3D
var fragments: MultiMeshInstance3D
var embers: MultiMeshInstance3D
var fire_material: ShaderMaterial
var fire_poses: Array[Transform3D] = []
var fire_buffer_writes := 0
var fire_slot_updates := 0
var _fire_initialized := PackedByteArray()
var _fire_seeds := PackedFloat64Array()
var _particles: Array[Dictionary] = []
var _serial := 0
var _time := 0.0
var emitted := 0


func setup(parent: Node3D) -> TreeDebris3D:
	root = parent
	fragments = _batch("TreeSplinters", LIMIT, false)
	embers = _batch("TreeEmbers", FIRE_LIMIT * TreeDamageGeometry3D.FLAMES_PER_TREE, true)
	fire_poses.resize(FIRE_LIMIT * TreeDamageGeometry3D.FLAMES_PER_TREE)
	_fire_initialized.resize(fire_poses.size())
	_fire_seeds.resize(fire_poses.size())
	return self


func _batch(label: String, count: int, glow: bool) -> MultiMeshInstance3D:
	var ink := StandardMaterial3D.new()
	ink.vertex_color_use_as_albedo = true
	ink.roughness = 0.95
	var shape: Mesh
	if glow:
		var fire := ShaderMaterial.new()
		fire.shader = load("res://assets/effects/shaders/tree_fire.gdshader")
		fire_material = fire
		fire.set_shader_parameter("density_noise", load("res://assets/effects/textures/tree_fire_density.tres"))
		shape = _flame_mesh(fire)
	else:
		var shard := PrismMesh.new()
		shard.size = Vector3(0.08, 0.20, 0.055)
		shard.material = ink
		shape = shard
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.use_custom_data = glow
	multi.mesh = shape
	multi.instance_count = count
	var draw := MultiMeshInstance3D.new()
	draw.name = label
	draw.multimesh = multi
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	draw.set_meta("occlusion_dynamic", true)
	root.add_child(draw)
	for index in count:
		multi.set_instance_transform(index, _hidden())
	return draw


## 공유 프록시의 내부 밀도를 셰이더가 적분한다. 외면은 불의 실루엣이 아니다.
## 작은 실제 불씨2개도 같은 메시/패스에 넣는다. UV2.y로만 구별한다.
static func _flame_mesh(material: Material) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	# COLOR.a를 읽는 인스턴스는 다른 draw의 GL 기본 속성값에 의존하지 않게 한다.
	surface.set_color(Color.WHITE)
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 1.3, 1.0)
	var box_arrays := box.surface_get_arrays(0)
	var box_vertices: PackedVector3Array = box_arrays[Mesh.ARRAY_VERTEX]
	var box_normals: PackedVector3Array = box_arrays[Mesh.ARRAY_NORMAL]
	var box_uvs: PackedVector2Array = box_arrays[Mesh.ARRAY_TEX_UV]
	var box_indices: PackedInt32Array = box_arrays[Mesh.ARRAY_INDEX]
	for index in box_indices:
		surface.set_normal(box_normals[index])
		surface.set_uv(box_uvs[index])
		surface.set_uv2(Vector2.ZERO)
		surface.add_vertex(box_vertices[index] + Vector3.UP * 0.65)
	for ember in 2:
		var center := Vector3(-0.14 + float(ember) * 0.27, 0.94 + float(ember) * 0.22, 0.08)
		var points: Array[Vector3] = [center + Vector3(0, 0.032, 0), center + Vector3(-0.018, 0, -0.015), center + Vector3(0.018, 0, -0.015), center + Vector3(0, 0, 0.022)]
		for face in [[0, 1, 2], [0, 2, 3], [0, 3, 1], [1, 3, 2]]:
			var normal := (points[face[1]] - points[face[0]]).cross(points[face[2]] - points[face[0]]).normalized()
			var face_center: Vector3 = (points[face[0]] + points[face[1]] + points[face[2]]) / 3.0
			if normal.dot(face_center - (center + Vector3.UP * 0.008)) < 0.0:
				normal = -normal
			var normals: Array[Vector3] = [normal, normal, normal, normal]
			var uvs: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
			_flame_triangle(surface, points, normals, uvs, face, Vector2(float(ember) * 0.43 + 0.16, 1))
	return surface.commit()


static func _flame_triangle(surface: SurfaceTool, points: Array[Vector3], normals: Array[Vector3], uvs: Array[Vector2], indices: Array, tag: Vector2) -> void:
	var a: int = indices[0]
	var b: int = indices[1]
	var c: int = indices[2]
	if (points[b] - points[a]).cross(points[c] - points[a]).dot(normals[a]) > 0.0:
		b = indices[2]
		c = indices[1]
	for index in [a, b, c]:
		surface.set_normal(normals[index])
		surface.set_uv(uvs[index])
		surface.set_uv2(tag)
		surface.add_vertex(points[index])


static func _hidden() -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)


func burst(point: Vector3, kind: String) -> void:
	if Prefs.reduce_motion:
		return
	var count := 2 if kind == "chip" else PER_BREAK
	for index in count:
		_serial += 1
		var angle := float((_serial * 137) % 360) * PI / 180.0
		var color := Color(0.47, 0.32, 0.16)
		if kind == "frozen":
			color = Color(0.56, 0.81, 0.93)
		elif kind in ["charred", "ash", "burning"]:
			color = Color(0.22, 0.20, 0.18)
		if _particles.size() >= LIMIT:
			_particles.pop_front()
		_particles.append(
			{
				"at": point + Vector3.UP * 0.4,
				"age": 0.0,
				"velocity": Vector3(cos(angle) * 0.9, 1.5 + (index % 3) * 0.25, sin(angle) * 0.9),
				"angle": angle,
				"color": color
			}
		)
		emitted += 1


func sync(delta: float, burning: Array[Dictionary], camera_basis := Basis.IDENTITY) -> void:
	_time += delta
	for particle in _particles:
		particle["age"] += delta
	_particles = _particles.filter(func(p: Dictionary): return p["age"] < 0.6)
	var multi := fragments.multimesh
	multi.visible_instance_count = 0 if Prefs.reduce_motion else _particles.size()
	for index in multi.visible_instance_count:
		var p: Dictionary = _particles[index]
		var age: float = p["age"]
		var at: Vector3 = p["at"] + p["velocity"] * age + Vector3.DOWN * 2.8 * age * age
		var scale := 1.0 - smoothstep(0.4, 0.6, age)
		var basis := Basis.from_euler(Vector3(age * 4.0, p["angle"], age * 3.0))
		multi.set_instance_transform(index, Transform3D(basis.scaled(Vector3.ONE * scale), at))
		multi.set_instance_color(index, p["color"])
	var fire := embers.multimesh
	# GLES3의 인스턴스 custom data는 half-float다. 공유 시계는 float uniform으로 정밀도를 유지한다.
	fire_material.set_shader_parameter("fire_time", 0.4 if Prefs.reduce_motion else _time)
	fire_material.set_shader_parameter("density_steps", 6 if Prefs.low_resolution else 10)
	var per_tree := TreeDamageGeometry3D.FLAMES_PER_TREE
	var fire_count := mini(FIRE_LIMIT, burning.size()) * per_tree
	if fire.visible_instance_count != fire_count:
		fire.visible_instance_count = fire_count
		fire_buffer_writes += 1
	var fire_bounds := AABB()
	# 밀도 프록시와 셰이더에서 위로 떠오르는 불씨까지 포함한다.
	var local_bounds := fire.mesh.get_aabb().expand(Vector3(0.5, 2.5, 0.5))
	for index in fire.visible_instance_count:
		var entry: Dictionary = burning[index / per_tree]
		var frame: Transform3D = entry["transform"]
		var sector := TreeDamageGeometry3D.fire_view_sector(frame, camera_basis)
		var anchors := TreeDamageGeometry3D.fire_anchors(entry["variant"], sector)
		var anchor: Vector3 = frame * anchors[index % per_tree]
		var crown: Mesh = TreeGeometry3D.mesh_library()[entry["variant"]]["mesh"]
		var height := crown.get_aabb().size.y * frame.basis.y.length()
		var seed := fposmod(frame.origin.x * 0.73 + frame.origin.z * 0.41 + float(index % per_tree) * 0.618, 1.0)
		var size := clampf(height * 0.16, 0.52, 1.05) * lerpf(0.68, 1.16, seed)
		if index % per_tree < 2:
			size *= 0.70
		# 외피에서 몇cm만 떼어 잎과 겹치는 깊이 깜빡임을 막는다. 다른 물체의 깊이는 유지한다.
		var at := anchor + camera_basis.z * clampf(height * 0.008, 0.025, 0.05)
		var slot := index % per_tree
		var spread := Vector3(0.85, 1.55, 0.85)
		if slot in [2, 3, 4, 5]:
			# 네 넓은 가지 군락이 겹치고 꼭대기 둘은 가느다란 불꽃으로 남는다.
			spread = Vector3(2.45, lerpf(1.10, 1.50, seed), 1.85)
		elif slot >= 6:
			spread = Vector3(1.45, lerpf(1.45, 1.85, seed), 1.15)
		var lean := (seed - 0.5) * 0.52
		var basis := Basis(Vector3.UP, seed * TAU) * Basis(Vector3.FORWARD, lean)
		basis = basis * Basis.from_scale(spread * size)
		var pose := Transform3D(basis, at)
		# 불의 움직임은 셰이더 밀도장으로 만든다. 고정된 가지의 GPU 버퍼는 바뀔 때만 쓴다.
		if (
			_fire_initialized[index] == 0
			or not fire_poses[index].is_equal_approx(pose)
			or not is_equal_approx(_fire_seeds[index], seed)
		):
			fire_poses[index] = pose
			_fire_seeds[index] = seed
			_fire_initialized[index] = 1
			fire.set_instance_transform(index, pose)
			fire.set_instance_color(index, Color(1.0, 1.0, 1.0, 0.95))
			fire.set_instance_custom_data(index, Color(seed, 0.0, 0.0, 0.0))
			fire_slot_updates += 1
			fire_buffer_writes += 3
		var bounds: AABB = pose * local_bounds
		fire_bounds = bounds if index == 0 else fire_bounds.merge(bounds)

	if not fire.custom_aabb.is_equal_approx(fire_bounds):
		fire.custom_aabb = fire_bounds
		fire_buffer_writes += 1

	fragments.visible = not _particles.is_empty() and not Prefs.reduce_motion
	embers.visible = not burning.is_empty()

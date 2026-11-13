class_name TreeDebris3D
extends RefCounted
## 작은 불투명 파편48개를 한 MultiMesh로 재사용한다. 물리/그림자/광원 없음.

const LIMIT := 48
const PER_BREAK := 6
const FIRE_LIMIT := 8
var root: Node3D
var fragments: MultiMeshInstance3D
var embers: MultiMeshInstance3D
var _particles: Array[Dictionary] = []
var _serial := 0
var _time := 0.0
var emitted := 0


func setup(parent: Node3D) -> TreeDebris3D:
	root = parent
	fragments = _batch("TreeSplinters", LIMIT, false)
	embers = _batch("TreeEmbers", FIRE_LIMIT * 3, true)
	return self


func _batch(label: String, count: int, glow: bool) -> MultiMeshInstance3D:
	var ink := StandardMaterial3D.new()
	ink.vertex_color_use_as_albedo = true
	ink.roughness = 0.95
	var shape: PrimitiveMesh
	if glow:
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		var fire := ShaderMaterial.new()
		fire.shader = load("res://assets/models/environment/traps/shared/flame.gdshader")
		fire.set_shader_parameter(
			"fire_atlas", load("res://assets/effects/textures/combat-frames.webp")
		)
		quad.material = fire
		shape = quad
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


func sync(delta: float, burning: Array[Vector3], camera_basis := Basis.IDENTITY) -> void:
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
	fire.visible_instance_count = mini(FIRE_LIMIT, burning.size()) * 3
	for index in fire.visible_instance_count:
		var tree_index := index / 3
		var phase := fmod(_time * 1.1 + float(index) * 0.37, 1.0)
		if Prefs.reduce_motion:
			phase = 0.4
		var angle := float(index % 3) * TAU / 3.0
		var at := (
			burning[tree_index] + Vector3(sin(angle) * 0.55, 0.6 + phase * 0.2, cos(angle) * 0.55)
		)
		var basis := camera_basis.scaled(Vector3(0.55, 0.8, 1.0) * (1.0 - phase * 0.25))
		fire.set_instance_transform(index, Transform3D(basis, at))
		fire.set_instance_color(index, Color(1.0, 1.0, 1.0, 0.65))
		fire.set_instance_custom_data(index, Color(floorf(phase * 4.0) / 4.0, 0.0, 0.0, 0.0))
	fragments.visible = not _particles.is_empty() and not Prefs.reduce_motion
	embers.visible = not burning.is_empty()

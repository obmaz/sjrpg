class_name NovaEffects3D
extends RefCounted
## 기존 nova 소스의 시간만 읽는 얇은 바닥 링. 짧은 효과 노드를 한도 안에서 재사용한다.
const MAX_PULSES := 24
const SEGMENTS := 64
const SURFACE_LIFT := .08
static var _mesh: ArrayMesh
var _renderer: Node
var _root: Node3D
var entries: Dictionary = {}
var _pool: Array[MeshInstance3D] = []
var builds := 0


func setup(presenter: Node) -> NovaEffects3D:
	_renderer = presenter
	_root = Node3D.new()
	_root.name = "NativeNovaPulses"
	_renderer.stage.add_child(_root)
	if _mesh == null:
		_mesh = _ring()
	return self


static func _ring() -> ArrayMesh:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for index in SEGMENTS:
		var angle := TAU * index / SEGMENTS
		for radius: float in [.93, 1.0]:
			points.append(Vector3(cos(angle) * radius, 0, sin(angle) * radius))
			normals.append(Vector3.UP)
		var here := index * 2
		var next := ((index + 1) % SEGMENTS) * 2
		indices.append_array(PackedInt32Array([here, next, here + 1, here + 1, next, next + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result


func _new_node() -> MeshInstance3D:
	builds += 1
	var node := MeshInstance3D.new()
	node.mesh = _mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ink.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = ink
	_root.add_child(node)
	return node


func sync() -> void:
	var current := {}
	var selected: Array[Effect] = []
	if not Prefs.reduce_motion:
		var sources := Effect.in_world(_renderer.game.world)
		for index in range(sources.size() - 1, -1, -1):
			var source: Effect = sources[index]
			if (
				source.is_queued_for_deletion()
				or source.kind != "nova"
				or source.age < 0
				or source.age >= source.life
				or source.radius <= 0
				or not source.native_position().is_finite()
			):
				continue
			selected.append(source)
			current[source.get_instance_id()] = true
			if selected.size() >= MAX_PULSES:
				break
	# 먼저 퇴역시켜 지역 전환에서도 기존 노드를 새 효과에 재사용한다.
	for id in entries.keys():
		if not current.has(id):
			var node: MeshInstance3D = entries[id]
			node.hide()
			_pool.append(node)
			entries.erase(id)
	for source: Effect in selected:
		var id := source.get_instance_id()
		if not entries.has(id):
			entries[id] = _pool.pop_back() if not _pool.is_empty() else _new_node()
		var node: MeshInstance3D = entries[id]
		var progress := clampf(source.age / maxf(.001, source.life), 0, 1)
		var radius := SpatialWorld3D.radius_metres(source.radius) * lerpf(.3, 1.0, progress)
		node.position = source.native_position() + Vector3.UP * SURFACE_LIFT
		node.scale = Vector3.ONE * radius
		var ink := node.material_override as StandardMaterial3D
		var color := Color(source.color, source.color.a * (1.0 - progress))
		if ink.albedo_color != color:
			ink.albedo_color = color
		node.show()


func snapshot() -> Dictionary:
	return {
		"active": entries.size(),
		"pooled": _pool.size(),
		"builds": builds,
		"triangles_per_pulse": SEGMENTS * 2
	}

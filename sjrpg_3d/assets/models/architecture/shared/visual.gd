@tool
class_name NativeArchitectureVisual
extends Node3D
## GLB는 기하·UV·피벗을, 씬은 Godot 전용 재질을 소유한다. 충돌과 게임 상태는 외부 책임이다.
@export var layout: Resource
@export var materials: Dictionary = {}
var report: Dictionary = {}
var _prepared := false


func _ready() -> void:
	prepare()


func prepare(shared: Dictionary = {}) -> void:
	if _prepared:
		return
	if Engine.is_editor_hint() and (layout == null or not has_node("Geometry")):
		return
	assert(layout != null and has_node("Geometry"), "건물 씬의 GLB와 배치 기록이 필요합니다.")
	materials = materials.duplicate()
	for role: String in shared:
		if materials.has(role):
			materials[role] = shared[role]
	var geometry := get_node("Geometry")
	var roles: Dictionary = layout.get_meta("mesh_roles")
	for path: String in roles:
		var mesh := geometry.get_node(NodePath(path)) as MeshInstance3D
		assert(mesh != null and mesh.mesh != null)
		mesh.material_override = materials[roles[path]]
	var flags: Dictionary = layout.get_meta("node_flags", {})
	for path: String in flags:
		var node := geometry.get_node(NodePath(path))
		for key: String in flags[path]:
			node.set_meta(key, flags[path][key])
	report = _resolve(layout.get_meta("report"), geometry)
	_prepared = true


func _resolve(value: Variant, geometry: Node) -> Variant:
	if value is Dictionary:
		if value.has("$node"):
			return geometry.get_node(NodePath(value["$node"]))
		if value.has("$material"):
			return materials[value["$material"]]
		var result := {}
		for key: Variant in value:
			result[key] = _resolve(value[key], geometry)
		return result
	if value is Array:
		var nodes_only: bool = not value.is_empty()
		for item: Variant in value:
			nodes_only = nodes_only and item is Dictionary and item.has("$node")
		if nodes_only:
			var meshes: Array[MeshInstance3D] = []
			for item: Dictionary in value:
				var node := geometry.get_node(NodePath(item["$node"]))
				if not node is MeshInstance3D:
					nodes_only = false
					break
				meshes.append(node)
			if nodes_only:
				return meshes
		var result: Array = []
		for item: Variant in value:
			result.append(_resolve(item, geometry))
		return result
	return value

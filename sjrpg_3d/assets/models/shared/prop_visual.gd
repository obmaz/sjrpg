@tool
extends Node3D
## GLB의 중립 슬롯을 Godot 공유 재질에 연결한다. 런타임 조형은 하지 않는다.
@export var layout: Resource


func _notification(what: int) -> void:
	if what != NOTIFICATION_SCENE_INSTANTIATED or layout == null:
		return
	var roles: Dictionary = layout.get_meta("mesh_roles")
	var actor: bool = layout.get_meta("actor", false)
	for path: String in roles:
		var part := get_node(path) as MeshInstance3D
		var slots: Array = roles[path]
		for index: int in slots.size():
			var role: String = slots[index]
			(part.mesh as ArrayMesh).surface_set_name(index, role)
			if actor:
				(part.mesh as ArrayMesh).surface_set_material(
					index, NativeActorMaterials.material(role)
				)
	var flags: Dictionary = layout.get_meta("node_flags", {})
	for path: String in flags:
		var part := get_node(path) as MeshInstance3D
		part.cast_shadow = flags[path]["cast_shadow"]
		for key: String in flags[path]["metadata"]:
			part.set_meta(key, flags[path]["metadata"][key])

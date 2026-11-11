@tool
extends Node3D
## GLB의 고정된 재질 역할과 같은 동굴 석재를 에디터/게임 양쪽에서 연결한다.
@export var stone: Material


func _ready() -> void:
	set_meta("exclude_static_batch", true)
	for child in find_children("*", "MeshInstance3D", true, false):
		if child.name == "BaseStone":
			(child as MeshInstance3D).material_override = stone

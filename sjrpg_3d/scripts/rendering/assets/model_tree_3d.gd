class_name ModelTree3D
extends RefCounted
## 씬 소유자나 표시 상태와 무관하게 실제 인스턴스 트리를 읽는다. 노드를 복제하거나 변경하지 않는다.


static func meshes_including_root(root: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		meshes.append(root as MeshInstance3D)
	for child: Node in root.get_children():
		meshes.append_array(meshes_including_root(child))
	return meshes


static func first_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child: Node in root.get_children():
		var animator := first_animation_player(child)
		if animator != null:
			return animator
	return null


static func first_skeleton(root: Node) -> Skeleton3D:
	if root == null:
		return null
	if root is Skeleton3D:
		return root as Skeleton3D
	for child: Node in root.get_children():
		var skeleton := first_skeleton(child)
		if skeleton != null:
			return skeleton
	return null


static func scene_paths(root: Node3D) -> Array[String]:
	var paths: Array[String] = []
	var nodes: Array[Node] = root.find_children("*", "Node3D", true, false)
	nodes.append(root)
	for node: Node in nodes:
		if not node.scene_file_path.is_empty() and not paths.has(node.scene_file_path):
			paths.append(node.scene_file_path)
	return paths

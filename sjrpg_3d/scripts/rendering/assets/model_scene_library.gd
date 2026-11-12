class_name ModelSceneLibrary
extends RefCounted
## 고정 소품·배우의 씬 캐시. 게임 규칙과 물리 상태를 소유하지 않는다.
const MODEL_SCENE_ROOT := "res://assets/models/"
static var _scenes := {}
static var _meshes := {}


static func create(asset_id: String) -> Node3D:
	if not _scenes.has(asset_id):
		_scenes[asset_id] = load(MODEL_SCENE_ROOT + asset_id + "/visual.tscn") as PackedScene
	var scene: PackedScene = _scenes[asset_id]
	return scene.instantiate() as Node3D if scene != null else null


## MultiMesh와 기존 메시 API도 같은 자산을 공유한다. 인스턴스별 복제는 하지 않는다.
static func mesh(asset_id: String, mesh_node_path: String) -> ArrayMesh:
	var key := asset_id + ":" + mesh_node_path
	if not _meshes.has(key):
		var model := create(asset_id)
		if model == null:
			return null
		var part := model.get_node_or_null(mesh_node_path) as MeshInstance3D
		assert(part != null and part.mesh is ArrayMesh, "Missing asset mesh: " + key)
		_meshes[key] = part.mesh
		model.free()
	return _meshes[key]

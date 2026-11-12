class_name NativePropAssets
extends RefCounted
## 고정 소품·배우의 씬 캐시. 게임 규칙과 물리 상태를 소유하지 않는다.
const ROOT := "res://assets/models/"
static var _scenes := {}
static var _meshes := {}


static func create(id: String) -> Node3D:
	if not _scenes.has(id):
		_scenes[id] = load(ROOT + id + "/visual.tscn") as PackedScene
	var scene: PackedScene = _scenes[id]
	return scene.instantiate() as Node3D if scene != null else null


## MultiMesh와 기존 메시 API도 같은 자산을 공유한다. 인스턴스별 복제는 하지 않는다.
static func mesh(id: String, path: String) -> ArrayMesh:
	var key := id + ":" + path
	if not _meshes.has(key):
		var model := create(id)
		if model == null:
			return null
		var part := model.get_node_or_null(path) as MeshInstance3D
		assert(part != null and part.mesh is ArrayMesh, "Missing asset mesh: " + key)
		_meshes[key] = part.mesh
		model.free()
	return _meshes[key]

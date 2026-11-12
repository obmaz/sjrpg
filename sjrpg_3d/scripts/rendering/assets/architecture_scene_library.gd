class_name ArchitectureSceneLibrary
extends RefCounted
## 개별 건물 씬은 한 번 불러오고 정적 메시·재질을 공유한다. 생성기는 앱에 포함하지 않는다.
const ROOT := "res://assets/models/architecture/"
static var _scenes := {}


static func create(id: String, shared: Dictionary = {}) -> NativeArchitectureVisual:
	assert(id.is_valid_identifier())
	if not _scenes.has(id):
		_scenes[id] = load(ROOT + id + "/visual.tscn") as PackedScene
	var visual := (_scenes[id] as PackedScene).instantiate() as NativeArchitectureVisual
	visual.prepare(shared)
	return visual

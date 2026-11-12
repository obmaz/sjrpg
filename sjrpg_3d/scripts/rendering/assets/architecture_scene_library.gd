class_name ArchitectureSceneLibrary
extends RefCounted
## 개별 건물 씬은 한 번 불러오고 정적 메시·재질을 공유한다. 생성기는 앱에 포함하지 않는다.
const ARCHITECTURE_SCENE_ROOT := "res://assets/models/architecture/"
static var _scenes := {}


static func create(asset_id: String, shared_materials: Dictionary = {}) -> NativeArchitectureVisual:
	assert(asset_id.is_valid_identifier())
	if not _scenes.has(asset_id):
		_scenes[asset_id] = load(ARCHITECTURE_SCENE_ROOT + asset_id + "/visual.tscn") as PackedScene
	var visual := (_scenes[asset_id] as PackedScene).instantiate() as NativeArchitectureVisual
	visual.prepare(shared_materials)
	return visual

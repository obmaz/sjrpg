class_name EnemyAssets
extends RefCounted
## 몬스터 폴더의 visual.tscn이 독립 교체 단위다. 월드·물리·종별 전투 규칙은 소유하지 않는다.
static var _scenes: Dictionary = {}
static var loads := 0
static var hits := 0


static func uses_asset(kind: String) -> bool:
	return ResourceLoader.exists("res://assets/models/enemies/%s/visual.tscn" % kind)


static func build(kind: String) -> Dictionary:
	if not _scenes.has(kind):
		_scenes[kind] = load("res://assets/models/enemies/%s/visual.tscn" % kind) as PackedScene
		loads += 1
	else:
		hits += 1
	var root := (_scenes[kind] as PackedScene).instantiate() as EnemyVisual
	root.prepare()
	return {
		"root": root,
		"visual": root,
		"kind": kind,
		"base_height": root.manifest["height_m"],
		"torso": root.hit_pivot,
		"materials": root.materials,
		"colors": root.colors
	}


static func cache_stats() -> Dictionary:
	return {"asset_loads": loads, "cache_hits": hits, "cached_species": _scenes.size()}

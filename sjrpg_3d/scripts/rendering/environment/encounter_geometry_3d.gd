class_name EncounterGeometry3D
extends RefCounted
## Reproducible, fully sided metre geometry. No camera-facing asset planes.

const STONE_SIZE := Vector3(0.80, 1.58, 32.0 / 65.0)
## 현재 요청에 따라 기존 상자의 각 축을 2배로 굽는다. 노드 배율은 ONE이다.
const CHEST_SCALE := 2.50
const CHEST_COLLISION_HEIGHT := 0.424 * CHEST_SCALE
const CHEST_WIDTH := 0.44
const CHEST_DEPTH := 0.26
const CHEST_RIM := 0.28
const LID_RADIUS := CHEST_DEPTH * 0.5
const OPEN_ANGLE := -65.0
const LID_PIVOT := Vector3(0, CHEST_RIM, -LID_RADIUS) * CHEST_SCALE


## 검수한 공유 GLB 메시만 읽는다. 판정에 쓰는 미터 상수는 위에 보존한다.
static func build() -> Dictionary:
	var result := {}
	for key: String in ["stone", "glyph"]:
		result[key] = ModelSceneLibrary.mesh("environment/encounter_stone", key)
	for key: String in ["base", "lid", "splinters"]:
		var path := "ObservedConsumedLid/lid" if key == "lid" else key
		result[key] = ModelSceneLibrary.mesh("environment/treasure_chest", path)
	for pair: Array in [
		["stone_triangles", ["stone", "glyph"]], ["chest_triangles", ["base", "lid", "splinters"]]
	]:
		var total := 0
		for key: String in pair[1]:
			var geometry: Mesh = result[key]
			for surface: int in geometry.get_surface_count():
				var indices: PackedInt32Array = geometry.surface_get_arrays(surface)[
					Mesh.ARRAY_INDEX
				]
				total += (
					(
						indices.size()
						if not indices.is_empty()
						else geometry.surface_get_array_len(surface)
					)
					/ 3
				)
		result[pair[0]] = total
	return result

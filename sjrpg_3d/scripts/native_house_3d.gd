class_name NativeHouse3D
extends RefCounted
## 미터 규격의 GLB 주택 씬. 닫힌 문·작업 홈과 기존 전체 건물 충돌은 유지한다.

const WALL = NativeHousePlan.WALL
const EAVES = NativeHousePlan.EAVES
const FLOOR = NativeHousePlan.FLOOR
const MATERIAL_KEYS = NativeHousePlan.MATERIAL_KEYS
const STYLES = NativeHousePlan.STYLES
const TIMBER_TILE = NativeHousePlan.TIMBER_TILE
const SLATE_TILE = NativeHousePlan.SLATE_TILE
const SLATE_COURSES = NativeHousePlan.SLATE_COURSES
const SLATE_PITCH = NativeHousePlan.SLATE_PITCH
const SLATE_COLUMNS = NativeHousePlan.SLATE_COLUMNS
const SLATE_WIDTH = NativeHousePlan.SLATE_WIDTH
const ASHLAR_COURSE = NativeHousePlan.ASHLAR_COURSE


static func build(
	presenter: Node, root: Node3D, key: String, width: float, depth: float, height: float
) -> Dictionary:
	var shared := {}
	for role: String in MATERIAL_KEYS:
		if role != "wall":
			shared[role] = presenter._materials[resource_key(key, role)]
	var visual := NativeArchitectureAssets.create(str(STYLES[key]["wall"]), shared)
	var dimensions: Vector3 = visual.layout.get_meta("source_dimensions")
	assert(dimensions.is_equal_approx(Vector3(width, height, depth)), "건물 규격 변경 후 GLB를 다시 구워야 합니다.")
	root.add_child(visual)
	root.set_meta("native_house", visual.report)
	return visual.report


static func resource_key(key: String, material: String) -> String:
	return NativeHousePlan.resource_key(key, material)

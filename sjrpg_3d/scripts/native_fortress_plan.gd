class_name NativeFortressPlan
extends RefCounted
## 새 원형 망루의 지상 몸체와 SOLID가 같은 미터 기준을 사용한다.
const CORNER_RADIUS := 1.30
const CORNER_SHAFT_TOP := 4.15
const CORNER_GALLERY_BASE := 4.25
const CORNER_EAVES := 5.05
const CORNER_ROOF_TOP := 6.95
const CORNER_GALLERY_RADIUS := 1.48
const CORNER_ROOF_RADIUS := 1.65

static func roof_points(at: Vector3) -> PackedVector3Array:
	var points := PackedVector3Array([at + Vector3.UP * CORNER_ROOF_TOP])
	for segment: int in 16:
		var angle := TAU * segment / 16.0
		points.append(at + Vector3(cos(angle) * CORNER_ROOF_RADIUS, CORNER_EAVES, sin(angle) * CORNER_ROOF_RADIUS))
	return points


static func corners(village: Village) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for run: Array in village.data["wall_runs"]:
		var point: Array = run[1]
		var native := Iso.unproject(village.point(Vector2(point[0], point[1]))) / 65.0
		result.append(Vector3(native.x, 0, native.y))
	return result

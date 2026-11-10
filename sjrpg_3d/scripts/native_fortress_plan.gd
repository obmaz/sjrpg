class_name NativeFortressPlan
extends RefCounted
const CORNER_RADIUS := 1.02
static func corners(village: Village) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for run: Array in village.data["wall_runs"]:
		var point: Array = run[1]
		var native := Iso.unproject(village.point(Vector2(point[0], point[1]))) / 65.0
		result.append(Vector3(native.x, 0, native.y))
	return result

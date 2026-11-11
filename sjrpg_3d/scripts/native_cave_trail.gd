class_name NativeCaveTrail
extends RefCounted

const SIGN_INDICES := [0, 2, 4, 5]
const HALF_WIDTH := 1.8


## 같은 미터 경로를 흙길 재질·식생 제외·실제 보행에서 공유한다.
static func frame(village: Village) -> Transform3D:
	return NativeCavePlan.frame(Iso.project(village.cave_ground) + NativeCavePlan.ENTRY_OFFSET)


static func proposal(village: Village) -> Vector2:
	var at := frame(village) * Vector3(5.0, 0.0, 40.0)
	return Iso.project(Vector2(at.x, at.z) * SpatialWorld3D.UNITS)


static func points(village: Village) -> PackedVector2Array:
	var anchor: Vector2 = village.sanctuary_points.get("cave", proposal(village))
	var cached: Dictionary = village.get_meta("native_cave_trail", {})
	if cached.get("anchor") == anchor and cached.get("cave") == village.cave_ground:
		return cached["points"]
	var inverse := frame(village).affine_inverse()
	var result := PackedVector2Array()
	# 남쪽 필드 길에서 갈라져 암반의 남쪽을 돌아 하강로 정면에 합류한다.
	for ground: Vector2 in [
		Vector2(0, 6500),
		Vector2(2200, 7200),
		Vector2(4400, 8450),
		Vector2(6600, 9300),
		Vector2(8500, 9500)
	]:
		var local := inverse * Vector3(ground.x / 65.0, 0, ground.y / 65.0)
		result.append(Vector2(local.x, local.z))
	var local := inverse * Ortho3DPreview.ground_position(anchor)
	result.append_array(
		PackedVector2Array(
			[
				Vector2(local.x, local.z),
				Vector2(local.x * 0.55, 31),
				Vector2(0.8, 25),
				Vector2(-0.6, 19),
				Vector2(0, 12)
			]
		)
	)
	village.set_meta(
		"native_cave_trail", {"anchor": anchor, "cave": village.cave_ground, "points": result}
	)
	return result


static func bounds(village: Village) -> Rect2:
	return Iso.poly_bounds(points(village)).grow(3.4)


static func signs(village: Village) -> Array[Dictionary]:
	var trail := points(village)
	var transform := frame(village)
	var result: Array[Dictionary] = []
	for index: int in SIGN_INDICES:
		var forward := (trail[index + 1] - trail[index]).normalized()
		var side := forward.orthogonal()
		var local := trail[index] + side * 2.6
		var at := transform * Vector3(local.x, 0, local.y)
		var direction := transform.basis * Vector3(forward.x, 0, forward.y)
		result.append({"point": SpatialWorld3D.projected(at), "direction": direction})
	return result


static func distance_to(village: Village, ground: Vector2) -> float:
	var at := frame(village).affine_inverse() * Vector3(ground.x / 65.0, 0, ground.y / 65.0)
	var trail := points(village)
	var distance := INF
	for index in trail.size() - 1:
		distance = minf(
			distance,
			Vector2(at.x, at.z).distance_to(
				Geometry2D.get_closest_point_to_segment(
					Vector2(at.x, at.z), trail[index], trail[index + 1]
				)
			)
		)
	return distance

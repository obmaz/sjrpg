class_name NativeChapelPlan
extends RefCounted
## 표시와 실제 물리가 공용하는 세 디딤판의 미터 단위 설계.
const SIZE_FACTOR := 1.25
const FOOTPRINT_SCALE := 1.60
const NAVE_FRONT_FRACTION := 0.30
const NAVE_DEPTH_FRACTION := 0.80
const PORCH_EAVES := 3.0
const PORCH_RISE := 1.6
const NAVE_EAVES := 3.5
const NAVE_RISE := 2.7
const FLOOR := 0.28
const RUN := 1.14
const STEPS := 3


static func stair_width(width: float) -> float:
	return minf(1.90, width * 0.48)


static func tiers(center: Vector2, width: float, depth: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	center.x += entrance_x(width)
	var front := center.y + depth * 0.5 + 0.04
	var span := stair_width(width)
	for i: int in STEPS:
		var reach := RUN * (STEPS - i) / STEPS
		result.append(
			{
				"rect": Rect2(center.x - span * 0.5, front, span, reach),
				"height": FLOOR * (i + 1) / STEPS
			}
		)
	return result


static func polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		]
	)


static func entrance_x(width: float) -> float:
	return -width * 0.30


static func body_polygon(center: Vector2, width: float, depth: float) -> PackedVector2Array:
	var points := PackedVector2Array(
		[
			Vector2(-width * 0.5, -depth * 0.5),
			Vector2(width * 0.5, -depth * 0.5),
			Vector2(width * 0.5, depth * NAVE_FRONT_FRACTION),
			Vector2(-width * 0.10, depth * NAVE_FRONT_FRACTION),
			Vector2(-width * 0.10, depth * 0.5),
			Vector2(-width * 0.5, depth * 0.5)
		]
	)
	for index in points.size():
		points[index] += center
	return points

class_name NativeChapelPlan
extends RefCounted
## 표시와 실제 물리가 공용하는 세 디딤판의 미터 단위 설계.
const SIZE_FACTOR := 1.25
const FLOOR := 0.28
const RUN := 1.14
const STEPS := 3
const EXTRA_WIDTH := 1.10

static func stair_width(width: float) -> float:
	return minf(1.38, width * 0.40) + EXTRA_WIDTH

static func tiers(center: Vector2, width: float, depth: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var front := center.y + depth * 0.5 + 0.04
	var span := stair_width(width)
	for i: int in STEPS:
		var reach := RUN * (STEPS - i) / STEPS
		result.append({"rect": Rect2(center.x - span * 0.5, front, span, reach), "height": FLOOR * (i + 1) / STEPS})
	return result

static func polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])

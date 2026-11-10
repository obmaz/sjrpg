class_name ForestRegion
extends RefCounted
## 기존 북서 경계와 마을을 고정한 숲1장의 실제 지면 범위.
const FIELD := Rect2(-3600,-3600,14400,14400)
const CAVE_GROUND := Vector2(7600,7600)
const BRIDGE_U := 9000.0
const RIVER_END_U := 10920.0

static func native_bounds() -> Rect2:
	return Rect2(FIELD.position/65.0,FIELD.size/65.0)

class_name NativeCavePlan
extends RefCounted
## 원화의 비대칭 암반 윤곽·열린 입구를 표시와 실제 물리가 공유한다.
const SOURCE_RADIUS := 500.0
const CENTER_OFFSET := Vector2(0, -210)
const ENTRY_OFFSET := Vector2(30, 100)
const HILL_HEIGHT := 5.8
const OPENING_WIDTH := 3.92
const DESCENT := 1.20
const SITE_DEPTH := 3.20
const APPROACH_LENGTH := 20.0
const SITE_RADIUS := 32.0

static func approach_height(z: float) -> float:
	return -SITE_DEPTH+floor_height(z) if z<1.2 else -SITE_DEPTH*(1.0-smoothstep(1.2,APPROACH_LENGTH,z))

static func floor_height(z: float) -> float:
	return -DESCENT * smoothstep(1.20,-3.50,z)

static func front_offset() -> float:
	return SpatialWorld3D.radius_metres(SOURCE_RADIUS) - 1.65

static func body_center(entry: Vector2) -> Vector2:
	return entry - ENTRY_OFFSET + CENTER_OFFSET

static func frame(entry: Vector2) -> Transform3D:
	var forward := Vector3(1, 0, 1).normalized()
	var axis := Vector3(1, 0, -1).normalized()
	return Transform3D(Basis(axis, Vector3.UP, forward), WorldSpace3D.projected_to_world(body_center(entry),-SITE_DEPTH) + forward * front_offset())

static func outline(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in 20:
		var angle := TAU * i / 20.0
		var r := radius * (0.90 + 0.10 * (0.5 + 0.5 * sin(angle * 3.0 + 0.4)))
		var q := Vector2(cos(angle)*r,sin(angle)*r*0.82+0.55).limit_length(radius*0.995)
		points.append(Vector2(q.x,-front_offset()+q.y))
	points.append_array(PackedVector2Array([Vector2(-3.5,-0.3),Vector2(3.5,-0.3),Vector2(-2.0,0.35),Vector2(2.0,0.35)]))
	var hull := Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0].is_equal_approx(hull[-1]):
		hull.remove_at(hull.size()-1)
	return hull

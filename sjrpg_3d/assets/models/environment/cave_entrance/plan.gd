class_name NativeCavePlan
extends RefCounted
## 원화의 비대칭 암반 윤곽·열린 입구를 표시와 실제 물리가 공유한다.
const SOURCE_RADIUS := 460.0
const CENTER_OFFSET := Vector2(0, -210)
const ENTRY_OFFSET := Vector2(30, 100)
const HILL_HEIGHT := 5.8
const OPENING_WIDTH := 3.92

static func front_offset() -> float:
	return SpatialWorld3D.radius_metres(SOURCE_RADIUS) - 1.10

static func body_center(entry: Vector2) -> Vector2:
	return entry - ENTRY_OFFSET + CENTER_OFFSET

static func frame(entry: Vector2) -> Transform3D:
	var forward := Vector3(1, 0, 1).normalized()
	var axis := Vector3(1, 0, -1).normalized()
	return Transform3D(Basis(axis, Vector3.UP, forward), Ortho3DPreview.ground_position(body_center(entry)) + forward * front_offset())

static func outline(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in 20:
		var angle := TAU * i / 20.0
		var r := radius * (0.90 + 0.10 * (0.5 + 0.5 * sin(angle * 3.0 + 0.4)))
		points.append(Vector2(cos(angle) * r, -front_offset() + sin(angle) * r))
	points.append_array(PackedVector2Array([Vector2(-3.5,-0.3),Vector2(3.5,-0.3),Vector2(-2.0,0.35),Vector2(2.0,0.35)]))
	var hull := Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0].is_equal_approx(hull[-1]):
		hull.remove_at(hull.size()-1)
	return hull

static func ground_regions(radius: float) -> Array[PackedVector2Array]:
	var border := outline(radius)
	var masks := [
		PackedVector2Array([Vector2(-12,-12),Vector2(-1.96,-12),Vector2(-1.96,12),Vector2(-12,12)]),
		PackedVector2Array([Vector2(1.96,-12),Vector2(12,-12),Vector2(12,12),Vector2(1.96,12)]),
		PackedVector2Array([Vector2(-1.96,-12),Vector2(1.96,-12),Vector2(1.96,-3.50),Vector2(-1.96,-3.50)])]
	var result: Array[PackedVector2Array] = []
	for mask: PackedVector2Array in masks:
		for polygon: PackedVector2Array in Geometry2D.intersect_polygons(border,mask):
			result.append(polygon)
	return result

static func roof_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	for x: float in [-1.96,1.96]:
		for z: float in [0.35,-3.50]:
			points.append(Vector3(x,3.20,z))
			points.append(Vector3(x,4.25,z))
	return points

class_name Iso
extends RefCounted
## 2.5D quarter view (원본 IsometricGround): ground axes at ±30° on screen,
## so square floors become 60°/120° diamonds. Ground units follow the Flutter
## world; `S` converts them to this port's world pixels, calibrated so props,
## buildings and paving match the original's proportions to the hero.

const COS := 0.8660254037844386
const SIN := 0.5
const S := 0.97
const HERO_HEIGHT := 56.64  # SceneScale.heroHeight in original units


## Ground (u, v) in original units → screen-plane world position.
static func project(ground_point: Vector2) -> Vector2:
	return Vector2((ground_point.x - ground_point.y) * COS, (ground_point.x + ground_point.y) * SIN) * S


## 투영된 Node2D 월드 위치를 원본 지면 단위로 되돌린다.
static func unproject(projected_point: Vector2) -> Vector2:
	var scaled_point := projected_point / S
	return Vector2(scaled_point.x / COS + scaled_point.y / SIN, scaled_point.y / SIN - scaled_point.x / COS) / 2.0


## Transform that maps ground units directly onto the screen plane.
static func ground_transform() -> Transform2D:
	return Transform2D(Vector2(COS, SIN) * S, Vector2(-COS, SIN) * S, Vector2.ZERO)


## 원의 중심이 다각형 내부에 있거나 경계와 반경보다 가까우면 바깥쪽으로 밀어낸다.
static func push_out(center: Vector2, polygon: PackedVector2Array, radius: float) -> Vector2:
	var inside := Geometry2D.is_point_in_polygon(center, polygon)
	var nearest_distance := INF
	var nearest_point := center
	for i in polygon.size():
		var edge_start := polygon[i]
		var edge_end := polygon[(i + 1) % polygon.size()]
		var closest := Geometry2D.get_closest_point_to_segment(center, edge_start, edge_end)
		var distance := center.distance_to(closest)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_point = closest
	if inside:
		var inside_normal := (nearest_point - center).normalized() if nearest_distance > 0.001 else Vector2.DOWN
		return nearest_point + inside_normal * radius
	if nearest_distance < radius:
		var outside_normal := (center - nearest_point).normalized() if nearest_distance > 0.001 else Vector2.DOWN
		return nearest_point + outside_normal * radius
	return center


static func poly_bounds(polygon: PackedVector2Array) -> Rect2:
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		bounds = bounds.expand(point)
	return bounds

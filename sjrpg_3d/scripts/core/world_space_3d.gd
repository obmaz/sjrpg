class_name WorldSpace3D
extends RefCounted
## Node2D의 투영된 월드 좌표와 실제 X/Z 미터 좌표 사이의 변환. 화면/뷰포트 좌표는 아니다.
const GROUND_UNITS_PER_METER := 65.0
const GROUND_PROJECTION_FACTOR := 1.224744871391589 * Iso.S
const VERTICAL_PIXELS_PER_METER := GROUND_UNITS_PER_METER * Iso.S
const HORIZONTAL_PIXELS_PER_METER := GROUND_UNITS_PER_METER * GROUND_PROJECTION_FACTOR


static func projected_to_world(projected_ground: Vector2, elevation_m := 0.0) -> Vector3:
	var ground := Iso.unproject(projected_ground) / GROUND_UNITS_PER_METER
	return Vector3(ground.x, elevation_m, ground.y)


## 높이는 투영하지 않는다. 기존 Node2D 어댑터는 발치 지면 위치만 저장한다.
static func world_to_projected(world_position: Vector3) -> Vector2:
	return Iso.project(Vector2(world_position.x, world_position.z) * GROUND_UNITS_PER_METER)


## 이미 화면 위쪽으로 올린 효과 위치에서 높이 투영을 제거하고 실제 Y 높이를 적용한다.
static func elevated_projected_to_world(projected_point: Vector2, elevation_m: float) -> Vector3:
	return projected_to_world(projected_point + Vector2(0, elevation_m * VERTICAL_PIXELS_PER_METER), elevation_m)


static func pixels_per_meter(camera_zoom: float) -> float:
	return HORIZONTAL_PIXELS_PER_METER * camera_zoom

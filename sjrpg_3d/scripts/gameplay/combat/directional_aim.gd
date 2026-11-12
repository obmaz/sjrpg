class_name DirectionalAim
extends RefCounted
## 기존 화면 투영 조작 축에서 전방90도만 보정한다. 피해 범위·공격 시간은 별도다.
const HALF_ANGLE := PI / 4.0


static func contains(offset: Vector2, bearing: Vector2, half_angle := HALF_ANGLE) -> bool:
	if offset.length_squared() < 0.0001:
		return true  # 정확히 겹친 접점에는 앞뒤를 정의할 수 없다.
	return absf(bearing.angle_to(offset)) <= half_angle + 0.00001


static func score(offset: Vector2, bearing: Vector2, reach: float) -> float:
	return absf(bearing.angle_to(offset)) * reach + offset.length() * 0.2

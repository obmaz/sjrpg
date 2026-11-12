class_name NativeCaveEntrance3D
extends RefCounted
## 게임은 검수한 암반 메시를 읽는다. 조형 계산은 제작 단계에서만 수행한다.
static func mesh(_height: float, _body_radius: float) -> ArrayMesh:
	return NativePropAssets.mesh("environment/cave_entrance", "Body")

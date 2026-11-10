class_name NativeCaveTrail
extends RefCounted
## 같은 미터 단위 경로를 흙길 재질·식생 제외·실제 보행 검증에서 공유한다.
static func frame(village: Village) -> Transform3D:
	return NativeCavePlan.frame(Iso.project(village.cave_ground)+NativeCavePlan.ENTRY_OFFSET)

static func proposal(village: Village) -> Vector2:
	var at := frame(village)*Vector3(5.0,0.0,40.0)
	return Iso.project(Vector2(at.x,at.z)*SpatialWorld3D.UNITS)

static func points(village: Village) -> PackedVector2Array:
	var at: Vector2 = village.sanctuary_points.get("cave",proposal(village))
	var local := frame(village).affine_inverse()*Ortho3DPreview.ground_position(at)
	return PackedVector2Array([Vector2(local.x,local.z),Vector2(local.x*0.55,31.0),Vector2(0.8,25.0),Vector2(-0.6,19.0),Vector2(0.0,12.0)])

static func distance_to(village: Village, ground: Vector2) -> float:
	var at := frame(village).affine_inverse()*Vector3(ground.x/65.0,0.0,ground.y/65.0)
	var trail := points(village)
	var distance := INF
	for index in trail.size()-1:
		distance = minf(distance,Vector2(at.x,at.z).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(at.x,at.z),trail[index],trail[index+1])))
	return distance

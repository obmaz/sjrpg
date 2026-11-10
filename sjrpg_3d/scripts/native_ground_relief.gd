class_name NativeGroundRelief
extends RefCounted
## 표시와 보행 FLOOR가 같은 정점을 쓰는 낮은 강바닥과 동굴 하강로.
const WATER_LEVEL := -1.20
const BED_LEVEL := -1.85
const BANK_WIDTH := 2.80

static func river_outline(village: Village) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in village.river.polygon:
		result.append(point / SpatialWorld3D.UNITS)
	return result

static func river_distance(p: Vector2, outline: PackedVector2Array) -> float:
	var distance := INF
	for i: int in outline.size():
		distance = minf(distance, p.distance_to(Geometry2D.get_closest_point_to_segment(p, outline[i], outline[(i+1)%outline.size()])))
	return -distance if Geometry2D.is_point_in_polygon(p,outline) else distance

static func height(p: Vector2, river: PackedVector2Array, cave_frame: Transform3D, deck: PackedVector2Array) -> float:
	var distance := river_distance(p,river)
	var edge_noise := smoothstep(0.0,0.7,maxf(0.0,distance))*(0.14*sin(p.x*2.1)+0.08*cos(p.y*2.9))
	var river_y := WATER_LEVEL*(1.0-smoothstep(0.0,BANK_WIDTH,distance+edge_noise)) if distance>=0.0 else lerpf(WATER_LEVEL,BED_LEVEL,smoothstep(0.0,1.5,-distance))
	var along := (deck[1]-deck[0]).normalized()
	var across := (deck[3]-deck[0]).normalized()
	var local_deck := Vector2((p-deck[0]).dot(along),(p-deck[0]).dot(across))
	var length := deck[0].distance_to(deck[1])
	var width := deck[0].distance_to(deck[3])
	var end_distance := minf(absf(local_deck.x),absf(local_deck.x-length))
	var abutment := (1.0-smoothstep(1.80,3.8,end_distance))*(1.0-smoothstep(width*0.5+1.70,width*0.5+3.50,absf(local_deck.y-width*0.5)))
	river_y *= 1.0-abutment
	var local := cave_frame.affine_inverse() * Vector3(p.x,0,p.y)
	var cave_y := 0.0
	if absf(local.x) <= NativeCavePlan.OPENING_WIDTH*0.5+0.20 and local.z > -4.2 and local.z < 1.4:
		cave_y = NativeCavePlan.floor_height(local.z)
	return minf(river_y,cave_y)

static func bridge_outline(village: Village) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in village.bridge.deck_polygon():
		result.append(Iso.unproject(point)/SpatialWorld3D.UNITS)
	return result

static func at(village: Village, point: Vector2) -> float:
	var p := Iso.unproject(point)/SpatialWorld3D.UNITS
	var river := river_outline(village)
	var deck := bridge_outline(village)
	var frame := NativeCavePlan.frame(Iso.project(village.cave_ground)+NativeCavePlan.ENTRY_OFFSET)
	var origin := (p/3.0).floor()*3.0
	var river_bounds := Iso.poly_bounds(river).grow(BANK_WIDTH+3.0)
	var dense := river_bounds.intersects(Rect2(origin,Vector2(3,3))) or origin.distance_to(Vector2(frame.origin.x,frame.origin.z))<9.0
	var pitch := 0.5 if dense else 3.0
	var a := origin+((p-origin)/pitch).floor()*pitch
	var uv := (p-a)/pitch
	var ha := height(a,river,frame,deck)
	var hc := height(a+Vector2(pitch,pitch),river,frame,deck)
	# 보행 삼각형의 보간을 그대로 사용한다. 곡선 함수를 다시 평가하면 뿌리가 뜬다.
	if uv.x>=uv.y:
		return (1.0-uv.x)*ha+(uv.x-uv.y)*height(a+Vector2(pitch,0),river,frame,deck)+uv.y*hc
	return (1.0-uv.y)*ha+uv.x*hc+(uv.y-uv.x)*height(a+Vector2(0,pitch),river,frame,deck)


static func faces(village: Village) -> PackedVector3Array:
	if village.has_meta("native_ground_relief_faces"):
		return village.get_meta("native_ground_relief_faces")
	var river := river_outline(village)
	var deck := bridge_outline(village)
	var river_bounds := Iso.poly_bounds(river).grow(BANK_WIDTH+3.0)
	var frame := NativeCavePlan.frame(Iso.project(village.cave_ground)+NativeCavePlan.ENTRY_OFFSET)
	var mouth := Vector2(frame.origin.x,frame.origin.z)
	var result := PackedVector3Array()
	# 먼 지형은3m, 강둑과 입구만0.5m로 나눈다.
	for ix in range(-25,25):
		for iz in range(-25,25):
			var origin := Vector2(ix*3.0,iz*3.0)
			var dense := river_bounds.intersects(Rect2(origin,Vector2(3,3))) or origin.distance_to(mouth)<9.0
			var steps := 6 if dense else 1
			var pitch := 3.0/steps
			for x: int in steps:
				for z: int in steps:
					var a := origin+Vector2(x,z)*pitch
					var b := a+Vector2(pitch,0)
					var c := a+Vector2(pitch,pitch)
					var d := a+Vector2(0,pitch)
					var vertices := PackedVector3Array()
					for q: Vector2 in [a,b,c,d]:
						vertices.append(Vector3(q.x,height(q,river,frame,deck),q.y))
					result.append_array(PackedVector3Array([vertices[0],vertices[2],vertices[1],vertices[0],vertices[3],vertices[2]]))
	village.set_meta("native_ground_relief_faces",result)
	return result

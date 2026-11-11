class_name ChestPlacement
extends RefCounted
## 커진 상자를 건물·나무·주민에서 떼어 놓는다. 원본 데이터와 저장 ID는 유지한다.


static func find(village: Village, origin: Vector2) -> Vector2:
	var radius := Chest.COLLISION_RADIUS / (sqrt(1.5) * Iso.S) + 3.0
	var blockers: Array[PackedVector2Array] = []
	if village.has_meta("chest_clearance"):
		blockers = village.get_meta("chest_clearance")
	else:
		var shapes: Array = village.solids.duplicate()
		shapes.append(SpatialWorld3D.terrain_surfaces(village)[0]["building"])
		for polygon: PackedVector2Array in shapes:
			var flat := PackedVector2Array()
			for point in polygon:
				flat.append(Iso.unproject(point))
			for expanded in Geometry2D.offset_polygon(flat, radius, Geometry2D.JOIN_ROUND):
				blockers.append(expanded)
		village.set_meta("chest_clearance", blockers)
	var surfaces := SpatialWorld3D.terrain_surfaces(village)
	var height := SpatialWorld3D.surface_height_at(village, origin)
	for ring in 12:
		for step in 1 if ring == 0 else 16:
			var point := origin + Iso.project(Vector2.from_angle(step * TAU / 16.0) * ring * 30.0)
			var flat := Iso.unproject(point)
			if absf(SpatialWorld3D.surface_height_at(village, point) - height) > 0.01:
				continue
			var clear := true
			# 낮은 기단도 뚜껑의 회전 반경 안에 들어오면 겹침이다.
			for surface: Dictionary in surfaces:
				var top: PackedVector2Array = surface["top"]
				for edge in top.size():
					var a := Iso.unproject(top[edge])
					var b := Iso.unproject(top[(edge + 1) % top.size()])
					if (
						flat.distance_to(Geometry2D.get_closest_point_to_segment(flat, a, b))
						< radius
					):
						clear = false
						break
			for polygon in blockers:
				if Geometry2D.is_point_in_polygon(flat, polygon):
					clear = false
					break
			if not clear:
				continue
			for circle: Array in village.circles:
				if (
					flat.distance_to(Iso.unproject(circle[0]))
					< radius + float(circle[1]) / (sqrt(1.5) * Iso.S)
				):
					clear = false
					break
			if clear:
				return point
	return origin

class_name TerrainForms3D
extends RefCounted
## 생성형 지층/언덕 컨셉을 바탕으로 만든 측면. 표시와 SOLID가 같은 정점을 쓴다.
static func outline(surface: Dictionary) -> PackedVector2Array:
	var original: PackedVector2Array = surface["top"]
	var native := PackedVector2Array()
	for point: Vector2 in original:
		native.append(Iso.unproject(point) / 65.0)
	var ramp: PackedVector2Array = surface.get("ramp", PackedVector2Array())
	var result := PackedVector2Array()
	for i: int in native.size():
		var a := native[(i - 1 + native.size()) % native.size()]
		var b := native[i]
		var c := native[(i + 1) % native.size()]
		var at_ramp := false
		for j: int in ramp.size():
			if Geometry2D.get_closest_point_to_segment(original[i], ramp[j], ramp[(j + 1) % ramp.size()]).distance_to(original[i]) < 0.10:
				at_ramp = true
		if at_ramp:
			result.append(original[i])
		else:
			var bevel := minf(0.52, minf(a.distance_to(b), b.distance_to(c)) * 0.18)
			result.append(Iso.project(b.move_toward(a, bevel) * 65.0))
			result.append(Iso.project(b.move_toward(c, bevel * 0.84) * 65.0))
	# 불규칙한 모서리 깎기는 상면/경사로·절벽/사면 모두에 같은 경계가 된다.
	return result

static func faces(surface: Dictionary) -> PackedVector3Array:
	var result := PackedVector3Array()
	var top: PackedVector2Array = surface["top"]
	var source := SpatialWorld3D.surface_faces(surface)
	var used := {}
	var hill := str(surface["id"]) != "landmark_0"
	for triangle in range(0, source.size(), 3):
		for edge: int in 3:
			var a := source[triangle + edge]
			var b := source[triangle + (edge + 1) % 3]
			var from := SpatialWorld3D.projected(a)
			var to := SpatialWorld3D.projected(b)
			var boundary := false
			for i: int in top.size():
				if Geometry2D.get_closest_point_to_segment(from, top[i], top[(i + 1) % top.size()]).distance_squared_to(from) < 0.0001 and Geometry2D.get_closest_point_to_segment(to, top[i], top[(i + 1) % top.size()]).distance_squared_to(to) < 0.0001:
					boundary = true
			if not boundary or maxf(a.y, b.y) < 0.35 or SpatialWorld3D._is_entrance(surface, from, to):
				continue
			var key := "%s:%s" % [a, b] if a.x + a.z < b.x + b.z else "%s:%s" % [b, a]
			if used.has(key):
				continue
			used[key] = true
			var normal := Vector3(b.z - a.z, 0, a.x - b.x).normalized()
			var test := (from + to) * 0.5 + Iso.project(Vector2(normal.x, normal.z) * 65.0).normalized()
			if Geometry2D.is_point_in_polygon(test, top):
				normal = -normal
			var segments := maxi(1, ceili(a.distance_to(b) / 1.20))
			for segment: int in segments:
				var start := a.lerp(b, float(segment) / segments)
				var finish := a.lerp(b, float(segment + 1) / segments)
				var phase := sin(start.x * 3.7 + start.z * 2.9)
				var spread := (1.30 if hill else 0.80) * (0.88 + 0.12 * phase)
				var start_spread := spread * clampf(start.y / 0.60, 0.0, 1.0)
				var finish_spread := spread * clampf(finish.y / 0.60, 0.0, 1.0)
				var levels := [0.0, 0.28, 0.56, 0.80, 1.0]
				var offsets := [1.0, 0.76, 0.49, 0.23, 0.0] if hill else [1.0, 0.63, 0.83, 0.20, 0.0]
				for layer: int in 4:
					var lb: Vector3 = start * Vector3(1, levels[layer], 1) + normal * start_spread * offsets[layer]
					var rb: Vector3 = finish * Vector3(1, levels[layer], 1) + normal * finish_spread * offsets[layer]
					var lt: Vector3 = start * Vector3(1, levels[layer + 1], 1) + normal * start_spread * offsets[layer + 1]
					var rt: Vector3 = finish * Vector3(1, levels[layer + 1], 1) + normal * finish_spread * offsets[layer + 1]
					result.append_array(PackedVector3Array([lb, lt, rt, lb, rt, rb]))
					if (lt - lb).cross(rt - lb).dot(normal) < 0.0:
						var end := result.size()
						result[end - 6] = lb
						result[end - 5] = rt
						result[end - 4] = lt
						result[end - 3] = lb
						result[end - 2] = rb
						result[end - 1] = rt
					# 암괴 사이의 틈을 막는 측면. 지층마다 실제 두께가 있다.
					var inner_a := start * Vector3(1, levels[layer], 1)
					var inner_b := finish * Vector3(1, levels[layer], 1)
					result.append_array(PackedVector3Array([inner_a, lt, lb, inner_b, rb, rt]))
	var valid := PackedVector3Array()
	for i in range(0, result.size(), 3):
		if (result[i + 1] - result[i]).cross(result[i + 2] - result[i]).length_squared() >= 0.00000001:
			valid.append_array(PackedVector3Array([result[i], result[i + 1], result[i + 2]]))
	return valid

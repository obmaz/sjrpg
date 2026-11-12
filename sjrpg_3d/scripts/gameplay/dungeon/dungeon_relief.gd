class_name DungeonRelief
extends RefCounted
## 동굴 XZ 합집합과 높이 꺾임을 같은 격자로 나눠 표시/충돌의 바닥을 공유한다.
const UNITS := 65.0
const X_PROFILE := [
	Vector2(-220, 0),
	Vector2(400, 0),
	Vector2(1000, 0),
	Vector2(1250, -1.2),
	Vector2(1850, -1.2),
	Vector2(2100, -.25),
	Vector2(2700, -.25),
	Vector2(2950, -1.8),
	Vector2(3550, -1.8),
	Vector2(3800, -.7),
	Vector2(4920, -.7)
]
const Z_PROFILE := [
	Vector2(-600, 1.1),
	Vector2(-400, 1.1),
	Vector2(-300, 0),
	Vector2(300, 0),
	Vector2(400, -.6),
	Vector2(600, -.6)
]


class FloorCell:
	extends RefCounted
	var origin: Vector3
	var slope: Vector2
	var normal: Vector3


var floor_faces := PackedVector3Array()
var boundary_segments: Array[Dictionary] = []
var cells: Array[Rect2] = []
var _mesh: ArrayMesh
var _xs: Array[int] = []
var _zs: Array[int] = []
var _planes: Dictionary = {}


static func _profile(stations: Array, value: float) -> float:
	for index in range(1, stations.size()):
		var first: Vector2 = stations[index - 1]
		var last: Vector2 = stations[index]
		if value <= last.x:
			return lerpf(first.y, last.y, clampf((value - first.x) / (last.x - first.x), 0, 1))
	var last: Vector2 = stations[-1]
	return last.y


static func flat_height(authored: Vector2) -> float:
	return _profile(X_PROFILE, authored.x) + _profile(Z_PROFILE, authored.y)


static func at(projected: Vector2) -> float:
	return flat_height(Iso.unproject(projected))


static func vertex(xz: Vector2) -> Vector3:
	return Vector3(xz.x, flat_height(xz * UNITS), xz.y)


func setup(polygons: Array[PackedVector2Array]) -> DungeonRelief:
	floor_faces.clear()
	boundary_segments.clear()
	cells.clear()
	_mesh = null
	_planes.clear()
	# 격자 축은 정수 mm로 통일해 Vector2(float32)/스칼라(float64)의 미세 중복을 막는다.
	var xs: Array[int] = []
	var zs: Array[int] = []
	var rects: Array[Rect2] = []
	for polygon in polygons:
		var flat := PackedVector2Array()
		for point: Vector2 in polygon:
			flat.append(Iso.unproject(point) / UNITS)
		var box := Iso.poly_bounds(flat)
		var minimum := box.position.snapped(Vector2.ONE * .001)
		var maximum := box.end.snapped(Vector2.ONE * .001)
		rects.append(Rect2(minimum, maximum - minimum))
		for value: float in [minimum.x, maximum.x]:
			var key := roundi(value * 1000)
			if not xs.has(key):
				xs.append(key)
		for value: float in [minimum.y, maximum.y]:
			var key := roundi(value * 1000)
			if not zs.has(key):
				zs.append(key)
	for point: Vector2 in X_PROFILE:
		var x := roundi(point.x / UNITS * 1000)
		if not xs.has(x):
			xs.append(x)
	for point: Vector2 in Z_PROFILE:
		var z := roundi(point.x / UNITS * 1000)
		if not zs.has(z):
			zs.append(z)
	xs.sort()
	zs.sort()
	var occupied := {}
	for x in xs.size() - 1:
		for z in zs.size() - 1:
			var box := Rect2(
				Vector2(xs[x], zs[z]) / 1000.0,
				Vector2(xs[x + 1] - xs[x], zs[z + 1] - zs[z]) / 1000.0
			)
			for rect: Rect2 in rects:
				if rect.has_point(box.get_center()):
					occupied[Vector2i(x, z)] = true
					cells.append(box)
					break
	for key: Vector2i in occupied:
		var x := key.x
		var z := key.y
		var a := Vector2(xs[x], zs[z]) / 1000.0
		var b := Vector2(xs[x + 1], zs[z]) / 1000.0
		var c := Vector2(xs[x + 1], zs[z + 1]) / 1000.0
		var d := Vector2(xs[x], zs[z + 1]) / 1000.0
		for point: Vector2 in [a, b, c, a, c, d]:
			floor_faces.append(vertex(point))
		if not occupied.has(key + Vector2i.LEFT):
			_boundary(a, d, Vector2.LEFT)
		if not occupied.has(key + Vector2i.RIGHT):
			_boundary(b, c, Vector2.RIGHT)
		if not occupied.has(key + Vector2i.UP):
			_boundary(a, b, Vector2.UP)
		if not occupied.has(key + Vector2i.DOWN):
			_boundary(d, c, Vector2.DOWN)
		var plane := FloorCell.new()
		plane.origin = vertex(a)
		plane.slope = Vector2(
			(vertex(b).y - plane.origin.y) / (b.x - a.x),
			(vertex(d).y - plane.origin.y) / (d.y - a.y)
		)
		plane.normal = Vector3(-plane.slope.x, 1, -plane.slope.y).normalized()
		_planes[key] = plane
	_xs = xs
	_zs = zs
	_merge_boundaries()
	return self


## 실제 바닥 삼각형과 같은 셀 평면. 물리 광선의 내부 이음새 누락에만 사용한다.
## 정렬된 축의 이진 검색으로 빈 공간을 보행 가능한 바닥으로 확장하지 않는다.
func sample(xz: Vector2) -> Dictionary:
	var x := _interval(_xs, xz.x * 1000)
	var z := _interval(_zs, xz.y * 1000)
	var plane: FloorCell = _planes.get(Vector2i(x, z))
	if x < 0 or z < 0 or plane == null:
		return {"found": false}
	var offset := xz - Vector2(plane.origin.x, plane.origin.z)
	return {
		"found": true, "height": plane.origin.y + plane.slope.dot(offset), "normal": plane.normal
	}


static func _interval(axis: Array[int], value: float) -> int:
	if axis.size() < 2 or value < axis[0] or value > axis[-1]:
		return -1
	var first := 0
	var last := axis.size() - 1
	while first + 1 < last:
		var middle := (first + last) / 2
		if axis[middle] <= value:
			first = middle
		else:
			last = middle
	return first


## 통과한 rect 경계는 합치되 높이 기울기가 바뀌는 지점은 남긴다.
## 바닥 격자 수만큼 벽 메시/드로콜이 늘어나지 않는다.
func _merge_boundaries() -> void:
	var groups := {}
	for edge in boundary_segments:
		var a: Vector2 = edge["a"]
		var b: Vector2 = edge["b"]
		var along_x := is_equal_approx(a.y, b.y)
		var fixed := a.y if along_x else a.x
		var key := "%s:%.3f:%s" % [along_x, fixed, edge["outward"]]
		if not groups.has(key):
			groups[key] = {"x": along_x, "fixed": fixed, "outward": edge["outward"], "spans": []}
		groups[key]["spans"].append(Vector2(a.x, b.x) if along_x else Vector2(a.y, b.y))
	boundary_segments.clear()
	for group: Dictionary in groups.values():
		var spans: Array = group["spans"]
		spans.sort_custom(func(a: Vector2, b: Vector2): return a.x < b.x)
		var first: float = spans[0].x
		var last: float = spans[0].y
		for index in range(1, spans.size()):
			var next: Vector2 = spans[index]
			var before := _edge_slope(group, first, last)
			var after := _edge_slope(group, next.x, next.y)
			if absf(next.x - last) < .01 and absf(before - after) < .00001:
				last = next.y
			else:
				_emit_edge(group, first, last)
				first = next.x
				last = next.y
		_emit_edge(group, first, last)


static func _edge_point(group: Dictionary, along: float) -> Vector2:
	var fixed: float = group["fixed"]
	return Vector2(along, fixed) if group["x"] else Vector2(fixed, along)


static func _edge_slope(group: Dictionary, first: float, last: float) -> float:
	return (
		(flat_height(_edge_point(group, last)) - flat_height(_edge_point(group, first)))
		/ maxf(.00001, last - first)
	)


func _emit_edge(group: Dictionary, first: float, last: float) -> void:
	boundary_segments.append(
		{"a": _edge_point(group, first), "b": _edge_point(group, last), "outward": group["outward"]}
	)


func _boundary(a: Vector2, b: Vector2, outward: Vector2) -> void:
	boundary_segments.append({"a": a * UNITS, "b": b * UNITS, "outward": outward})


func mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(0, floor_faces.size(), 3):
		var a := floor_faces[index]
		var b := floor_faces[index + 1]
		var c := floor_faces[index + 2]
		var normal := -(b - a).cross(c - a).normalized()
		for point: Vector3 in [a, b, c]:
			tool.set_normal(normal)
			tool.set_uv(Vector2(point.x, point.z) / CaveWallGeometry3D.TILE_METRES)
			tool.add_vertex(point)
	_mesh = tool.commit()
	return _mesh

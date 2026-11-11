class_name MapMesh
extends RefCounted
## 지도 크기/위치 변화는 Canvas 변환만 바꾸고 실제 도형이 바뀔 때만 이 버퍼를 갱신한다.


static func update(pieces: Array[Dictionary], mesh: ArrayMesh = null) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for piece in pieces:
		var polygon: PackedVector2Array = piece["poly"]
		if polygon.size() < 3:
			continue
		var triangles := Geometry2D.triangulate_polygon(polygon)
		if triangles.is_empty():
			continue
		var first := vertices.size()
		for point in polygon:
			vertices.append(point)
			colors.append(piece["color"])
		for index in triangles:
			indices.append(first + index)
	if mesh == null:
		mesh = ArrayMesh.new()
	else:
		mesh.clear_surfaces()
	if not vertices.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

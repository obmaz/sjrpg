class_name NativeChapelFacade
extends RefCounted
## 한 면 그림의 구간별 UV와 실제 몰딩이 같은 표를 읽는다. 둥근 장식을 세로로 늘리지 않는다.

static var _tables := {}


static func rows(cell: int) -> PackedVector2Array:
	if _tables.has(cell):
		return _tables[cell]
	var spec: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/models/architecture/chapel/asset.json")
	)
	var data: Dictionary = spec["facadeWarp"]
	var result := PackedVector2Array()
	for pair: Array in data["entrance" if cell == 0 else "nave"]:
		result.append(Vector2(pair[0], pair[1]))
	_tables[cell] = result
	return result


static func height(cell: int, source_y: float, bottom: float, top: float) -> float:
	if cell not in [0, 1]:
		return lerpf(top, bottom, (source_y - .018) / .964)
	var table := rows(cell)
	for index in table.size() - 1:
		if source_y <= table[index + 1].y:
			var t := clampf(inverse_lerp(table[index].y, table[index + 1].y, source_y), 0, 1)
			return lerpf(top, bottom, lerpf(table[index].x, table[index + 1].x, t))
	return bottom


static func material() -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = preload("facade.gdshader")
	result.set_shader_parameter("atlas", load("res://assets/models/architecture/chapel/albedo.png"))
	result.set_shader_parameter("entrance_rows", rows(0))
	result.set_shader_parameter("nave_rows", rows(1))
	return result

class_name ArtWarp
extends RefCounted
## Small calibrated texture projections keep structural edges coherent throughout an illustration.
## Source pixels stay intact; the same triangle map serves drawing and collision coordinates.

static var _catalog: Dictionary = {}

static func data(id: String) -> Dictionary:
	if _catalog.is_empty():
		_catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/art_warps.json"))
	return _catalog.get(id, {})


static func point(id: String, source: Vector2) -> Vector2:
	var mesh := data(id)
	for triangle in mesh["triangles"]:
		var a := _source(mesh["points"][triangle[0]])
		var b := _source(mesh["points"][triangle[1]])
		var c := _source(mesh["points"][triangle[2]])
		var denominator := (b - a).cross(c - a)
		if absf(denominator) < 0.001:
			continue
		var u := (source - a).cross(c - a) / denominator
		var v := (b - a).cross(source - a) / denominator
		if u >= -0.001 and v >= -0.001 and u + v <= 1.001:
			return _target(mesh["points"][triangle[0]]) * (1.0 - u - v) + _target(mesh["points"][triangle[1]]) * u + _target(mesh["points"][triangle[2]]) * v
	return source


static func _source(point: Array) -> Vector2:
	return Vector2(point[0], point[1])


static func _target(point: Array) -> Vector2:
	return Vector2(point[2], point[3])

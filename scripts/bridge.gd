class_name Bridge
extends Node2D
## Measured remake pixels and foreground masks follow bridge_art.json. The
## original playable model remains independent, preserving both bank connections
## and all deck/parapet collision while the illustration is re-authored.

static var texture: Texture2D
static var _data: Dictionary = {}

var k := 1.0  # world pixels per baked texture pixel
var _model_k := 1.0
var front: Node2D


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/bridge_art.json"))
	return _data


static func _v(point: Array) -> Vector2:
	return Vector2(float(point[0]), float(point[1]))


static func axis_direction() -> Vector2:
	var model: Dictionary = data()["model_reference"]
	return (_v(model["axis_end"]) - _v(model["axis_start"])).normalized()


static func model_deck() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for point: Array in data()["model_reference"]["deck"]:
		result.append(_v(point))
	return result


static func front_edge(x: float) -> float:
	var coping: Array = data()["foreground"]["coping"]
	var index := 0
	while index < coping.size() - 2 and x > float(coping[index + 1][0]):
		index += 1
	var a := _v(coping[index])
	var b := _v(coping[index + 1])
	return a.y + (x - a.x) * (b.y - a.y) / (b.x - a.x)


## `forecourt` is the road end on the near bank in world pixels.
func setup(forecourt: Vector2) -> Bridge:
	if texture == null:
		texture = load("res://" + str(data()["render"]))
	var model: Dictionary = data()["model_reference"]
	var reference: Dictionary = data()["texture_reference"]
	_model_k = float(model["world_span"]) / float(model["deck_span"]) * Iso.S
	k = _model_k / float(reference["scale"])
	position = forecourt - (_v(model["axis_start"]) - _v(model["deck_center"])) * _model_k + axis_direction() * float(model["bank_clearance"]) * Iso.S
	z_index = -2
	front = _Front.new()
	front.bridge = self
	front.z_index = 3  # relative to this node: above actors
	add_child(front)
	return self


func point(pixel: Vector2) -> Vector2:
	return position + local(pixel)


func axis_point(t: float) -> Vector2:
	var model: Dictionary = data()["model_reference"]
	return _model_point(_v(model["axis_start"]).lerp(_v(model["axis_end"]), t))


func local(pixel: Vector2) -> Vector2:
	return _texture_local(ArtWarp.point(str(data()["warp_key"]), pixel))


func _texture_local(pixel: Vector2) -> Vector2:
	var reference: Dictionary = data()["texture_reference"]
	var center := _v(data()["model_reference"]["deck_center"]) * float(reference["scale"]) + _v(reference["offset"])
	return (pixel - center) * k


func _model_point(pixel: Vector2) -> Vector2:
	return position + (pixel - _v(data()["model_reference"]["deck_center"])) * _model_k


func deck_polygon() -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in model_deck():
		out.append(_model_point(p))
	return out


## Parapets along both long deck edges and the two end abutments.
func solids() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var deck := model_deck()
	var model: Dictionary = data()["model_reference"]
	for pair in [[deck[0], deck[1]], [deck[3], deck[2]]]:
		var a: Vector2 = pair[0]
		var b: Vector2 = pair[1]
		var n := (b - a).orthogonal().normalized() * float(model["rail_half_thickness"])
		out.append(PackedVector2Array([_model_point(a + n), _model_point(b + n), _model_point(b - n), _model_point(a - n)]))
	for poly in model["abutments"]:
		var pts := PackedVector2Array()
		for p in poly:
			pts.append(_model_point(_v(p)))
		out.append(pts)
	return out


func _draw() -> void:
	var size := _v(data()["texture_size"])
	draw_texture_rect(texture, Rect2(_texture_local(Vector2.ZERO), size * k), false)


class _Front:
	extends Node2D
	var bridge: Bridge

	func _draw() -> void:
		var size := Bridge._v(Bridge.data()["texture_size"])
		var band := PackedVector2Array([Vector2(0, Bridge.front_edge(0.0) - 2.0)])
		for point: Array in Bridge.data()["foreground"]["coping"]:
			band.append(Bridge._v(point) - Vector2(0, 2.0))
		band.append_array(PackedVector2Array([Vector2(size.x, Bridge.front_edge(size.x) - 2.0), Vector2(size.x, size.y + 400.0), Vector2(0, size.y + 400.0)]))
		var image := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
		var shapes: Array = []
		for piece in Geometry2D.intersect_polygons(band, image):
			shapes.append(piece)
		for post in Bridge.data()["foreground"]["posts"]:
			var polygon := PackedVector2Array()
			for point: Array in post:
				polygon.append(Bridge._v(point))
			shapes.append(polygon)
		for shape in shapes:
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			for p in shape:
				pts.append(bridge._texture_local(p))
				uvs.append(p / size)
			draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, Bridge.texture)

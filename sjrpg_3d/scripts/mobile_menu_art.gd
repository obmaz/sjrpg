class_name MobileMenuArt
extends RefCounted
## Broad, generated UI silhouettes. Caller owns button state, badges and touch bounds.

static var _data: Dictionary = {}
static var _texture: Texture2D


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/mobile_menu.json"))
	return _data


static func frame(key: String) -> Rect2:
	var region: Array = data()["atlas"]["frames"][key]["source"]
	return Rect2(region[0], region[1], region[2], region[3])


static func draw(canvas: CanvasItem, key: String, center: Vector2, radius: float, tint := Color.WHITE) -> void:
	if _texture == null:
		_texture = load("res://" + str(data()["atlas"]["path"]))
	var source := frame(key)
	var paint_half: float = data()["atlas"]["frames"][key]["paint_half"]
	var size := source.size * maxf(radius, 0.0) / maxf(paint_half, 1.0)
	canvas.draw_texture_rect_region(_texture, Rect2(center - size * 0.5, size), source, tint)

class_name MobileMenuArt
extends RefCounted
## Painted medallions. Legacy data/frame accessors retain archived source provenance.
## Caller owns live button state, badges and independently sized touch bounds.

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/mobile_menu.json"))
	return _data


static func frame(key: String) -> Rect2:
	var region: Array = data()["atlas"]["frames"][key]["source"]
	return Rect2(region[0], region[1], region[2], region[3])


static func draw(canvas: CanvasItem, key: String, center: Vector2, radius: float, tint := Color.WHITE) -> void:
	UiToneArt.draw_icon(canvas, key, center, radius, tint)

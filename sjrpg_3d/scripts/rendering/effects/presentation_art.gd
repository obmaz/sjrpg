class_name PresentationArt
extends RefCounted
## Generated HUD metal and registered elemental frames; all timings remain owned by their caller.

static var _data: Dictionary = {}
static var _textures: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/presentation_art.json"))
	return _data


static func _texture(key: String) -> Texture2D:
	if not _textures.has(key):
		_textures[key] = load("res://" + str(data()[key]["path"]))
	return _textures[key]


static func ui_frame(key: String) -> Rect2:
	var frame: Array = data()["ui"]["frames"][key]["source"]
	return Rect2(frame[0], frame[1], frame[2], frame[3])


static func draw_ui(canvas: CanvasItem, key: String, center: Vector2, radius: float, tint := Color.WHITE) -> void:
	var source := ui_frame(key)
	var half: float = data()["ui"]["frames"][key]["paint_half"]
	var size := source.size * radius / half
	canvas.draw_texture_rect_region(_texture("ui"), Rect2(center - size * 0.5, size), source, tint)


static func impact_frame(element: int, column: int) -> Rect2:
	var cell := float(data()["impact"]["cell"])
	return Rect2(Vector2(clampi(column, 0, 3), clampi(element, 0, 3)) * cell, Vector2.ONE * cell)


static func impact_columns(phase: float) -> Vector3:
	var progress := clampf(phase, 0.0, 1.0) * 3.0
	var first := floori(progress)
	return Vector3(first, mini(first + 1, 3), progress - first)


## Adjacent registered frames blend at constant total opacity, avoiding stepped flashes.
static func draw_impact(canvas: CanvasItem, element: int, phase: float, rect: Rect2, tint := Color.WHITE) -> void:
	var columns := impact_columns(phase)
	var blend := columns.z
	var first := impact_frame(element, int(columns.x))
	canvas.draw_texture_rect_region(_texture("impact"), rect, first, Color(tint, tint.a * (1.0 - blend)))
	if blend > 0.001 and columns.y != columns.x:
		canvas.draw_texture_rect_region(_texture("impact"), rect, impact_frame(element, int(columns.y)), Color(tint, tint.a * blend))

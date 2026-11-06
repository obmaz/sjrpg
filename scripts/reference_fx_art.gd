class_name ReferenceFxArt
extends RefCounted
## Generated skill silhouettes. Caller owns ADD material, lifetime and damage timing.

static var _data: Dictionary = {}
static var _texture: Texture2D
static var _overrides: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/reference_fx.json"))
	return _data


static func texture(key := "") -> Texture2D:
	if not key.is_empty() and data()["effects"].has(key) and data()["effects"][key].has("override"):
		if not _overrides.has(key):
			_overrides[key] = load("res://" + str(data()["effects"][key]["override"]["path"]))
		return _overrides[key]
	if _texture == null:
		_texture = load("res://" + str(data()["atlas"]["path"]))
	return _texture


static func frame(key: String, column: int) -> Rect2:
	var definition: Dictionary = data()["effects"][key]
	var cell: float = data()["atlas"]["cell"]
	var row: int = int(definition["override"]["row"]) if definition.has("override") else int(definition["row"])
	return Rect2(Vector2(clampi(column, 0, 3), row) * cell, Vector2.ONE * cell)


## Width is the visible PEAK effect width, not the black padded texture width.
## The common registered source contact remains at anchor in every animation phase.
static func rect(key: String, width: float, anchor := Vector2.ZERO) -> Rect2:
	var definition: Dictionary = data()["effects"][key]
	var pivot: Array = definition["pivot"]
	var cell: float = data()["atlas"]["cell"]
	var scale_factor := maxf(width, 0.0) / maxf(float(definition["paint_width"]), 1.0)
	return Rect2(anchor - Vector2(pivot[0], pivot[1]) * scale_factor, Vector2.ONE * cell * scale_factor)


static func draw(canvas: CanvasItem, key: String, phase: float, target: Rect2, tint := Color.WHITE) -> void:
	var columns := PresentationArt.impact_columns(phase)
	canvas.draw_texture_rect_region(texture(key), target, frame(key, int(columns.x)), Color(tint, tint.a * (1.0 - columns.z)))
	if columns.z > 0.001 and columns.y != columns.x:
		canvas.draw_texture_rect_region(texture(key), target, frame(key, int(columns.y)), Color(tint, tint.a * columns.z))

class_name NpcArt
extends RefCounted
## Eight generated identities share a visible human scale and a measured sole contact.

static var _data: Dictionary = {}
static var _texture: Texture2D


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/npc_art.json"))
	return _data


static func identity(label: String) -> String:
	return str(data()["labels"].get(label, "merchant"))


static func body_rect(label: String, height := 112.0) -> Rect2:
	var definition: Dictionary = data()["people"][identity(label)]
	var foot: Array = definition["foot"]
	var source: Array = definition["source"]
	var factor := height / float(definition["ref_height"])
	return Rect2(-Vector2(foot[0], foot[1]) * factor, Vector2(source[2], source[3]) * factor)


static func visible_rect(label: String, height := 112.0) -> Rect2:
	var definition: Dictionary = data()["people"][identity(label)]
	var foot: Array = definition["foot"]
	var bounds: Array = definition["visible_bounds"]
	var factor := height / float(definition["ref_height"])
	return Rect2((Vector2(bounds[0], bounds[1]) - Vector2(foot[0], foot[1])) * factor, Vector2(bounds[2] - bounds[0], bounds[3] - bounds[1]) * factor)


## Reserve the actual human silhouette plus name/quest-marker space above it.
static func readability_rect(label: String, height := 112.0) -> Rect2:
	return visible_rect(label, height).merge(Rect2(-70, -height - 50.0, 140, 64)).grow(10.0)


static func draw(canvas: CanvasItem, label: String, height := 112.0, tint := Color.WHITE) -> void:
	if _texture == null:
		_texture = load("res://" + str(data()["atlas"]["path"]))
	var definition: Dictionary = data()["people"][identity(label)]
	var source: Array = definition["source"]
	canvas.draw_texture_rect_region(_texture, body_rect(label, height), Rect2(source[0], source[1], source[2], source[3]), tint)

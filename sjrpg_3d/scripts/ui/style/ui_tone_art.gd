class_name UiToneArt
extends RefCounted
## Painted HUD family. Generated opaque atlas gutters are excluded by circular UV geometry.
const ICON_PATH := "res://assets/ui/hud/woodland-icons.png"
const PORTRAIT_PATH := "res://assets/ui/hud/woodland-portraits.png"
const BRONZE := Color("a48b63")
const IVORY := Color("e8dcc2")
const MUTED := Color("afa28c")
const CHARCOAL := Color("181c1b")
static var _icons: Texture2D
static var _portraits: Texture2D

static func icons() -> Texture2D:
	if _icons == null:
		_icons = _painted_texture(ICON_PATH)
	return _icons

static func portraits() -> Texture2D:
	if _portraits == null:
		_portraits = _painted_texture(PORTRAIT_PATH)
	return _portraits

## Scope mipmap sampling to these minified painted atlases, not unrelated skill textures.
static func _painted_texture(path: String) -> CanvasTexture:
	var texture := CanvasTexture.new()
	texture.diffuse_texture = load(path) as Texture2D
	texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return texture

static func frame(key: String) -> Rect2:
	var index: int = {"bag": 0, "skills": 1, "quests": 2, "settings": 3, "hp": 4, "mp": 5}.get(key, 0)
	return Rect2(Vector2(index % 3, index / 3) * 512.0, Vector2.ONE * 512.0)

static func draw_icon(canvas: CanvasItem, key: String, center: Vector2, radius: float, tint := Color.WHITE) -> void:
	if radius <= 0.0:
		return
	var source := frame(key)
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for index in 80:
		var direction := Vector2.from_angle(TAU * index / 80.0)
		points.append(center + direction * radius)
		uvs.append((source.get_center() + direction * 248.0) / icons().get_size())
	canvas.draw_polygon(points, PackedColorArray([tint]), uvs, icons())

static func portrait_uv(cls: String) -> Rect2:
	# Each delivered 887-square portrait has a 27px transparent outer margin.
	return Rect2(Vector2(914.0 if cls == "mage" else 27.0, 27.0) / Vector2(1774, 887), Vector2(833, 833) / Vector2(1774, 887))

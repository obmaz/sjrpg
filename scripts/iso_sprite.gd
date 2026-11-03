class_name IsoSprite
extends Node2D
## Native generated art with its measured ground contact (원본 IsometricSprite).
## The node origin is the feet point; the per-asset ground camera correction
## (groundVerticalScale/Skew) is applied exactly like the Flutter renderer.

var def: Dictionary
var texture: Texture2D
var k := 1.0  # world pixels per atlas pixel
var modulate_color := Color.WHITE
var flip := false

static var _textures := {}


static func sheet(name: String) -> Texture2D:
	var file := name.replace("forest-isometric-", "")
	if not _textures.has(file):
		_textures[file] = load("res://assets/art/village/%s.webp" % file)
	return _textures[file]


## `height` is in original world units (before Iso.S).
func setup(d: Dictionary, height: float) -> IsoSprite:
	def = d
	texture = IsoSprite.sheet(d["sheet"])
	k = height / float(d["height"]) * Iso.S
	return self


func _ground_delta(delta: Vector2) -> Vector2:
	return Vector2(delta.x, delta.y * float(def["gvs"]) + delta.x * float(def["gvk"]))


## Atlas pixel → world position.
func atlas_point(pixel: Vector2) -> Vector2:
	var foot := Vector2(def["foot"][0], def["foot"][1])
	return position + _ground_delta(pixel - foot) * k


## Original (pre-packing) measurement pixel → world position.
func native_point(native: Vector2) -> Vector2:
	var src := Vector2(def["source"][0], def["source"][1])
	var origin := Vector2(def["origin"][0], def["origin"][1])
	return atlas_point(src + (native - origin) * float(def["packing"]))


func atlas_polygon(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(atlas_point(Vector2(p[0], p[1])))
	return out


func native_polygon(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(native_point(Vector2(p[0], p[1])))
	return out


func _draw() -> void:
	var src := Rect2(def["source"][0], def["source"][1], def["source"][2], def["source"][3])
	var foot := Vector2(def["foot"][0], def["foot"][1])
	var sx := -k if flip else k
	draw_set_transform_matrix(Transform2D(Vector2(sx, k * float(def["gvk"])), Vector2(0, k * float(def["gvs"])), Vector2.ZERO))
	draw_texture_rect_region(texture, Rect2(src.position - foot, src.size), src, modulate_color)

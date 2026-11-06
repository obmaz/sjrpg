class_name ForestAtmosphere
extends Node2D
## Opt-in generated atmosphere trial. The two existing clearing openings own the
## source light, and the field root owns visibility/pause/quality transitions.
## This is not a volume renderer or a replacement for actual caster shadows.

const MAX_SHAFTS := 2
const DATA_PATH := "res://assets/data/forest_atmosphere.json"
static var _data: Dictionary = {}
static var _texture: Texture2D
static var _material: CanvasItemMaterial

var anchors := PackedVector2Array()
var enabled := false


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return _data


func setup(openings: PackedVector2Array) -> ForestAtmosphere:
	for index in mini(MAX_SHAFTS, openings.size()):
		anchors.append(openings[index])
	visible = false
	return self


func _ready() -> void:
	if enabled:
		_prepare_art()
	visible = enabled
	set_process(false)


func _prepare_art() -> void:
	if _texture == null:
		_texture = load("res://" + str(data()["texture"]["path"]))
	if _material == null:
		_material = CanvasItemMaterial.new()
		_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = _material
	z_as_relative = false
	z_index = int(data()["z_index"])
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# The source already includes sparse dust. No particle nodes, movement,
	# flicker, per-frame allocations or additional render passes are necessary.


func set_enabled(value: bool) -> void:
	enabled = value
	if value:
		_prepare_art()
	visible = value
	queue_redraw()


## Native source geometry is translated/scaled uniformly in screen-world space.
## Camera zoom and the economy viewport transform both openings identically.
func source_point(index: int, pixel: Vector2) -> Vector2:
	var definition: Dictionary = data()["shafts"][index]
	var pivot: Array = data()["pivot"]
	var source_size: Array = data()["texture"]["size"]
	var scale_factor := float(definition["world_width"]) / float(source_size[0])
	return anchors[index] + (pixel - Vector2(pivot[0], pivot[1])) * scale_factor


func _draw() -> void:
	if not enabled or _texture == null:
		return
	var source_size: Array = data()["texture"]["size"]
	var size := Vector2(source_size[0], source_size[1])
	var uvs := PackedVector2Array()
	for point in data()["source_envelope"]:
		uvs.append(Vector2(point[0], point[1]) / size)
	for index in anchors.size():
		var points := PackedVector2Array()
		for point in data()["source_envelope"]:
			points.append(source_point(index, Vector2(point[0], point[1])))
		var definition: Dictionary = data()["shafts"][index]
		draw_polygon(points, PackedColorArray([Color(1, 1, 1, float(definition["opacity"]))]), uvs, _texture)

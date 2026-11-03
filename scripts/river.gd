class_name River
extends Node2D
## 동문 밖 강. Authored in ground units (child of the ground layer), flowing along
## the +u axis from the field edge into a rounded pool beside the town.

var polygon := PackedVector2Array()
var _water: Polygon2D
var _shimmer: Polygon2D
var _time := 0.0

const TILE_UNITS := 170.0  # ground units covered by one 418px texture tile
const PX := 418.0 / TILE_UNITS


## u0 = west end of the straight reach, u1 = east end; v0 < v1 bound the water.
func setup(u0: float, u1: float, v0: float, v1: float, cap_u: float) -> River:
	var mid := (v0 + v1) / 2.0
	var rv := (v1 - v0) / 2.0
	var pts := PackedVector2Array([Vector2(u1, v0), Vector2(u0, v0)])
	# Rounded west end: half ellipse bulging toward -u, from (u0, v0) to (u0, v1).
	for i in range(1, 12):
		var t := PI * float(i) / 12.0
		pts.append(Vector2(u0 - cap_u * sin(t), mid - rv * cos(t)))
	pts.append(Vector2(u0, v1))
	pts.append(Vector2(u1, v1))
	polygon = pts
	_build()
	return self


func _poly(poly: PackedVector2Array, tex: String, mod := Color.WHITE, scale := 1.0) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = poly
	p.texture = load("res://assets/art/village/%s.webp" % tex)
	p.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	var uv := PackedVector2Array()
	for v in poly:
		uv.append(v * PX * scale)
	p.uv = uv
	p.modulate = mod
	return p


func _build() -> void:
	# Soft dirt shoulder, then a rocky embankment, then the water itself.
	var outer: Array = Geometry2D.offset_polygon(polygon, 78.0, Geometry2D.JOIN_ROUND)
	if outer.size() > 0:
		add_child(_poly(outer[0], "dirt", Color(1, 1, 1, 0.55)))
	var bank: Array = Geometry2D.offset_polygon(polygon, 40.0, Geometry2D.JOIN_ROUND)
	if bank.size() > 0:
		add_child(_poly(bank[0], "rock", Color(0.78, 0.78, 0.74)))
	_water = _poly(polygon, "water", Color(0.55, 0.74, 0.80))
	add_child(_water)
	_shimmer = _poly(polygon, "water", Color(1, 1, 1, 0.14), 0.55)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_shimmer.material = mat
	add_child(_shimmer)


func _process(delta: float) -> void:
	_time += delta
	_water.texture_offset = Vector2(_time * 38.0, _time * 6.0)
	_shimmer.texture_offset = Vector2(-_time * 24.0, _time * 11.0)

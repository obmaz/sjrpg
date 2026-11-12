class_name River
extends Node2D
## 마을 밖 필드를 가로지르는 강. 지면 좌표로 양쪽 맵 경계 밖까지 이어진다.

var polygon := PackedVector2Array()
var _water: Polygon2D
var _shimmer: Polygon2D
var _water_material: ShaderMaterial
var _shimmer_material: ShaderMaterial
var _time := 0.0

const FLOW_SHADER := preload("res://assets/sprites/shaders/river_flow.gdshader")
const SHIMMER_SHADER := preload("res://assets/sprites/shaders/river_shimmer.gdshader")
const TILE_UNITS := 170.0  # ground units covered by one generated 512px material tile
const PX := 512.0 / TILE_UNITS


## u0 = west end of the straight reach, u1 = east end; v0 < v1 bound the water.
func setup(u0: float, u1: float, v0: float, v1: float) -> River:
	polygon = PackedVector2Array(
		[Vector2(u1, v0), Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1)]
	)
	_build()
	return self


func _poly(poly: PackedVector2Array, tex: String, mod := Color.WHITE, scale := 1.0) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = poly
	p.texture = IsoSprite.sheet(tex)
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
		add_child(_poly(bank[0], "rock"))
	_water = _poly(polygon, "water")
	_water_material = ShaderMaterial.new()
	_water_material.shader = FLOW_SHADER
	_water_material.set_shader_parameter("flow_offset", Vector2.ZERO)
	_water.material = _water_material
	add_child(_water)
	_shimmer = _poly(polygon, "water", Color(1, 1, 1, 0.07), 0.55)
	_shimmer_material = ShaderMaterial.new()
	_shimmer_material.shader = SHIMMER_SHADER
	_shimmer_material.set_shader_parameter("flow_offset", Vector2.ZERO)
	_shimmer.material = _shimmer_material
	add_child(_shimmer)


func _process(delta: float) -> void:
	_time += delta
	# Godot 4.7's Polygon2D UV updates re-upload indices through a WebGL-incompatible
	# ARRAY_BUFFER target. Keep geometry/UVs fixed and move only the texture samples.
	var texture_size := _water.texture.get_size()
	_water_material.set_shader_parameter(
		"flow_offset", Vector2(_time * 38.0, _time * 6.0) / texture_size
	)
	_shimmer_material.set_shader_parameter(
		"flow_offset", Vector2(-_time * 24.0, _time * 11.0) / texture_size
	)

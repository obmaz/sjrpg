class_name PlazaWater
extends Node
## Animate the existing fluid pixels, keeping the reviewed stone geometry untouched.

const SHADER := preload("res://scripts/plaza_water.gdshader")
var phase := 0.0
var surface: IsoSprite
var water_material: ShaderMaterial


static func attach(sprite: IsoSprite, is_portal: bool) -> PlazaWater:
	var animation := PlazaWater.new()
	animation.surface = sprite
	animation.water_material = ShaderMaterial.new()
	animation.water_material.shader = SHADER
	var src: Array = sprite.def["source"]
	var size := sprite.texture.get_size()
	animation.water_material.set_shader_parameter("atlas_region", Vector4(src[0] / size.x, src[1] / size.y, src[2] / size.x, src[3] / size.y))
	animation.water_material.set_shader_parameter("portal", is_portal)
	sprite.material = animation.water_material
	sprite.add_child(animation)
	return animation


func _ready() -> void:
	surface.set_instance_shader_parameter("sort_y", surface.global_position.y)


func _process(delta: float) -> void:
	phase = 0.0 if Prefs.reduce_motion else fmod(phase + delta, TAU * 100.0)
	water_material.set_shader_parameter("phase", phase)

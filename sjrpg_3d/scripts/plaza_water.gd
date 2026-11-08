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
	WorldLighting.register_material(animation.water_material)
	# Native fountain/portal models use this phase clock, not the archived atlas.
	# First real texture consumption configures UVs before the source draw executes.
	sprite.texture_changed.connect(animation._texture_changed)
	animation._texture_changed(sprite.texture_if_loaded())
	animation.water_material.set_shader_parameter("portal", is_portal)
	var profile: Dictionary = sprite.def.get("fluid_profile", {})
	for key in ["basin_center", "basin_radius", "portal_center", "portal_radius"]:
		if profile.has(key):
			var value: Array = profile[key]
			animation.water_material.set_shader_parameter(key, Vector2(value[0], value[1]))
	for key in ["jet_left", "jet_right"]:
		if profile.has(key):
			var value: Array = profile[key]
			animation.water_material.set_shader_parameter(key, Vector4(value[0], value[1], value[2], value[3]))
	sprite.material = animation.water_material
	sprite.add_child(animation)
	return animation


func _texture_changed(value: Texture2D) -> void:
	if value == null:
		water_material.set_shader_parameter("atlas_region", Vector4.ZERO)
		return
	var size := value.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		water_material.set_shader_parameter("atlas_region", Vector4.ZERO)
		return
	var src: Array = surface.def["source"]
	water_material.set_shader_parameter("atlas_region",
		Vector4(src[0] / size.x, src[1] / size.y, src[2] / size.x, src[3] / size.y))


func _ready() -> void:
	surface.set_instance_shader_parameter("sort_y", surface.global_position.y)


func _process(delta: float) -> void:
	phase = 0.0 if Prefs.reduce_motion else fmod(phase + delta, TAU * 100.0)
	water_material.set_shader_parameter("phase", phase)

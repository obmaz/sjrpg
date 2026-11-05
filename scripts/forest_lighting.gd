class_name ForestLighting
extends Node2D
## Two bounded daylight openings on textured ground. Actors, water, HUD and the
## cave retain their own materials. Tree shadows use the actual canopy casters.

const GROUND_MASK := 2
const SHADE_OPACITY := 0.26
const BASE_SHADE_OPACITY := 0.11
const SHADER_CODE := """
shader_type canvas_item;
uniform float amount = 1.0;
void fragment() {
	COLOR.rgb *= mix(vec3(1.0), vec3(0.78, 0.83, 0.86), amount);
}
"""

var surfaces: Array[CanvasItem] = []
var lights: Array[PointLight2D] = []
var shades: Array[CanopyShade] = []
var ground_material: ShaderMaterial
var enabled := true


func setup(receiver: Node2D, village: Village) -> ForestLighting:
	var shader := Shader.new()
	shader.code = SHADER_CODE
	ground_material = ShaderMaterial.new()
	ground_material.shader = shader
	_bind_surfaces(receiver)
	# These openings stay in the world as the camera moves. The ellipse represents
	# a light footprint on the projected ground, not a perspective change to art.
	_add_daylight(village.chapel_steps[0] + Vector2(-40, 95), 850.0)
	_add_daylight(village.fountain.position + Vector2(0, 35), 750.0)
	set_enabled(true)
	return self


func _bind_surfaces(node: Node) -> void:
	if node is CanopyShade:
		shades.append(node)
	elif node is Sprite2D or node is Polygon2D:
		var surface := node as CanvasItem
		var texture: Texture2D = node.texture
		if surface.material == null and texture in [ForestArt.texture("grass"), ForestArt.texture("paving"), ForestArt.texture("earth")]:
			surface.material = ground_material
			surface.light_mask = GROUND_MASK
			surfaces.append(surface)
	for child in node.get_children():
		_bind_surfaces(child)


func _add_daylight(at: Vector2, diameter: float) -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.65), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	var light := PointLight2D.new()
	light.position = at
	light.texture = texture
	light.texture_scale = diameter / 256.0
	light.scale = Vector2(1.0, 0.58)
	light.color = Color(1.0, 0.91, 0.76)
	light.energy = 0.55
	light.range_item_cull_mask = GROUND_MASK
	light.range_z_min = -10
	light.range_z_max = -9
	light.range_layer_min = 0
	light.range_layer_max = 0
	add_child(light)
	lights.append(light)


func set_enabled(value: bool) -> void:
	enabled = value
	ground_material.set_shader_parameter("amount", 1.0 if value else 0.0)
	for light in lights:
		light.enabled = value
	for shade in shades:
		if is_instance_valid(shade):
			shade.opacity = SHADE_OPACITY if value else BASE_SHADE_OPACITY
			shade.refresh()

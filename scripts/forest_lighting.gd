class_name ForestLighting
extends Node2D
## Two bounded daylight openings on textured ground. Actors, water, HUD and the
## cave retain their own materials. Tree shadows use the actual canopy casters.

const SHADE_OPACITY := 0.26
const BASE_SHADE_OPACITY := 0.11
const SHADER_CODE := """
shader_type canvas_item;
render_mode unshaded;
uniform float amount = 1.0;
uniform vec2 opening_a;
uniform vec2 opening_b;
varying vec2 ground_world;
void vertex() {
	ground_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
float daylight(vec2 center, vec2 radius) {
	float r = clamp(length((ground_world - center) / radius), 0.0, 1.0);
	return 1.0 - smoothstep(0.0, 1.0, r * 0.5 + r * r * 0.5);
}
void fragment() {
	float sun = daylight(opening_a, vec2(425.0, 246.5)) + daylight(opening_b, vec2(375.0, 217.5));
	vec3 illumination = vec3(0.78, 0.83, 0.86) * (vec3(1.0) + vec3(1.0, 0.91, 0.76) * 0.55 * sun);
	COLOR.rgb *= mix(vec3(1.0), illumination, amount);
}
"""

var surfaces: Array[CanvasItem] = []
var openings := PackedVector2Array()
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
	openings.append(village.chapel_steps[0] + Vector2(-40, 95))
	openings.append(village.fountain.position + Vector2(0, 35))
	ground_material.set_shader_parameter("opening_a", openings[0])
	ground_material.set_shader_parameter("opening_b", openings[1])
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
			surfaces.append(surface)
	for child in node.get_children():
		_bind_surfaces(child)


func set_enabled(value: bool) -> void:
	enabled = value
	ground_material.set_shader_parameter("amount", 1.0 if value else 0.0)
	for shade in shades:
		if is_instance_valid(shade):
			shade.opacity = SHADE_OPACITY if value else BASE_SHADE_OPACITY
			shade.refresh()

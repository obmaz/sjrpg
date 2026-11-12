shader_type canvas_item;
render_mode unshaded;

#include "res://assets/sprites/shaders/world_occlusion.gdshaderinc"
#include "res://assets/sprites/shaders/world_daylight.gdshaderinc"

uniform float daylight_amount = 0.0;
uniform vec2 opening_a;
uniform vec2 opening_b;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	COLOR.rgb *= mix(vec3(1.0), world_daylight(world_position, opening_a, opening_b), daylight_amount);
	COLOR = uncover_hero(COLOR);
}

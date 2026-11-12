shader_type canvas_item;
render_mode unshaded;

#include "res://assets/sprites/shaders/world_daylight.gdshaderinc"

uniform float daylight_amount = 0.0;
uniform vec2 opening_a;
uniform vec2 opening_b;
varying vec2 daylight_world;

void vertex() {
	daylight_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	COLOR.rgb *= mix(vec3(1.0), world_daylight(daylight_world, opening_a, opening_b), daylight_amount);
}

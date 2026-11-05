shader_type canvas_item;
render_mode unshaded;

#include "res://scripts/world_occlusion.gdshaderinc"

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	COLOR = uncover_hero(COLOR);
}

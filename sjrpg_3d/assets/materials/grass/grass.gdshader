shader_type spatial;
render_mode cull_back;
#include "res://assets/materials/grass/variety.gdshaderinc"
uniform vec4 surface_tint : source_color = vec4(1.0);
uniform float habitat_bias = 0.0;
varying highp vec2 grass_world;
void vertex() { grass_world=(MODEL_MATRIX*vec4(VERTEX,1)).xz; }
void fragment() {
	ALBEDO=grass_surface(grass_world,habitat_bias)*surface_tint.rgb;
	ROUGHNESS=.98;
}

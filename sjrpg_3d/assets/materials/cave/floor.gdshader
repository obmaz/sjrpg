shader_type spatial;
render_mode cull_disabled;
#include "res://assets/materials/cave/variants.gdshaderinc"
varying vec3 cave_world;
void vertex() { cave_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec3 color=cave_surface(UV,cave_world.xz);
	ALBEDO=color*vec3(1.03,1.0,.95);
	ROUGHNESS=.97;
	SPECULAR=.16;
}

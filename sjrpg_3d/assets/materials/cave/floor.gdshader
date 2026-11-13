shader_type spatial;
render_mode cull_disabled;
#include "res://assets/materials/cave/variants.gdshaderinc"
varying vec3 cave_world;
void vertex() { cave_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec3 color=cave_surface(UV,cave_world.xz);
	// 큰 밝은 반점이 방마다 반복되지 않도록 재료 고유색의 편차만 완만하게 낮춘다.
	float luminance=dot(color,vec3(.2126,.7152,.0722));
	color=mix(vec3(luminance),color,.76);
	ALBEDO=mix(vec3(.40,.36,.30),color,.70)*vec3(1.03,1.0,.95);
	ROUGHNESS=.97;
	SPECULAR=.16;
}

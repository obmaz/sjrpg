shader_type spatial;
#include "res://assets/materials/grass/variety.gdshaderinc"
uniform vec4 surface_tint : source_color = vec4(1.0);
uniform float habitat_bias = 0.45;
uniform sampler2D rock_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D earth_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool rock_shelf = false;
uniform bool cliff = false;
varying vec3 world_position;
varying vec3 world_normal;
float patch(vec2 p) { return 0.5 + 0.25 * sin(p.x * 1.7 + sin(p.y * 1.1)) + 0.25 * cos(p.y * 2.3 + sin(p.x * 0.7)); }
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec3 p = world_position / 2.56;
	vec3 w = pow(abs(world_normal), vec3(6.0));
	w /= max(dot(w, vec3(1.0)), 0.0001);
	vec3 stone = texture(rock_texture, p.zy).rgb * w.x + texture(rock_texture, p.xz).rgb * w.y + texture(rock_texture, p.xy).rgb * w.z;
	vec3 soil = texture(earth_texture, p.zy).rgb * w.x + texture(earth_texture, p.xz).rgb * w.y + texture(earth_texture, p.xy).rgb * w.z;
	float field = patch(world_position.xz * 0.53);
	if (cliff) {
		float strata = 0.86 + 0.14 * smoothstep(-0.8, 0.3, sin(world_position.y * 15.0 + field * 1.7));
		ALBEDO = mix(soil, stone, rock_shelf ? 0.88 : 0.30 + field * 0.35) * strata;
	} else {
		vec3 base = mix(soil, stone, rock_shelf ? 0.82 : 0.18);
		vec3 turf = grass_surface(world_position.xz, habitat_bias) * surface_tint.rgb;
		ALBEDO = mix(base, turf, smoothstep(rock_shelf ? 0.44 : 0.10, rock_shelf ? 0.91 : 0.58, field));
	}
	ROUGHNESS = 0.98;
}

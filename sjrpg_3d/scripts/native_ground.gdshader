shader_type spatial;
render_mode cull_back;
uniform sampler2D base_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D edge_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D distance_field : filter_linear, repeat_disable;
#include "res://scripts/grass_variety.gdshaderinc"

uniform sampler2D shore_field : filter_linear, repeat_disable;
uniform sampler2D rock_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D earth_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 field_origin;
uniform vec2 field_extent;
varying vec2 ground_world;

float hash_ground(vec2 p) {
	vec2 q = fract(p * vec2(0.1031, 0.1030));
	q += dot(q, q.yx + 33.33);
	return fract((q.x + q.y) * q.x);
}
float ground_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_ground(i), hash_ground(i + vec2(1.0, 0.0)), f.x),
		mix(hash_ground(i + vec2(0.0, 1.0)), hash_ground(i + vec2(1.0)), f.x), f.y);
}
// 원화의 마주 보는 가장자리가 완벽하지 않아도 반사 반복은 색의 연속성을 지킨다.
vec2 mirrored(vec2 uv) {
	return 1.0 - abs(fract(uv * 0.5) * 2.0 - 1.0);
}
vec3 base_tile(vec2 uv, vec2 cell) {
	return texture(base_atlas, (cell + mix(vec2(0.012), vec2(0.988), mirrored(uv))) * 0.5).rgb;
}
vec3 edge_tile(vec2 uv, vec2 cell) {
	vec2 local = vec2(clamp(uv.x, 0.0, 1.0), mirrored(uv).y);
	return texture(edge_atlas, (cell + mix(vec2(0.012), vec2(0.988), local)) * 0.5).rgb;
}
void vertex() {
	ground_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	vec2 field_uv = (ground_world - field_origin) / field_extent;
	vec4 data = texture(distance_field, field_uv);
	vec3 encoded = data.rgb;
	float d = (encoded.r * 2.0 - 1.0) * 2.0;
	if (any(lessThan(field_uv, vec2(0.0))) || any(greaterThan(field_uv, vec2(1.0)))) {
		d = 2.0;
	}
	vec2 uv = ground_world / 2.56;
	vec3 grass = grass_surface(ground_world,0.0);
	vec3 color = grass;
	if (d < 1.25) {
		vec3 paving = mix(base_tile(uv, vec2(0.0)), base_tile(uv, vec2(1.0, 0.0)), ground_noise(ground_world / 3.8));
		float irregular = (ground_noise(ground_world * 2.3) - 0.5) * 0.22;
		float edge_d = d + irregular;
		color = mix(paving, grass, smoothstep(-0.18, 0.18, edge_d));
		if (abs(edge_d) < 1.15) {
			vec2 outward = normalize(encoded.gb * 2.0 - 1.0 + vec2(0.00001));
			vec2 tangent = vec2(-outward.y, outward.x);
			vec2 join_uv = vec2(0.5 + edge_d / 2.56, dot(ground_world, tangent) / 2.56);
			float a = ground_noise(ground_world / 3.1 + vec2(8.0, 0.0));
			float b = ground_noise(ground_world / 2.7 + vec2(0.0, 12.0));
			vec3 joins = mix(mix(edge_tile(join_uv, vec2(0.0)), edge_tile(join_uv, vec2(1.0, 0.0)), a),
				mix(edge_tile(join_uv, vec2(0.0, 1.0)), edge_tile(join_uv, vec2(1.0)), a), b);
			color = mix(color, joins, 1.0 - smoothstep(0.60, 1.15, abs(edge_d)));
		}
	}
	// 막다른 포장길은 흙길로 좁아지며 풀 속으로 이어진다.
	float terminal = data.a;
	if (all(greaterThanEqual(field_uv, vec2(0.0))) && all(lessThanEqual(field_uv, vec2(1.0)))) {
		vec3 soil = texture(earth_texture, uv).rgb;
		float speckle = ground_noise(ground_world * 3.1);
		color = mix(color, soil, smoothstep(0.05, 0.88, terminal + (speckle - 0.5) * 0.18));
		float bank_d = (texture(shore_field, field_uv).r * 2.0 - 1.0) * 2.0;
		float broken = bank_d + (ground_noise(ground_world * 1.9) - 0.5) * 0.48;
		vec3 stones = texture(rock_texture, uv * 1.24).rgb;
		vec3 bank = mix(stones * 0.67, mix(stones, soil, 0.63), smoothstep(-0.05, 0.45, broken));
		color = mix(color, bank, 1.0 - smoothstep(0.12, 1.18, broken));
	}
	ALBEDO = color;
	ROUGHNESS = 0.98;
}

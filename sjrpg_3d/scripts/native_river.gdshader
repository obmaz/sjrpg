shader_type spatial;
render_mode blend_mix, depth_prepass_alpha;
uniform sampler2D water_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D shore_field : filter_linear, repeat_disable;
uniform vec2 field_origin;
uniform vec2 field_extent;
uniform float phase = 0.0;
varying vec2 ground_world;
void vertex() { ground_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
	vec2 uv = ground_world / 2.56;
	vec3 water = texture(water_texture, uv + vec2(phase * 0.025, phase * 0.006)).rgb;
	float d = (texture(shore_field, (ground_world - field_origin) / field_extent).r * 2.0 - 1.0) * 2.0;
	float ripple = sin(ground_world.x * 19.0 + ground_world.y * 12.0 + phase * 1.4) * 0.024;
	ALBEDO = water * vec3(0.78, 0.91, 0.96);
	ROUGHNESS = 0.35;
	METALLIC = 0.12;
	ALPHA = 1.0 - smoothstep(-0.17, 0.005, d + ripple);
}

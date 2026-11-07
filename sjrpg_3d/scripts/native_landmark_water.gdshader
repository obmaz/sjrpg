shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
uniform sampler2D source_water : source_color, filter_linear_mipmap, repeat_enable;
uniform float phase = 0.0;
uniform float motion = 1.0;
uniform bool falling = false;
void vertex() {
	VERTEX += NORMAL * (0.003 * motion * sin(UV.x * 31.0 + UV.y * 26.0 - phase * 2.5));
}
void fragment() {
	vec2 drift = vec2(phase * 0.012, phase * (falling ? -0.12 : 0.018));
	vec3 grain = texture(source_water, UV * (falling ? vec2(1.0, 1.4) : vec2(2.0)) + drift * motion).rgb;
	float lightness = dot(grain, vec3(0.2126, 0.7152, 0.0722));
	vec3 base = mix(vec3(0.035, 0.14, 0.15), vec3(0.09, 0.28, 0.29), lightness);
	float filaments = pow(max(0.0, sin(UV.x * 43.0 + sin(UV.y * 6.0 - phase * 0.7 * motion) * 0.5)), 18.0);
	ALBEDO = base + vec3(0.12, 0.16, 0.15) * filaments * (falling ? 0.65 : 0.12);
	ROUGHNESS = 0.26;
	METALLIC = 0.06;
	float edge = smoothstep(0.0, 0.10, UV.x) * smoothstep(0.0, 0.10, 1.0 - UV.x);
	ALPHA = falling ? edge * (0.62 + lightness * 0.20) : 0.76;
}

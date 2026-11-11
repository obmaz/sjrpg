shader_type spatial;
render_mode cull_disabled;

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform int cell = 0;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	// 기하와 같은 2.6m당8단·6열, 홀수 단의 반 칸 엇갈림. 그림 속 줄눈은 없다.
	float row = floor(UV.y * 8.0);
	vec2 tile = vec2(UV.x * 6.0 - mod(row, 2.0) * 0.5, UV.y * 8.0);
	vec2 within = fract(tile);
	vec2 corner = vec2(float(cell % 2), float(cell / 2));
	vec2 sample_uv = (corner + mix(vec2(0.018), vec2(0.982), fract(tile))) * 0.5;
	float variation = fract(sin(dot(floor(tile), vec2(12.9898, 78.233))) * 43758.5453);
	// 실제 겹침선의 좁은 접촉 음영. 줄 전체를 그린 그림과 기하가 어긋나지 않는다.
	float joint = smoothstep(0.0, 0.055, within.y) * smoothstep(0.0, 0.02, min(within.x, 1.0 - within.x));
	ALBEDO = texture(atlas, sample_uv).rgb * tint.rgb * mix(0.87, 1.08, variation) * mix(0.76, 1.0, joint);
	ROUGHNESS = 0.96;
}

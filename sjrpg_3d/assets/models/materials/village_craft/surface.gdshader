shader_type spatial;
render_mode cull_back;

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform int cell_override = -1;
varying vec3 local_position;
varying vec3 local_normal;

vec3 stone(vec2 uv, vec2 cell) {
	vec2 repeat_uv = 1.0 - abs(fract(uv * 0.5) * 2.0 - 1.0);
	return texture(atlas, (cell + mix(vec2(0.018), vec2(0.982), repeat_uv)) * 0.5).rgb;
}

void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	vec3 n = normalize(local_normal);
	// 위를 향한 디딤판/덮개에는 줄눈 없는 돌, 낮은 수직 기단에는 큰 판석을 쓴다.
	vec2 cell = n.y > 0.65 ? vec2(1.0, 0.0) : (local_position.y < 0.28 ? vec2(1.0) : vec2(0.0));
	if (cell_override >= 0) {
		cell = vec2(float(cell_override % 2), float(cell_override / 2));
	}
	vec3 weight = pow(abs(n), vec3(4.0));
	weight /= max(dot(weight, vec3(1.0)), 0.0001);
	vec3 p = local_position / 2.56;
	ALBEDO = stone(vec2(p.z, -p.y), cell) * weight.x
		+ stone(p.xz, cell) * weight.y
		+ stone(vec2(p.x, -p.y), cell) * weight.z;
	ROUGHNESS = 0.94;
}

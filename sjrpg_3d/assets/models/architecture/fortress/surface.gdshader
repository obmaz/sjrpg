shader_type spatial;
uniform sampler2D masonry_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool dressed = false;
varying vec3 world_position;
varying vec3 world_normal;
vec3 stone(vec2 uv, vec2 cell) {
	vec2 mirrored = 1.0 - abs(fract(uv * 0.5) * 2.0 - 1.0);
	return texture(masonry_atlas, (cell + mix(vec2(0.012), vec2(0.988), mirrored)) * 0.5).rgb;
}
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec3 p = world_position / 2.56;
	vec3 weights = pow(abs(world_normal), vec3(8.0));
	weights /= max(dot(weights, vec3(1.0)), 0.0001);
	float patch = sin(world_position.x * 0.41 + sin(world_position.z * 0.27)) * cos(world_position.y * 0.63);
	vec2 cell = vec2(step(0.1, patch), 0.0);
	if (world_position.y < 0.30) { cell = vec2(0.0, 1.0); }
	if (dressed && world_position.y >= 0.30) { cell = vec2(1.0); }
	ALBEDO = stone(p.zy, cell) * weights.x + stone(p.xz, cell) * weights.y + stone(p.xy, cell) * weights.z;
	ROUGHNESS = 0.94;
}

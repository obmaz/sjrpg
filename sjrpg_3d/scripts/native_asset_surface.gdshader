shader_type spatial;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 extent = vec3(6.0,5.0,6.0);
uniform bool tile = false;
uniform float tile_metres = 2.56;
uniform int cell_override = -1;
uniform float roughness = 0.94;
varying vec3 point;
varying vec3 surface_normal;
void vertex() { point = VERTEX; surface_normal = NORMAL; }
void fragment() {
	vec3 n = normalize(surface_normal);
	bool side = abs(n.x) > abs(n.z);
	float horizontal = side ? point.z : point.x;
	float width = side ? extent.z : extent.x;
	float orientation = side ? -sign(n.x) : sign(n.z);
	int face = side ? (n.x > 0.0 ? 1 : 3) : (n.z > 0.0 ? 0 : 2);
	vec2 uv = vec2(horizontal * orientation / width + 0.5, 1.0-point.y/extent.y);
	if (!tile && point.y > extent.y) { uv.y = clamp(0.35+(point.y-extent.y)*0.08,0.35,0.65); }
	if (tile) {
		uv = abs(n.y)>0.7 ? point.xz/tile_metres : vec2(horizontal, -point.y)/tile_metres;
		uv = 1.0-abs(fract(uv*0.5)*2.0-1.0);
	}
	if (cell_override >= 0) { face = cell_override; }
	vec2 cell = vec2(float(face % 2),float(face / 2));
	// 검은 구분선과 이웃 셀의 밉 샘플을 피하고 원본 크기는 보존한다.
	ALBEDO = texture(atlas,(cell+mix(vec2(0.018),vec2(0.982),clamp(uv,vec2(0.0),vec2(1.0))))*0.5).rgb;
	ROUGHNESS = roughness;
}

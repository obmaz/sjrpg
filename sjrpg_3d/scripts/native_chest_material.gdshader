shader_type spatial;
// COLOR: R는 실제 철물, G는 앞면/옆면/펼친 뚜껑 영역, B는 장식 없는 내부다.
uniform sampler2D surface_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform int variant = 0;
void fragment() {
	int face = int(round(COLOR.g * 2.0));
	// 생성 원본의 실제 면 경계. 이미지를 자르거나 임의로 등분하지 않는다.
	float left = face == 0 ? 0.0 : (face == 1 ? 522.0 : 836.0);
	float width = face == 0 ? 522.0 : (face == 1 ? 314.0 : 418.0);
	bool interior = COLOR.b > 0.5;
	if (interior) { left = 836.0; width = 418.0; }
	vec2 inset = vec2(2.0/width,2.0/418.0);
	vec2 local_uv = mix(inset,vec2(1.0)-inset,UV);
	if (interior) { local_uv = vec2(.43,.45)+UV*vec2(.14,.13); }
	ALBEDO = texture(surface_atlas,vec2((left+local_uv.x*width)/1254.0,(float(variant)+local_uv.y)/3.0)).rgb;
	float hardware = step(0.5,COLOR.r);
	ROUGHNESS = variant == 2 ? mix(.85,.47,hardware) : (variant == 1 ? .69 : mix(.94,.72,hardware));
	METALLIC = variant == 1 ? .58 : hardware*(variant == 2 ? .68 : .38);
	if (interior) { ALBEDO *= .82; ROUGHNESS = .95; METALLIC = variant == 1 ? .38 : 0.0; }
}

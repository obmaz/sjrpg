uniform sampler2D paving_0 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paving_1 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paving_2 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paving_3 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paving_4 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paving_5 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

vec3 paving_sample(vec2 uv, int variant) {
	if (variant == 0) { return texture(paving_0,uv).rgb; }
	if (variant == 1) { return texture(paving_1,uv).rgb; }
	if (variant == 2) { return texture(paving_2,uv).rgb; }
	if (variant == 3) { return texture(paving_3,uv).rgb; }
	if (variant == 4) { return texture(paving_4,uv).rgb; }
	return texture(paving_5,uv).rgb;
}
// 타일마다 무작위로 돌리면 이음새가 생기므로 연속 좌표로 넓은 보수 구역을 섞는다.
vec3 paving_surface(vec2 world, float town) {
	float region = fract(ground_noise(world/8.5)*1.83+0.17)*6.0;
	region = mix(mix(3.6,5.99,ground_noise(world/6.7)),region,town);
	int first = int(floor(region));
	int next = (first+1)%6;
	vec2 uv = world/3.2;
	uv += vec2(ground_noise(world/1.9),ground_noise(world/2.1+vec2(16.0)))*0.035;
	vec3 a = paving_sample(uv,first);
	vec3 b = paving_sample(uv,next);
	float relief_a = dot(a,vec3(.30,.55,.15));
	float relief_b = dot(b,vec3(.30,.55,.15));
	float weight = smoothstep(.18,.82,fract(region)+(relief_b-relief_a)*.85);
	return mix(a,b,weight);
}

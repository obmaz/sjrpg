uniform sampler2D surface_0 : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D surface_1 : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D surface_2 : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D surface_3 : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D surface_4 : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D surface_5 : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
float cave_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float cave_noise(vec2 p) {
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(cave_hash(i),cave_hash(i+vec2(1.0,0.0)),f.x),mix(cave_hash(i+vec2(0.0,1.0)),cave_hash(i+vec2(1.0)),f.x),f.y);
}
vec3 cave_sample(vec2 uv,int variant) {
	// 반사 반복으로 원본 가장자리의 작은 색차를 연결한다.
	uv=1.0-abs(fract(uv*.5)*2.0-1.0);
	uv=mix(vec2(.003),vec2(.997),uv);
	if (variant==0) { return texture(surface_0,uv).rgb; }
	if (variant==1) { return texture(surface_1,uv).rgb; }
	if (variant==2) { return texture(surface_2,uv).rgb; }
	if (variant==3) { return texture(surface_3,uv).rgb; }
	if (variant==4) { return texture(surface_4,uv).rgb; }
	return texture(surface_5,uv).rgb;
}
vec3 cave_surface(vec2 uv,vec2 region) {
	// 미러 반복의 축이 방 모서리와 겹쳐 거대한 V자를 만들지 않게 비대칭으로 옮긴다.
	vec2 warp=vec2(cave_noise(region/4.9+vec2(2.7,1.3)),cave_noise(region/5.3+vec2(-1.1,4.6)));
	uv=uv*.91+vec2(.271,.113)+(warp-.5)*.19;
	float selector=clamp(cave_noise(region/7.2)*1.91+.13,0.0,1.99)*3.0;
	int first=int(floor(selector)), next=(first+1)%6;
	vec3 a=cave_sample(uv,first), b=cave_sample(uv,next);
	float weight=smoothstep(.16,.84,fract(selector)+(dot(b-a,vec3(.3,.55,.15)))*.55);
	return mix(a,b,weight);
}

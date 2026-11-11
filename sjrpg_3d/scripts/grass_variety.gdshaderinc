// 열 가지 생성 원화를 미터 배율과 연속적인 서식지 분포로 섞는다.
// 레이어/회전이 바뀌는 2×2 픽셀에서 GLES 이방성 필터의 footprint가 달라지지 않게
// 명시적 미분 + 선형 밉맵 필터를 공유한다. 원본과 밉맵/압축 데이터는 보존한다.
uniform sampler2DArray grass_layers : source_color, filter_linear_mipmap, repeat_disable;
float grass_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float grass_noise(vec2 p) {
	vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(grass_hash(i),grass_hash(i+vec2(1,0)),f.x),mix(grass_hash(i+vec2(0,1)),grass_hash(i+vec2(1)),f.x),f.y);
}
vec2 grass_turn(vec2 p,float index) {
	if(index<.5) return p;
	if(index<1.5) return vec2(-p.y,p.x);
	if(index<2.5) return -p;
	return vec2(p.y,-p.x);
}
vec3 grass_tile(vec2 p,float layer,vec2 dx,vec2 dy) {
	vec2 margin=vec2(1.5)/vec2(textureSize(grass_layers,0).xy);
	vec2 uv=margin+fract(p)*(1.0-2.0*margin);
	return textureGrad(grass_layers,vec3(uv,layer),dx,dy).rgb;
}
vec3 grass_seamless(vec2 p,float layer,vec2 dx,vec2 dy) {
	// 네 겹의 분리 가능한 창은 합이 항상 1이다. 각 그림의 가장자리는
	// 가중치와 기울기가 모두 0이어서 원화 경계와 교차점이 드러나지 않는다.
	vec2 s=sin(fract(p)*3.14159265);
	vec2 w=s*s;
	vec3 a=mix(grass_tile(p+vec2(.5,0),layer,dx,dy),grass_tile(p,layer,dx,dy),w.x);
	vec3 b=mix(grass_tile(p+vec2(.5),layer,dx,dy),grass_tile(p+vec2(0,.5),layer,dx,dy),w.x);
	return mix(b,a,w.y);
}
vec3 grass_variant(vec2 p,float layer,vec2 dx,vec2 dy) {
	float turn=mod(layer,4.0);
	vec2 offset=vec2(.217+layer*.173,.39+layer*.311);
	return grass_seamless(grass_turn(p,turn)+offset,layer,grass_turn(dx,turn),grass_turn(dy,turn));
}
vec3 grass_surface(vec2 world,float habitat_bias) {
	float habitat=mod(grass_noise(world/11.5+vec2(31,7))*8.1+grass_noise(world/3.4+vec2(9,43))*2.4+habitat_bias,9.999);
	float first=floor(habitat),second=mod(first+1.0,10.0);
	vec2 p=world/2.56;
	vec2 dx=dFdx(p),dy=dFdy(p);
	vec3 x=grass_variant(p,first,dx,dy);
	vec3 y=grass_variant(p,second,dx,dy);
	return mix(x,y,smoothstep(.1,.9,fract(habitat)))*mix(.96,1.04,grass_noise(world/27.0));
}

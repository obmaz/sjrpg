// 열 가지 생성 원화를 미터 배율과 연속적인 서식지 분포로 섞는다.
uniform sampler2DArray grass_layers : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
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
	vec2 a=sin(fract(p)*3.14159265),b=sin(fract(p+.5)*3.14159265);
	float wa=a.x*a.x*a.y*a.y+.001,wb=b.x*b.x*b.y*b.y+.001;
	return (grass_tile(p,layer,dx,dy)*wa+grass_tile(p+.5,layer,dx,dy)*wb)/(wa+wb);
}
vec3 grass_surface(vec2 world,float habitat_bias) {
	float habitat=mod(grass_noise(world/11.5+vec2(31,7))*8.1+grass_noise(world/3.4+vec2(9,43))*2.4+habitat_bias,9.999);
	float first=floor(habitat),second=mod(first+1.0,10.0);
	vec2 p=world/2.56;
	vec2 dx=dFdx(p),dy=dFdy(p);
	vec3 x=grass_seamless(grass_turn(p,mod(first,4.0))+vec2(.217+first*.173,.39+first*.311),first,grass_turn(dx,mod(first,4.0)),grass_turn(dy,mod(first,4.0)));
	vec3 y=grass_seamless(grass_turn(p,mod(second,4.0))+vec2(.217+second*.173,.39+second*.311),second,grass_turn(dx,mod(second,4.0)),grass_turn(dy,mod(second,4.0)));
	return mix(x,y,smoothstep(.1,.9,fract(habitat)))*mix(.96,1.04,grass_noise(world/27.0));
}

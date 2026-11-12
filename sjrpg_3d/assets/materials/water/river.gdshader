shader_type spatial;
render_mode blend_mix, depth_prepass_alpha;
uniform sampler2DArray water_layers : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D shore_field : filter_linear, repeat_disable;
uniform vec2 field_origin;
uniform vec2 field_extent;
uniform float phase = 0.0;
varying vec2 ground_world;
// 세계 좌표의 물결 패밀리는 유지하고 흐름의 위상만 전진시킨다.
float water_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float water_noise(vec2 p) {
 vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(water_hash(i),water_hash(i+vec2(1,0)),f.x),mix(water_hash(i+vec2(0,1)),water_hash(i+vec2(1)),f.x),f.y);
}
vec3 water_tile(vec2 p,float layer) {
 vec2 uv=1.0-abs(mod(p,2.0)-1.0);
 return textureGrad(water_layers,vec3(uv,layer),dFdx(p),dFdy(p)).rgb;
}
vec3 water_surface(vec2 p,vec2 region) {
 float selection=mod(water_noise(region/18.0+vec2(13,57))*8.4+water_noise(region/6.0)*2.0,9.999);
 float a=floor(selection),b=mod(a+1.0,10.0);
 return mix(water_tile(p,a),water_tile(p+vec2(.37,.21),b),smoothstep(.12,.88,fract(selection)));
}
void vertex() { ground_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
 vec2 p = ground_world;
 vec2 moving = p-vec2(phase*0.62,phase*0.035);
 vec3 first = water_surface(moving/2.56,p);
 vec3 second = water_surface(p/3.71-vec2(phase*0.091,-phase*0.021),p);
 float d = (texture(shore_field,(p-field_origin)/field_extent).r*2.0-1.0)*2.0;
 float ribbons = sin(moving.y*13.0+sin(moving.x*2.2)*1.1);
 float chop = sin(moving.x*7.8+moving.y*4.2);
 float foam = pow(max(0.0,ribbons*chop),8.0)*0.19;
 float shoreline = (1.0-smoothstep(0.03,0.32,abs(d+sin(p.x*6.0-phase*2.2)*0.055)))*0.20;
 ALBEDO = mix(first,second,0.26)*vec3(0.68,0.86,0.90)+vec3(0.64,0.77,0.73)*(foam+shoreline);
 vec3 wave_normal = normalize(vec3(cos(moving.x*7.8+moving.y*4.2)*0.11,1.0,cos(moving.y*13.0+sin(moving.x*2.2))*0.14));
 NORMAL = normalize((VIEW_MATRIX*vec4(wave_normal,0.0)).xyz);
 ROUGHNESS = 0.29;
 METALLIC = 0.10;
 ALPHA = 1.0-smoothstep(-0.17,0.005,d+sin(p.x*19.0+p.y*12.0+phase*2.4)*0.024);
}

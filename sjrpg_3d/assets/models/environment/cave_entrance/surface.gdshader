shader_type spatial;
#include "res://assets/materials/terrain/cave_depth.gdshaderinc"
uniform sampler2D stone : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D earth : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 p;
varying vec3 n;
void vertex() { p=VERTEX; n=NORMAL; }
void fragment() {
 vec3 weights=pow(abs(normalize(n)),vec3(5.0));
 weights/=max(dot(weights,vec3(1.0)),0.0001);
 vec3 rock=texture(stone,p.zy/3.2).rgb*weights.x+texture(stone,p.xz/3.2).rgb*weights.y+texture(stone,p.xy/3.2).rgb*weights.z;
 float patches=smoothstep(-0.55,0.4,sin(p.x*1.7+sin(p.z*1.2))*cos(p.z*1.4));
 float turf=smoothstep(0.62,0.88,normalize(n).y)*smoothstep(2.7,4.2,p.y)*0.72;
 vec3 olive=texture(grass,p.xz/2.56).rgb*vec3(0.64,0.67,0.43);
 vec3 soil=texture(earth,p.xz/3.2).rgb*vec3(0.72,0.69,0.57);
 ALBEDO=mix(rock*vec3(0.72,0.75,0.72),mix(soil,olive,patches),turf);
 ALBEDO *= cave_depth_visibility(p);
 ROUGHNESS=0.98;
}

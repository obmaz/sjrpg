shader_type spatial;
#include "res://assets/materials/cave/variants.gdshaderinc"
uniform bool exposed=false;
varying vec3 cave_world;
varying vec3 cave_normal;
void vertex() {
	cave_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	cave_normal=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz);
}
void fragment() {
	vec3 color;
	if(exposed) {
		vec3 weights=pow(abs(cave_normal),vec3(5.0));weights/=max(.0001,weights.x+weights.y+weights.z);
		vec3 p=cave_world/2.6;
		color=cave_surface(p.zy,cave_world.xz)*weights.x+cave_surface(p.xz,cave_world.xz)*weights.y+cave_surface(p.xy,cave_world.xz)*weights.z;
	} else { color=cave_surface(UV,cave_world.xz); }
	ALBEDO=color*vec3(.84,.83,.79);
	ROUGHNESS=.98;
	SPECULAR=.16;
}

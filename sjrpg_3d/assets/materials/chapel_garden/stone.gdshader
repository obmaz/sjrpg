shader_type spatial;
render_mode cull_back;
uniform sampler2D atlas : source_color,filter_linear_mipmap_anisotropic,repeat_disable;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	vec2 tile=1.0-abs(fract(world.xz/1.3*.5)*2.0-1.0);
	vec2 uv=(vec2(1.0,0.0)+mix(vec2(.04),vec2(.96),tile))*.5;
	vec3 stone=texture(atlas,uv).rgb;
	ALBEDO=mix(vec3(dot(stone,vec3(.30,.55,.15))),stone,.45)*COLOR.rgb;
	ROUGHNESS=.91;
	SPECULAR=.15;
}

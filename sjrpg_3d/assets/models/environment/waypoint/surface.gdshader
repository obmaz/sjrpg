shader_type spatial;
uniform sampler2D albedo : source_color, filter_linear_mipmap_anisotropic;
uniform float phase = 0.0;
uniform float motion = 1.0;
uniform float strength = 0.0;
void fragment() {
	vec3 stone = texture(albedo,UV).rgb;
	vec2 p = UV-vec2(0.5);
	float r = length(p);
	float ring = 1.0-smoothstep(0.002,0.009,abs(r-0.402));
	ring += (1.0-smoothstep(0.002,0.007,abs(r-0.292)))*0.6;
	float angle = atan(p.y,p.x);
	float spokes = (1.0-smoothstep(0.012,0.025,abs(sin(angle*4.0))))*smoothstep(0.12,0.22,r)*(1.0-smoothstep(0.39,0.42,r));
	float pulse = 0.88+0.12*sin(phase*1.5)*motion;
	float grey = dot(stone,vec3(0.299,0.587,0.114));
	ALBEDO = mix(vec3(grey)*vec3(0.69,0.70,0.67),mix(vec3(grey),stone,0.12),strength)*mix(0.46,0.68,strength);
	EMISSION = vec3(0.25,0.35,0.32)*(ring+spokes)*strength*pulse*0.18;
	ROUGHNESS = 0.92;
}

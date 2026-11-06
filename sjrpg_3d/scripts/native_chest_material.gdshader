shader_type spatial;
// One shared surface per moving part. Vertex red selects actual iron geometry,
// keeping its PBR response separate from the reused family timber albedo.
uniform sampler2D timber : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 timber_tint : source_color = vec4(1.0);
uniform vec4 iron_tint : source_color = vec4(0.16, 0.17, 0.16, 1.0);
uniform float timber_scale = 0.65;
uniform float timber_roughness = 0.94;
uniform float iron_roughness = 0.94;
uniform float iron_metallic = 0.0;
void fragment() {
	float iron = step(0.5, COLOR.r);
	vec3 oak = texture(timber, UV * timber_scale).rgb * timber_tint.rgb;
	ALBEDO = mix(oak, iron_tint.rgb, iron);
	ROUGHNESS = mix(timber_roughness, iron_roughness, iron);
	METALLIC = iron * iron_metallic;
}

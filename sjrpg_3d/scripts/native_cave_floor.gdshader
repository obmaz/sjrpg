shader_type spatial;
render_mode cull_disabled;

// Reuse the exact compressed slab albedo and metre UVs. This is material colour
// separation only; real geometry normals and existing cave lights still shade it.
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 base_tone : source_color = vec4(0.48, 0.44, 0.36, 1.0);
uniform float detail_strength : hint_range(0.0, 1.0) = 0.68;

void fragment() {
	vec3 sampled = texture(albedo_texture, UV).rgb;
	float luminance = dot(sampled, vec3(0.2126, 0.7152, 0.0722));
	vec3 neutral_grain = mix(vec3(luminance), sampled, 0.30);
	ALBEDO = mix(base_tone.rgb, neutral_grain * vec3(1.08, 1.01, 0.86), detail_strength);
	ROUGHNESS = 0.97;
	SPECULAR = 0.16;
}

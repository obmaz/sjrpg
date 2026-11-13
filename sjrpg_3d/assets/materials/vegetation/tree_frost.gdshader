shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform bool cutout = false;
uniform float cutout_threshold = 0.42;

void fragment() {
	vec4 sample_color = texture(albedo_texture, UV);
	if (cutout && sample_color.a < cutout_threshold) {
		discard;
	}
	// Keep bark grain and leaf holes; use opaque frost instead of a transparent ice shell.
	float grain = dot(sample_color.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 frost = mix(vec3(0.20, 0.36, 0.46), vec3(0.73, 0.88, 0.94), grain * 0.8 + 0.2);
	ALBEDO = mix(sample_color.rgb, frost, 0.90);
	ROUGHNESS = 0.52;
	METALLIC = 0.08;
	EMISSION = vec3(0.01, 0.025, 0.035);
}

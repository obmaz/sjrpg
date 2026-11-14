shader_type canvas_item;
render_mode unshaded;

// Colour-band comparison on the native world texture; HUD is on a separate layer.
void fragment() {
	vec4 original = texture(TEXTURE, UV);
	float lightness = dot(original.rgb, vec3(.299, .587, .114));
	float band = floor(lightness * 6.0 + .5) / 6.0;
	vec3 color = original.rgb * mix(1.0, band / max(lightness, .045), .70);
	vec2 pixel = TEXTURE_PIXEL_SIZE;
	float dx = dot(texture(TEXTURE, UV + vec2(pixel.x, 0.0)).rgb - texture(TEXTURE, UV - vec2(pixel.x, 0.0)).rgb, vec3(.299, .587, .114));
	float dy = dot(texture(TEXTURE, UV + vec2(0.0, pixel.y)).rgb - texture(TEXTURE, UV - vec2(0.0, pixel.y)).rgb, vec3(.299, .587, .114));
	float edge = smoothstep(.10, .28, length(vec2(dx, dy)));
	COLOR = vec4(color * (1.0 - edge * .28), original.a);
}

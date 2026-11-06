shader_type canvas_item;
render_mode unshaded;

uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_strength : hint_range(0.0, 0.65) = 0.0;
varying vec4 inherited_modulate;

void vertex() {
	inherited_modulate = COLOR;
}

void fragment() {
	// Paint only the original frame silhouette. Ground shadows never use this material.
	float silhouette = texture(TEXTURE, UV).a;
	COLOR = vec4(flash_color.rgb * inherited_modulate.rgb,
		silhouette * flash_strength * inherited_modulate.a);
}

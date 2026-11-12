shader_type canvas_item;
render_mode unshaded;

uniform vec2 flow_offset = vec2(0.0);
varying vec4 art_tint;

void vertex() {
	art_tint = COLOR;
}

void fragment() {
	COLOR = texture(TEXTURE, UV + flow_offset) * art_tint;
}

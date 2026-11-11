shader_type spatial;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 entrance_rows[5];
uniform vec2 nave_rows[8];
void fragment() {
	vec2 corner = floor(UV*2.0);
	vec2 local = UV*2.0-corner;
	float at = clamp((local.y-.018)/.964,0.0,1.0);
	float source_y = local.y;
	if (corner.y < .5) {
		if (corner.x < .5) {
			for (int i=0;i<4;i++) {
				if (at >= entrance_rows[i].x && at <= entrance_rows[i+1].x) {
					float t=(at-entrance_rows[i].x)/max(.0001,entrance_rows[i+1].x-entrance_rows[i].x);
					source_y=mix(entrance_rows[i].y,entrance_rows[i+1].y,t);
				}
			}
		} else {
			for (int i=0;i<7;i++) {
				if (at >= nave_rows[i].x && at <= nave_rows[i+1].x) {
					float t=(at-nave_rows[i].x)/max(.0001,nave_rows[i+1].x-nave_rows[i].x);
					source_y=mix(nave_rows[i].y,nave_rows[i+1].y,t);
				}
			}
		}
	}
	ALBEDO=texture(atlas,(corner+vec2(local.x,source_y))*.5).rgb;
	ROUGHNESS=.96;
}

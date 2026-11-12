shader_type spatial;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 entrance_rows[5];
uniform vec2 nave_rows[8];
float lancet(vec2 p,float center,float half_width,float top,float spring,float bottom) {
	float x = abs(p.x-center)/half_width;
	float arch = mix(top,spring,clamp(x,0.0,1.0));
	return step(x,1.0)*step(arch,p.y)*step(p.y,bottom);
}
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
	vec2 source = vec2(local.x,source_y);
	vec3 color = texture(atlas,(corner+source)*.5).rgb;
	float window = 0.0;
	if (corner.x > .5 && corner.y < .5) {
		window = lancet(source,.50,.042,.12,.18,.35);
		window = max(window,lancet(source,.25,.095,.49,.62,.90));
		window = max(window,lancet(source,.75,.095,.49,.62,.90));
	} else if (corner.x < .5 && corner.y > .5) {
		window = max(lancet(source,.25,.095,.17,.31,.79),lancet(source,.75,.095,.17,.31,.79));
	} else if (corner.x < .5) {
		window = 1.0-smoothstep(.045,.075,length(source-vec2(.5,.18)));
	}
	// 어둡고 유색인 창유리만 반사 분포를 구분한다. 석재 음영을 법선으로 사용하지 않는다.
	float saturation = max(color.r,max(color.g,color.b))-min(color.r,min(color.g,color.b));
	float glass = window*smoothstep(.045,.11,saturation)*(1.0-smoothstep(.25,.40,dot(color,vec3(.30,.55,.15))));
	ALBEDO=color;
	ROUGHNESS=mix(.94,.36,glass);
	SPECULAR=mix(.16,.46,glass);
}

shader_type spatial;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
varying vec3 point;
varying vec3 direction;
vec2 mirror(vec2 uv) { return 1.0-abs(fract(uv*0.5)*2.0-1.0); }
vec3 tile(vec2 uv,vec2 cell) { return texture(atlas,(cell+mix(vec2(0.02),vec2(0.98),mirror(uv)))*0.5).rgb; }
void vertex() { point=VERTEX; direction=NORMAL; }
void fragment() {
	vec3 n=normalize(direction);
	vec3 w=pow(abs(n),vec3(8.0));
	w/=max(dot(w,vec3(1.0)),0.0001);
	vec2 cell=vec2(1.0,0.0);
	if (point.y<0.4) { cell=vec2(1.0); }
	if (abs(n.y)>0.65 || point.y>2.85) { cell=vec2(0.0,1.0); }
	vec3 stone=tile(point.zy/2.56,cell)*w.x+tile(point.xz/2.56,cell)*w.y+tile(point.xy/2.56,cell)*w.z;
	if (max(abs(point.x),abs(point.z))<0.43 && point.y>0.92 && point.y<2.78 && abs(n.y)<0.5) {
		bool side=abs(n.x)>abs(n.z);
		float h=side ? -point.z*sign(n.x) : point.x*sign(n.z);
		vec2 uv=clamp(vec2(h/0.76+0.5,1.0-(point.y-0.92)/1.86),vec2(0.0),vec2(1.0));
		stone=texture(atlas,mix(vec2(0.02),vec2(0.98),uv)*0.5).rgb;
	}
	ALBEDO=stone;
	ROUGHNESS=0.94;
}

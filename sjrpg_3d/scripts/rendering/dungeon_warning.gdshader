shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 ink : source_color = vec4(1.0,0.6,0.15,0.8);
void fragment() {
 float edge=min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y));
 float border=1.0-smoothstep(.015,.05,edge);
 float hatch=step(.76,fract((UV.x+UV.y)*7.0));
 ALBEDO=ink.rgb;
 ALPHA=(border*.70+.05+hatch*.07)*ink.a;
}

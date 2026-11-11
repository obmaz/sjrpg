shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform sampler2D fire_atlas : source_color, filter_linear_mipmap;
varying float frame_index;
void vertex() { frame_index=INSTANCE_CUSTOM.r*4.0; }
void fragment() {
 vec2 cell=vec2(mod(floor(frame_index),4.0),1.0);
 vec4 flame=texture(fire_atlas,(cell+mix(vec2(.025),vec2(.975),UV))/4.0);
 ALBEDO=flame.rgb;
 ALPHA=flame.a*COLOR.a;
}

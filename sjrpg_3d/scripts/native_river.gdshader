shader_type spatial;
render_mode blend_mix, depth_prepass_alpha;
uniform sampler2D water_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D shore_field : filter_linear, repeat_disable;
uniform vec2 field_origin;
uniform vec2 field_extent;
uniform float phase = 0.0;
varying vec2 ground_world;
void vertex() { ground_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
 vec2 p = ground_world;
 vec2 moving = p-vec2(phase*0.62,phase*0.035);
 vec3 first = texture(water_texture,moving/2.56).rgb;
 vec3 second = texture(water_texture,p/3.71-vec2(phase*0.091,-phase*0.021)).rgb;
 float d = (texture(shore_field,(p-field_origin)/field_extent).r*2.0-1.0)*2.0;
 float ribbons = sin(moving.y*13.0+sin(moving.x*2.2)*1.1);
 float chop = sin(moving.x*7.8+moving.y*4.2);
 float foam = pow(max(0.0,ribbons*chop),8.0)*0.19;
 float shoreline = (1.0-smoothstep(0.03,0.32,abs(d+sin(p.x*6.0-phase*2.2)*0.055)))*0.20;
 ALBEDO = mix(first,second,0.26)*vec3(0.68,0.86,0.90)+vec3(0.64,0.77,0.73)*(foam+shoreline);
 vec3 wave_normal = normalize(vec3(cos(moving.x*7.8+moving.y*4.2)*0.11,1.0,cos(moving.y*13.0+sin(moving.x*2.2))*0.14));
 NORMAL = normalize((VIEW_MATRIX*vec4(wave_normal,0.0)).xyz);
 ROUGHNESS = 0.29;
 METALLIC = 0.10;
 ALPHA = 1.0-smoothstep(-0.17,0.005,d+sin(p.x*19.0+p.y*12.0+phase*2.4)*0.024);
}

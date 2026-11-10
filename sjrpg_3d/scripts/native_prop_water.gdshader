shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
uniform float phase = 0.0;
uniform float motion = 1.0;
varying vec3 local_point;
void vertex() {
 local_point = VERTEX * 0.5;
 VERTEX.y += motion * 0.004 * sin(local_point.x * 21.0 + local_point.z * 17.0 - phase * 2.5);
}
void fragment() {
 float r = length(local_point.xz);
 float wave = sin(r * 46.0 - phase * 3.0) * sin(local_point.x * 18.0 + local_point.z * 24.0 + phase * 1.7);
 float splash = exp(-length(local_point.xz - vec2(0.87, 0.0)) * 22.0) + exp(-length(local_point.xz - vec2(0.0, 0.87)) * 22.0);
 vec3 base = mix(vec3(0.045, 0.19, 0.20), vec3(0.10, 0.36, 0.38), 0.5 + wave * 0.18 * motion);
 ALBEDO = base + vec3(0.12, 0.18, 0.18) * splash * (0.6 + 0.12 * motion * sin(phase * 3.4));
 ROUGHNESS = 0.22;
 METALLIC = 0.06;
 ALPHA = 0.76;
}

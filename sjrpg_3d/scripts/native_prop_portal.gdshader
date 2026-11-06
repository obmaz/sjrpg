shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float phase = 0.0;
uniform float motion = 1.0;
uniform float strength = 0.8;
void fragment() {
 vec2 q = UV * 2.0 - 1.0;
 float radius = length(q);
 float angle = atan(q.y, q.x + 0.0001);
 float current = angle * 3.0 + radius * 13.0 - phase * 1.6 * motion;
 float ribbon = pow(0.5 + 0.5 * sin(current), 10.0);
 float filament = pow(0.5 + 0.5 * sin(current * 1.7 + radius * 5.0), 24.0);
 float edge = smoothstep(0.58, 1.0, radius);
 vec3 base = vec3(0.025, 0.11, 0.16);
 vec3 light = vec3(0.19, 0.60, 0.65) * ribbon + vec3(0.24, 0.37, 0.39) * filament;
 ALBEDO = base + light * strength;
 ALPHA = 0.43 + 0.22 * edge + 0.14 * ribbon * strength;
}

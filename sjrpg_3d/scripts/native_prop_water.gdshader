shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
uniform float phase = 0.0;
uniform float motion = 1.0;
uniform sampler2D legacy_water : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 water_region = vec4(0.26171875,0.392578125,0.087890625,0.05859375);
varying vec3 local_point;
void vertex() {
 local_point = VERTEX * 0.5;
 VERTEX.y += motion * 0.004 * sin(local_point.x * 21.0 + local_point.z * 17.0 - phase * 2.5);
}
void fragment() {
 float r = length(local_point.xz);
 float wave = sin(r * 46.0 - phase * 3.0) * sin(local_point.x * 18.0 + local_point.z * 24.0 + phase * 1.7);
 float splash = exp(-length(local_point.xz - vec2(0.87, 0.0)) * 22.0) + exp(-length(local_point.xz - vec2(0.0, 0.87)) * 22.0);
 // 기존 2D 분수의 물 부분만 UV로 읽는다. 새 이미지를 그리거나 원본을 변형하지 않는다.
 vec2 a = 1.0-abs(fract((local_point.xz/0.72+phase*motion*vec2(0.014,-0.009))*0.5)*2.0-1.0);
 vec2 b = 1.0-abs(fract((local_point.zx/1.05+phase*motion*vec2(-0.008,0.012))*0.5)*2.0-1.0);
 vec2 origin=water_region.xy;
 vec2 size=water_region.zw;
 vec3 base=mix(texture(legacy_water,origin+a*size).rgb,texture(legacy_water,origin+b*size).rgb,0.38);
 float da=length(local_point.xz-vec2(0.87,0.0));
 float db=length(local_point.xz-vec2(0.0,0.87));
 float rings=pow(0.5+0.5*sin(da*72.0-phase*5.0*motion),8.0)*exp(-da*4.0);
 rings+=pow(0.5+0.5*sin(db*72.0-phase*5.0*motion),8.0)*exp(-db*4.0);
 ALBEDO = base*(0.82+wave*0.07*motion)+vec3(0.30,0.42,0.40)*rings+vec3(0.12,0.18,0.18)*splash*0.5;
 float jet=smoothstep(0.36,0.42,local_point.y)*(1.0-smoothstep(1.40,1.48,local_point.y));
 float flow=0.5+0.5*sin(local_point.y*38.0-phase*9.0*motion);
 ALBEDO=mix(ALBEDO,vec3(0.44,0.68,0.72)+flow*vec3(0.20),jet);
 EMISSION=vec3(0.16,0.23,0.25)*jet;
 ROUGHNESS = 0.22;
 METALLIC = 0.06;
 ALPHA = mix(0.76,0.90,jet);
}

shader_type spatial;
render_mode cull_back;
uniform sampler2D distance_field : filter_linear, repeat_disable;
uniform vec4 town_bounds;
uniform sampler2D woodland_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
#include "res://assets/materials/grass/variety.gdshaderinc"

uniform sampler2D shore_field : filter_linear, repeat_disable;
uniform sampler2D rock_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D earth_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 field_origin;
uniform vec2 field_extent;
uniform sampler2D bank_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D site_rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform mat4 world_to_cave;
uniform vec2 cave_trail[10];
uniform vec4 cave_trail_bounds;
uniform vec4 chapel_beds[6];
uniform vec4 chapel_path;
uniform vec4 chapel_bounds;
uniform vec4 courtyard_bounds[6];
uniform vec4 courtyard_paths[6];
uniform vec4 courtyard_beds[18];
uniform vec4 courtyard_aprons[6];
uniform float courtyard_themes[6];
varying highp vec2 ground_world;
varying float ground_height;

float hash_ground(vec2 p) {
	vec2 q = fract(p * vec2(0.1031, 0.1030));
	q += dot(q, q.yx + 33.33);
	return fract((q.x + q.y) * q.x);
}
float ground_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_ground(i), hash_ground(i + vec2(1.0, 0.0)), f.x),
		mix(hash_ground(i + vec2(0.0, 1.0)), hash_ground(i + vec2(1.0)), f.x), f.y);
}
// 원화의 마주 보는 가장자리가 완벽하지 않아도 반사 반복은 색의 연속성을 지킨다.
vec2 mirrored(vec2 uv) {
	return 1.0 - abs(fract(uv * 0.5) * 2.0 - 1.0);
}
vec3 woodland(vec2 world,vec2 cell,float metres) {
	vec2 uv = mirrored(world/metres);
	return texture(woodland_atlas,(cell+mix(vec2(.025),vec2(.975),uv))*.5).rgb;
}
// 판석 사이 흙은 직사각 매트가 아니라 둥근 마모 자국으로 이어진다.
float path_wear(vec2 world, vec4 bounds, float detail) {
	vec2 half_size = (bounds.zw-bounds.xy)*.5;
	vec2 offset = abs(world-(bounds.xy+bounds.zw)*.5);
	float radius = min(half_size.x,half_size.y);
	float segment = abs(half_size.x-half_size.y);
	vec2 closest = half_size.x > half_size.y ? vec2(max(0.0,offset.x-segment),offset.y) : vec2(offset.x,max(0.0,offset.y-segment));
	return 1.0-smoothstep(-.15,.30,length(closest)-radius+(detail-.5)*.16);
}

#include "res://assets/materials/paving/surface.gdshaderinc"
void vertex() {
	ground_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	ground_height = VERTEX.y;
}
void fragment() {
	vec2 field_uv = (ground_world - field_origin) / field_extent;
	vec4 data = texture(distance_field, field_uv);
	vec3 encoded = data.rgb;
	float d = (encoded.r * 2.0 - 1.0) * 2.0;
	if (any(lessThan(field_uv, vec2(0.0))) || any(greaterThan(field_uv, vec2(1.0)))) {
		d = 2.0;
	}
	vec2 uv = ground_world / 2.56;
	vec3 grass = grass_surface(ground_world,0.0);
	vec2 town_edge = min(ground_world-town_bounds.xy,town_bounds.zw-ground_world);
	float settled = smoothstep(-1.5,1.0,min(town_edge.x,town_edge.y));
	vec3 woodland_grass = woodland(ground_world,vec2(1.0),2.1);
	grass = mix(grass,woodland_grass,mix(.48,.72,ground_noise(ground_world/4.0))*settled);
	vec3 color = grass;
	float paving_relief = 0.0;
	if (d < 1.5) {
		vec2 town_edge = min(ground_world-town_bounds.xy,town_bounds.zw-ground_world);
		float town = smoothstep(-0.8,1.2,min(town_edge.x,town_edge.y));
		vec3 paving = paving_surface(ground_world,town);
		paving = mix(paving,woodland(ground_world,vec2(0.0),1.2),town*.95);
		float irregular = (ground_noise(ground_world*1.65)-.5)*mix(1.55,.48,town);
		float edge_d = d+irregular;
		float feather = mix(.85,.32,town);
		float cover = 1.0-smoothstep(-feather,feather,edge_d);
		// 바깥길은 빠진 돌·흙 패치와 길 안까지 들어온 풀로 중심선의 반복도 깬다.
		float encroach = smoothstep(.57,.77,ground_noise(ground_world/1.45+vec2(5.0)));
		encroach *= mix(.72,.13,town)*smoothstep(-1.7,-.10,d+ground_noise(ground_world*2.0)*.6);
		vec3 soil = texture(earth_texture,ground_world/2.56).rgb;
		paving = mix(paving,soil,encroach*.44);
		paving = mix(paving,grass,encroach*.78);
		color = mix(grass,paving,cover);
		// 낮은 표면 요철만 광원에 반응한다. 보행 지형의 매크로 높이는 기존 공유 메시다.
		paving_relief = smoothstep(.16,.55,dot(paving,vec3(.30,.55,.15)))*.018*cover;
	}

	// 막다른 포장길은 흙길로 좁아지며 풀 속으로 이어진다.
	float terminal = data.a;
	if (all(greaterThanEqual(field_uv, vec2(0.0))) && all(lessThanEqual(field_uv, vec2(1.0)))) {
		vec3 soil = texture(earth_texture, uv).rgb;
		float speckle = ground_noise(ground_world * 3.1);
		color = mix(color, soil, smoothstep(0.05, 0.88, terminal + (speckle - 0.5) * 0.18));
		float bank_d = (texture(shore_field, field_uv).r * 2.0 - 1.0) * 2.0;
		float broken = bank_d + (ground_noise(ground_world * 1.9) - 0.5) * 0.48;
		vec3 stones = texture(rock_texture, uv * 1.24).rgb;
		vec3 bank = mix(stones * 0.67, mix(stones, soil, 0.63), smoothstep(-0.05, 0.45, broken));
		color = mix(color, bank, 1.0 - smoothstep(0.12, 1.18, broken));
	}
	if (ground_height < -0.015) {
		vec2 local_uv = mix(vec2(0.018),vec2(0.982),mirrored(ground_world/2.0));
		vec3 wet = texture(bank_atlas,local_uv*0.5).rgb;
		vec3 roots = texture(bank_atlas,(vec2(1.0,0.0)+local_uv)*0.5).rgb;
		vec3 turf = texture(bank_atlas,(vec2(0.0,1.0)+local_uv)*0.5).rgb;
		vec3 riverbed = texture(bank_atlas,(vec2(1.0)+local_uv)*0.5).rgb;
		float water_distance = (texture(shore_field,field_uv).r*2.0-1.0)*2.0;
		vec3 slopes = mix(turf,mix(roots,wet,ground_noise(ground_world*1.3)),smoothstep(0.0,0.9,-ground_height));
		slopes = mix(slopes,riverbed,smoothstep(1.35,1.80,-ground_height));
		vec3 descent = texture(earth_texture,uv).rgb*vec3(0.62,0.60,0.54);
		color = mix(color,mix(slopes,descent,smoothstep(1.5,1.9,water_distance)),smoothstep(0.01,0.14,-ground_height));
	}
	vec3 site = (world_to_cave*vec4(ground_world.x,ground_height,ground_world.y,1.0)).xyz;
	float zone = 1.0-smoothstep(0.82,1.12,length(vec2(site.x/16.0,(site.z-2.0)/24.0)));
	if (zone > 0.0) {
		vec3 shale = texture(site_rock,ground_world/3.2).rgb*vec3(0.80,0.81,0.76);
		vec3 gravel = texture(bank_atlas,(vec2(1.0)+mix(vec2(0.018),vec2(0.982),mirrored(ground_world/2.0)))*0.5).rgb;
		float path = 1.0-smoothstep(2.0,4.0,abs(site.x));
		vec3 ravine = mix(shale,gravel*vec3(0.78,0.76,0.68),path*0.74);
		ravine = mix(ravine,grass,ground_noise(ground_world/1.7)*0.30*smoothstep(-1.0,0.6,ground_height));
		color = mix(color,ravine,zone);
	}
	// 필드 갈림길에서 웨이포인트와 바위 골짜기로 이어지는 닳은 흙·잔디 길.
	if (all(greaterThan(site.xz,cave_trail_bounds.xy)) && all(lessThan(site.xz,cave_trail_bounds.zw))) {
		float trail_d = 100.0;
		for (int i=0; i<9; i++) {
			vec2 a = cave_trail[i];
			vec2 segment = cave_trail[i+1]-a;
			float t = clamp(dot(site.xz-a,segment)/max(dot(segment,segment),0.001),0.0,1.0);
			trail_d = min(trail_d,length(site.xz-a-segment*t));
		}
		float wear_d = trail_d+(ground_noise(ground_world*2.4)-0.5)*0.42;
		float verge = 1.0-smoothstep(2.0,3.0,wear_d);
		color = mix(color,grass*vec3(0.88,0.84,0.69),verge*0.50);
		float worn = 1.0-smoothstep(1.25,2.0,wear_d);
		vec3 soil = texture(earth_texture,ground_world/2.56).rgb*vec3(1.30,1.12,0.86);
		vec3 grit = texture(bank_atlas,(vec2(1.0)+mix(vec2(0.018),vec2(0.982),mirrored(ground_world/2.0)))*0.5).rgb;
		color = mix(color,mix(soil,grit*0.97,0.28+zone*0.25),worn);
	}
	// 화단·길은 같은 미터 배치도를 따른다. 돌 틈의 흙이 화단까지 이어진다.
	if (all(greaterThan(ground_world,chapel_bounds.xy)) && all(lessThan(ground_world,chapel_bounds.zw))) {
		float bed_cover = 0.0;
		float broken_edge = (ground_noise(ground_world*4.0)-.5)*.30;
		for (int i=0; i<6; i++) {
			float radius = length((ground_world-chapel_beds[i].xy)/chapel_beds[i].zw);
			bed_cover = max(bed_cover,1.0-smoothstep(.70,1.3,radius+broken_edge));
		}
		float path_cover = path_wear(ground_world,chapel_path,ground_noise(ground_world*3.8));
		vec3 soil = woodland(ground_world,vec2(0.0,1.0),2.1);
		vec3 garden_floor = mix(soil,grass,0.65+ground_noise(ground_world*2.0)*.22);
		color = mix(color,garden_floor,bed_cover*.96);
		color = mix(color,mix(soil,grass,.40),path_cover*.78);
		paving_relief *= 1.0-max(bed_cover,path_cover);
	}
	// 건물 구역 안에서만 화단·작업 마당을 계산하며 먼 필드에는 적용하지 않는다.
	if (all(greaterThan(ground_world,town_bounds.xy)) && all(lessThan(ground_world,town_bounds.zw))) {
		for (int i=0; i<6; i++) {
			vec4 bounds = courtyard_bounds[i];
			if (all(greaterThan(ground_world,bounds.xy)) && all(lessThan(ground_world,bounds.zw))) {
				float bed = 0.0;
				float noise = ground_noise(ground_world*3.8);
				for (int j=0; j<3; j++) {
					vec4 ellipse = courtyard_beds[i*3+j];
					float radius = length((ground_world-ellipse.xy)/ellipse.zw);
					bed = max(bed,1.0-smoothstep(.70,1.25,radius+(noise-.5)*.27));
				}
				vec4 path = courtyard_paths[i];
				float path_cover = path_wear(ground_world,path,noise);
				vec4 apron = courtyard_aprons[i];
				float apron_radius = length((ground_world-apron.xy)/apron.zw);
				float worn = (1.0-smoothstep(.68,1.25,apron_radius+(noise-.5)*.18))*courtyard_themes[i];
				vec3 soil = woodland(ground_world,vec2(0.0,1.0),2.1);
				vec3 gravel = texture(rock_texture,ground_world/2.56).rgb;
				vec3 working = mix(soil,gravel,.46)*vec3(.77,.77,.72);
				color = mix(color,working,worn*.80);
				color = mix(color,mix(soil,grass,.78),bed*.95);
				color = mix(color,mix(soil,grass,mix(.27,.08,courtyard_themes[i])),path_cover*.78);
				paving_relief *= 1.0-max(bed,path_cover);
			}
		}
	}
	vec3 dx = dFdx(vec3(ground_world.x,paving_relief,ground_world.y));
	vec3 dy = dFdy(vec3(ground_world.x,paving_relief,ground_world.y));
	vec3 detail = normalize(cross(dx,dy));
	if (detail.y < 0.0) { detail = -detail; }
	NORMAL = normalize(NORMAL+(VIEW_MATRIX*vec4(detail-vec3(0.0,1.0,0.0),0.0)).xyz);
	ALBEDO = color;
	ROUGHNESS = 0.98;
}

shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;

uniform sampler2D density_noise : filter_linear_mipmap, repeat_enable;
uniform float fire_time = 0.0;
uniform int density_steps = 10;
varying vec3 volume_position;
varying vec3 volume_ray;
varying float fire_seed;
varying float ember;
varying float ember_life;

void vertex() {
	// The simulation clock also stops the internal flow and embers on pause.
	fire_seed = INSTANCE_CUSTOM.r;
	ember = UV2.y;
	ember_life = fract(fire_time * 0.42 + fire_seed + UV2.x);
	volume_position = VERTEX;
	volume_ray = normalize((inverse(MODELVIEW_MATRIX) * vec4(0.0, 0.0, -1.0, 0.0)).xyz);
	if (ember > 0.5) {
		VERTEX.x += sin(fire_seed * 17.0 + ember_life * 5.0) * ember_life * 0.28;
		VERTEX.z += cos(fire_seed * 13.0 + ember_life * 4.0) * ember_life * 0.24;
		VERTEX.y += ember_life * 1.15;
	}
}

void fragment() {
	if (ember > 0.5) {
		ALBEDO = mix(vec3(1.0, 0.64, 0.18), vec3(0.8, 0.10, 0.015), ember_life);
		ALPHA = (1.0 - ember_life) * 0.52 * COLOR.a;
	} else {
		// A soft 3D density field fills the shared proxy. Mesh faces never supply flame colour.
		vec3 ray = normalize(volume_ray);
		vec3 safe_ray = (step(vec3(0.0), ray) * 2.0 - 1.0) * max(abs(ray), vec3(0.0001));
		vec3 edge0 = (vec3(-0.5, 0.0, -0.5) - volume_position) / safe_ray;
		vec3 edge1 = (vec3(0.5, 1.3, 0.5) - volume_position) / safe_ray;
		vec3 far_edge = max(edge0, edge1);
		float ray_length = max(0.0, min(far_edge.x, min(far_edge.y, far_edge.z)));
		float closest = clamp(-dot(volume_position.xz, ray.xz) / max(dot(ray.xz, ray.xz), 0.0001), 0.0, ray_length);
		if (length(volume_position.xz + ray.xz * closest) > 0.47) {
			discard;
		}
		int steps = clamp(density_steps, 6, 10);
		float stride = ray_length / float(steps);
		vec4 fire = vec4(0.0);
		for (int i = 0; i < 10; i++) {
			if (i >= steps || fire.a > 0.96) {
				break;
			}
			vec3 p = volume_position + ray * (float(i) + 0.5) * stride;
			float h = p.y / 1.22;
			float support = max(max(0.0, 0.27 * (1.0 - h)) * 1.53,
				max(0.0, 0.14 * (1.0 - h / 0.73)) * 1.65 + 0.19) + h * h * 0.23 + 0.025;
			if (length(p.xz) > support) {
				continue;
			}
			vec2 flow0 = p.xy * vec2(2.1, 1.7) + vec2(fire_seed * 5.3, -fire_time * 0.93);
			vec2 flow1 = p.zy * vec2(2.7, 2.4) + vec2(fire_seed * 8.1 + 0.27, -fire_time * 1.24);
			float billow = texture(density_noise, flow0).r * 0.58 + texture(density_noise, flow1).r * 0.42;
			vec2 bend = vec2(sin(h * 5.2 - fire_time * 2.2 + fire_seed * 9.0), cos(h * 4.1 - fire_time * 1.6 + fire_seed * 8.0));
			bend *= h * h * 0.16;
			float radius = max(0.0, 0.27 * (1.0 - h)) * (0.58 + billow * 0.95);
			float main = radius - length((p.xz - bend) * vec2(1.0, 1.15));
			float fork_radius = max(0.0, 0.14 * (1.0 - h / 0.73)) * (0.65 + billow);
			vec2 fork_bend = vec2(-0.17, 0.08) * smoothstep(0.0, 0.3, h);
			fork_bend += vec2(sin(fire_time * 1.7 + h * 9.0), cos(fire_time * 1.3 + h * 6.0)) * h * 0.055;
			float fork = fork_radius - length(p.xz - bend - fork_bend);
			float shape = smoothstep(-0.025, 0.11, max(main, fork));
			float pockets = smoothstep(0.25, 0.68, billow + (1.0 - h) * 0.10);
			float density = shape * pockets * smoothstep(0.0, 0.10, p.y) * (1.0 - smoothstep(0.75, 1.22, p.y));
			float heat = clamp(density * 0.76 + (1.0 - h) * 0.27, 0.0, 1.0);
			vec3 color = mix(vec3(0.70, 0.018, 0.002), vec3(1.0, 0.20, 0.008), smoothstep(0.12, 0.65, heat));
			color = mix(color, vec3(1.25, 0.98, 0.48), smoothstep(0.68, 0.99, heat));
			float alpha = clamp(density * stride * 4.2, 0.0, 0.80);
			fire.rgb += (1.0 - fire.a) * alpha * color;
			fire.a += (1.0 - fire.a) * alpha;
		}
		ALBEDO = fire.rgb / max(fire.a, 0.001);
		ALPHA = fire.a * COLOR.a;
	}
}

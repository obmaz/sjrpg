shader_type canvas_item;
render_mode unshaded;

#include "res://assets/sprites/shaders/world_occlusion.gdshaderinc"
#include "res://assets/sprites/shaders/world_daylight.gdshaderinc"

uniform float daylight_amount = 0.0;
uniform vec2 opening_a;
uniform vec2 opening_b;

uniform vec4 atlas_region;
uniform float phase = 0.0;
uniform bool portal = false;
// Measured UV regions in the isolated source cell, independent of atlas packing.
uniform vec2 basin_center = vec2(0.495, 0.46);
uniform vec2 basin_radius = vec2(0.28, 0.19);
uniform vec4 jet_left = vec4(0.421, 0.224, 0.354, 0.430);
uniform vec4 jet_right = vec4(0.567, 0.224, 0.633, 0.430);
uniform vec2 portal_center = vec2(0.5, 0.5);
uniform vec2 portal_radius = vec2(0.15, 0.23);
varying vec4 art_tint;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	art_tint = COLOR;
}

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 d = b - a;
	return length(p - a - clamp(dot(p - a, d) / dot(d, d), 0.0, 1.0) * d);
}

void fragment() {
	vec2 p = (UV - atlas_region.xy) / atlas_region.zw;
	vec4 original = texture(TEXTURE, UV);
	// Only turquoise pixels are fluid: stone mortar, silhouettes and measured edges stay still.
	float water = smoothstep(0.045, 0.14, original.g - original.r) * smoothstep(0.04, 0.13, original.b - original.r);
	vec2 shift = vec2(0.0);
	float glow = 1.0;
	if (portal) {
		vec2 q = p - portal_center;
		float r = length(q / max(portal_radius, vec2(0.001)));
		float a = atan(q.y, q.x + 0.0001);
		// Advect the existing painted spiral; never rotate the gatehouse or its opening.
		shift = vec2(-q.y, q.x) * sin(phase * 1.8 + r * 6.0) * 0.06;
		shift += vec2(sin(phase * 2.1 + p.y * 30.0), cos(phase * 1.6 + p.x * 24.0)) * 0.005;
		glow += 0.16 * sin(a * 3.0 - r * 9.0 + phase * 3.8);
	} else {
		vec2 q = (p - basin_center) / max(basin_radius, vec2(0.001));
		water *= 1.0 - smoothstep(0.92, 1.08, length(q));
		shift = vec2(sin(p.y * 85.0 - phase * 5.5), cos(p.x * 65.0 + phase * 4.0)) * 0.005;
		glow += 0.12 * sin(length(q) * 28.0 - phase * 5.0);
		float jets = min(segment_distance(p, jet_left.xy, jet_left.zw), segment_distance(p, jet_right.xy, jet_right.zw));
		float spray = (1.0 - smoothstep(0.009, 0.025, jets)) * smoothstep(0.45, 0.85, original.r);
		water = max(water, spray);
		glow += spray * 0.22 * sin(p.y * 180.0 - phase * 14.0);
	}
	vec2 sample_uv = UV + shift * atlas_region.zw * water;
	vec4 flowing = texture(TEXTURE, clamp(sample_uv, atlas_region.xy, atlas_region.xy + atlas_region.zw));
	// Reject samples that cross from the water into neutral stone or transparent space.
	float blue_sample = smoothstep(0.02, 0.09, flowing.g - flowing.r);
	float sample_weight = water * blue_sample;
	vec4 ink = mix(original, flowing, sample_weight);
	ink.rgb *= mix(1.0, glow, water);
	// The same daylight reaches the real stone; the animated fluid keeps its glow.
	ink.rgb *= mix(vec3(1.0), world_daylight(world_position, opening_a, opening_b), daylight_amount * (1.0 - water));
	ink.a = original.a;
	COLOR = uncover_hero(ink * art_tint);
}

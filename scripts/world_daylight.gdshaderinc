// A shared world-space model for authored albedo, not a screen tint or a light node.
// Soft union keeps overlapping openings below the same warm daylight maximum.
float world_daylight_opening(vec2 p, vec2 center, vec2 radius) {
	float r = clamp(length((p - center) / radius), 0.0, 1.0);
	return 1.0 - smoothstep(0.0, 1.0, r * 0.5 + r * r * 0.5);
}

vec3 world_daylight(vec2 p, vec2 opening_a, vec2 opening_b) {
	float a = world_daylight_opening(p, opening_a, vec2(425.0, 246.5));
	// The expanded town is an open clearing; do not leave its service courtyard in deep forest shade.
	float b = world_daylight_opening(p, opening_b, vec2(1100.0, 638.0));
	float sun = 1.0 - (1.0 - a) * (1.0 - b);
	return vec3(0.58, 0.66, 0.72) + vec3(0.58, 0.44, 0.27) * sun;
}

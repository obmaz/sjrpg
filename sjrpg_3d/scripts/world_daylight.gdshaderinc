// A shared world-space model for authored albedo, not a screen tint or a light node.
// Soft union keeps overlapping openings below the same warm daylight maximum.
uniform vec4 contact_light_a = vec4(0.0);
uniform vec4 contact_light_b = vec4(0.0);
uniform vec3 contact_color_a = vec3(0.0);
uniform vec3 contact_color_b = vec3(0.0);

#ifdef WORLD_CONTACT_LIGHTS
vec3 world_contact_light(vec2 p, vec4 light, vec3 tint) {
	if (light.w <= 0.0) {
		return vec3(0.0);
	}
	vec2 radius = vec2(light.z, light.z * 0.577350269);
	float falloff = max(0.0, 1.0 - length((p - light.xy) / radius));
	return tint * light.w * falloff * falloff;
}
#endif

float world_daylight_opening(vec2 p, vec2 center, vec2 radius) {
	float r = clamp(length((p - center) / radius), 0.0, 1.0);
	return 1.0 - smoothstep(0.0, 1.0, r * 0.5 + r * r * 0.5);
}

// The higher forest fill preserves outside readability; reducing direct light
// by the same amount keeps fully sunlit town stone at its existing exposure.
const vec3 FOREST_AMBIENT = vec3(0.70, 0.78, 0.84);
const vec3 CLEARING_DIRECT = vec3(0.46, 0.32, 0.15);

vec3 world_daylight(vec2 p, vec2 opening_a, vec2 opening_b) {
	float a = world_daylight_opening(p, opening_a, vec2(425.0, 246.5));
	// The expanded town is an open clearing; do not leave its service courtyard in deep forest shade.
	float b = world_daylight_opening(p, opening_b, vec2(1100.0, 638.0));
	float sun = 1.0 - (1.0 - a) * (1.0 - b);
	vec3 illumination = FOREST_AMBIENT + CLEARING_DIRECT * sun;
#ifdef WORLD_CONTACT_LIGHTS
	if (contact_light_a.w > 0.0 || contact_light_b.w > 0.0) {
		illumination += min(vec3(0.55), world_contact_light(p, contact_light_a, contact_color_a) + world_contact_light(p, contact_light_b, contact_color_b));
	}
#endif
	return illumination;
}

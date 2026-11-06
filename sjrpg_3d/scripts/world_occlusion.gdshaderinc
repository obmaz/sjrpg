global uniform vec2 hero_world_position;
global uniform bool hero_above;
instance uniform float sort_y = 0.0;
varying vec2 world_position;

vec4 uncover_hero(vec4 ink) {
	if (!hero_above && sort_y > hero_world_position.y + 4.0) {
		vec2 delta = (world_position - hero_world_position - vec2(0.0, -42.0)) / vec2(38.0, 58.0);
		float covered = 1.0 - smoothstep(0.75, 1.0, length(delta));
		ink.a *= mix(1.0, 0.22, covered);
	}
	return ink;
}

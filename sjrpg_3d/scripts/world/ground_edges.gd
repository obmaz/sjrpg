class_name GroundEdges
extends RefCounted
## Blend authored terrain through masks derived from actual road outlines/tree feet.
## These masks contain geometry coverage, never replacement material art or shadows.

const DISTANCE_RANGE := 64.0
const EDGE_MASK_LIMIT := 128
const ROOT_MASK_LIMIT := 512
const CACHE_LIMIT := 32
const SHADER_CODE := """
shader_type canvas_item;
render_mode unshaded;
#include "res://assets/sprites/shaders/world_daylight.gdshaderinc"
uniform float amount = 1.0;
uniform vec2 opening_a;
uniform vec2 opening_b;
uniform bool edge_enabled = false;
uniform bool edge_paving = false;
uniform sampler2D edge_distance : filter_linear, repeat_disable;
uniform sampler2D edge_soil : filter_linear, repeat_enable;
uniform vec2 edge_origin;
uniform vec2 edge_extent = vec2(1.0);
uniform float edge_span = 24.0;
uniform bool root_enabled = false;
uniform sampler2D root_mask : filter_linear, repeat_disable;
uniform vec2 root_origin;
uniform vec2 root_extent = vec2(1.0);
uniform vec4 root_inverse_basis;
uniform vec2 root_inverse_origin;
varying vec2 ground_world;
varying vec2 ground_local;
void vertex() {
	ground_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	ground_local = VERTEX;
}
float hash_edge(vec2 p) {
	vec2 q = fract(p * vec2(0.1031, 0.1030));
	q += dot(q, q.yx + 33.33);
	return fract((q.x + q.y) * q.x);
}
float edge_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_edge(i), hash_edge(i + vec2(1.0, 0.0)), f.x),
		mix(hash_edge(i + vec2(0.0, 1.0)), hash_edge(i + vec2(1.0)), f.x), f.y);
}
void fragment() {
	if (edge_enabled) {
		vec2 mask_uv = (ground_local - edge_origin) / edge_extent;
		float d = (texture(edge_distance, mask_uv).r * 2.0 - 1.0) * 64.0;
		if (d < 60.0) {
			float irregular = edge_noise(ground_local / 42.0);
			float start = 1.5 + 5.0 * irregular;
			float width = edge_span * (0.65 + 0.9 * irregular);
			COLOR.a *= smoothstep(start, start + width, d);
			if (edge_paving) {
				vec3 soil = texture(edge_soil, ground_local / 360.0).rgb;
				COLOR.rgb = mix(soil, COLOR.rgb, smoothstep(start + 4.0, start + width * 1.2, d));
			}
		}
	}
	if (root_enabled) {
		float roots = texture(root_mask, (ground_world - root_origin) / root_extent).r;
		if (roots > 0.005) {
			vec2 root_ground = vec2(dot(root_inverse_basis.xy, ground_world), dot(root_inverse_basis.zw, ground_world)) + root_inverse_origin;
			float broken_edge = edge_noise(root_ground / 32.0);
			roots = smoothstep(0.04 + broken_edge * 0.10, 0.85, roots);
			// Existing earth albedo: a quiet clearing, distinct from canopy leaf green.
			vec3 soil = texture(edge_soil, root_ground / 360.0).rgb;
			float grey = dot(soil, vec3(0.2126, 0.7152, 0.0722));
			soil = mix(soil, vec3(grey), 0.45) * vec3(1.0, 0.94, 0.84);
			COLOR.rgb = mix(COLOR.rgb, soil, roots * 0.72);
		}
	}
	vec3 illumination = world_daylight(ground_world, opening_a, opening_b);
	COLOR.rgb *= mix(vec3(1.0), illumination, amount);
}
"""

static var _edge_cache: Dictionary = {}
static var _root_cache: Dictionary = {}


static func signed_distance(at: Vector2, polygon: PackedVector2Array) -> float:
	var nearest := INF
	for index in polygon.size():
		var point := Geometry2D.get_closest_point_to_segment(at, polygon[index], polygon[(index + 1) % polygon.size()])
		nearest = minf(nearest, at.distance_squared_to(point))
	var distance := sqrt(nearest)
	return distance if Geometry2D.is_point_in_polygon(at, polygon) else -distance


## The CPU work happens once per distinct road outline; shader work is one lookup.
static func distance_record(polygon: PackedVector2Array) -> Dictionary:
	var key := hash(polygon)
	if _edge_cache.has(key) and _edge_cache[key]["polygon"] == polygon:
		return _edge_cache[key]
	var bounds := Iso.poly_bounds(polygon).grow(DISTANCE_RANGE)
	var size := Vector2i(clampi(ceili(bounds.size.x / 18.0), 4, EDGE_MASK_LIMIT), clampi(ceili(bounds.size.y / 18.0), 4, EDGE_MASK_LIMIT))
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var at := bounds.position + Vector2(x + 0.5, y + 0.5) / Vector2(size) * bounds.size
			var distance := clampf(signed_distance(at, polygon), -DISTANCE_RANGE, DISTANCE_RANGE)
			image.set_pixel(x, y, Color(distance / (DISTANCE_RANGE * 2.0) + 0.5, 0, 0, 1))
	var record := {"polygon": polygon.duplicate(), "origin": bounds.position, "extent": bounds.size, "texture": ImageTexture.create_from_image(image)}
	if _edge_cache.size() >= CACHE_LIMIT:
		_edge_cache.erase(_edge_cache.keys()[0])
	_edge_cache[key] = record
	return record


static func material_for(surface: Polygon2D, base: ShaderMaterial) -> ShaderMaterial:
	if surface.polygon.size() < 3 or surface.invert_enabled:
		return base
	var polygon := surface.polygon.duplicate()
	for index in polygon.size():
		polygon[index] += surface.offset
	var record := distance_record(polygon)
	var ink := base.duplicate() as ShaderMaterial
	ink.set_shader_parameter("edge_enabled", true)
	ink.set_shader_parameter("edge_paving", surface.texture == ForestArt.texture("paving"))
	ink.set_shader_parameter("edge_distance", record["texture"])
	ink.set_shader_parameter("edge_origin", record["origin"])
	ink.set_shader_parameter("edge_extent", record["extent"])
	ink.set_shader_parameter("edge_span", clampf(minf(Iso.poly_bounds(polygon).size.x, Iso.poly_bounds(polygon).size.y) * 0.18, 6.0, 24.0))
	surface.set_meta("ground_edge_mask", record)
	return ink


## All actual town/field tree feet share one bounded albedo mask, no extra draws.
static func root_record(receiver: Node2D, village: Village) -> Dictionary:
	var trees: Array[IsoSprite] = []
	var centers := PackedVector2Array()
	var radii := PackedFloat32Array()
	var world := village.fountain.get_parent()
	var bounds := Rect2()
	var inverse := receiver.global_transform.affine_inverse()
	var transform := receiver.global_transform
	var footprint_scale := Vector2(Vector2(transform.x.x, transform.y.x).length(), Vector2(transform.x.y, transform.y.y).length())
	for child in world.get_children():
		var tree := child as IsoSprite
		if tree == null or str(tree.def.get("sheet", "")) != "forest-isometric-trees":
			continue
		var shown_height := float(tree.def["height"]) * tree.k / Iso.S
		var radius := clampf(shown_height * 0.28, 65.0, 135.0)
		var extent := footprint_scale * radius
		var region := Rect2(tree.global_position - extent, extent * 2.0)
		bounds = region if trees.is_empty() else bounds.merge(region)
		trees.append(tree)
		centers.append(tree.global_position)
		radii.append(radius)
	if trees.is_empty():
		return {}
	bounds = bounds.grow(32.0)
	var key := hash([centers, radii, receiver.global_transform])
	if _root_cache.has(key):
		return _root_cache[key]
	var ratio := bounds.size / maxf(bounds.size.x, bounds.size.y)
	var size := Vector2i(maxi(4, ceili(ratio.x * ROOT_MASK_LIMIT)), maxi(4, ceili(ratio.y * ROOT_MASK_LIMIT)))
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 1))
	# 커진 지도에서도 한 텍셀보다 작은 발 접점은 보수적으로 남긴다.
	var footprint := bounds.size/Vector2(size)
	var pixel_radius := (inverse.basis_xform(Vector2(footprint.x,0)).length()+inverse.basis_xform(Vector2(0,footprint.y)).length())*0.5
	for index in trees.size():
		var center := centers[index]
		var radius := radii[index]
		var extent := footprint_scale * radius
		var first := Vector2i(((center - extent - bounds.position) / bounds.size * Vector2(size)).floor()).clamp(Vector2i.ZERO, size - Vector2i.ONE)
		var last := Vector2i(((center + extent - bounds.position) / bounds.size * Vector2(size)).ceil()).clamp(Vector2i.ZERO, size - Vector2i.ONE)
		var contact := inverse * center
		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				var at := bounds.position + Vector2(x + 0.5, y + 0.5) / Vector2(size) * bounds.size
				var distance := maxf(0.0,(inverse * at).distance_to(contact)-pixel_radius) / radius
				var coverage := 1.0 - smoothstep(0.15, 1.0, distance)
				if coverage > image.get_pixel(x, y).r:
					image.set_pixel(x, y, Color(coverage, 0, 0, 1))
	var record := {"origin": bounds.position, "extent": bounds.size, "texture": ImageTexture.create_from_image(image), "centers": centers, "radii": radii, "count": trees.size(), "inverse_basis": Vector4(inverse.x.x, inverse.y.x, inverse.x.y, inverse.y.y), "inverse_origin": inverse.origin}
	if _root_cache.size() >= 4:
		_root_cache.erase(_root_cache.keys()[0])
	_root_cache[key] = record
	return record

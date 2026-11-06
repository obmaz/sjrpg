class_name TownGateRuntime
extends Node2D
## Threat-aware portcullises. Monster exclusion is permanent, including a gate
## opened for the hero; the door animation never becomes the town's only guard.

const CLOSE_DISTANCE := 200.0
const CLEAR_DISTANCE := 280.0
const CLEAR_DELAY := 1.2
const SCAN_INTERVAL := 0.15
const HERO_OPEN_DISTANCE := 110.0
const HERO_CLEAR_DISTANCE := 150.0
const MOTION_TIME := 0.42

var game: Node
var danger := false
var closed: Array[bool] = [false, false, false, false]
var hero_access: Array[bool] = [false, false, false, false]
var progress: Array[float] = [0.0, 0.0, 0.0, 0.0]
var doors: Array[Portcullis] = []
var _scan_remaining := 0.0
var _clear_time := 0.0
var _walls: Array[PackedVector2Array] = []
var _wall_bounds: Array[Rect2] = []
var _enemy_boundary: Dictionary = {}


func setup(world_game: Node) -> TownGateRuntime:
	game = world_game
	for polygon in game.village.wall_footprints + game.village.gate_passages:
		_walls.append(polygon)
		_wall_bounds.append(Iso.poly_bounds(polygon).grow(CLEAR_DISTANCE))
	for index in game.village.gate_points.size():
		var door := Portcullis.new()
		door.setup(game.village, index)
		game.world.add_child(door)
		doors.append(door)
	return self


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if game.dungeon.active:
		return
	_scan_remaining -= delta
	if _scan_remaining <= 0.0:
		_scan_remaining = SCAN_INTERVAL
		_scan(maxf(delta, SCAN_INTERVAL))
	for index in doors.size():
		progress[index] = move_toward(progress[index], 1.0 if closed[index] else 0.0, delta / MOTION_TIME)
		doors[index].set_progress((1.0 if closed[index] else 0.0) if Prefs.reduce_motion else progress[index])


func _scan(elapsed: float) -> void:
	var near := false
	var lingering := false
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy.is_queued_for_deletion():
			continue
		for index in _walls.size():
			if not _wall_bounds[index].has_point(enemy.position):
				continue
			var distance := distance_to_polygon(enemy.position, _walls[index])
			near = near or distance <= CLOSE_DISTANCE
			lingering = lingering or distance <= CLEAR_DISTANCE
			if near:
				break
		if near:
			break
	if near:
		danger = true
		_clear_time = 0.0
	elif danger and not lingering:
		_clear_time += elapsed
		if _clear_time >= CLEAR_DELAY:
			danger = false
	else:
		_clear_time = 0.0
	for index in closed.size():
		var distance := INF
		if is_instance_valid(game.player) and not game.player.dead:
			distance = distance_to_polygon(game.player.position, game.village.gate_passages[index])
		hero_access[index] = distance <= (HERO_CLEAR_DISTANCE if hero_access[index] else HERO_OPEN_DISTANCE)
		closed[index] = danger and not hero_access[index]


static func distance_to_polygon(point: Vector2, polygon: PackedVector2Array) -> float:
	if Geometry2D.is_point_in_polygon(point, polygon):
		return 0.0
	var distance := INF
	for index in polygon.size():
		var closest := Geometry2D.get_closest_point_to_segment(point, polygon[index], polygon[(index + 1) % polygon.size()])
		distance = minf(distance, point.distance_to(closest))
	return distance


func blocks(point: Vector2, radius: float) -> bool:
	if game.dungeon.active:
		return false
	for index in closed.size():
		if closed[index] and distance_to_polygon(point, game.village.gate_passages[index]) <= radius:
			return true
	return false


func blocks_melee(from: Vector2, to: Vector2) -> bool:
	if game.dungeon.active:
		return false
	for index in closed.size():
		if not closed[index]:
			continue
		var passage: PackedVector2Array = game.village.gate_passages[index]
		if Geometry2D.is_point_in_polygon(from, passage) or Geometry2D.is_point_in_polygon(to, passage):
			return true
		for edge in passage.size():
			if Geometry2D.segment_intersects_segment(from, to, passage[edge], passage[(edge + 1) % passage.size()]) != null:
				return true
	return false


func _boundary(radius: float) -> PackedVector2Array:
	if not _enemy_boundary.has(radius):
		var expanded := Geometry2D.offset_polygon(game.village.safe_zone, radius + 1.0, Geometry2D.JOIN_ROUND)
		_enemy_boundary[radius] = expanded[0] if not expanded.is_empty() else game.village.safe_zone
	return _enemy_boundary[radius]


func resolve_actor(from: Vector2, to: Vector2, radius: float, monster: bool) -> Vector2:
	if game.dungeon.active:
		return to
	# Existing explicit combat fixtures can start inside town. Production spawns
	# and survivor restore reject that state; outside monsters never cross inward.
	if monster and not game.in_town(from):
		var boundary := _boundary(radius)
		if Geometry2D.is_point_in_polygon(from, boundary):
			# An existing outside actor may already overlap the new radius margin.
			# Let it retreat, never pin it against the boundary or move farther in.
			if not Geometry2D.is_point_in_polygon(to, boundary):
				return to
			if not game.in_town(to) and distance_to_polygon(to, game.village.safe_zone) >= distance_to_polygon(from, game.village.safe_zone):
				return to
			return from
		if Geometry2D.is_point_in_polygon(to, boundary):
			return from
		for index in boundary.size():
			if Geometry2D.segment_intersects_segment(from, to, boundary[index], boundary[(index + 1) % boundary.size()]) != null:
				return from
	if blocks(to, radius):
		return from
	return to


class Portcullis:
	extends Node2D
	## Static clipped mesh, one material per door. Only a UV slide changes while
	## lowering; the actual stone arch and open wooden leaves occlude it in front.
	const SHADER_CODE := """
shader_type canvas_item;
render_mode unshaded;
#include "res://scripts/world_daylight.gdshaderinc"
uniform float reveal = 0.0;
uniform float slide_uv = 1.0;
uniform float daylight_amount = 0.0;
uniform vec2 opening_a;
uniform vec2 opening_b;
varying vec2 daylight_world;
varying vec4 vertex_tint;
void vertex() {
	daylight_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vertex_tint = COLOR;
}
void fragment() {
	vec2 uv = UV + vec2(0.0, (1.0 - reveal) * slide_uv);
	if (uv.y < 0.0 || uv.y > 1.0) { COLOR = vec4(0.0); }
	else {
		COLOR = texture(TEXTURE, uv) * vertex_tint;
		COLOR.rgb *= mix(vec3(1.0), world_daylight(daylight_world, opening_a, opening_b), daylight_amount);
	}
}
"""
	static var _art: Dictionary = {}
	static var _texture: Texture2D
	static var _shader: Shader
	var _mesh: ArrayMesh
	var _base := Vector2.ZERO
	var _across := Vector2.ZERO
	var _height := 0.0
	var _native := Rect2()
	var _crop := Vector2.ZERO
	var _packing := Vector2.ONE
	var _offset := Vector2.ZERO
	var _plane: Dictionary

	static func art() -> Dictionary:
		if _art.is_empty():
			_art = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/gate_closure_art.json"))
		return _art

	func setup(village: Village, index: int) -> void:
		var data := art()
		if _texture == null:
			_texture = load("res://" + str(data["texture"]["path"]))
		if _shader == null:
			_shader = Shader.new()
			_shader.code = SHADER_CODE
		var key := "gate-0" if index < 2 else "gate-2"
		_plane = data["gates"][key]
		var definition: Dictionary = village.data["sprites"][key]
		var pose := IsoSprite.new().setup(definition, float(definition["world_height"]))
		position = village.gate_points[index]
		pose.position = position
		var first: Array = _plane["base_a"]
		var last: Array = _plane["base_b"]
		var base := Vector2(first[0], first[1])
		_base = pose.atlas_point(base) - position
		_across = pose.atlas_point(Vector2(last[0], last[1])) - position - _base
		_height = absf((pose.atlas_point(base - Vector2(0, float(_plane["height"]))) - position - _base).y)
		var bounds: Array = data["native_bounds"]
		_native = Rect2(bounds[0], bounds[1], bounds[2], bounds[3])
		var crop: Array = data["source_crop"]
		_crop = Vector2(crop[0], crop[1])
		var pack: Array = data["texture"]["packing"]
		_packing = Vector2(pack[0], pack[1])
		var offset: Array = data["texture"]["offset"]
		_offset = Vector2(offset[0], offset[1])
		var outline := PackedVector2Array()
		for point in _plane["arch_clip"]:
			outline.append(pose.atlas_point(Vector2(point[0], point[1])) - position)
		pose.free()
		var vertices := PackedVector3Array()
		var uvs := PackedVector2Array()
		for point in outline:
			vertices.append(Vector3(point.x, point.y, 0))
			var along := (point.x - _base.x) / _across.x
			var vertical := 1.0 + (point.y - _base.y - _across.y * along) / _height
			uvs.append(native_uv(_native.position + Vector2(along, vertical) * _native.size))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = Geometry2D.triangulate_polygon(outline)
		_mesh = ArrayMesh.new()
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var ink := ShaderMaterial.new()
		ink.shader = _shader
		ink.set_shader_parameter("slide_uv", _native.size.y * _packing.y / _texture.get_height())
		WorldLighting.register_material(ink)
		material = ink
		z_as_relative = false
		z_index = -1
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		set_progress(0.0)

	func native_uv(pixel: Vector2) -> Vector2:
		return ((pixel - _crop) * _packing + _offset) / _texture.get_size()

	## The same source-coordinate map used to build actual drawing UVs, retained
	## for upper/middle/lower bar and parallel-line tests on both gate orientations.
	func native_point(pixel: Vector2) -> Vector2:
		var at := (pixel - _native.position) / _native.size
		return global_transform * (_base + _across * at.x + Vector2(0, -_height * (1.0 - at.y)))

	## Inverse texture lookup through the actual clipped triangle mesh, not a
	## separately reconstructed collision rectangle. INF means arch-occluded.
	func drawn_native_point(pixel: Vector2) -> Vector2:
		var uv := native_uv(pixel)
		var arrays := _mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for index in range(0, indices.size(), 3):
			var first := indices[index]
			var second := indices[index + 1]
			var third := indices[index + 2]
			var across := uvs[second] - uvs[first]
			var down := uvs[third] - uvs[first]
			var relative := uv - uvs[first]
			var determinant := across.cross(down)
			if absf(determinant) < 0.000001:
				continue
			var b := relative.cross(down) / determinant
			var c := across.cross(relative) / determinant
			if b < -0.0001 or c < -0.0001 or b + c > 1.0001:
				continue
			var drawn := vertices[first] * (1.0 - b - c) + vertices[second] * b + vertices[third] * c
			return global_transform * Vector2(drawn.x, drawn.y)
		return Vector2(INF, INF)

	func set_progress(value: float) -> void:
		visible = value > 0.001
		(material as ShaderMaterial).set_shader_parameter("reveal", clampf(value, 0.0, 1.0))

	func _draw() -> void:
		if _mesh != null:
			draw_mesh(_mesh, _texture)

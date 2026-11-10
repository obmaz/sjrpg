class_name SpatialWorld3D
extends Node3D
## Native3D authority. Node2D positions are projected-ground gameplay/HUD adapters.
## Source polygons construct collision shapes once; movement never calls Iso.push_out.

const UNITS := 65.0
const VERTICAL := UNITS * Iso.S
const HORIZONTAL := UNITS * 1.224744871391589 * Iso.S
const SOLID := 1
const FLOOR := 2
const MONSTER_BOUNDARY := 4
const ACTOR := 8
const PROP := 16
const SKIN := 0.015
const MAX_STEP := 0.38
var game: Node
var actor_bodies := {}
var physics_ticks := 0
var realm := "forest"
var _sources := {}
var _geometry: Node3D
var _gates: Array[StaticBody3D] = []
var _circles: Array[Dictionary] = []
var _props: Array[Dictionary] = []
var _surfaces: Array[Dictionary] = []
var _layout_id := 0
var _resolver: CharacterBody3D
var _resolver_shape: CapsuleShape3D
var _sphere := SphereShape3D.new()


func setup(world_game: Node, stage: Node3D) -> SpatialWorld3D:
	game = world_game
	name = "SpatialWorld3D"
	stage.add_child(self)
	_surfaces = terrain_surfaces(game.village)
	_resolver = _new_body("PlacementSweep", Vector2(0.3, 1.7), false)
	_resolver.collision_layer = 0
	_resolver_shape = (_resolver.get_child(0) as CollisionShape3D).shape as CapsuleShape3D
	sync_scope(true)
	register_actor(game.player, Player.RADIUS)
	return self


static func native_point(point: Vector2, height := 0.0) -> Vector3:
	var flat := Iso.unproject(point) / UNITS
	return Vector3(flat.x, height, flat.y)


static func projected(point: Vector3) -> Vector2:
	return Iso.project(Vector2(point.x, point.z) * UNITS)


static func actor_dimensions(source: Node2D, radius_pixels: float) -> Vector2:
	var radius := radius_metres(radius_pixels)
	var authored_height := 84.0
	if source != null and source.get("sprite") is ActorSprite:
		var sprite: ActorSprite = source.get("sprite")
		authored_height = sprite.body_height
	var height_factor: float = 1.0 if source is Enemy else 1.25
	# Enemy source height is already canonical native metres; no second hidden enlargement.
	return Vector2(radius, maxf(radius * 2.0 + 0.05, authored_height / VERTICAL * height_factor))


static func radius_metres(radius_pixels: float) -> float:
	# A horizontal isometric ground-circle silhouette spans sqrt(3/2)*S pixels
	# per ground unit; vertical elevation uses S instead and is a different unit.
	return radius_pixels / HORIZONTAL


func register_actor(source: Node2D, radius := -1.0, monster := false) -> CharacterBody3D:
	var id := source.get_instance_id()
	if actor_bodies.has(id):
		return actor_bodies[id] as CharacterBody3D
	if radius < 0.0:
		radius = (source as Enemy).radius if source is Enemy else Player.RADIUS
	monster = monster or source is Enemy
	var dimensions := actor_dimensions(source, radius)
	var body := _new_body("Actor_%d" % id, dimensions, monster)
	body.set_meta("radius_pixels", radius)
	body.set_meta("monster", monster)
	body.set_meta("height", dimensions.y)
	body.set_meta("projected", source.position)
	body.position = native_point(source.position, _construction_height(source.position) + dimensions.y * 0.5 + SKIN)
	actor_bodies[id] = body
	_sources[id] = weakref(source)
	return body


func _new_body(label: String, dimensions: Vector2, monster: bool) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = label
	body.collision_layer = ACTOR
	# This walking motor follows real FLOOR ray support. Sweeping the rounded
	# capsule against that same ramp steers it sideways before its foot centre
	# enters; walls, real cliff faces, props and monster boundaries still sweep.
	body.collision_mask = SOLID | PROP | (MONSTER_BOUNDARY if monster else 0)
	body.safe_margin = 0.002
	body.floor_snap_length = 0.20
	body.floor_max_angle = deg_to_rad(55.0)
	var shape := CapsuleShape3D.new()
	shape.radius = dimensions.x
	shape.height = dimensions.y
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body


func actor_foot(source: Node2D, radius := -1.0, monster := false) -> Vector3:
	if source is Enemy and not game.enemies.has(source):
		return native_point(source.position, height_at(source.position))
	var body := register_actor(source, radius, monster)
	var last: Vector2 = body.get_meta("projected")
	if source.position.distance_squared_to(last) > 0.01:
		teleport_source_actor(source, source.position, float(body.get_meta("radius_pixels")), bool(body.get_meta("monster")))
	return body.position - Vector3.UP * (float(body.get_meta("height")) * 0.5 + SKIN)


func move_source_actor(source: Node2D, to: Vector2, radius: float, monster := false) -> Vector2:
	sync_scope()
	var body := register_actor(source, radius, monster)
	var last: Vector2 = body.get_meta("projected")
	if source.position.distance_squared_to(last) > 0.01:
		teleport_source_actor(source, source.position, radius, monster)
	_move_body(body, to)
	var result := projected(body.position)
	body.set_meta("projected", result)
	source.position = result
	return result


func teleport_source_actor(source: Node2D, point: Vector2, radius: float, monster := false) -> Vector2:
	sync_scope()
	var body := register_actor(source, radius, monster)
	var landing := _free_landing(point, radius, monster)
	var sample := _floor_sample(landing)
	var height: float = sample.get("height", _construction_height(landing))
	body.position = native_point(landing, height + float(body.get_meta("height")) * 0.5 + SKIN)
	body.velocity = Vector3.ZERO
	body.set_meta("projected", landing)
	source.position = landing
	return landing


func _move_body(body: CharacterBody3D, destination: Vector2) -> void:
	var start := body.position
	var finish := native_point(destination)
	var horizontal := Vector2(finish.x - start.x, finish.z - start.z)
	var steps := maxi(1, ceili(horizontal.length() / 0.20))
	var height := float(body.get_meta("height", _resolver_shape.height))
	for index in steps:
		var point := Vector2(start.x, start.z) + horizontal * (float(index + 1) / steps)
		var screen := Iso.project(point * UNITS)
		var floor_info := _floor_sample(screen)
		if not bool(floor_info.get("found", false)):
			break
		var foot := body.position.y - height * 0.5 - SKIN
		var floor_height: float = floor_info["height"]
		# Native sampled floor height prevents implicit cliff jumps; only the
		# actual continuous ramp can connect floor levels in this walking game.
		if absf(floor_height - foot) > MAX_STEP:
			break
		var previous := body.position
		var validated_pose := Vector3(point.x, floor_height + height * 0.5 + SKIN, point.y)
		var motion := validated_pose - body.position
		for slide in 3:
			if motion.length_squared() < 0.0000001:
				break
			var hit := body.move_and_collide(motion, false, 0.002, true, 4)
			if hit == null:
				break
			motion = hit.get_remainder().slide(hit.get_normal())
		_settle_support(body, previous, height, validated_pose)
		# 계단 높이가 바뀌는 프레임에도 벽 접촉 복구가 캡슐을 안으로
		# 밀어 넣지 않도록 마지막으로 확인된 지지점을 보존한다.
		# 스윕이 이미 safe_margin을 적용했다. 여기서 같은 여유를 다시
		# 부풀리면 난간 접촉 뒤의 정상적인 미끄러짐까지 되돌리게 된다.
		if not _clear_pose(body, body.position, 0.0):
			body.position = previous


func _settle_support(body: CharacterBody3D, previous: Vector3, height: float, validated_pose := Vector3(INF, INF, INF)) -> void:
	var actual := body.position
	# An unobstructed step already sampled FLOOR and checked its height above.
	# Reuse only that full pose within one micrometre; slides/recovery resample below.
	if validated_pose.is_finite() and actual.distance_squared_to(validated_pose) <= 0.000000000001:
		return
	# Solid-edge recovery can lift a capsule, and a slide can change its XZ.
	# FLOOR support belongs to that actual XZ, not to the intended step above.
	var origin_foot := previous.y - height * 0.5 - SKIN
	var support := _supported_pose(actual, origin_foot, height)
	if not support.is_empty():
		var grounded: Vector3 = support["position"]
		if absf(actual.y - grounded.y) <= 0.00001 or _clear_pose(body, grounded):
			body.position = grounded
			return
	# Snapping straight down through the raised edge would penetrate SOLID.
	# Keep the last clear, supported point along the actual horizontal move.
	var initial := _supported_pose(previous, origin_foot, height)
	if initial.is_empty() or not _clear_pose(body, initial["position"]):
		body.position = previous
		return
	var accepted: Vector3 = initial["position"]
	var low := 0.0
	var high := 1.0
	for attempt in 12:
		var fraction := (low + high) * 0.5
		var candidate := _supported_pose(previous.lerp(actual, fraction), origin_foot, height)
		if not candidate.is_empty() and _clear_pose(body, candidate["position"]):
			accepted = candidate["position"]
			low = fraction
		else:
			high = fraction
	body.position = accepted


func _supported_pose(point: Vector3, origin_foot: float, height: float) -> Dictionary:
	var sample := _floor_sample(projected(point))
	if not bool(sample.get("found", false)) or absf(float(sample["height"]) - origin_foot) > MAX_STEP:
		return {}
	return {"position": Vector3(point.x, float(sample["height"]) + height * 0.5 + SKIN, point.z)}


func _clear_pose(body: CharacterBody3D, point: Vector3, margin := -1.0) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = (body.get_child(0) as CollisionShape3D).shape
	query.transform = Transform3D(Basis.IDENTITY, point)
	query.collision_mask = body.collision_mask
	query.exclude = [body.get_rid()]
	query.margin = body.safe_margin if margin < 0.0 else margin
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func move_actor(from: Vector2, to: Vector2, radius: float, monster := false) -> Vector2:
	sync_scope()
	var native_radius := radius_metres(radius)
	var dimensions := Vector2(native_radius, maxf(1.65, native_radius * 2.0 + 0.05))
	_resolver_shape.radius = dimensions.x
	_resolver_shape.height = dimensions.y
	_resolver.collision_mask = SOLID | PROP | (MONSTER_BOUNDARY if monster else 0)
	_resolver.set_meta("height", dimensions.y)
	_resolver.position = native_point(from, height_at(from) + dimensions.y * 0.5 + SKIN)
	_move_body(_resolver, to)
	return projected(_resolver.position)


func resolve_movement(from: Vector2, to: Vector2, radius: float, monster := false) -> Vector2:
	if from.distance_squared_to(to) < 0.0001:
		return _free_landing(to, radius, monster)
	return move_actor(from, to, radius, monster)


func _free_landing(point: Vector2, radius: float, monster: bool) -> Vector2:
	if not blocked(point, radius, monster):
		return point
	for ring in range(1, 13):
		for sample in 16:
			var candidate := point + Vector2.from_angle(sample * TAU / 16.0) * radius * ring * 0.6
			if not blocked(candidate, radius, monster):
				return candidate
	return point


func blocked(point: Vector2, radius: float, monster := false) -> bool:
	sync_scope()
	var floor_info := _floor_sample(point)
	if not bool(floor_info.get("found", false)):
		return true
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius_metres(radius)
	capsule.height = maxf(1.65, capsule.radius * 2.0 + 0.05)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, native_point(point, float(floor_info["height"]) + capsule.height * 0.5 + SKIN))
	query.collision_mask = SOLID | PROP | (MONSTER_BOUNDARY if monster else 0)
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func height_at(point: Vector2) -> float:
	sync_scope()
	return float(_floor_sample(point).get("height", 0.0))


func contains(point: Vector2, radius := 0.0) -> bool:
	sync_scope()
	if not bool(_floor_sample(point).get("found", false)):
		return false
	var center := native_point(point)
	for sample in 8:
		var offset := Vector2.from_angle(sample * TAU / 8.0) * radius_metres(radius)
		if not bool(_floor_sample(projected(center + Vector3(offset.x, 0, offset.y))).get("found", false)):
			return false
	return true


func _floor_sample(point: Vector2) -> Dictionary:
	var at := native_point(point)
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 40.0, at - Vector3.UP * 10.0, FLOOR)
	ray.hit_back_faces = true
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return {"found": false}
	var position: Vector3 = hit["position"]
	return {"found": true, "height": position.y, "normal": hit["normal"]}


func can_melee(from: Vector2, to: Vector2) -> bool:
	sync_scope()
	var a := height_at(from)
	var b := height_at(to)
	if absf(a - b) > TerrainLevels.STEP_REACH / VERTICAL:
		return false
	var ray := PhysicsRayQueryParameters3D.create(native_point(from, a + 0.70), native_point(to, b + 0.70), SOLID)
	var exclusions: Array[RID] = []
	for circle in _circles:
		var at: Vector2 = circle["point"]
		var radius: float = circle["radius"]
		if at.distance_to(from) <= radius + 1.0 or at.distance_to(to) <= radius + 1.0:
			exclusions.append((circle["body"] as StaticBody3D).get_rid())
	ray.exclude = exclusions
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func projectile_fraction(from: Vector3, to: Vector3, radius_m: float) -> float:
	sync_scope()
	_sphere.radius = maxf(radius_m, 0.005)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _sphere
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.motion = to - from
	query.collision_mask = SOLID
	var state := get_world_3d().direct_space_state
	if not state.intersect_shape(query, 1).is_empty():
		return 0.0
	var result := state.cast_motion(query)
	return result[0] if result.size() == 2 else 1.0


func _physics_process(_delta: float) -> void:
	physics_ticks += 1
	sync_scope()
	if is_instance_valid(game.player):
		register_actor(game.player, Player.RADIUS)
	for source: Enemy in game.enemies:
		if is_instance_valid(source) and not source.dead:
			register_actor(source, (source as Enemy).radius, true)
	for id in actor_bodies.keys():
		var source: Node2D = _sources[id].get_ref()
		var body: CharacterBody3D = actor_bodies[id]
		if source == null or source.is_queued_for_deletion() or (source is Enemy and (source.dead or not game.enemies.has(source))):
			body.collision_layer = 0
			body.queue_free()
			actor_bodies.erase(id)
			_sources.erase(id)
			continue
		var last: Vector2 = body.get_meta("projected")
		if source.position.distance_squared_to(last) > 0.01:
			teleport_source_actor(source, source.position, float(body.get_meta("radius_pixels")), bool(body.get_meta("monster")))
		else:
			source.position = projected(body.position)


func sync_scope(force := false) -> void:
	var cave: bool = game.dungeon.active
	var identity: int = game.dungeon.layout.get_instance_id() if cave else 0
	if force or (realm == "cave") != cave or identity != _layout_id:
		realm = "cave" if cave else "forest"
		_layout_id = identity
		_rebuild()
	for index in _gates.size():
		_gates[index].collision_layer = SOLID if not cave and game.town_gates.closed[index] else 0
	for entry in _props:
		var source: Chest = entry["owner"].get_ref()
		(entry["body"] as StaticBody3D).collision_layer = PROP if is_instance_valid(source) and not source.dead else 0


func _rebuild() -> void:
	if is_instance_valid(_geometry):
		for child in _geometry.find_children("*", "CollisionObject3D", true, false):
			(child as CollisionObject3D).collision_layer = 0
		_geometry.queue_free()
	_geometry = Node3D.new()
	_geometry.name = "CavePhysics" if realm == "cave" else "ForestPhysics"
	add_child(_geometry)
	_gates.clear()
	_circles.clear()
	_props.clear()
	if realm == "cave":
		_build_cave()
	else:
		_build_forest()
	for id in actor_bodies:
		var source: Node2D = _sources[id].get_ref()
		if source != null:
			var body: CharacterBody3D = actor_bodies[id]
			body.position = native_point(source.position, _construction_height(source.position) + float(body.get_meta("height")) * 0.5 + SKIN)
			body.set_meta("projected", source.position)


func _build_forest() -> void:
	var field: Rect2 = game.FIELD
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(field.size.x / UNITS, 0.20, field.size.y / UNITS)
	_shape_body(floor_shape, Transform3D(Basis.IDENTITY, Vector3(0, -0.10, 0)), FLOOR, "Ground")
	var boundary := PackedVector2Array([field.position, Vector2(field.end.x, field.position.y), field.end, Vector2(field.position.x, field.end.y)])
	for index in boundary.size():
		_segment(Vector3(boundary[index].x, 0, boundary[index].y) / UNITS, Vector3(boundary[(index + 1) % boundary.size()].x, 0, boundary[(index + 1) % boundary.size()].y) / UNITS, 0.0, 8.0, SOLID)
	var terrain_blockers: Array[PackedVector2Array] = []
	for surface in _surfaces:
		var faces := surface_faces(surface)
		if not faces.is_empty():
			_triangle_body(faces, FLOOR, "RaisedFloor_" + str(surface["id"]))
		if str(surface["id"]) in ["landmark_0", "landmark_2", "landmark_3"]:
			_triangle_body(NativeTerrainForms.faces(surface), SOLID, "NaturalGeology")
		for polygon: PackedVector2Array in surface["blockers"]:
			terrain_blockers.append(polygon)
		var top: PackedVector2Array = surface["top"]
		for edge in top.size():
			if _is_entrance(surface, top[edge], top[(edge + 1) % top.size()]):
				continue
			var a := native_point(top[edge], _surface_height(surface, top[edge]))
			var b := native_point(top[(edge + 1) % top.size()], _surface_height(surface, top[(edge + 1) % top.size()]))
			if maxf(a.y, b.y) <= 0.01:
				continue
			_triangle_body(PackedVector3Array([Vector3(a.x, 0, a.z), a, b, Vector3(a.x, 0, a.z), b, Vector3(b.x, 0, b.z)]), SOLID, "CliffFace")
	for polygon: PackedVector2Array in game.village.solids:
		if terrain_blockers.has(polygon) or _legacy_chapel_polygon(polygon):
			continue
		var center := Iso.poly_bounds(polygon).get_center()
		var base := _construction_height(center)
		_prism_body(polygon, base, base + 3.5, PROP if _attackable_polygon(polygon) else SOLID, "Obstacle")
	var chapel := _native_chapel(game.village)
	_prism_body(chapel["building"], 0.28, 8.0, SOLID, "NativeChapelBody")
	for corner: Vector3 in NativeFortressPlan.corners(game.village):
		var shape := CylinderShape3D.new()
		shape.radius = NativeFortressPlan.CORNER_RADIUS
		shape.height = game.village.wall_height / UNITS
		_shape_body(shape, Transform3D(Basis.IDENTITY, corner + Vector3.UP * shape.height * 0.5), SOLID, "CornerBastion")
	# Bridge rails are full-height native solids even though their deck has zero rise.
	for polygon in game.village.bridge.solids():
		_prism_body(polygon, 0.0, 0.96, SOLID, "BridgeRail")
	for circle: Array in game.village.circles:
		var point: Vector2 = circle[0]
		var radius: float = circle[1]
		var chest := _chest_at(point)
		var shape := CylinderShape3D.new()
		shape.radius = radius_metres(radius)
		shape.height = NativeEncounterMesh3D.CHEST_COLLISION_HEIGHT if chest != null else 2.2
		var base := _construction_height(point)
		var body := _shape_body(shape, Transform3D(Basis.IDENTITY, native_point(point, base + shape.height * 0.5)), PROP if chest != null else SOLID, "TrunkOrResident")
		if chest != null:
			_props.append({"owner": weakref(chest), "body": body})
		else:
			_circles.append({"point": point, "radius": radius, "body": body})
	for polygon in game.village.gate_passages:
		_gates.append(_prism_body(polygon, 0.0, 4.5, 0, "ClosedGate"))
	var safe: PackedVector2Array = game.village.safe_zone
	for edge in safe.size():
		_segment(native_point(safe[edge]), native_point(safe[(edge + 1) % safe.size()]), -1.0, 12.0, MONSTER_BOUNDARY)


func _attackable_polygon(polygon: PackedVector2Array) -> bool:
	if game.encounters != null:
		for stone in game.encounters.stones.values():
			if polygon == stone.body():
				return true
	return false


func _legacy_chapel_polygon(polygon: PackedVector2Array) -> bool:
	var range_: Vector2i = game.village.chapel_solids
	for index in range(range_.x, range_.y):
		if game.village.solids[index] == polygon:
			return true
	return false


func _chest_at(point: Vector2) -> Chest:
	for chest: Chest in game.chests:
		if point.distance_squared_to(chest.position) < 1.0:
			return chest
	return null


func _build_cave() -> void:
	var layout: DungeonLayout = game.dungeon.layout
	var xs: Array[float] = []
	var zs: Array[float] = []
	var rects: Array[Rect2] = []
	for polygon in layout.polygons:
		var flat := PackedVector2Array()
		for point in polygon:
			flat.append(Iso.unproject(point) / UNITS)
		var bounds := Iso.poly_bounds(flat)
		# Project/unproject uses float Vector2s; shared authored rectangle edges
		# can differ by micrometres. Canonicalize before the union-cell boundary
		# construction, or a false microscopic empty cell becomes a real wall.
		var minimum := bounds.position.snapped(Vector2.ONE * 0.001)
		var maximum := bounds.end.snapped(Vector2.ONE * 0.001)
		bounds = Rect2(minimum, maximum - minimum)
		rects.append(bounds)
		for x in [bounds.position.x, bounds.end.x]:
			if not xs.has(x):
				xs.append(x)
		for z in [bounds.position.y, bounds.end.y]:
			if not zs.has(z):
				zs.append(z)
		_floor_polygon(polygon, 0.0, "CaveFloor")
	xs.sort()
	zs.sort()
	var cells := {}
	for x in xs.size() - 1:
		for z in zs.size() - 1:
			var center := Vector2((xs[x] + xs[x + 1]) * 0.5, (zs[z] + zs[z + 1]) * 0.5)
			for rect in rects:
				if rect.has_point(center):
					cells[Vector2i(x, z)] = true
					break
	for cell: Vector2i in cells:
		var x := cell.x
		var z := cell.y
		if not cells.has(cell + Vector2i.LEFT):
			_segment(Vector3(xs[x], 0, zs[z]), Vector3(xs[x], 0, zs[z + 1]), 0.0, 3.5, SOLID)
		if not cells.has(cell + Vector2i.RIGHT):
			_segment(Vector3(xs[x + 1], 0, zs[z]), Vector3(xs[x + 1], 0, zs[z + 1]), 0.0, 3.5, SOLID)
		if not cells.has(cell + Vector2i.UP):
			_segment(Vector3(xs[x], 0, zs[z]), Vector3(xs[x + 1], 0, zs[z]), 0.0, 3.5, SOLID)
		if not cells.has(cell + Vector2i.DOWN):
			_segment(Vector3(xs[x], 0, zs[z + 1]), Vector3(xs[x + 1], 0, zs[z + 1]), 0.0, 3.5, SOLID)
	for obstacle in layout.obstacles:
		_prism_body(obstacle, 0.0, 2.5, SOLID, "CaveObstacle")


func _construction_height(point: Vector2) -> float:
	if realm == "cave":
		return 0.0
	for surface in _surfaces:
		if _contains(surface["top"], point):
			return _surface_height(surface, point)
	return 0.0


static func _contains(polygon: PackedVector2Array, point: Vector2) -> bool:
	if Geometry2D.is_point_in_polygon(point, polygon):
		return true
	for edge in polygon.size():
		if Geometry2D.get_closest_point_to_segment(point, polygon[edge], polygon[(edge + 1) % polygon.size()]).distance_squared_to(point) < 0.0001:
			return true
	return false


static func _surface_height(surface: Dictionary, point: Vector2) -> float:
	if surface.has("native_steps"):
		var flat := Iso.unproject(point) / UNITS
		var step_height := 0.0
		for tier: Dictionary in surface["native_steps"]:
			var rect: Rect2 = tier["rect"]
			if rect.has_point(flat):
				step_height = maxf(step_height, float(tier["height"]))
		return step_height if step_height > 0.0 else NativeChapelPlan.FLOOR
	var height := float(surface["rise"]) / VERTICAL
	if surface.has("ramp") and _contains(surface["ramp"], point):
		var bottom: Vector2 = surface["bottom"]
		var upper: Vector2 = surface["upper"]
		var along := upper - bottom
		height *= clampf((point - bottom).dot(along) / maxf(along.length_squared(), 0.001), 0.0, 1.0)
	return height


static func _is_entrance(surface: Dictionary, a: Vector2, b: Vector2) -> bool:
	if not surface.has("entrance"):
		return false
	var edge: PackedVector2Array = surface["entrance"]
	return (a.distance_to(edge[0]) + b.distance_to(edge[1]) < 0.05) or (a.distance_to(edge[1]) + b.distance_to(edge[0]) < 0.05)


## Native chapel thresholds replace the old illustration's fictitious high yard.
## Other measured terrain remains source data, converted into real3D floor meshes.
static func terrain_surfaces(village: Village) -> Array[Dictionary]:
	if village.has_meta("native_terrain_surfaces"):
		var cached: Array[Dictionary] = village.get_meta("native_terrain_surfaces")
		return cached
	var result: Array[Dictionary] = []
	for surface in TerrainLevels._surfaces(village):
		if str(surface["id"]) != "chapel":
			if str(surface["id"]) in ["landmark_0", "landmark_2", "landmark_3"]:
				surface = surface.duplicate()
				surface["top"] = NativeTerrainForms.outline(surface)
			result.append(surface)
	result.push_front(_native_chapel(village))
	village.set_meta("native_terrain_surfaces", result)
	return result


## Construction-time visuals can use this before the physics world exists.
## Runtime movement/reach uses height_at's real native floor-ray result instead.
static func surface_height_at(village: Village, point: Vector2) -> float:
	for surface in terrain_surfaces(village):
		if _contains(surface["top"], point):
			return _surface_height(surface, point)
	return 0.0


static func _native_chapel(village: Village) -> Dictionary:
	var sprite: IsoSprite = village.buildings["chapel"]
	var definition: Dictionary = village.data["frames"]["chapel"]
	var ground := PackedVector2Array()
	for point in sprite.atlas_polygon(definition["ground"]):
		ground.append(Iso.unproject(point) / UNITS)
	var bounds := Iso.poly_bounds(ground)
	var center := bounds.get_center()
	var width := maxf(3.5, bounds.size.x)
	var depth := maxf(3.0, bounds.size.y)
	var front := center.y + depth * 0.5
	var door_width := NativeChapelPlan.stair_width(width)
	var base := Rect2(center - Vector2(width + 0.30, depth + 0.30) * 0.5, Vector2(width + 0.30, depth + 0.30))
	var platform := PackedVector2Array([base.position, Vector2(base.end.x, base.position.y), base.end, Vector2(base.position.x, base.end.y)])
	var ramp := PackedVector2Array([Vector2(center.x - door_width * 0.5, front + 0.04 + NativeChapelPlan.RUN), Vector2(center.x + door_width * 0.5, front + 0.04 + NativeChapelPlan.RUN), Vector2(center.x + door_width * 0.5, front + 0.04), Vector2(center.x - door_width * 0.5, front + 0.04)])
	var merged := Geometry2D.merge_polygons(platform, ramp)
	var top_native: PackedVector2Array = merged[0] if not merged.is_empty() else platform
	var top := PackedVector2Array()
	var projected_ramp := PackedVector2Array()
	for point in top_native:
		top.append(Iso.project(point * UNITS))
	for point in ramp:
		projected_ramp.append(Iso.project(point * UNITS))
	var building := PackedVector2Array()
	for point in [center + Vector2(-width, -depth) * 0.5, center + Vector2(width, -depth) * 0.5, center + Vector2(width, depth) * 0.5, center + Vector2(-width, depth) * 0.5]:
		building.append(Iso.project(point * UNITS))
	return {"id": "chapel", "top": top, "ramp": projected_ramp, "rise": 0.28 * VERTICAL,
		"native_steps": NativeChapelPlan.tiers(center, width, depth),
		"bottom": Iso.project(Vector2(center.x, front + 0.04 + NativeChapelPlan.RUN) * UNITS), "upper": Iso.project(Vector2(center.x, front + 0.04) * UNITS),
		"entrance": PackedVector2Array([projected_ramp[0], projected_ramp[1]]), "blockers": [] as Array[PackedVector2Array], "building": building}


## Shared collision/visible-top vertices: ramp is split from the flat top before
## triangulation, so a large triangle cannot interpolate across a ramp crease.
static func surface_faces(surface: Dictionary) -> PackedVector3Array:
	var result := PackedVector3Array()
	var top: PackedVector2Array = surface["top"]
	if surface.has("native_steps"):
		for polygon: PackedVector2Array in Geometry2D.clip_polygons(top, surface["ramp"]):
			result.append_array(_floor_region(polygon, surface, NativeChapelPlan.FLOOR))
		var tiers: Array = surface["native_steps"]
		for i: int in tiers.size():
			var rect: Rect2 = tiers[i]["rect"]
			if i + 1 < tiers.size():
				var next: Rect2 = tiers[i + 1]["rect"]
				var original: Rect2 = tiers[i]["rect"]
				rect.position.y = next.end.y
				rect.size.y = original.end.y - next.end.y
			var polygon := PackedVector2Array()
			for point: Vector2 in NativeChapelPlan.polygon(rect):
				polygon.append(Iso.project(point * UNITS))
			result.append_array(_floor_region(polygon, surface, float(tiers[i]["height"])))
		return result
	var flat: Array[PackedVector2Array] = [top]
	var ramp: Array[PackedVector2Array] = []
	if surface.has("ramp"):
		flat = Geometry2D.clip_polygons(top, surface["ramp"])
		ramp = Geometry2D.intersect_polygons(top, surface["ramp"])
	for polygon in flat:
		result.append_array(_floor_region(polygon, surface, float(surface["rise"]) / VERTICAL))
	for polygon in ramp:
		var bottom: Vector2 = surface["bottom"]
		var upper: Vector2 = surface["upper"]
		var along := upper - bottom
		# An irregular entrance need not be perpendicular to the gradient.
		# Split the clamp creases first: otherwise interpolating clamped endpoint
		# heights lifts a zero-height entrance into an invisible physical step.
		for lower in _half_plane(polygon, bottom, along, false):
			result.append_array(_floor_region(lower, surface, 0.0))
		for higher in _half_plane(polygon, upper, along, true):
			result.append_array(_floor_region(higher, surface, float(surface["rise"]) / VERTICAL))
		for middle in _half_plane(polygon, bottom, along, true):
			for clipped in _half_plane(middle, upper, along, false):
				result.append_array(_floor_region(clipped, surface))
	return result


static func _half_plane(polygon: PackedVector2Array, origin: Vector2, direction: Vector2, positive: bool) -> Array[PackedVector2Array]:
	var extent := Iso.poly_bounds(polygon).size.length() * 4.0 + 100.0
	var axis := direction.normalized() * (1.0 if positive else -1.0)
	var side := axis.orthogonal() * extent
	var clip := PackedVector2Array([origin - side, origin + side, origin + side + axis * extent, origin - side + axis * extent])
	return Geometry2D.intersect_polygons(polygon, clip)


static func _floor_region(polygon: PackedVector2Array, surface: Dictionary, constant_height := -1.0) -> PackedVector3Array:
	var result := PackedVector3Array()
	for index in Geometry2D.triangulate_polygon(polygon):
		var point := polygon[index]
		result.append(native_point(point, constant_height if constant_height >= 0.0 else _surface_height(surface, point)))
	return result


func _floor_polygon(polygon: PackedVector2Array, height: float, label: String) -> void:
	var vertices := PackedVector3Array()
	for index in Geometry2D.triangulate_polygon(polygon):
		vertices.append(native_point(polygon[index], height))
	_triangle_body(vertices, FLOOR, label)


func _triangle_body(vertices: PackedVector3Array, layer: int, label: String) -> StaticBody3D:
	var valid := PackedVector3Array()
	for index in range(0, vertices.size(), 3):
		var a := vertices[index]
		var b := vertices[index + 1]
		var c := vertices[index + 2]
		# A cliff side at a zero-rise ramp endpoint collapses one of its two
		# triangles. Invalid faces produce spurious native recovery contacts.
		if (b - a).cross(c - a).length_squared() <= 0.0000000001:
			continue
		valid.append_array(PackedVector3Array([a, b, c]))
	if valid.is_empty():
		return null
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(valid)
	return _shape_body(shape, Transform3D.IDENTITY, layer, label)


func _prism_body(polygon: PackedVector2Array, bottom: float, top: float, layer: int, label: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.set_meta("physics_kind", label)
	body.set_meta("source_polygon", polygon)
	body.collision_layer = layer
	body.collision_mask = 0
	_geometry.add_child(body)
	# Triangular convex prisms preserve concave footprints instead of replacing
	# them with a bounding box or a convex hull across a real gate passage.
	var indices := Geometry2D.triangulate_polygon(polygon)
	for index in range(0, indices.size(), 3):
		var points := PackedVector3Array()
		for corner in 3:
			var point := polygon[indices[index + corner]]
			points.append(native_point(point, bottom))
			points.append(native_point(point, top))
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
	return body


func _segment(a: Vector3, b: Vector3, bottom: float, top: float, layer: int) -> void:
	var direction := b - a
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.08, top - bottom, direction.length() + 0.04)
	var basis := Basis(Quaternion(Vector3(0, 0, 1), direction.normalized()))
	_shape_body(shape, Transform3D(basis, (a + b) * 0.5 + Vector3.UP * (top + bottom) * 0.5), layer, "Boundary")


func _shape_body(shape: Shape3D, transform: Transform3D, layer: int, label: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.set_meta("physics_kind", label)
	body.collision_layer = layer
	body.collision_mask = 0
	_geometry.add_child(body)
	body.transform = transform
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	return body

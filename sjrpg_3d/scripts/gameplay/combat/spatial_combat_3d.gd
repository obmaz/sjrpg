class_name SpatialCombat3D
extends RefCounted
## Combat adapters query the same native floors, capsules and solid sweeps as movement.
## Legacy skill ranges remain screen-world units; native elevation is measured in metres.

const GROUND_PER_METER := 65.0
const HEIGHT_PIXELS := GROUND_PER_METER * Iso.S
const HORIZONTAL_PIXELS := GROUND_PER_METER * 1.224744871391589 * Iso.S
const PROJECTILE_LIFT := 34.0 / HEIGHT_PIXELS
const PROJECTILE_RADIUS := 26.0


static func world(game: Node) -> Node:
	if not is_instance_valid(game):
		return null
	return game.get("spatial_world") as Node


static func point(at: Vector2, height: float) -> Vector3:
	var flat := Iso.unproject(at) / GROUND_PER_METER
	return Vector3(flat.x, height, flat.y)


static func floor_at(game: Node, at: Vector2) -> float:
	var backend := world(game)
	return float(backend.height_at(at)) if backend != null else 0.0


static func register_actor(game: Node, source: Node2D, radius: float, monster := false) -> void:
	var backend := world(game)
	if backend != null:
		backend.register_actor(source, radius, monster)


static func move_actor(game: Node, source: Node2D, to: Vector2, radius: float, monster := false) -> Vector2:
	var backend := world(game)
	if backend != null:
		return backend.move_source_actor(source, to, radius, monster)
	return game.move_actor(source.position, to, radius, monster)


static func teleport_actor(game: Node, source: Node2D, to: Vector2, radius: float, monster := false) -> Vector2:
	var backend := world(game)
	return backend.teleport_source_actor(source, to, radius, monster) if backend != null else to


static func launch_height(game: Node, at: Vector2, owner: Node2D = null) -> float:
	var backend := world(game)
	if backend != null and is_instance_valid(owner) and at.distance_to(owner.position) <= 36.0:
		var bodies: Dictionary = backend.actor_bodies
		if bodies.has(owner.get_instance_id()):
			var foot: Vector3 = backend.actor_foot(owner)
			return foot.y + PROJECTILE_LIFT
	return floor_at(game, at) + PROJECTILE_LIFT


static func wall_fraction(game: Node, from: Vector2, to: Vector2, height: float, radius_pixels := PROJECTILE_RADIUS) -> float:
	var backend := world(game)
	if backend == null:
		return 1.0
	backend.sync_scope()
	return clampf(float(backend.projectile_fraction(point(from, height), point(to, height), radius_pixels / HORIZONTAL_PIXELS)), 0.0, 1.0)


static func line_clear(game: Node, from: Vector2, to: Vector2, from_floor := INF, to_floor := INF) -> bool:
	var backend := world(game)
	if backend == null:
		return true
	backend.sync_scope()
	var a := floor_at(game, from) if is_inf(from_floor) else from_floor
	var b := floor_at(game, to) if is_inf(to_floor) else to_floor
	return float(backend.projectile_fraction(point(from, a + PROJECTILE_LIFT), point(to, b + PROJECTILE_LIFT), 0.015)) >= 0.9999


## Keep the authored horizontal range, adding the real vertical separation to its budget.
static func area_reaches(game: Node, from: Vector2, to: Vector2, radius: float, from_floor := INF) -> bool:
	if world(game) == null:
		return true
	var base := floor_at(game, from) if is_inf(from_floor) else from_floor
	var destination := floor_at(game, to)
	var rise := (destination - base) * HEIGHT_PIXELS
	return from.distance_squared_to(to) + rise * rise <= radius * radius + 0.001 and line_clear(game, from, to, base, destination)


## A sphere swept against the backend's exact vertical actor capsule, in its native space.
static func target_fraction(game: Node, from: Vector2, to: Vector2, height: float, target: Node2D, radius_pixels := PROJECTILE_RADIUS, target_radius := -1.0) -> float:
	var backend := world(game)
	if backend == null or not is_instance_valid(target):
		return INF
	if target is Chest:
		var chest := target as Chest
		if chest.dead:
			return INF
		return cylinder_fraction(point(from, height), point(to, height), point(chest.position, floor_at(game, chest.position)), SpatialWorld3D.radius_metres(Chest.COLLISION_RADIUS), EncounterGeometry3D.CHEST_COLLISION_HEIGHT, radius_pixels / HORIZONTAL_PIXELS)
	var bodies: Dictionary = backend.actor_bodies
	var foot: Vector3 = backend.actor_foot(target) if bodies.has(target.get_instance_id()) else point(target.position, floor_at(game, target.position))
	var resolved_radius: float = target_radius if target_radius >= 0.0 else (target as Enemy).radius if target is Enemy else 20.0
	var dimensions: Vector2 = backend.actor_dimensions(target, resolved_radius)
	var bottom := foot + Vector3(0, dimensions.x, 0)
	var top := foot + Vector3(0, dimensions.y - dimensions.x, 0)
	return capsule_fraction(point(from, height), point(to, height), bottom, top, dimensions.x + radius_pixels / HORIZONTAL_PIXELS)


## Swept sphere against the same finite upright chest cylinder used by native movement.
## Fixed-height projectiles have an exact horizontal-circle solution, including
## rounded rim contact. Sloped segments retain a convex-distance fallback.
static func cylinder_fraction(from: Vector3, to: Vector3, foot: Vector3, radius: float, height: float, projectile_radius: float) -> float:
	if is_equal_approx(from.y, to.y):
		var vertical := maxf(foot.y - from.y, maxf(from.y - foot.y - height, 0.0))
		if vertical > projectile_radius:
			return INF
		var reach := radius + sqrt(maxf(projectile_radius * projectile_radius - vertical * vertical, 0.0))
		var ground_center := Vector3(foot.x, 0, foot.z)
		return capsule_fraction(Vector3(from.x, 0, from.z), Vector3(to.x, 0, to.z), ground_center, ground_center, reach)
	var center := foot + Vector3.UP * height * 0.5
	var bound := sqrt(radius * radius + height * height * 0.25) + projectile_radius
	if is_inf(capsule_fraction(from, to, center, center, bound)):
		return INF
	var squared := projectile_radius * projectile_radius
	if _cylinder_distance_squared(from, foot, radius, height) <= squared:
		return 0.0
	var travel := to - from
	var low := 0.0
	var high := 1.0
	for iteration in 40:
		var left := lerpf(low, high, 1.0 / 3.0)
		var right := lerpf(low, high, 2.0 / 3.0)
		if _cylinder_distance_squared(from + travel * left, foot, radius, height) <= _cylinder_distance_squared(from + travel * right, foot, radius, height):
			high = right
		else:
			low = left
	var minimum := (low + high) * 0.5
	if _cylinder_distance_squared(from + travel * minimum, foot, radius, height) > squared + 0.0000000001:
		return INF
	low = 0.0
	high = minimum
	for iteration in 32:
		var middle := (low + high) * 0.5
		if _cylinder_distance_squared(from + travel * middle, foot, radius, height) <= squared + 0.0000000001:
			high = middle
		else:
			low = middle
	return high


static func _cylinder_distance_squared(at: Vector3, foot: Vector3, radius: float, height: float) -> float:
	var offset := at - foot
	var radial := maxf(Vector2(offset.x, offset.z).length() - radius, 0.0)
	var vertical := maxf(-offset.y, maxf(offset.y - height, 0.0))
	return radial * radial + vertical * vertical


static func capsule_fraction(from: Vector3, to: Vector3, bottom: Vector3, top: Vector3, radius: float) -> float:
	var nearest := Vector3(bottom.x, clampf(from.y, bottom.y, top.y), bottom.z)
	if from.distance_squared_to(nearest) <= radius * radius:
		return 0.0
	var travel := to - from
	var offset := from - bottom
	var a := travel.x * travel.x + travel.z * travel.z
	var b := 2.0 * (offset.x * travel.x + offset.z * travel.z)
	var c := offset.x * offset.x + offset.z * offset.z - radius * radius
	var fraction := INF
	if a > 0.0000001:
		var discriminant := b * b - 4.0 * a * c
		if discriminant >= 0.0:
			for root in [(-b - sqrt(discriminant)) / (2.0 * a), (-b + sqrt(discriminant)) / (2.0 * a)]:
				var y: float = from.y + travel.y * root
				if root >= 0.0 and root <= 1.0 and y >= bottom.y and y <= top.y:
					fraction = minf(fraction, root)
	for center in [bottom, top]:
		fraction = minf(fraction, _sphere_fraction(from, travel, center, radius))
	return fraction


static func _sphere_fraction(from: Vector3, travel: Vector3, center: Vector3, radius: float) -> float:
	var a := travel.length_squared()
	if a <= 0.0000001:
		return INF
	var offset := from - center
	var b := offset.dot(travel)
	var discriminant := b * b - a * (offset.length_squared() - radius * radius)
	if discriminant < 0.0:
		return INF
	var fraction := (-b - sqrt(discriminant)) / a
	return fraction if fraction >= 0.0 and fraction <= 1.0 else INF

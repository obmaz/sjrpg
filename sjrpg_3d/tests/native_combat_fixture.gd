extends RefCounted
## Collision-only native fixtures: source-map edits do not mutate a built World3D.


static func prism(parent: Node3D, polygon: PackedVector2Array, bottom := -2.0, top := 12.0) -> StaticBody3D:
	var points := PackedVector3Array()
	for at in polygon:
		points.append(SpatialWorld3D.native_point(at, bottom))
		points.append(SpatialWorld3D.native_point(at, top))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	return _body(parent, shape, Vector3.ZERO, SpatialWorld3D.SOLID)


static func box(parent: Node3D, at: Vector3, size: Vector3, layer: int) -> StaticBody3D:
	var shape := BoxShape3D.new()
	shape.size = size
	return _body(parent, shape, at, layer)


static func _body(parent: Node3D, shape: Shape3D, at: Vector3, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	body.position = at
	return body


static func settle(tree: SceneTree) -> void:
	await tree.physics_frame
	await tree.process_frame
	await tree.physics_frame
	await tree.process_frame


static func remove(bodies: Array) -> void:
	for body: StaticBody3D in bodies:
		body.collision_layer = 0
		body.queue_free()

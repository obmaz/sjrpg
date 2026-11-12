extends TestCase
## Billboard animation must preserve world corners/UVs while reusing GPU geometry.


func _corner_error(card: MeshInstance3D, basis: Basis, foot: Vector3, rect: Rect2) -> float:
	var factor := WorldSpace3D.GROUND_UNITS_PER_METER * WorldSpace3D.GROUND_PROJECTION_FACTOR
	var expected: Array[Vector3] = []
	for point: Vector2 in [rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]:
		expected.append(foot + basis.x * (point.x / factor) - basis.y * (point.y / factor))
	var arrays: Array = card.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var maximum := 0.0
	for vertex: Vector3 in vertices:
		var actual := card.global_transform * vertex
		var closest := INF
		for point: Vector3 in expected:
			closest = minf(closest, actual.distance_to(point))
		maximum = maxf(maximum, closest)
	return maximum


func run() -> void:
	# Keep the real card factory and placement path, without constructing gameplay.
	var renderer := WorldRenderer3D.new()
	var stage := Node3D.new()
	add_child(stage)
	renderer.stage = stage
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.rotation = Vector3(-0.6154797, 0.7853982, 0.0)
	renderer.camera = camera
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var frame := Rect2(2, 1, 4, 3)
	var card := renderer._new_card(texture, frame, true)
	var mesh := card.mesh as QuadMesh
	var initial_size := mesh.size
	var initial_rid := mesh.get_rid()
	var initial_arrays: Array = mesh.surface_get_arrays(0)
	var ink := card.material_override as ShaderMaterial
	var atlas_rect: Vector4 = ink.get_shader_parameter("atlas_rect")
	var changes: Array[int] = [0]
	mesh.changed.connect(func() -> void: changes[0] += 1)
	var maximum_error := 0.0
	for index in 128:
		var width := 20.0 + float(index % 19) * 11.0
		var height := 15.0 + float(index % 13) * 7.0
		var rect := Rect2(Vector2(-width * 0.35, -height * 0.7), Vector2(width, height))
		var angle := float(index) * 0.13
		var foot := Vector3(float(index) * 0.03, 1.5 + float(index % 7) * 0.2, -3.0)
		renderer._place_card(card, Vector2(10, 20), rect, angle, foot)
		var basis := camera.global_transform.basis * Basis(Vector3(0, 0, 1), -angle)
		maximum_error = maxf(maximum_error, _corner_error(card, basis, foot, rect))
	check("all animated billboard corners retain the original camera/angle/foot placement", maximum_error < 0.00002)
	check("varying card width and height never changes the primitive mesh size or RID",
		mesh.size == initial_size and mesh.get_rid() == initial_rid)
	check("animation reuses the original surface vertices, UVs, indices and normals",
		mesh.surface_get_arrays(0) == initial_arrays and changes[0] == 0)
	check("placement preserves the authored atlas UV rectangle and shader",
		ink.get_shader_parameter("atlas_rect") == atlas_rect and ink.shader != null)
	# Empty health fills remain valid collapsed geometry, without a zero-size mesh.
	var empty := Rect2(Vector2(4, -9), Vector2(0, 5))
	var empty_foot := Vector3(2, 3, 4)
	renderer._place_card(card, Vector2.ZERO, empty, 0.0, empty_foot)
	check("zero health width preserves its exact collapsed world corners",
		_corner_error(card, camera.global_transform.basis, empty_foot, empty) < 0.00002
		and mesh.size == initial_size and changes[0] == 0)
	stage.free()
	renderer.free()

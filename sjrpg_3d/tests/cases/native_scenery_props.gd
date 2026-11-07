extends TestCase
## Native scene geometry must leave the measured cave opening physically visible.
func run() -> void:
	for width in [1.4, 3.0, 4.0]:
		var mesh := NativeSceneryProps3D.arch_mesh(width, 4.0)
		var arrays := mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var valid := points.size() > 100 and normals.size() == points.size() and uv.size() == points.size()
		for i in range(0, points.size(), 3):
			var geometric := (points[i + 1] - points[i]).cross(points[i + 2] - points[i])
			valid = valid and geometric.length_squared() > 0.00000001 and geometric.dot(normals[i]) < 0.0
			valid = valid and absf((uv[i + 1] - uv[i]).cross(uv[i + 2] - uv[i])) > 0.00000001
		check("native arch has valid closed-volume normals, clockwise winding and full UV area", valid)
		var open := true
		for x in [-0.35, 0.0, 0.35]:
			for y in [0.1, 0.9, 1.7]:
				for i in range(0, points.size(), 3):
					open = open and Geometry3D.ray_intersects_triangle(Vector3(x, y, -4), Vector3.BACK, points[i], points[i + 1], points[i + 2]) == null
		check("native arch does not fill its capsule-clear central passage", open)
	var game := await make_game("mage")
	if game.ortho_preview == null:
		game._enable_ortho_preview()
	await _frames(3)
	var preview: Ortho3DPreview = game.ortho_preview
	var environment: Ortho3DEnvironment = preview._world_environment
	var forest := environment.forest.get_node("NativeFieldScenery")
	var report: Dictionary = forest.get_meta("native_scenery_report")
	var rock_count := 0
	var entrance_count := 0
	for entry: Dictionary in report["entries"]:
		if entry["role"] == "boulder":
			rock_count += 1
			var transform: Transform3D = entry["transform"]
			var point: Vector2 = entry["source_foot"]
			check("field rock keeps its original native foot", transform.origin.is_equal_approx(Ortho3DPreview.ground_position(point, preview.surface_height(point))))
		elif entry["role"] == "entrance":
			entrance_count += 1
			var transform: Transform3D = entry["transform"]
			var source_foot: Vector2 = entry["source_foot"]
			var body_centre := Ortho3DPreview.ground_position(source_foot + Vector2(0, -60))
			var native_mesh: ArrayMesh = entry["mesh"]
			var arrays := native_mesh.surface_get_arrays(0)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var fits_original_circle := not points.is_empty()
			var foundation_covers_body := false
			var radius := SpatialWorld3D.radius_metres(120.0)
			for point in points:
				var world := transform * point
				var distance := Vector2(world.x - body_centre.x, world.z - body_centre.z).length()
				fits_original_circle = fits_original_circle and distance <= radius + 0.002
				foundation_covers_body = foundation_covers_body or (is_equal_approx(point.y, 0.5) and distance >= radius - 0.002)
			check("field cave has volumetric cliff mass within the original circular blocker", fits_original_circle and foundation_covers_body and 0.50 > SpatialWorld3D.MAX_STEP)
			var backs := forest.find_children("TunnelDepth", "MeshInstance3D", true, false)
			check("field cave transition has actual dark tunnel depth behind its raised mouth", backs.size() == 1 and (backs[0].mesh as BoxMesh).size.z > 0.1)
	check("actual field rocks and the existing scene-transition cave mouth have native owners", rock_count > 0 and entrance_count == 1)
	game.player.position = game.dungeon.entry_point()
	await _frames(2)
	if check("existing cave entry remains playable", game.dungeon.enter()):
		preview._sync_scope()
		environment.sync(0, true)
		var cave := environment.cave.get_node("NativeCaveScenery")
		var cave_report: Dictionary = cave.get_meta("native_scenery_report")
		check("all six actual passage arches have native owners", cave_report["entries"].size() == 6 and cave_report["owned_source_ids"].size() == 6)
		for entry: Dictionary in cave_report["entries"]:
			var transform: Transform3D = entry["transform"]
			check("cave arch retains an upright positive native basis and measured opening", transform.basis.y.is_equal_approx(Vector3.UP) and transform.basis.determinant() > 0.99 and float(entry["clear_width"]) > 2.0)
		var cave_instance := cave.get_instance_id()
		game.dungeon.leave("")
		preview._sync_scope()
		environment.sync(0, true)
		check("leaving cave hides its native props without a scenery leak", not environment.cave.visible and cave.get_instance_id() == cave_instance)
	game.queue_free()
	await _frames(2)

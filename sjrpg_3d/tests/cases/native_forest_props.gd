extends TestCase
## Actual native owners must replace individual source cards and keep native floors.
func run() -> void:
	var library := NativeForestFlora3D.mesh_library()
	check("plant family contains four distinct shared lit meshes", library.size() == 4)
	for species: String in NativeForestFlora3D.SPECIES:
		var mesh: ArrayMesh = library[species]
		var box := mesh.get_aabb()
		var arrays := mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var valid := true
		for point in points:
			valid = valid and point.is_finite()
		for normal in normals:
			valid = valid and normal.is_finite() and normal.length_squared() > 0.8
		check("native plant has actual volume and finite normals " + species, valid and box.size.x > 0.1 and box.size.z > 0.05 and box.size.y > 0.8 and points.size() >= 100 and points.size() < 2000)
		var material := mesh.surface_get_material(0) as StandardMaterial3D
		check("plant receives actual scene light without a cutout texture " + species, material != null and material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL and material.albedo_texture == null)
	var game := await make_game("mage")
	if game.ortho_preview == null:
		game._enable_ortho_preview()
	await _frames(3)
	var preview: Ortho3DPreview = game.ortho_preview
	var environment: Ortho3DEnvironment = preview._world_environment
	var flora: Node3D = environment.forest.get_node("NativeBorderFlora")
	var report: Dictionary = flora.get_meta("native_flora_report")
	var count := 0
	for child in game.world.get_children():
		if child is IsoSprite and NativeForestFlora3D.accepts(child):
			count += 1
			check("supported original flora is owned exactly once", report["owned_source_ids"].has(child.get_instance_id()))
	check("native flora covers the authored close scene rather than a demo object", count > 200 and report["placements"].size() == count and report["groups"] <= count)
	for placement: Dictionary in report["placements"]:
		var transform: Transform3D = placement["transform"]
		var foot: Vector2 = placement["source_foot"]
		check("plant roots use actual native height and preserve uniform scale", transform.origin.is_equal_approx(Ortho3DPreview.ground_position(foot, preview.surface_height(foot))) and is_equal_approx(transform.basis.x.length(), transform.basis.y.length()) and is_equal_approx(transform.basis.y.length(), transform.basis.z.length()))
	var native_landmarks: Node3D = environment.forest.get_node("NativeLandmarks")
	var landmarks: Dictionary = native_landmarks.get_meta("native_landmark_report")
	check("all four landmark art cards have native source owners", landmarks["entries"].size() == 4 and landmarks["owned_source_ids"].size() == 4)
	for entry: Dictionary in landmarks["entries"]:
		var surface: Dictionary = entry["surface"]
		var faces: PackedVector3Array = entry["faces"]
		check("landmark top shares exact physics triangle source", faces == SpatialWorld3D.surface_faces(surface))
		check("landmark includes lit volume geometry", (entry["root"] as Node3D).get_child_count() >= 2)
	var children := environment.forest.get_child_count()
	environment.sync(0.0, true)
	environment.sync(0.0, true)
	check("pause does not rebuild vegetation or landmark geometry", children == environment.forest.get_child_count())
	game.queue_free()
	await _frames(2)

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
		for candidate in (entry["root"] as Node3D).find_children("*", "MeshInstance3D", true, false):
			var node := candidate as MeshInstance3D
			if not (str(node.name) == "CliffSides" or str(node.name).begins_with("WeatheredStone") or str(node.name) == "RootMound"):
				continue
			var arrays := node.mesh.surface_get_arrays(0)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var valid_uv := uv.size() == points.size()
			var clockwise := true
			var plane_normals := true
			var vertical_faces := 0
			for i in range(0, points.size(), 3):
				var geometric := (points[i + 1] - points[i]).cross(points[i + 2] - points[i])
				if geometric.length_squared() <= 0.00000001:
					continue
				var uv_a := uv[i + 1] - uv[i]
				var uv_b := uv[i + 2] - uv[i]
				valid_uv = valid_uv and absf(uv_a.cross(uv_b)) > 0.00000001
				clockwise = clockwise and geometric.dot(normals[i]) < 0.0
				var edge_a := (points[i + 1] - points[i]).normalized()
				var edge_b := (points[i + 2] - points[i]).normalized()
				for offset in 3:
					var normal := normals[i + offset]
					plane_normals = plane_normals and absf(normal.length() - 1.0) < 0.001 and absf(normal.dot(edge_a)) < 0.001 and absf(normal.dot(edge_b)) < 0.001
				if absf(normals[i].y) < 0.7:
					vertical_faces += 1
					for offset in [1, 2]:
						var point_delta := points[i + offset] - points[i]
						# Vertical UV height always follows metre Y at 2.56m/tile.
						valid_uv = valid_uv and is_equal_approx((uv[i + offset].y - uv[i].y) * 2.56, -point_delta.y)
			check("landmark all mapped triangles retain area and vertical metre density " + str(node.name), valid_uv and (vertical_faces > 0 or str(node.name) == "RootMound"))
			check("landmark tapered and broken face normals are perpendicular to the real triangle plane " + str(node.name), plane_normals)
			check("landmark winding is Godot clockwise with outward normals " + str(node.name), clockwise)
	var water_materials: Array = landmarks.get("water_materials", [])
	var clock: PlazaWater
	for child in game.village.fountain.get_children():
		if child is PlazaWater:
			clock = child
	if check("landmark water observes the existing fountain clock", clock != null and water_materials.size() == 3):
		var old_phase := clock.phase
		var old_reduced := Prefs.reduce_motion
		Prefs.reduce_motion = false
		clock.phase = 12.5
		NativeLandmarks3D.sync_water(environment.forest, game.village)
		var follows_source := true
		for material: ShaderMaterial in water_materials:
			follows_source = follows_source and is_equal_approx(float(material.get_shader_parameter("phase")), clock.phase) and material.get_shader_parameter("source_water") != null
		check("ponds and cascade use actual textured water at the original source phase", follows_source)
		environment.sync(25.0, true)
		var remains_paused := is_equal_approx(clock.phase, 12.5)
		for material: ShaderMaterial in water_materials:
			remains_paused = remains_paused and is_equal_approx(float(material.get_shader_parameter("phase")), 12.5)
		check("paused environment delta cannot advance the shared water source", remains_paused)
		Prefs.reduce_motion = true
		NativeLandmarks3D.sync_water(environment.forest, game.village)
		var reduced := true
		for material: ShaderMaterial in water_materials:
			reduced = reduced and is_zero_approx(float(material.get_shader_parameter("phase"))) and is_zero_approx(float(material.get_shader_parameter("motion")))
		check("reduced motion freezes landmark waves and texture drift", reduced)
		Prefs.reduce_motion = old_reduced
		clock.phase = old_phase
		NativeLandmarks3D.sync_water(environment.forest, game.village)
	var waterfall := native_landmarks.get_node("Landmark3/FallingWater") as MeshInstance3D
	var shores: Array = waterfall.get_meta("source_shores")
	var waterfall_source: Landmark = game.village.landmarks[3]
	var old_span := Ortho3DPreview.ground_position(Iso.poly_bounds(waterfall_source.water[0]).get_center()).distance_squared_to(Ortho3DPreview.ground_position(Iso.poly_bounds(waterfall_source.water[1]).get_center()))
	var new_span := Ortho3DPreview.ground_position(shores[0]).distance_squared_to(Ortho3DPreview.ground_position(shores[1]))
	check("cascade connects the actual nearest shores instead of crossing both pond centres", new_span < old_span)
	var children := environment.forest.get_child_count()
	environment.sync(0.0, true)
	environment.sync(0.0, true)
	check("pause does not rebuild vegetation or landmark geometry", children == environment.forest.get_child_count())
	game.player.position = game.dungeon.entry_point()
	await _frames(2)
	if game.dungeon.enter():
		preview._sync_scope()
		environment.sync(0.0, true)
		check("authored cave lanterns have native volume owners and existing lights", int(environment.report["native_cave_lanterns"]) == 10 and environment._cave_lights.size() == 10 and environment.cave.get_node("NativeCaveLanterns").get_child_count() == 10)
		for record: Dictionary in environment.report["remaining_sources"]["cave"]:
			check("converted cave lamp never remains in a card bucket", str(record["role"]) != "lantern")
	game.queue_free()
	await _frames(2)

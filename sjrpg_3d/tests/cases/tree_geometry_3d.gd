extends TestCase
## Actual native mesh provenance, projected size, root contact and fixed leaf shadows.


func run() -> void:
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/vegetation/shared/tree_profiles.json"))
	var generation: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/source/vegetation/town_trees/generation.json"))
	var source: Dictionary = generation["preserved_source"]
	check("native trees bind the shared materials without embedded duplicate images", not record["packaging"]["embedded_images"] and record["packaging"]["export_texcoords"])
	check("leaf source retains actual generated pixels", FileAccess.get_sha256("res://" + str(source["path"])) == source["sha256"])
	var leaf: Dictionary = generation["runtime_leaf"]
	check("runtime leaves match the recorded mechanical texture pack", FileAccess.get_sha256("res://" + str(leaf["path"])) == leaf["sha256"])
	for variant: Dictionary in record["variants"]:
		check("native tree mesh matches its generated-material provenance", FileAccess.get_sha256("res://" + str(variant["path"])) == variant["sha256"])
		check("native tree stays within the web geometry budget", int(variant["triangles"]) < 5000 and int(variant["branches"]) >= 40 and int(variant["leaf_sprays"]) >= 100 and not variant["billboard"])
	var game := await make_game("mage")
	game._create_world_renderer()
	await _frames(2)
	var renderer: WorldRenderer3D = game.world_renderer
	var trees: Node3D = renderer._trees
	if not check("the actual native forest owns its single tree replacement group", is_instance_valid(trees) and renderer._world_environment.forest.is_ancestor_of(trees) and renderer.stage.find_children("NativeTownTrees", "Node3D", true, false).size() == 1):
		game.queue_free()
		await _frames(2)
		return
	var report: Dictionary = trees.get_meta("native_tree_report")
	check("all existing town trees receive native replacements", report["trees"].size() == game.village.town_trees.size() and report["trees"].size() > 2)
	check("native trees share bounded species mesh groups", int(report["groups"]) <= TreeGeometry3D.PATHS.size() and not report["billboards"])
	check("native tree width and canopy top match original measured sprite size", float(report["max_fit_error"]) < 0.0001)
	var roots_match := true
	var materials_valid := true
	var volume := true
	for entry: Dictionary in report["trees"]:
		var original: IsoSprite = entry["source"].get_ref()
		var position: Vector3 = entry["position"]
		roots_match = roots_match and position.distance_to(WorldSpace3D.projected_to_world(original.position)) < 0.00001 and absf(position.y) < 0.00001
	for child: Node in trees.get_children():
		if not child is MultiMeshInstance3D:
			continue
		var batch := child as MultiMeshInstance3D
		materials_valid = materials_valid and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var mesh: Mesh = batch.multimesh.mesh
		var points := PackedVector3Array()
		var leaf_found := false
		var bark_found := false
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			points.append_array(vertices)
			var material := mesh.surface_get_material(surface) as StandardMaterial3D
			materials_valid = materials_valid and material != null and material.albedo_texture != null and material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED
			if material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
				leaf_found = true
				materials_valid = materials_valid and material.cull_mode == BaseMaterial3D.CULL_DISABLED and material.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED
			else:
				bark_found = true
		materials_valid = materials_valid and leaf_found and bark_found
		var bounds := mesh.get_aabb()
		volume = volume and bounds.size.x > 1.0 and bounds.size.z > 1.0 and bounds.size.y > 3.5 and absf(bounds.position.y) < 0.001
		for yaw in [0.0, PI * 0.5, PI, PI * 1.5]:
			var fit := TreeGeometry3D.fit_basis(points, 4.5, 4.2, yaw)
			var projected := TreeGeometry3D.projected_bounds(points, fit)
			check("projected full mesh keeps measured size after quarter turn", absf(projected.size.x - 4.5) < 0.0001 and absf(projected.position.y + 4.2) < 0.0001 and fit.determinant() > 0.0)
	check("tree roots preserve source ground position and collision ownership", roots_match)
	check("both variants have real depth and root contact", volume)
	check("leaves use lit double sided cutout surfaces with real shadow casting", materials_valid)
	game.queue_free()
	await _frames(2)

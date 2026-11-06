extends TestCase
## Actual outer tree ownership, complete crown culling, stable layout and native floors.


func run() -> void:
	var recipe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Ortho3DForestTrees.RECIPE))
	check("forest tree recipe pins its existing mesh and material provenance", recipe["mesh_provenance"] == "assets/art/preview3d/town-trees.json" and recipe["material_provenance"] == "assets/source/preview3d/trees/generation.json" and not recipe["new_generated_pixels"])
	var game := await make_game("mage")
	if game.ortho_preview == null:
		game._enable_ortho_preview()
	await _frames(2)
	var preview: Ortho3DPreview = game.ortho_preview
	var environment: Ortho3DEnvironment = preview._world_environment
	var root := environment.forest.get_node_or_null("NativeForestTrees") as Node3D
	if not check("native forest owns one explicit outer-tree group", root != null and environment.forest.find_children("NativeForestTrees", "Node3D", true, false).size() == 1):
		game.queue_free()
		await _frames(2)
		return
	var report: Dictionary = root.get_meta("native_forest_tree_report")
	var layout: Dictionary = root.get_meta("native_forest_tree_layout")
	var selected := Ortho3DForestTrees.sources(game.world, game.village.town_trees)
	check("all 260 outer trees own real replacements instead of source cards", selected.size() >= 260 and report["trees"].size() == selected.size() and int(environment.report["native_forest_trees"]) == selected.size())
	check("the placement audit contains every source-sized native transform", layout["placements"].size() == selected.size() and not JSON.stringify(layout).is_empty())
	check("forest uses bounded spatial chunks instead of one forest-wide AABB", int(report["chunks"]) > 4 and int(report["groups"]) <= int(report["chunks"]) * 2 and float(report["chunk_metres"]) == 16.0)
	check("full native crowns keep measured source width and canopy top", float(report["max_fit_error"]) < 0.0001 and not report["billboards"])
	var ownership := true
	for tree: IsoSprite in game.village.town_trees:
		ownership = ownership and not report["owned_source_ids"].has(tree.get_instance_id())
	for tree: IsoSprite in selected:
		ownership = ownership and report["owned_source_ids"].has(tree.get_instance_id())
		# No fallback batch may still draw this source atlas after all instances succeeded.
		ownership = ownership and environment.forest.get_node_or_null("ForestArt_%d" % tree.texture.get_instance_id()) == null
	check("replacement ownership excludes town and prevents duplicate forest tree cards", ownership)
	var library := Ortho3DTrees.mesh_library()
	var roots_match := true
	var collisions_match := true
	var bounds_match := true
	var sharing := true
	var variation := {}
	var keys := {}
	for entry: Dictionary in report["trees"]:
		var source: IsoSprite = entry["source"].get_ref()
		var batch: MultiMeshInstance3D = entry["batch"]
		var transform: Transform3D = entry["transform"]
		var local: Transform3D = entry["local_transform"]
		var position: Vector3 = entry["position"]
		var actual_floor := preview.surface_height(source.global_position)
		roots_match = roots_match and position.distance_to(Ortho3DPreview.ground_position(source.global_position, actual_floor)) < 0.00001
		roots_match = roots_match and (batch.position + local.origin).distance_to(transform.origin) < 0.00001 and transform.basis.determinant() > 0.0
		var source_radius := Ortho3DForestTrees._collision_radius(source, game.village.circles)
		collisions_match = collisions_match and source_radius > 0.0 and is_equal_approx(float(entry["collision_radius_pixels"]), source_radius) and is_equal_approx(float(entry["collision_radius_metres"]), SpatialWorld3D.radius_metres(source_radius))
		var variant := int(entry["variant"])
		sharing = sharing and batch.multimesh.mesh == library[variant]["mesh"] and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var points: PackedVector3Array = library[variant]["points"]
		for point in points:
			if not batch.multimesh.custom_aabb.has_point(local * point):
				bounds_match = false
				break
		variation[variant] = true
		keys[entry["key"]] = true
	check("every root follows native ground and retains the original trunk collision", roots_match and collisions_match)
	check("chunk AABBs contain every branch, root and full crown vertex", bounds_match)
	check("all chunks share only the two approved shadow-casting native meshes", sharing and variation.size() == 2 and keys.size() == selected.size())
	var town_report: Dictionary = preview._trees.get_meta("native_tree_report")
	var town_shared := true
	for entry: Dictionary in town_report["trees"]:
		var mesh: Mesh = entry["batch"].multimesh.mesh
		town_shared = town_shared and (mesh == library[0]["mesh"] or mesh == library[1]["mesh"])
	check("town and outer forest share native mesh and lit material resources", town_shared)
	# Fresh nodes and changed child order must not change persistent source-key variation.
	var fixture := Node2D.new()
	game.add_child(fixture)
	var original: IsoSprite = selected[0]
	var copy := IsoSprite.new().setup(original.def, float(original.def["world_height"]))
	copy.position = original.global_position
	copy.flip = original.flip
	fixture.add_child(copy)
	check("placement seed ignores transient node identity and child order", Ortho3DForestTrees.source_key(copy) == Ortho3DForestTrees.source_key(original) and Ortho3DForestTrees.placement_seed(Ortho3DForestTrees.source_key(copy)) == Ortho3DForestTrees.placement_seed(Ortho3DForestTrees.source_key(original)))
	# Move onto an actual raised native floor before constructing the test replacement.
	var surface: Dictionary = SpatialWorld3D.terrain_surfaces(game.village)[0]
	var polygon: PackedVector2Array = surface["top"]
	var center := Vector2.ZERO
	for point in polygon:
		center += point
	copy.position = center / float(polygon.size())
	var unsupported := IsoSprite.new().setup(original.def, float(original.def["world_height"]))
	unsupported.position = copy.position + Vector2(2.0, 0.0)
	unsupported.clip = Vector2(1.0, 2.0)
	fixture.add_child(unsupported)
	var circles_before: Array = game.village.circles.duplicate(true)
	var trial := Ortho3DForestTrees.build(preview, environment.forest, fixture)
	var trial_report: Dictionary = trial.get_meta("native_forest_tree_report")
	var trial_trees: Array = trial_report["trees"]
	check("unsupported source cards retain fallback ownership", int(trial_report["source_count"]) == 2 and trial_trees.size() == 1 and trial_report["owned_source_ids"].has(copy.get_instance_id()) and not trial_report["owned_source_ids"].has(unsupported.get_instance_id()))
	var elevated := false
	if trial_trees.size() == 1:
		var position: Vector3 = trial_trees[0]["position"]
		elevated = position.y > 0.1 and absf(position.y - preview.surface_height(copy.global_position)) < 0.00001
	check("raised forest roots use actual terrain height rather than constant Y zero", elevated)
	check("native tree visual replacement never rewrites simulation circles", circles_before == game.village.circles)
	trial.free()
	fixture.free()
	game.player.position = game.dungeon.entry_point()
	await _frames(2)
	var entered: bool = game.dungeon.enter()
	check("existing cave remains available after native tree replacement", entered)
	if entered:
		preview._sync_scope()
		environment.sync(0.0, true)
		check("outer tree geometry is hidden with the forest in cave", not root.is_visible_in_tree() and environment.cave.visible)
		game.dungeon.leave("")
		preview._sync_scope()
		environment.sync(0.0, true)
		check("return reuses the same native forest tree group", root.is_visible_in_tree() and environment.forest.get_node("NativeForestTrees") == root)
	game.queue_free()
	await _frames(2)

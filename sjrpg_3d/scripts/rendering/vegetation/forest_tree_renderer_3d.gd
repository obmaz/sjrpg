class_name ForestTreeRenderer3D
extends RefCounted
## Native outer forest only. Source nodes still own simulation/collision; this helper
## owns successful visual replacements, grouped by mesh and small spatial cells.

const SHEET := "forest-isometric-trees"
const CHUNK_METRES := 16.0
const RECIPE := "res://assets/data/native_forest_trees.json"


static func source_key(tree: IsoSprite) -> String:
	# FNV-1a below is explicit rather than relying on runtime instance IDs or RNG.
	# Six decimal source pixels is finer than physics precision in this field.
	return "%s|%s|%.6f,%.6f|%d" % [tree.def.get("sheet", ""), str(tree.def.get("source", [])), tree.global_position.x, tree.global_position.y, int(tree.flip)]


static func placement_seed(key: String) -> int:
	var value := 2166136261
	for byte in key.to_utf8_buffer():
		value = ((value ^ int(byte)) * 16777619) & 0xffffffff
	return value


static func sources(world: Node2D, town_trees: Array) -> Array[IsoSprite]:
	var town := {}
	for tree: IsoSprite in town_trees:
		if is_instance_valid(tree):
			town[tree.get_instance_id()] = true
	var result: Array[IsoSprite] = []
	for child in world.get_children():
		if child is IsoSprite and not child.is_queued_for_deletion() and not town.has(child.get_instance_id()) and child.def.get("sheet", "") == SHEET:
			result.append(child)
	# Stable ordering also keeps GPU instance indices stable if child order changes.
	result.sort_custom(func(a: IsoSprite, b: IsoSprite) -> bool: return source_key(a) < source_key(b))
	return result


static func _collision_radius(tree: IsoSprite, circles: Array) -> float:
	for circle: Array in circles:
		var point: Vector2 = circle[0]
		if point.distance_squared_to(tree.global_position) < 0.000001:
			return float(circle[1])
	return -1.0


static func _v3(point: Vector3) -> Array:
	return [point.x, point.y, point.z]


static func _basis_record(value: Basis) -> Array:
	return [_v3(value.x), _v3(value.y), _v3(value.z)]


static func build(renderer: Node, parent: Node3D, world: Node2D) -> Node3D:
	var root := Node3D.new()
	root.name = "NativeForestTrees"
	parent.add_child(root)
	var library := TreeGeometry3D.mesh_library()
	var selected := sources(world, renderer.game.village.town_trees)
	var factor: float = WorldRenderer3D.GROUND_PER_METER * WorldRenderer3D.PROJECTION_FACTOR
	var buckets := {}
	var report := {"trees": [], "owned_source_ids": {}, "source_count": selected.size(), "groups": 0, "chunks": 0, "chunk_metres": CHUNK_METRES, "triangles_per_tree": 4358, "billboards": false, "max_fit_error": 0.0, "recipe": RECIPE}
	var record := {"recipe": RECIPE, "chunk_metres": CHUNK_METRES, "placements": []}
	for tree: IsoSprite in selected:
		# Partial/unknown future source definitions retain their authored card.
		if not tree.def.has("source") or not tree.def.has("foot") or tree.clip != Vector2.ZERO or tree.draw_shift != Vector2.ZERO:
			continue
		var key := source_key(tree)
		var seed := placement_seed(key)
		var variant := seed % TreeGeometry3D.PATHS.size()
		var mesh := library[variant]["mesh"] as Mesh
		var points: PackedVector3Array = library[variant]["points"]
		if mesh == null or points.is_empty():
			continue
		var frame: Array = tree.def["source"]
		var foot: Array = tree.def["foot"]
		var width := float(frame[2]) * tree.k / factor * TreeGeometry3D.crown_ratio(variant)
		var top := (float(foot[1]) - float(frame[1])) * tree.k / factor
		if width <= 0.0 or top <= 0.0:
			continue
		var yaw := float((seed >> 1) & 0xffffff) / 16777216.0 * TAU
		var basis := TreeGeometry3D.fit_basis(points, width, top, yaw)
		var crown := TreeGeometry3D.projected_bounds(points, basis)
		var fit_error := maxf(absf(crown.size.x - width), absf(crown.position.y + top))
		if not is_finite(basis.determinant()) or basis.determinant() <= 0.0 or fit_error > 0.001:
			continue
		# Read the actual native floor. Do not infer height from screen y or assume Y=0.
		var point := tree.global_position
		var position := WorldRenderer3D.ground_position(point, renderer.surface_height(point))
		var chunk := Vector2i(floori(position.x / CHUNK_METRES), floori(position.z / CHUNK_METRES))
		var bucket_key := "%d,%d:%d" % [chunk.x, chunk.y, variant]
		if not buckets.has(bucket_key):
			buckets[bucket_key] = {"chunk": chunk, "variant": variant, "mesh": mesh, "entries": []}
		var radius := _collision_radius(tree, renderer.game.village.circles)
		var entry := {"source": weakref(tree), "key": key, "variant": variant, "yaw": yaw, "position": position, "transform": Transform3D(basis, position), "target_width": width, "target_top": top, "projected_bounds": crown, "fit_error": fit_error, "collision_radius_pixels": radius, "collision_radius_metres": SpatialWorld3D.radius_metres(radius) if radius >= 0.0 else -1.0, "tint": tree.modulate_color * tree.modulate * tree.self_modulate}
		buckets[bucket_key]["entries"].append(entry)
		report["max_fit_error"] = maxf(float(report["max_fit_error"]), fit_error)
		# A JSON-safe complete placement audit, including the full source sizing recipe.
		record["placements"].append({"key": key, "source_frame": frame.duplicate(), "source_foot": foot.duplicate(), "source_k": tree.k, "source_flip": tree.flip, "crown_ratio": TreeGeometry3D.crown_ratio(variant), "source_position": [point.x, point.y], "variant": variant, "mesh": TreeGeometry3D.PATHS[variant], "yaw": yaw, "position": _v3(position), "basis": _basis_record(basis), "width": width, "top": top, "collision_radius_pixels": radius})
	var chunks := {}
	for key: String in buckets:
		var bucket: Dictionary = buckets[key]
		var chunk: Vector2i = bucket["chunk"]
		var origin := Vector3(float(chunk.x) * CHUNK_METRES, 0.0, float(chunk.y) * CHUNK_METRES)
		var entries: Array = bucket["entries"]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = bucket["mesh"]
		multi.instance_count = entries.size()
		var batch := MultiMeshInstance3D.new()
		batch.name = "ForestOak_%d_%d_V%d" % [chunk.x, chunk.y, int(bucket["variant"])]
		batch.set_meta("occlusion_static_instances", true)
		batch.position = origin
		batch.multimesh = multi
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(batch)
		var bounds := AABB()
		for index in entries.size():
			var entry: Dictionary = entries[index]
			var transform: Transform3D = entry["transform"]
			transform.origin -= origin
			multi.set_instance_transform(index, transform)
			multi.set_instance_color(index, entry["tint"])
			# Transform the complete mesh AABB, not just the trunk/cell rectangle.
			var crown_bounds: AABB = transform * multi.mesh.get_aabb()
			bounds = crown_bounds if index == 0 else bounds.merge(crown_bounds)
			entry["batch"] = batch
			entry["index"] = index
			entry["local_transform"] = transform
			report["trees"].append(entry)
			var source: IsoSprite = entry["source"].get_ref()
			report["owned_source_ids"][source.get_instance_id()] = true
		# Tiny roundoff margin; this includes raised roots and every transformed crown.
		multi.custom_aabb = bounds.grow(0.02)
		batch.set_meta("chunk", chunk)
		chunks[chunk] = true
	report["groups"] = buckets.size()
	report["chunks"] = chunks.size()
	WildVegetationRenderer3D.build_shrubs(renderer, root, selected)
	root.set_meta("native_forest_tree_report", report)
	root.set_meta("native_forest_tree_layout", record)
	return root

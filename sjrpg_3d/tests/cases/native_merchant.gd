extends TestCase
## Verify the imported merchant scene itself, then its real Villager runtime ownership.

func _pose(skeleton: Skeleton3D) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for index: int in skeleton.get_bone_count():
		result.append(skeleton.get_bone_pose(index))
	return result


func _changed(first: Array[Transform3D], second: Array[Transform3D]) -> bool:
	if first.size() != second.size():
		return true
	for index: int in first.size():
		if not first[index].is_equal_approx(second[index]):
			return true
	return false


func run() -> void:
	if not check("merchant runtime asset is the real imported scene", ResourceLoader.exists(ResidentRenderer3D.IMPORTED_MERCHANT)):
		return
	var model: Node3D = ResidentRenderer3D.create("merchant")
	if not check("merchant factory creates the imported root", model != null):
		return
	add_child(model)
	await _frames(2)
	check("merchant has no unused procedural substitute", ResidentRenderer3D.build("merchant") == null and str(model.get_meta("resident_source", "")) == "cc0_import" and str(model.get_meta("resident_asset", "")) == ResidentRenderer3D.IMPORTED_MERCHANT)
	check("unmapped residents remain unmapped", ResidentRenderer3D.create("unknown") == null)
	check("imported root has baked unit scale", model.scale.is_equal_approx(Vector3.ONE))
	var bounds: AABB = ResidentRenderer3D.local_bounds(model)
	check("merchant soles use the shared actor ground pivot", absf(bounds.position.y) <= 0.015)
	check("bareheaded merchant has the measured adult height", absf(bounds.size.y - 1.78) <= 0.04 and bounds.size.x > 0.3 and bounds.size.z > 0.15)
	var meshes: Array[MeshInstance3D] = ModelTree3D.meshes_including_root(model)
	var skinned := false
	var triangles := 0
	for mesh: MeshInstance3D in meshes:
		skinned = skinned or mesh.skin != null
		if not check("imported resident material is light-responsive", mesh.mesh != null):
			continue
		for surface: int in mesh.mesh.get_surface_count():
			var material: Material = mesh.get_active_material(surface)
			var standard: StandardMaterial3D = material as StandardMaterial3D
			check("imported surfaces use actual lit materials", standard != null and standard.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL)
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
	check("merchant is a real skinned mesh within the pilot mobile budget", skinned and triangles > 500 and triangles <= 18000)
	check("visual import creates no physics body", model.find_children("*", "CollisionObject3D", true, false).is_empty())
	print("ART_AUDIT imported_merchant " + JSON.stringify({"bounds": str(bounds), "meshes": meshes.size(), "triangles": triangles}))
	var animator: AnimationPlayer = ResidentRenderer3D.idle_player(model)
	var skeleton: Skeleton3D = ModelTree3D.first_skeleton(model)
	if not check("import retains a real skeleton and AnimationPlayer", animator != null and skeleton != null and skeleton.get_bone_count() >= 20):
		model.queue_free()
		await _frames(2)
		return
	check("imported animation has no independent playback clock", animator.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL and animator.autoplay.is_empty() and is_zero_approx(animator.playback_default_blend_time))
	var first_sample: Dictionary = ResidentRenderer3D.sample_idle(model, 0.0)
	if not check("actual imported idle clip is present", not str(first_sample.get("clip", "")).is_empty()):
		model.queue_free()
		await _frames(2)
		return
	var clip: Animation = animator.get_animation(str(first_sample["clip"]))
	var before: Array[Transform3D] = _pose(skeleton)
	ResidentRenderer3D.sample_idle(model, clip.length * 0.37)
	check("manual source-clock sampling changes actual bone transforms", _changed(before, _pose(skeleton)))
	var held: Array[Transform3D] = _pose(skeleton)
	var held_position: float = animator.current_animation_position
	await _frames(3)
	check("frames alone never advance the imported idle", not _changed(held, _pose(skeleton)) and is_equal_approx(animator.current_animation_position, held_position))
	model.queue_free()
	await _frames(2)
	var game: Node = await make_game("mage")
	await _frames(3)
	var renderer: ResidentRenderer3D = game.world_renderer._resident_renderer
	renderer.sync()
	var merchant: Villager
	for candidate: Villager in game.village.npc_nodes.values():
		if NpcArt.identity(candidate.display_name) == "merchant":
			merchant = candidate
			break
	if not check("real village merchant owns the imported pilot", merchant != null and renderer.entries.has(merchant.get_instance_id())):
		game.queue_free()
		await _frames(2)
		return
	var entry: Dictionary = renderer.entries[merchant.get_instance_id()]
	var resident_model: Node3D = entry["node"]
	var resident_animation: AnimationPlayer = entry["animation"]
	var resident_skeleton: Skeleton3D = entry["skeleton"]
	if not check("runtime and gallery share the actual imported factory", str(entry["source"]) == "cc0_import" and resident_animation != null and resident_skeleton != null):
		game.queue_free()
		await _frames(2)
		return
	check("merchant has no duplicate 2D camera card", not game.world_renderer._cards.has(merchant.get_instance_id()))
	var bodies: int = game.spatial_world.actor_bodies.size()
	var source_clock: float = merchant._time
	var source_pose: Array[Transform3D] = _pose(resident_skeleton)
	await _frames(5)
	renderer.sync()
	check("original resident clock drives real imported bone motion", merchant._time > source_clock and _changed(source_pose, _pose(resident_skeleton)))
	get_tree().paused = true
	var pause_clock: float = merchant._time
	var pause_sample: float = resident_animation.current_animation_position
	var pause_pose: Array[Transform3D] = _pose(resident_skeleton)
	await _frames(4)
	renderer.sync()
	check("pause freezes source clock, imported time and bone pose", is_equal_approx(merchant._time, pause_clock) and is_equal_approx(resident_animation.current_animation_position, pause_sample) and not _changed(pause_pose, _pose(resident_skeleton)))
	get_tree().paused = false
	var base_materials: Array[Material] = []
	var runtime_meshes: Array[MeshInstance3D] = entry["meshes"]
	for mesh: MeshInstance3D in runtime_meshes:
		for surface: int in mesh.mesh.get_surface_count():
			base_materials.append(mesh.get_active_material(surface))
	merchant.show_hurt()
	renderer.sync()
	for mesh: MeshInstance3D in runtime_meshes:
		check("all imported body parts share original injury feedback", mesh.material_overlay != null and is_equal_approx(float((mesh.material_overlay as ShaderMaterial).get_shader_parameter("flash_strength")), merchant._hurt_flash * 0.65))
	merchant._hurt_flash = 0.0
	renderer.sync()
	var material_index := 0
	for mesh: MeshInstance3D in runtime_meshes:
		check("imported injury clears without changing base materials", mesh.material_overlay == null)
		for surface: int in mesh.mesh.get_surface_count():
			check("shared imported materials are not mutated by the overlay", mesh.get_active_material(surface) == base_materials[material_index])
			material_index += 1
	var old_position: Vector2 = merchant.position
	merchant.position += Vector2(12, -8)
	merchant.facing += 0.2
	renderer.sync()
	check("imported actor follows original feet and facing", resident_model.position.is_equal_approx(game.world_renderer.actor_foot(merchant)) and resident_model.scale.is_equal_approx(Vector3.ONE))
	merchant.position = old_position
	merchant.visible = false
	renderer.sync()
	check("local resident visibility controls the imported model", not resident_model.visible)
	merchant.visible = true
	game.dungeon.active = true
	renderer.sync()
	check("town merchant disappears in dungeon scope", not resident_model.visible)
	game.dungeon.active = false
	renderer.sync()
	check("scope restoration keeps the same model and original physics ownership", resident_model.visible and renderer.entries[merchant.get_instance_id()]["node"] == resident_model and game.spatial_world.actor_bodies.size() == bodies)
	var old_id: int = merchant.get_instance_id()
	for key: Variant in game.village.npc_nodes.keys():
		if game.village.npc_nodes[key] == merchant:
			game.village.npc_nodes.erase(key)
			break
	merchant.queue_free()
	await _frames(2)
	renderer.sync()
	await _frames(2)
	check("removed resident releases its imported model and owner entry", not renderer.entries.has(old_id) and not is_instance_valid(resident_model))
	game.queue_free()
	await _frames(2)

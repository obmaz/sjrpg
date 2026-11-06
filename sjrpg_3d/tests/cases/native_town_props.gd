extends TestCase
## Real imported models share source footprints, clocks and realm lifecycle.


func _phase(source: IsoSprite) -> PlazaWater:
	for child in source.get_children():
		if child is PlazaWater:
			return child
	return null


func _centre(footprint: PackedVector2Array) -> Vector2:
	var centre := Vector2.ZERO
	for point in footprint:
		centre += point
	return centre / footprint.size()


func _check_geometry(entry: Dictionary, expected_triangles: int, expected_surfaces: int, size: Vector3) -> void:
	var root: Node3D = entry["root"]
	var triangles := 0
	var surfaces := 0
	var bounds := AABB()
	var first := true
	var bindings := true
	for candidate in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := candidate as MeshInstance3D
		var local := root.global_transform.affine_inverse() * mesh.global_transform
		var box: AABB = local * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		for index in mesh.mesh.get_surface_count():
			triangles += mesh.mesh.surface_get_array_index_len(index) / 3
			surfaces += 1
		bindings = bindings and mesh.material_override != null and mesh.scale.is_equal_approx(Vector3.ONE)
		if mesh.name == "limestone":
			bindings = bindings and mesh.material_override == _preview_material("stone")
		elif mesh.name == "timber":
			bindings = bindings and mesh.material_override == _preview_material("wood")
	check("%s imports actual bounded volume and baked scale" % root.name, not first and bounds.position.y >= -0.001 and bounds.size.is_equal_approx(size) and root.scale.is_equal_approx(Vector3.ONE))
	check("%s retains its actual triangle/surface budget and shared bindings" % root.name, triangles == expected_triangles and surfaces == expected_surfaces and bindings)
	check("%s introduces no extra physics blockers" % root.name, root.find_children("*", "CollisionObject3D", true, false).is_empty())


func _preview_material(key: String) -> Material:
	return (_current_preview._town_props as NativeTownProps3D)._materials[key]


var _current_preview: Ortho3DPreview


func run() -> void:
	var old_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var game := await make_game()
	game.set_process(false)
	game.player.set_process(false)
	game.encounters.set_process(false)
	var preview: Ortho3DPreview = game.ortho_preview
	_current_preview = preview
	var props: NativeTownProps3D = preview._town_props
	props.sync()
	var fountain: IsoSprite = game.village.fountain
	var fountain_polygon := fountain.atlas_polygon(game.village.data["frames"]["pool"]["ground"])
	var footprint_before := fountain_polygon.duplicate()
	check("native fountain and every forest warp role replace their own source only", props.owns(fountain) and props._entries.size() == game.village.portal_sprites.size() + 2)
	var fountain_entry: Dictionary = props._entries[fountain.get_instance_id()]
	_check_geometry(fountain_entry, 3612, 3, NativeTownProps3D.FOUNTAIN_SIZE)
	var portal: IsoSprite = game.village.portal_sprites["town"]
	var portal_entry: Dictionary = props._entries[portal.get_instance_id()]
	_check_geometry(portal_entry, 1883, 4, NativeTownProps3D.PORTAL_SIZE)
	var mote: MultiMeshInstance3D = portal_entry["motes"]
	check("portal uses one bounded shared mote mesh", mote.multimesh.instance_count == NativeTownProps3D.MOTE_COUNT and mote.multimesh.mesh == props._mote_mesh)
	var centre := _centre(fountain_polygon)
	var expected := Ortho3DPreview.ground_position(centre, preview.surface_height(centre))
	check("fountain uses measured base centre rather than its front source-foot pivot", (fountain_entry["root"] as Node3D).position.is_equal_approx(expected) and not expected.is_equal_approx(Ortho3DPreview.ground_position(fountain.position)))
	preview._affordances.sync()
	for source in game.village.portal_sprites.values():
		check("a native gate has no duplicate fallback art card", props.owns(source) and not preview._affordances._art.has(source.get_instance_id()))
	var clock := _phase(fountain)
	clock._process(0.2)
	props.sync()
	var ink: ShaderMaterial = fountain_entry["fluid"]
	check("native water follows the original source clock", is_equal_approx(float(ink.get_shader_parameter("phase")), clock.phase))
	var portal_clock := _phase(portal)
	portal_clock._process(0.3)
	props.sync()
	var portal_ink: ShaderMaterial = portal_entry["fluid"]
	check("portal swirl observes its own actual source clock", is_equal_approx(float(portal_ink.get_shader_parameter("phase")), portal_clock.phase))
	var portal_held := portal_clock.phase
	var held := clock.phase
	get_tree().paused = true
	await _frames(2)
	props.sync()
	check("paused native water preserves its source phase", clock.phase == held and is_equal_approx(float(ink.get_shader_parameter("phase")), held))
	check("paused portal swirl and mote phase remain frozen", portal_clock.phase == portal_held and is_equal_approx(float(portal_ink.get_shader_parameter("phase")), portal_held))
	get_tree().paused = false
	Prefs.reduce_motion = true
	clock._process(0.1)
	props.sync()
	check("reduced motion fixes the native fluid without hiding its geometry", float(ink.get_shader_parameter("motion")) == 0.0 and float(ink.get_shader_parameter("phase")) == 0.0 and (fountain_entry["root"] as Node3D).visible)
	check("reduced motion keeps the native portal stationary and restrained", float(portal_ink.get_shader_parameter("motion")) == 0.0 and float(portal_ink.get_shader_parameter("phase")) == 0.0 and is_equal_approx(float(portal_ink.get_shader_parameter("strength")), 0.5))
	check("native props do not alter source collision or interaction anchors", fountain.atlas_polygon(game.village.data["frames"]["pool"]["ground"]) == footprint_before and game.village.portal_point == game.village.portal_points["town"])
	var forest_ids := props.source_ids()
	game.player.position = game.dungeon.entry_point()
	check("native prop realm fixture enters the real cave", game.dungeon.enter())
	props.sync()
	var clean := true
	for id in forest_ids:
		clean = clean and not props._entries.has(id)
	check("cave replaces previous-realm props with its actual return gate", clean and props._entries.size() == 1)
	game.dungeon.leave("")
	props.sync()
	check("returning restores the same forest asset family", props.owns(fountain) and props._entries.size() == forest_ids.size())
	Prefs.reduce_motion = old_reduce
	game.queue_free()
	await _frames(2)

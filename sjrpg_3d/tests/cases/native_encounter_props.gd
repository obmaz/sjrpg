extends TestCase
## Native volume, retained interaction ownership and source-clock state changes.


func _geometry(mesh: ArrayMesh) -> Dictionary:
	var valid := true
	var triangles := 0
	var bounds := mesh.get_aabb()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for index in vertices.size():
			valid = valid and vertices[index].is_finite() and uv[index].is_finite() and absf(normals[index].length() - 1.0) < 0.001
		for index in range(0, indices.size(), 3):
			var a := vertices[indices[index]]
			var b := vertices[indices[index + 1]]
			var c := vertices[indices[index + 2]]
			var cross := (b - a).cross(c - a)
			valid = valid and cross.length_squared() > 0.0000000001 and cross.dot(normals[indices[index]]) < 0.0
			triangles += 1
	return {"valid": valid, "triangles": triangles, "bounds": bounds}


func _approach(game: Node, stone: EncounterStone) -> Vector2:
	for index in 24:
		var point := stone.position + Vector2.from_angle(TAU * index / 24.0) * 110.0
		if not game._blocked(point, Player.RADIUS) and not game.in_town(point) and game.encounters.clear_line(point, stone.position):
			return point
	return Vector2.INF


func run() -> void:
	var old_sound := Prefs.sound_enabled
	Prefs.sound_enabled = false
	var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/native_encounter_props.json"))
	var textures_match := true
	for source: Dictionary in provenance["shared_textures"]:
		textures_match = textures_match and FileAccess.get_sha256("res://" + str(source["path"])) == str(source["sha256"])
	check("native props retain the recorded original shared generated albedos", textures_match and int(provenance["new_texture_bytes"]) == 0 and FileAccess.get_sha256("res://" + str(provenance["reference"]["path"])) == str(provenance["reference"]["sha256"]))
	var game: Node = await make_game("mage")
	game.set_process(false)
	game.player.set_process(false)
	game.encounters.set_process(false)
	game.exploration.set_process(false)
	var preview: Ortho3DPreview = game.ortho_preview
	preview.set_process(false)
	var props: NativeEncounterProps3D = preview._encounter_props
	props.sync()
	var expected: int = game.chests.size() + game.encounters.stones.size()
	check("all existing forest stones and chests receive individual native ownership", props._entries.size() == expected and props.source_ids().size() == expected)
	var valid := true
	var mesh_report := {}
	for key in ["stone", "glyph", "base", "lid", "splinters"]:
		var mesh: ArrayMesh = props._meshes[key]
		var measured := _geometry(mesh)
		valid = valid and bool(measured["valid"])
		var bounds: AABB = measured["bounds"]
		mesh_report[key] = {"triangles": measured["triangles"], "surfaces": mesh.get_surface_count(), "bounds_m": [bounds.size.x, bounds.size.y, bounds.size.z], "origin_m": [bounds.position.x, bounds.position.y, bounds.position.z]}
	check("actual prop meshes have finite UVs unit normals and correct nonzero front faces", valid)
	var models: Dictionary = props._meshes
	var base_bounds: AABB = (models["base"] as ArrayMesh).get_aabb()
	var lid_bounds: AABB = Transform3D(Basis.IDENTITY, NativeEncounterMesh3D.LID_PIVOT) * (models["lid"] as ArrayMesh).get_aabb()
	var chest_bounds := base_bounds.merge(lid_bounds)
	check("closed chest reads as a broad low box without any runtime axis scale", chest_bounds.size.y < chest_bounds.size.x and absf(chest_bounds.size.y - 0.4232) < 0.001 and absf(chest_bounds.size.x - 0.456) < 0.001)
	print("NATIVE_ENCOUNTER_METRICS " + JSON.stringify({"meshes": mesh_report, "stone_triangles": models["stone_triangles"], "chest_triangles": models["chest_triangles"], "stone_surfaces": 3, "chest_closed_surfaces": 2, "chest_open_surfaces": 3, "chest_closed_bounds_m": [chest_bounds.size.x, chest_bounds.size.y, chest_bounds.size.z], "chest_sweep_radius_m": props._lid_sweep_radius}))
	check("stone and chest retain bounded full-volume mobile mesh budgets", int(models["stone_triangles"]) < 2000 and int(models["chest_triangles"]) < 2000 and (models["stone"] as ArrayMesh).get_surface_count() + (models["glyph"] as ArrayMesh).get_surface_count() <= 3 and (models["base"] as ArrayMesh).get_surface_count() + (models["lid"] as ArrayMesh).get_surface_count() + (models["splinters"] as ArrayMesh).get_surface_count() <= 3)
	var stone_bounds: AABB = (models["stone"] as ArrayMesh).get_aabb()
	check("stone keeps the source structural footprint and a real upright back face", stone_bounds.position.y >= -0.0001 and stone_bounds.size.is_equal_approx(NativeEncounterMesh3D.STONE_SIZE))
	var sweep := 0.0
	for pose_index in 131:
		var pose := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(NativeEncounterMesh3D.OPEN_ANGLE) * pose_index / 130.0), NativeEncounterMesh3D.LID_PIVOT)
		var lid: ArrayMesh = models["lid"]
		for surface in lid.get_surface_count():
			var vertices: PackedVector3Array = lid.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var point := pose * vertex
				sweep = maxf(sweep, Vector2(point.x, point.z).length())
	check("every sampled hinge pose stays within the original chest collision radius", sweep <= SpatialWorld3D.radius_metres(24.0) and sweep <= props._lid_sweep_radius + 0.0001, "sweep=%s radius=%s" % [sweep, SpatialWorld3D.radius_metres(24.0)])
	check("chest reuses actual family timber and iron response in one shared material", props._chest_material.get_shader_parameter("timber") == (preview._materials["wood"] as StandardMaterial3D).albedo_texture and props._chest_material.get_shader_parameter("iron_tint") == (preview._materials["iron"] as StandardMaterial3D).albedo_color)
	var no_colliders := true
	for entry: Dictionary in props._entries.values():
		no_colliders = no_colliders and (entry["root"] as Node3D).find_children("*", "CollisionObject3D", true, false).is_empty()
	check("native display introduces no replacement physics or interaction blockers", no_colliders)
	preview._affordances.sync()
	check("native encounter models have no duplicate stone or chest cards", preview._world_environment._stone_cards.is_empty() and preview._affordances._art.is_empty())
	var stone: EncounterStone = game.encounters.stones["west"]
	var original_body := stone.body()
	var state: Dictionary = game.encounters.states["west"]
	state["initial_spawned"] = true
	state["charges"] = 3
	var approach := _approach(game, stone)
	check("source summoning stone still has a real clear native approach", approach.is_finite())
	game.spatial_world.teleport_source_actor(game.player, approach, Player.RADIUS)
	var struck := stone.take_damage(1.0, game.player)
	stone._process(0.03)
	props.sync()
	var entry: Dictionary = props._entries[stone.get_instance_id()]
	var tint := stone.art.modulate_color * (preview._materials["stone"] as StandardMaterial3D).albedo_color
	check("real source hit summons once and native stone observes its actual flash", struck and int(state["charges"]) == 2 and game.encounters.living("west") > 0 and (entry["stone"] as StandardMaterial3D).albedo_color.is_equal_approx(tint) and is_equal_approx(float(entry["observed_flash"]), stone._flash))
	for enemy in game.enemies:
		enemy.queue_free()
	game.enemies.clear()
	game.encounters._members["west"] = []
	state["charges"] = 0
	state["recharge"] = 298.2
	var state_before := state.duplicate(true)
	var flash_before := stone._flash
	props.sync()
	var header: Label3D = entry["header"]
	check("native recharge seconds come only from the source runtime", header.text == "충전까지 2초" and state == state_before and stone._flash == flash_before)
	var root: Node3D = entry["root"]
	check("stone display keeps its source body and actual ground anchor", stone.body() == original_body and root.position.is_equal_approx(Ortho3DPreview.ground_position(stone.position, preview.surface_height(stone.position))))
	stone.visible = false
	props.sync()
	check("source-local hiding removes the native stone and its header", not root.visible and not header.is_visible_in_tree())
	stone.visible = true
	var chest: Chest = game.chests[0]
	var old_art_id := chest.body_sprite.get_instance_id()
	var chest_entry: Dictionary = props._entries[chest.get_instance_id()]
	var chest_root: Node3D = chest_entry["root"]
	var original_anchor := chest.position
	# A missing/unsupported native owner uses the actual individual card, and
	# respects the Chest's own visibility independently of hidden adapter parents.
	props._source_ids.erase(old_art_id)
	preview._affordances.sync()
	check("unowned chest retains its measured individual source card", preview._affordances._art.has(old_art_id))
	chest.visible = false
	preview._affordances.sync()
	check("fallback ownership respects source-local hiding", not preview._affordances._art.has(old_art_id))
	chest.visible = true
	props.sync()
	preview._affordances.sync()
	check("unopened native chest starts closed with an intact capsule blocker", not chest.dead and is_zero_approx((chest_entry["lid"] as Node3D).rotation.x) and game.spatial_world.blocked(chest.position, 1.0))
	chest.take_damage(1.0, game.player)
	props.sync()
	preview._affordances.sync()
	game.spatial_world.sync_scope()
	await get_tree().physics_frame
	var gold_after := GameState.gold
	props.sync()
	chest.take_damage(1.0, game.player)
	check("real consumed chest opens once without duplicating art rewards or blockers", chest.dead and GameState.opened_chests.has(chest.index) and GameState.gold == gold_after and not game.spatial_world.blocked(chest.position, 1.0) and props.owns(chest.body_sprite) and not props.source_ids().has(old_art_id) and preview._affordances._art.is_empty())
	check("opened native chest keeps its source anchor and a real empty lid pose", chest.position == original_anchor and is_equal_approx((chest_entry["lid"] as Node3D).rotation.x, deg_to_rad(NativeEncounterMesh3D.OPEN_ANGLE)) and (chest_entry["splinters"] as MeshInstance3D).visible and chest_root.position.is_equal_approx(Ortho3DPreview.ground_position(chest.position, preview.surface_height(chest.position))))
	var empty := NativeEncounterProps3D.new().setup(preview, {})
	empty.sync()
	check("missing native material family leaves source-art ownership available", empty._entries.is_empty() and not empty.owns(stone.art) and not empty.owns(chest.body_sprite))
	Quests.state("sun")["started"] = false
	game.spatial_world.teleport_source_actor(game.player, game.dungeon.entry_point(), Player.RADIUS)
	check("prop lifetime fixture enters the existing cave", game.dungeon.enter())
	props.sync()
	preview._affordances.sync()
	var hidden := true
	for item: Dictionary in props._entries.values():
		hidden = hidden and not (item["root"] as Node3D).visible
	check("forest props and chest fallback cards never ghost into the cave", hidden and preview._affordances._art.is_empty())
	game.dungeon.leave("")
	props.sync()
	check("cave return restores the same forest models and consumed chest state", root.visible and chest_root.visible and chest.dead and props._entries.size() == expected)
	var removed_id := chest.get_instance_id()
	var removed_art := chest.body_sprite.get_instance_id()
	var removed_root: WeakRef = weakref(chest_root)
	chest.queue_free()
	props.sync()
	preview._affordances.sync()
	check("a queued source cannot briefly reappear through a fallback card", not preview._affordances._art.has(removed_art))
	game.chests.erase(chest)
	await _frames(2)
	check("a removed source cleans native ownership instead of leaving a ghost prop", not props._entries.has(removed_id) and removed_root.get_ref() == null)
	game.queue_free()
	await _frames(2)
	Prefs.sound_enabled = old_sound

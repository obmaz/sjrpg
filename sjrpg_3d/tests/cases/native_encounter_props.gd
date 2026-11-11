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


func _chest_clearance(game: Node, props: NativeEncounterProps3D) -> void:
	# Check every source placement, including the raised waterfall reward chest.
	# Use actual native physics; source screen circles cannot establish wall clearance.
	var world: SpatialWorld3D = game.spatial_world
	await get_tree().physics_frame
	var all_clear := true
	var all_approachable := true
	var colliders_match := true
	var reports: Array[Dictionary] = []
	for chest: Chest in game.chests:
		var body: StaticBody3D = null
		for entry: Dictionary in world._props:
			if (entry["owner"] as WeakRef).get_ref() == chest:
				body = entry["body"]
				break
		if body == null:
			colliders_match = false
			continue
		var collider: CylinderShape3D = (body.get_child(0) as CollisionShape3D).shape
		var anchor := world.native_point(chest.position, world.height_at(chest.position))
		colliders_match = colliders_match and is_equal_approx(collider.radius, world.radius_metres(Chest.COLLISION_RADIUS)) and absf(collider.height - NativeEncounterMesh3D.CHEST_COLLISION_HEIGHT) < 0.001 and absf(body.position.y - collider.height * 0.5 - anchor.y) < 0.001
		# Conservative cylinder contains fixed geometry plus every continuous lid pose.
		# Floor is deliberately not an obstruction; cliff side faces remain SOLID.
		var envelope := CylinderShape3D.new()
		envelope.radius = props._lid_sweep_radius
		envelope.height = 0.80
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = envelope
		query.transform = Transform3D(Basis.IDENTITY, anchor + Vector3.UP * 0.401)
		query.collision_mask = SpatialWorld3D.SOLID | SpatialWorld3D.PROP
		query.exclude = [body.get_rid()]
		var hits := world.get_world_3d().direct_space_state.intersect_shape(query, 8)
		all_clear = all_clear and hits.is_empty()
		var clear: Array[bool] = []
		var points: Array[Vector2] = []
		var ring := collider.radius + world.radius_metres(Player.RADIUS) + 0.18
		for index in 16:
			var direction := Vector3(cos(TAU * index / 16.0), 0, sin(TAU * index / 16.0))
			var point := world.projected(anchor + direction * ring)
			points.append(point)
			clear.append(not world.blocked(point, Player.RADIUS) and absf(world.height_at(point) - anchor.y) <= SpatialWorld3D.MAX_STEP)
		var walkable_arc := false
		for index in 16:
			var next := (index + 1) % 16
			if not clear[index] or not clear[next]:
				continue
			var reached := world.move_actor(points[index], points[next], Player.RADIUS)
			var returned := world.move_actor(points[next], points[index], Player.RADIUS)
			if world.native_point(reached).distance_to(world.native_point(points[next])) < 0.04 and world.native_point(returned).distance_to(world.native_point(points[index])) < 0.04:
				walkable_arc = true
				break
		all_approachable = all_approachable and walkable_arc
		var hit_names: Array[Dictionary] = []
		for hit: Dictionary in hits:
			var obstacle: StaticBody3D = hit["collider"]
			var detail := {"name": str(obstacle.name), "kind": str(obstacle.get_meta("physics_kind", "")), "position": [obstacle.position.x, obstacle.position.y, obstacle.position.z], "source_polygon": str(obstacle.get_meta("source_polygon", PackedVector2Array()))}
			for circle: Dictionary in world._circles:
				if circle["body"] == obstacle:
					detail["source_circle"] = {"point": str(circle["point"]), "radius": circle["radius"]}
			var shapes: Array[Dictionary] = []
			for child in obstacle.get_children():
				if not child is CollisionShape3D:
					continue
				var shape: Shape3D = (child as CollisionShape3D).shape
				var info := {"type": shape.get_class(), "position": str((child as CollisionShape3D).global_position)}
				if shape is CylinderShape3D:
					info["radius_m"] = (shape as CylinderShape3D).radius
					info["height_m"] = (shape as CylinderShape3D).height
				elif shape is ConvexPolygonShape3D:
					info["points"] = str((shape as ConvexPolygonShape3D).points)
				elif shape is ConcavePolygonShape3D:
					info["faces"] = str((shape as ConcavePolygonShape3D).get_faces())
				elif shape is BoxShape3D:
					info["size"] = str((shape as BoxShape3D).size)
				shapes.append(info)
			detail["shapes"] = shapes
			hit_names.append(detail)
		reports.append({"index": chest.index, "radius_m": collider.radius, "height_m": collider.height, "lid_clear": hits.is_empty(), "obstacles": hit_names, "walkable_arc": walkable_arc})
	check("every enlarged chest uses a ground-aligned native blocker matching the new envelope", colliders_match and reports.size() == game.chests.size())
	check("all enlarged chest bodies and complete lid sweeps clear existing walls and props", all_clear, JSON.stringify(reports))
	check("every enlarged chest retains a real capsule approach and adjacent walking passage", all_approachable, JSON.stringify(reports))
	var route_start := Iso.project(Vector2(1530, 160))
	var route_finish := Iso.project(Vector2(1530, 360))
	var route_forward := world.move_actor(route_start, route_finish, Player.RADIUS)
	var route_backward := world.move_actor(route_finish, route_start, Player.RADIUS)
	check("the east memory chest keeps the existing exterior corridor walkable both ways", not game.in_town(route_start) and not game.in_town(route_finish) and world.native_point(route_forward).distance_to(world.native_point(route_finish)) < 0.04 and world.native_point(route_backward).distance_to(world.native_point(route_start)) < 0.04)
	print("NATIVE_CHEST_PLACEMENT_METRICS " + JSON.stringify(reports))


func run() -> void:
	var old_sound := Prefs.sound_enabled
	Prefs.sound_enabled = false
	var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/native_encounter_props.json"))
	var textures_match := true
	for source: Dictionary in provenance["shared_textures"]:
		textures_match = textures_match and FileAccess.get_sha256("res://" + str(source["path"])) == str(source["sha256"])
	check("native props retain the recorded original shared generated albedos", textures_match and int(provenance["new_texture_bytes"]) == FileAccess.get_file_as_bytes("res://assets/models/materials/chests/albedo.png").size() and FileAccess.get_sha256("res://" + str(provenance["reference"]["path"])) == str(provenance["reference"]["sha256"]))
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
	check("closed chest reads as a broad low box without any runtime axis scale", chest_bounds.size.y < chest_bounds.size.x and absf(chest_bounds.size.y - 1.0580) < 0.001 and absf(chest_bounds.size.x - 1.140) < 0.001 and absf(chest_bounds.size.z - 0.750) < 0.001)
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
	check("every sampled hinge pose stays within the enlarged chest collision radius", sweep <= SpatialWorld3D.radius_metres(Chest.COLLISION_RADIUS) and sweep <= props._lid_sweep_radius + 0.0001, "sweep=%s radius=%s" % [sweep, SpatialWorld3D.radius_metres(Chest.COLLISION_RADIUS)])
	await _chest_clearance(game, props)
	check("all chest variants share the generated full-face atlas with distinct material states",props._chest_material.get_shader_parameter("surface_atlas")==load("res://assets/models/materials/chests/albedo.png") and props._chest_variants["iron"].get_shader_parameter("variant")==1 and props._chest_variants["gold"].get_shader_parameter("variant")==2)
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
	var chest_floor := SpatialCombat3D.floor_at(game, chest.position)
	var horizontal := Vector3.RIGHT
	var native_center := SpatialWorld3D.native_point(chest.position)
	var start := SpatialWorld3D.projected(native_center - horizontal)
	var finish := SpatialWorld3D.projected(native_center + horizontal)
	var projectile_radius := 8.0
	var above := chest_floor + NativeEncounterMesh3D.CHEST_COLLISION_HEIGHT + SpatialWorld3D.radius_metres(projectile_radius) + 0.02
	check("overhead shots miss the actual closed chest cylinder", is_inf(SpatialCombat3D.target_fraction(game, start, finish, above, chest, projectile_radius, Chest.COLLISION_RADIUS)))
	check("normal chest-height projectile spheres still contact the lid rim", SpatialCombat3D.target_fraction(game, start, finish, chest_floor + SpatialCombat3D.PROJECTILE_LIFT, chest, 22.0, Chest.COLLISION_RADIUS) < 1.0)
	check("shots through the real chest body still hit", SpatialCombat3D.target_fraction(game, start, finish, chest_floor + 0.25, chest, projectile_radius, Chest.COLLISION_RADIUS) < 1.0)
	var rim := chest.position + Vector2(Chest.COLLISION_RADIUS + 0.5, 0)
	game.break_chests_at(rim, 1.0, game.player, false)
	check("the enlarged target rim receives the real chest attack path", chest.dead)
	props.sync()
	preview._affordances.sync()
	game.spatial_world.sync_scope()
	await get_tree().physics_frame
	check("consumed chests are absent from the projectile target volume", is_inf(SpatialCombat3D.target_fraction(game, start, finish, chest_floor + 0.25, chest, projectile_radius, Chest.COLLISION_RADIUS)))
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
		var owner: Node2D = (item["owner"] as WeakRef).get_ref()
		var in_cave: bool = owner.get_parent() == game.world
		hidden = hidden and (item["root"] as Node3D).visible == in_cave
	check("only current cave chest models are visible while forest props stay hidden", hidden and preview._affordances._art.is_empty())
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

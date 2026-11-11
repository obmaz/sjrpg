extends TestCase
## Actual closed3D rock, native boundary alignment and source-owned replacements.


func _point_key(point: Vector3) -> String:
	return "%d:%d:%d" % [roundi(point.x * 10000), roundi(point.y * 10000), roundi(point.z * 10000)]


func _edge_key(a: Vector3, b: Vector3) -> String:
	var first := _point_key(a)
	var last := _point_key(b)
	return first + "/" + last if first < last else last + "/" + first


func run() -> void:
	var provenance: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/data/native_cave_geometry.json")
	)
	var sources_match := true
	for key in [
		"reference",
		"generator",
		"material",
		"outer_material",
		"floor_shader",
		"floor_material",
		"surface_generator",
		"wall_shader",
		"variant_shader"
	]:
		var source: Dictionary = provenance[key]
		sources_match = (
			sources_match
			and FileAccess.get_sha256("res://" + str(source["path"])) == str(source["sha256"])
		)
	check(
		"native cave retains the actual guide generator and reused albedo provenance", sources_match
	)
	var game := await make_game("mage")
	var preview: Ortho3DPreview = game.ortho_preview
	var environment: Ortho3DEnvironment = preview._world_environment
	var settings: Environment
	for child in preview.stage.get_children():
		if child is WorldEnvironment:
			settings = (child as WorldEnvironment).environment
	var outdoor_energy := settings.ambient_light_energy
	var outdoor_color := settings.ambient_light_color
	var outdoor_background := settings.background_color
	game.player.position = game.dungeon.entry_point()
	await _frames(2)
	var entered: bool = game.dungeon.enter()
	check("existing Stage1 cave entry remains available", entered)
	if not entered:
		game.queue_free()
		return
	var layout: DungeonLayout = game.dungeon.layout
	var source_polygons := layout.polygons.duplicate(true)
	var source_obstacles := layout.obstacles.duplicate(true)
	environment.sync(0.0, true)
	var rock: Dictionary = environment._cave_rock
	check(
		"native rock follows the existing layout instance without changing rooms or props",
		(
			int(rock["layout_id"]) == layout.get_instance_id()
			and layout.polygons == source_polygons
			and layout.obstacles == source_obstacles
			and DungeonLayout.ROOMS.size() == 5
		)
	)
	check(
		"native rock replaces the full original boundary with bounded chunks",
		(
			int(rock["segments"]) == game.dungeon.art.boundary_segments.size()
			and int(rock["groups"]) == int(rock["segments"])
			and int(rock["triangles"]) > 1000
			and int(rock["triangles"]) < 20000
		)
	)
	var metadata: Dictionary = environment.cave.get_meta("boundary_sources")
	var ownership := true
	var wall_count := 0
	var keep_count := 0
	for source: Node2D in game.dungeon.art.visuals:
		var id := source.get_instance_id()
		if str(source.get_meta("cave_role", "")) == "wall":
			wall_count += 1
			ownership = (
				ownership and metadata["replaced"].has(id) and not metadata["retained"].has(id)
			)
		else:
			keep_count += 1
			ownership = (
				ownership
				and metadata["native_props"].has(id)
				and not metadata["retained"].has(id)
				and not metadata["replaced"].has(id)
			)
	check(
		"wall boundaries and non-wall props each retain exact native owners",
		ownership and wall_count > 10 and keep_count >= 16
	)
	var return_portal: IsoSprite = game.world.get_node("CaveReturnPortal")
	var portal_anchor := Iso.project(DungeonLayout.EXIT + Vector2(50, -110))
	check(
		"return portal retains its original anchor and native source ownership",
		(
			metadata["native_props"].has(return_portal.get_instance_id())
			and preview._town_props.owns(return_portal)
			and not metadata["retained"].has(return_portal.get_instance_id())
			and not metadata["replaced"].has(return_portal.get_instance_id())
			and return_portal.position.is_equal_approx(portal_anchor)
		)
	)
	var material: ShaderMaterial = rock["materials"]["inner"]
	var outer_material: ShaderMaterial = rock["materials"]["outer"]
	check(
		"inner and outer rock share six natural skins with upright and normal-aware mapping",
		(
			material.shader == outer_material.shader
			and not material.get_shader_parameter("exposed")
			and outer_material.get_shader_parameter("exposed")
		)
	)
	_check_variants(material, "wall")
	_check_variants(outer_material, "wall")
	_check_floor_surfaces(environment, layout)
	var vertices_present := {}
	var vertex_roles := {}
	var wall_directions := {}
	var uv_valid := true
	var upper_caps := 0
	var edges := {}
	var valid := true
	var peak := 0.0
	for node: MeshInstance3D in rock["meshes"]:
		valid = (
			valid
			and node.has_meta("native_cave_boundary")
			and node.material_override == null
			and node.mesh.get_surface_count() == 2
		)
		for surface in node.mesh.get_surface_count():
			var surface_material := node.mesh.surface_get_material(surface)
			var inner := surface_material == material
			valid = valid and (inner or surface_material == outer_material)
			var tile := Ortho3DCaveRock.TILE_METRES if inner else Ortho3DCaveRock.OUTER_TILE_METRES
			var arrays := node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for index in vertices.size():
				valid = (
					valid
					and vertices[index].is_finite()
					and uv[index].is_finite()
					and absf(normals[index].length() - 1.0) < 0.001
				)
				var vertex_key := _point_key(vertices[index])
				vertices_present[vertex_key] = true
				vertex_roles[vertex_key] = (
					int(vertex_roles.get(vertex_key, 0)) | (1 if inner else 2)
				)
				peak = maxf(peak, vertices[index].y)
			for index in range(0, indices.size(), 3):
				var a := vertices[indices[index]]
				var b := vertices[indices[index + 1]]
				var c := vertices[indices[index + 2]]
				valid = valid and (b - a).cross(c - a).length_squared() > 0.0000000001
				valid = valid and (b - a).cross(c - a).dot(normals[indices[index]]) <= 0.00001
				var ia := indices[index]
				var ib := indices[index + 1]
				var ic := indices[index + 2]
				var edge_uv_a := uv[ib] - uv[ia]
				var edge_uv_b := uv[ic] - uv[ia]
				uv_valid = uv_valid and absf(edge_uv_a.cross(edge_uv_b)) > 0.00000001
				var chart_x := true
				var chart_z := true
				var chart_cap := not inner
				for vertex_index: int in [ia, ib, ic]:
					var at := vertices[vertex_index]
					var actual := uv[vertex_index] * tile
					chart_x = chart_x and actual.is_equal_approx(Vector2(at.x, at.y))
					chart_z = chart_z and actual.is_equal_approx(Vector2(at.z, at.y))
					chart_cap = chart_cap and actual.is_equal_approx(Vector2(at.x, at.z))
				uv_valid = uv_valid and (chart_x or chart_z or chart_cap)
				if inner:
					var normal := normals[ia]
					var direction := (
						("x+" if normal.x > 0.0 else "x-")
						if absf(normal.x) > absf(normal.z)
						else ("z+" if normal.z > 0.0 else "z-")
					)
					wall_directions[direction] = true
					uv_valid = uv_valid and not chart_cap
				elif chart_cap and normals[ia].y > 0.1:
					upper_caps += 1
				for edge in [_edge_key(a, b), _edge_key(b, c), _edge_key(c, a)]:
					edges[edge] = int(edges.get(edge, 0)) + 1
	var closed := true
	for count: int in edges.values():
		closed = closed and count == 2
	check(
		"actual rock triangles form closed volumes across chunk boundaries",
		closed and valid and peak > 3.0
	)
	check(
		"all four inner wall directions have noncollapsed vertical UVs and original exposed caps remain present",
		(
			uv_valid
			and wall_directions.size() == 4
			and upper_caps > 10
			and int(rock["surfaces"]) == int(rock["groups"]) * 2
		)
	)
	var ridges_shared := true
	for profile: Dictionary in rock["profiles"]:
		for end in ["section_a", "section_b"]:
			var section: PackedVector3Array = profile[end]
			ridges_shared = ridges_shared and int(vertex_roles.get(_point_key(section[4]), 0)) == 3
	check("inside and exposed materials meet at the original shared profile ridge", ridges_shared)
	var toes_match := true
	var corners := {}
	for profile: Dictionary in rock["profiles"]:
		var outward: Vector2 = profile["outward"]
		for side in ["a", "b"]:
			var source_point: Vector2 = profile[side]
			var section: PackedVector3Array = profile["section_" + side]
			var toe := Vector2(section[0].x, section[0].z)
			toes_match = (
				toes_match
				and absf((toe - source_point / SpatialWorld3D.UNITS).dot(outward) + 0.04) < 0.0001
			)
			for vertex in section:
				toes_match = toes_match and vertices_present.has(_point_key(vertex))
			var key := "%d:%d" % [roundi(source_point.x), roundi(source_point.y)]
			if corners.has(key):
				var other: PackedVector3Array = corners[key]
				for index in section.size():
					toes_match = toes_match and section[index].distance_to(other[index]) < 0.0001
			else:
				corners[key] = section
	check("real rock toes and shared corners meet the native collision inset", toes_match)
	check(
		"front cutaways keep combat readable while rear walls retain real volume",
		int(rock["front_cutaways"]) > 0 and Ortho3DCaveRock.OUTER_DEPTH >= 1.0
	)
	game.player.set_process(false)
	game.spatial_world.sync_scope()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var blocked_boundaries := 0
	var collision_match := true
	for profile: Dictionary in rock["profiles"]:
		var a: Vector2 = profile["a"]
		var b: Vector2 = profile["b"]
		var outward: Vector2 = profile["outward"]
		var middle := (a + b) * 0.5 / SpatialWorld3D.UNITS
		var from := Iso.project((middle - outward * 0.60) * SpatialWorld3D.UNITS)
		var to := Iso.project((middle + outward * 0.60) * SpatialWorld3D.UNITS)
		if game.spatial_world.blocked(from, Player.RADIUS):
			continue
		var stopped: Vector2 = game.spatial_world.move_actor(from, to, Player.RADIUS)
		var native := Iso.unproject(stopped) / SpatialWorld3D.UNITS
		var limit := (
			-SpatialWorld3D.radius_metres(Player.RADIUS) - Ortho3DCaveRock.COLLISION_INSET + 0.015
		)
		collision_match = collision_match and (native - middle).dot(outward) <= limit
		# A missing floor alone also stops the motor. Independently hit the
		# actual SOLID wall at the visible toe, so this cannot pass without it.
		var ray_from := Vector3(middle.x - outward.x * 0.60, 0.10, middle.y - outward.y * 0.60)
		var ray_to := Vector3(middle.x + outward.x * 0.60, 0.10, middle.y + outward.y * 0.60)
		var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to, SpatialWorld3D.SOLID)
		var hit: Dictionary = game.spatial_world.get_world_3d().direct_space_state.intersect_ray(
			query
		)
		if hit.is_empty():
			collision_match = false
		else:
			var position: Vector3 = hit["position"]
			collision_match = (
				collision_match
				and (
					absf(
						(
							(Vector2(position.x, position.z) - middle).dot(outward)
							+ Ortho3DCaveRock.COLLISION_INSET
						)
					)
					< 0.01
				)
			)
		blocked_boundaries += 1
	check(
		"actual3D sweeps stop on the same visible rock boundary",
		collision_match and blocked_boundaries > 10
	)
	check(
		"cave fill adds real bounded light without replacing authored lamps",
		(
			environment._cave_lights.size() == 10
			and environment._cave_key.shadow_enabled
			and environment._cave_key.light_energy > 0.0
			and environment._cave_entry_light.omni_range <= 6.5
			and not environment._cave_entry_light.shadow_enabled
		)
	)
	check(
		"cave lighting gives the entry its own neutral support",
		(
			is_equal_approx(settings.ambient_light_energy, Ortho3DEnvironment.CAVE_AMBIENT)
			and environment._cave_entry_light.position.distance_to(Vector3(0, 2.3, 0)) < 1.0
		)
	)
	var entry_energy := environment._cave_entry_light.light_energy
	var lamp_energy := environment._cave_lights[0].light_energy
	environment.sync(10.0, true)
	check(
		"paused cave lighting does not advance flicker or entry energy",
		(
			environment._cave_entry_light.light_energy == entry_energy
			and environment._cave_lights[0].light_energy == lamp_energy
		)
	)
	game.dungeon.leave("")
	environment.sync(0.0, true)
	check(
		"leaving cave restores the exact previous outdoor ambient and background",
		(
			is_equal_approx(settings.ambient_light_energy, outdoor_energy)
			and settings.ambient_light_color == outdoor_color
			and settings.background_color == outdoor_background
			and not environment._cave_key.is_visible_in_tree()
		)
	)
	game.queue_free()
	await _frames(2)


func _check_floor_surfaces(environment: Ortho3DEnvironment, layout: DungeonLayout) -> void:
	var floors := environment.cave.find_children("CaveFloor_*", "MeshInstance3D", true, false)
	var valid := floors.size() == layout.polygons.size()
	var shared: ShaderMaterial
	for index in layout.polygons.size():
		var node := environment.cave.get_node_or_null("CaveFloor_%d" % index) as MeshInstance3D
		if node == null:
			valid = false
			continue
		var material := node.material_override as ShaderMaterial
		if material == null:
			valid = false
			continue
		if shared == null:
			shared = material
		valid = valid and material == shared
		var arrays := node.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var polygon: PackedVector2Array = layout.polygons[index]
		valid = valid and vertices.size() == polygon.size()
		for vertex_index in mini(vertices.size(), polygon.size()):
			var expected := Ortho3DPreview.ground_position(polygon[vertex_index], 0.004)
			# ArrayMesh normals are octahedral uint16 pairs; measured UP error is 1/65535.
			valid = (
				valid
				and vertices[vertex_index].is_equal_approx(expected)
				and normals[vertex_index].distance_to(Vector3.UP) <= 2.0 / 65535.0
				and uv[vertex_index].is_equal_approx(Vector2(expected.x, expected.z) / 2.6)
			)
	check(
		"warm cave floor preserves every original flat polygon vertex metre UV and shared lit material",
		valid and shared != null
	)
	if shared == null:
		return
	_check_variants(shared, "floor")
	check(
		"walkable floor remains lit without emission and retains its existing shader entry point",
		(
			shared.shader.resource_path == "res://scripts/native_cave_floor.gdshader"
			and not shared.shader.code.contains("unshaded")
			and not shared.shader.code.contains("EMISSION")
		)
	)


func _check_variants(material: ShaderMaterial, kind: String) -> void:
	var hashes := {}
	var valid := true
	var provenance: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(
			"res://assets/source/materials/cave/" + kind + "/provenance.json"
		)
	)
	for index in 6:
		var texture: Texture2D = material.get_shader_parameter("surface_%d" % index)
		var path := "res://assets/models/materials/cave/" + kind + "/" + kind + "-%d.png" % index
		var hash := FileAccess.get_sha256(path)
		hashes[hash] = true
		valid = (
			valid
			and texture != null
			and texture.resource_path == path
			and texture.get_width() == 1254
			and texture.get_height() == 1254
			and provenance["images"][index]["sha256"] == hash
		)
	check(
		(
			"six distinct unmodified generated "
			+ kind
			+ " images are bound to the actual cave material"
		),
		valid and hashes.size() == 6
	)

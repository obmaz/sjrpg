extends TestCase
## Real surface geometry and native source ownership; pixels remain a browser review gate.

func run() -> void:
	var signatures := {}
	var materials := {}
	for identity: String in ResidentRenderer3D.AUTHORED_IDS:
		var mesh := ResidentRenderer3D.build(identity)
		var bounds := mesh.get_aabb()
		var triangles := 0
		var vertex_count := 0
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
			vertex_count += vertices.size()
			check("resident has lit colored geometry on every surface " + identity, normals.size() == vertices.size() and colors.size() == vertices.size())
			for normal in normals:
				if not normal.is_finite() or normal.length() < 0.8:
					check("resident normals remain finite and unit length " + identity, false)
					break
			var ink := mesh.surface_get_material(surface) as StandardMaterial3D
			check("resident uses shared opaque lit material " + identity, ink != null and ink.vertex_color_use_as_albedo and ink.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL and ink.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED)
			materials[ink.get_instance_id()] = true
		check("resident model has volume from front side and rear " + identity, bounds.size.x > 0.45 and bounds.size.z > 0.25 and bounds.size.y >= 1.64 and bounds.size.y <= 1.86)
		check("resident soles are baked at the native ground pivot " + identity, absf(bounds.position.y) < 0.001)
		check("resident keeps mobile surface and geometry budget " + identity, mesh.get_surface_count() <= 4 and triangles <= 6500)
		var signature := str(bounds) + ":" + str(vertex_count)
		signatures[signature] = true
		print("ART_AUDIT native_resident " + JSON.stringify({"identity": identity, "triangles": triangles, "surfaces": mesh.get_surface_count(), "bounds": str(bounds)}))
	check("the remaining authored roles have distinct actual geometry", signatures.size() == ResidentRenderer3D.AUTHORED_IDS.size())
	check("the remaining authored roles share at most four actual materials", materials.size() <= 4)
	check("unknown identity is not falsely claimed as converted", ResidentRenderer3D.build("unknown") == null)
	var game := await make_game("mage")
	var world_renderer: WorldRenderer3D = game.world_renderer
	var residents: ResidentRenderer3D = world_renderer._resident_renderer
	residents.sync()
	check("every actual villager has a native owner", residents.entries.size() == game.village.npc_nodes.size())
	var body_count: int = game.spatial_world.actor_bodies.size()
	for resident: Villager in game.village.npc_nodes.values():
		var id := resident.get_instance_id()
		var node: Node3D = residents.entries[id]["node"]
		check("converted resident has no duplicate source card", not world_renderer._cards.has(id))
		check("native resident follows authoritative actor foot", node.position.is_equal_approx(world_renderer.actor_foot(resident)))
		check("resident runtime geometry has baked unit scale", node.scale.is_equal_approx(Vector3.ONE))
	check("visual replacement does not add physics actors", game.spatial_world.actor_bodies.size() == body_count)
	var first: Villager = game.village.npc_nodes.values()[0]
	first.show_hurt()
	residents.sync()
	var first_meshes: Array[MeshInstance3D] = residents.entries[first.get_instance_id()]["meshes"]
	for mesh: MeshInstance3D in first_meshes:
		check("native resident uses the real injury state on each body mesh", mesh.material_overlay != null)
	first._hurt_flash = 0.0
	residents.sync()
	for mesh: MeshInstance3D in first_meshes:
		check("native injury overlay clears with its source state", mesh.material_overlay == null)
	var active: bool = game.dungeon.active
	game.dungeon.active = true
	residents.sync()
	check("forest residents disappear in cave scope", residents.review_snapshot()["visible"] == 0)
	game.dungeon.active = active
	residents.sync()

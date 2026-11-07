extends TestCase
## Volume/normal/pose/lifetime contracts, independent of a camera-facing texture.
func run() -> void:
	for kind: String in NativeEnemyModels.KINDS:
		var model := NativeEnemyModels.build(kind)
		var root: Node3D = model["root"]
		add_child(root)
		var triangles := 0
		var meshes := root.find_children("*", "MeshInstance3D", true, false)
		for child in meshes:
			var mesh := child as MeshInstance3D
			check("actor part has closed volume " + kind, mesh.get_aabb().size.x > 0.0 and mesh.get_aabb().size.y > 0.0 and mesh.get_aabb().size.z > 0.0 and not mesh.mesh is QuadMesh)
			check("actor surface receives native lights " + kind, mesh.material_override is StandardMaterial3D and not (mesh.material_override as StandardMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED)
			for surface in mesh.mesh.get_surface_count():
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				check("actor vertices retain normals " + kind, vertices.size() > 0 and normals.size() == vertices.size())
				triangles += indices.size() / 3 if indices.size() > 0 else vertices.size() / 3
		check("model remains a mobile budget rig " + kind, meshes.size() <= 20 and triangles < 6000)
		NativeEnemyModels.pose(model, 0.0, 0.25, 0.0)
		var leg := (model["legs"][0] as Node3D).rotation.x
		NativeEnemyModels.pose(model, 0.0, 0.0, 0.5)
		check("walk and attack change real joints " + kind, not is_zero_approx(leg) and (not model["arms"].is_empty() or absf((model["torso"] as Node3D).rotation.x) > 0.0))
		NativeEnemyModels.tint(model, Color.WHITE, 0.6, Color.RED, 0.4)
		check("native death fade uses source alpha " + kind, is_equal_approx((model["materials"][0] as StandardMaterial3D).albedo_color.a, 0.4))
		root.queue_free()
	await _frames(2)
	check("corpse lifetime still belongs to original gameplay", is_zero_approx(CorpseArt.opacity(30.0)) and is_equal_approx(CorpseArt.opacity(15.0), 1.0) and is_zero_approx(CorpseArt.opacity(0.0)))

extends TestCase
## Volume/normal/pose/lifetime contracts, independent of a camera-facing texture.


func _check_winding(mesh: Mesh, surface: int, label: String) -> void:
	var arrays: Array = mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = (
		arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	)
	var count: int = indices.size() if not indices.is_empty() else vertices.size()
	var signed_volume: float = 0.0
	var wrong_normal: int = 0
	var nondegenerate: int = 0
	for offset: int in range(0, count, 3):
		var ia: int = indices[offset] if not indices.is_empty() else offset
		var ib: int = indices[offset + 1] if not indices.is_empty() else offset + 1
		var ic: int = indices[offset + 2] if not indices.is_empty() else offset + 2
		var a: Vector3 = vertices[ia]
		var b: Vector3 = vertices[ib]
		var c: Vector3 = vertices[ic]
		var cross: Vector3 = (b - a).cross(c - a)
		signed_volume += a.dot(b.cross(c)) / 6.0
		if cross.length_squared() > 0.0000000000000001:
			nondegenerate += 1
			var exported: Vector3 = normals[ia] + normals[ib] + normals[ic]
			if cross.dot(exported) >= 0.0:
				wrong_normal += 1
	check(
		"closed actor surface has outward Godot clockwise volume " + label,
		signed_volume < -0.000000001
	)
	check(
		"actual exported normals oppose clockwise face cross products " + label,
		nondegenerate > 0 and wrong_normal == 0
	)


func run() -> void:
	for kind: String in NativeEnemyModels.KINDS.filter(
		func(k): return not NativeEnemyAssets.uses_asset(k)
	):
		var model := NativeEnemyModels.build(kind)
		var root: Node3D = model["root"]
		add_child(root)
		var triangles := 0
		var meshes := root.find_children("*", "MeshInstance3D", true, false)
		for child in meshes:
			var mesh := child as MeshInstance3D
			check(
				"actor part has closed volume " + kind,
				(
					mesh.get_aabb().size.x > 0.0
					and mesh.get_aabb().size.y > 0.0
					and mesh.get_aabb().size.z > 0.0
					and not mesh.mesh is QuadMesh
				)
			)
			check(
				"actor surface receives native lights " + kind,
				(
					mesh.material_override is StandardMaterial3D
					and not (
						(mesh.material_override as StandardMaterial3D).shading_mode
						== BaseMaterial3D.SHADING_MODE_UNSHADED
					)
				)
			)
			for surface in mesh.mesh.get_surface_count():
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var indices: PackedInt32Array = (
					arrays[Mesh.ARRAY_INDEX]
					if arrays[Mesh.ARRAY_INDEX] != null
					else PackedInt32Array()
				)
				check(
					"actor vertices retain normals " + kind,
					vertices.size() > 0 and normals.size() == vertices.size()
				)
				_check_winding(mesh.mesh, surface, kind + "/" + str(surface))
				triangles += indices.size() / 3 if indices.size() > 0 else vertices.size() / 3
		check("model remains a mobile budget rig " + kind, meshes.size() <= 20 and triangles < 6000)
		NativeEnemyModels.pose(model, 0.0, 0.25, 0.0)
		var leg := (model["legs"][0] as Node3D).rotation.x
		NativeEnemyModels.pose(model, 0.0, 0.0, 0.5)
		check(
			"walk and attack change real joints " + kind,
			(
				not is_zero_approx(leg)
				and (
					not model["arms"].is_empty()
					or absf((model["torso"] as Node3D).rotation.x) > 0.0
				)
			)
		)
		NativeEnemyModels.tint(model, Color.WHITE, 0.6, Color.RED, 0.4)
		check(
			"native death fade uses source alpha " + kind,
			is_equal_approx((model["materials"][0] as StandardMaterial3D).albedo_color.a, 0.4)
		)
		root.queue_free()
	await _frames(2)
	check(
		"corpse lifetime still belongs to original gameplay",
		(
			is_zero_approx(CorpseArt.opacity(30.0))
			and is_equal_approx(CorpseArt.opacity(15.0), 1.0)
			and is_zero_approx(CorpseArt.opacity(0.0))
		)
	)

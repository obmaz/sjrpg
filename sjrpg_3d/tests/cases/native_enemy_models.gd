extends TestCase
## 가져온 메시의 실제 입체·법선·예산·조명·페이드를 검사한다.


func run() -> void:
	for kind: String in EnemyRenderer3D.KINDS + [EnemyRenderer3D.CRAWLER]:
		var model := EnemyRenderer3D.build(kind)
		var visual: NativeEnemyVisual = model["visual"]
		add_child(visual)
		var triangles := 0
		for instance in visual.meshes:
			var bounds := instance.get_aabb()
			check(
				"actor has real volume " + kind,
				(
					bounds.size.x > .1
					and bounds.size.y > .1
					and bounds.size.z > .1
					and not instance.mesh is QuadMesh
				)
			)
			for surface in instance.mesh.get_surface_count():
				var material := instance.get_active_material(surface) as StandardMaterial3D
				check(
					"surface receives actual lights " + kind,
					(
						material != null
						and material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL
					)
				)
				var arrays := instance.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var valid := normals.size() == vertices.size()
				for normal in normals:
					valid = valid and normal.is_finite() and normal.length() > .9
				check("all authored vertices have unit normals " + kind, valid)
				triangles += indices.size() / 3
		check(
			"species remains a mobile budget rig " + kind,
			visual.meshes.size() == 1 and triangles > 1000 and triangles < 6000
		)
		EnemyRenderer3D.tint(model, Color.WHITE, .6, Color.RED, .4)
		check(
			"native fade retains the source alpha " + kind,
			is_equal_approx(visual.materials[0].albedo_color.a, .4)
		)
		visual.free()
	check(
		"corpse lifetime remains game-owned",
		(
			is_zero_approx(CorpseArt.opacity(15))
			and is_equal_approx(CorpseArt.opacity(7.5), 1)
			and is_zero_approx(CorpseArt.opacity(0))
		)
	)

extends TestCase
## 실제 GLB 씬·공유 메시·독립 노드·재질 슬롯·물리 분리를 검사한다.


func run() -> void:
	for id: String in ["shop", "smith", "stable", "home", "chapel", "fortress", "bridge"]:
		var first := ArchitectureSceneLibrary.create(id)
		var second := ArchitectureSceneLibrary.create(id)
		add_child(first)
		add_child(second)
		var one := first.find_children("*", "MeshInstance3D", true, false)
		var two := second.find_children("*", "MeshInstance3D", true, false)
		check(
			"architecture instances retain the imported GLB scene " + id,
			(
				first.get_node("Geometry").scene_file_path.ends_with("/model.glb")
				and one.size() == two.size()
				and one.size() > 0
			)
		)
		var triangles := 0
		var shared := true
		for index in one.size():
			var a := one[index] as MeshInstance3D
			var b := two[index] as MeshInstance3D
			shared = shared and a != b and a.mesh == b.mesh
			shared = shared and a.material_override == b.material_override
			for surface in a.mesh.get_surface_count():
				triangles += a.mesh.surface_get_array_index_len(surface) / 3
		check("architecture nodes are independent and source meshes/materials shared " + id, shared)
		check(
			"actual imported triangles match the source measurement " + id,
			triangles == int(first.report["triangles"])
		)
		check(
			"visual assets do not introduce collision or a new gameplay clock " + id,
			(
				first.find_children("*", "CollisionObject3D", true, false).is_empty()
				and first.find_children("*", "AnimationPlayer", true, false).is_empty()
			)
		)
		if id == "fortress":
			var gates: Array = first.report["gates"]
			check("four gates keep eight independently movable leaves", gates.size() == 4)
			for gate: Dictionary in gates:
				check(
					"gate leaves keep dynamic batching exclusions",
					(
						gate["leaves"].size() == 2
						and gate["leaves"][0].get_meta("exclude_static_batch", false)
					)
				)
		first.free()
		second.free()

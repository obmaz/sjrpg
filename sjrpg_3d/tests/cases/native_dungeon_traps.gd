extends TestCase
## 모델별 GLB/TSCN·정밀도·재질 공유와 움직이는 부품의 납품 계약을 확인한다.


func run() -> void:
	for id: String in ["spikes", "flame_vent"]:
		var folder: String = DungeonHazardRenderer3D.ROOT + id + "/"
		var spec: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(folder + "asset.json")
		)
		check(
			"trap model retains current construction and binary hashes " + id,
			(
				FileAccess.get_sha256(folder + "model.glb") == spec["modelSha256"]
				and FileAccess.get_sha256("res://" + str(spec["source"])) == spec["sourceSha256"]
			)
		)
		var scene := load(folder + "visual.tscn") as PackedScene
		var first := scene.instantiate() as Node3D
		var second := scene.instantiate() as Node3D
		add_child(first)
		add_child(second)
		var one := first.find_children("*", "MeshInstance3D", true, false)
		var two := second.find_children("*", "MeshInstance3D", true, false)
		var triangles := 0
		var valid := true
		var degenerate := 0
		var shared := one.size() == two.size()
		for index in one.size():
			var mesh := one[index] as MeshInstance3D
			shared = shared and mesh.mesh == (two[index] as MeshInstance3D).mesh
			for surface in mesh.mesh.get_surface_count():
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var count := indices.size() if not indices.is_empty() else vertices.size()
				triangles += count / 3
				valid = valid and uv.size() == vertices.size() and normals.size() == vertices.size()
				for point in vertices.size():
					valid = (
						valid
						and vertices[point].is_finite()
						and uv[point].is_finite()
						and absf(normals[point].length() - 1) < .005
					)
				for face in range(0, count, 3):
					var a: int = indices[face] if not indices.is_empty() else face
					var b: int = indices[face + 1] if not indices.is_empty() else face + 1
					var c: int = indices[face + 2] if not indices.is_empty() else face + 2
					var cross: Vector3 = (vertices[b] - vertices[a]).cross(
						vertices[c] - vertices[a]
					)
					if cross.length_squared() < .0000000001:
						degenerate += 1
					valid = valid and cross.dot(normals[a]) <= .000001
		check(
			"trap instances share bounded model geometry " + id,
			shared and triangles == int(spec["triangles"]) and triangles < 1200
		)
		check("trap triangles have valid normals UVs and winding " + id, valid)
		check("trap models contain no zero-area caps " + id, degenerate == 0, str(degenerate))
		var part := first.find_child("Spikes", true, false) as Node3D
		check(
			"only the spike model has a movable named part " + id,
			(part != null) == (id == "spikes")
		)
		first.queue_free()
		second.queue_free()
		await _frames(2)

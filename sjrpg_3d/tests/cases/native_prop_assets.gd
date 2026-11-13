extends TestCase
## 실제 임포트가 원본 미터 형상·공유 자원·독립 피벗을 보존하는지 검사한다.


func run() -> void:
	var ids: Array[String] = []
	for id: String in ["smith", "stable", "elder", "elin", "noah", "rowen"]:
		ids.append("residents/" + id)
	for id: String in [
		"encounter_stone", "treasure_chest", "waypoint", "cave_entrance", "wall_torch", "trail_sign"
	]:
		ids.append("environment/" + id)
	for id: String in ["dark_fir", "black_pine", "spire_cypress", "juniper", "thorn_bramble"]:
		ids.append("vegetation/" + id)
	for id: String in ids:
		var a := ModelSceneLibrary.create(id)
		var b := ModelSceneLibrary.create(id)
		if not check("fixed asset has two editable scene instances " + id, a != null and b != null):
			return
		var proof: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(ModelSceneLibrary.MODEL_SCENE_ROOT + id + "/geometry.json")
		)
		var triangles := 0
		var geometry := true
		var shared := true
		for path: String in proof["meshes"]:
			var first := a.get_node_or_null(path) as MeshInstance3D
			var second := b.get_node_or_null(path) as MeshInstance3D
			if not check(
				"import preserves named mesh paths " + id + ":" + path,
				first != null and second != null
			):
				geometry = false
				continue
			var expected: Dictionary = proof["meshes"][path]
			var low: Array = expected["min"]
			var size: Array = expected["size"]
			var bounds := first.mesh.get_aabb()
			geometry = (
				geometry and bounds.position.distance_to(Vector3(low[0], low[1], low[2])) < 0.00001
			)
			geometry = (
				geometry and bounds.size.distance_to(Vector3(size[0], size[1], size[2])) < 0.00001
			)
			geometry = geometry and first.mesh.get_surface_count() == int(expected["surfaces"])
			shared = shared and first != second and first.mesh == second.mesh
			var previous := second.position
			first.position.x += 1.0
			shared = shared and second.position == previous
			for surface: int in first.mesh.get_surface_count():
				var indices: PackedInt32Array = first.mesh.surface_get_arrays(surface)[
					Mesh.ARRAY_INDEX
				]
				triangles += (
					(
						indices.size()
						if not indices.is_empty()
						else first.mesh.surface_get_array_len(surface)
					)
					/ 3
				)
		check(
			"import preserves original bounds surfaces and triangle count " + id,
			geometry and triangles == int(proof["triangles"])
		)
		check("scene nodes move independently while source meshes stay shared " + id, shared)
		check(
			"visual introduces no physics or independent gameplay clocks " + id,
			(
				a.find_children("*", "CollisionObject3D", true, false).is_empty()
				and a.find_children("*", "AnimationPlayer", true, false).is_empty()
			)
		)
		a.free()
		b.free()
	var first := ModelSceneLibrary.mesh("environment/cave_entrance", "Body")
	check(
		"cave render and physical collision use the same imported mesh",
		first == NativeCaveEntrance3D.mesh(NativeCavePlan.HILL_HEIGHT, 1.0)
	)

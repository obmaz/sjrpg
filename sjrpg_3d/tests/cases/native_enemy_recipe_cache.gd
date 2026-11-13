extends TestCase
## Real meshes/joints/materials, not a mirrored recipe format or timing-only assertion.


class FloorPresenter:
	extends Node
	var floor_height := 0.0

	func surface_height(_point: Vector2) -> float:
		return floor_height


func _meshes(root: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child: Node in root.find_children("*", "MeshInstance3D", true, false):
		result.append(child as MeshInstance3D)
	return result


func _world_vertices(root: Node3D) -> PackedVector3Array:
	var result := PackedVector3Array()
	if root is EnemyVisual:
		for vertex in (root as EnemyVisual).posed_vertices():
			result.append(root.global_transform * vertex)
		return result
	for instance: MeshInstance3D in _meshes(root):
		for surface: int in instance.mesh.get_surface_count():
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				result.append(instance.global_transform * vertex)
	return result


func _same_vertices(first: PackedVector3Array, second: PackedVector3Array) -> bool:
	if first.size() != second.size():
		return false
	for index: int in first.size():
		if first[index].distance_to(second[index]) > 0.000001:
			return false
	return true


func run() -> void:
	var benchmark: Array[Dictionary] = []
	for kind: String in EnemyRenderer3D.KINDS:
		var before: Dictionary = EnemyRenderer3D.cache_stats()
		var first_start: int = Time.get_ticks_usec()
		var first: Dictionary = EnemyRenderer3D.build(kind)
		var first_us: int = Time.get_ticks_usec() - first_start
		var after_first: Dictionary = EnemyRenderer3D.cache_stats()
		var cold: bool = int(after_first["asset_loads"]) > int(before["asset_loads"])
		var first_root: Node3D = first["root"]
		add_child(first_root)
		var second: Dictionary = EnemyRenderer3D.build(kind)
		var second_root: Node3D = second["root"]
		add_child(second_root)
		var first_meshes: Array[MeshInstance3D] = _meshes(first_root)
		var second_meshes: Array[MeshInstance3D] = _meshes(second_root)
		check(
			"recipe reuses actual immutable GPU meshes for " + kind,
			not first_meshes.is_empty() and first_meshes.size() == second_meshes.size()
		)
		if first_meshes.size() == second_meshes.size():
			for index: int in first_meshes.size():
				check(
					"mesh resources shared but render instances independent " + kind,
					(
						first_meshes[index] != second_meshes[index]
						and first_meshes[index].mesh == second_meshes[index].mesh
					)
				)
		check(
			"fresh actor rig has independent root and torso " + kind,
			first_root != second_root and first["torso"] != second["torso"]
		)
		var first_materials: Array = first["materials"]
		var second_materials: Array = second["materials"]
		check(
			"base height and material palette preserved " + kind,
			(
				is_equal_approx(float(first["base_height"]), float(second["base_height"]))
				and first["colors"] == second["colors"]
			)
		)
		for index: int in first_materials.size():
			check(
				"mutable material state belongs to each actor " + kind,
				first_materials[index] != second_materials[index]
			)
			for other: int in first_materials.size():
				check(
					"intra-rig material aliases preserved " + kind,
					(
						(first_materials[index] == first_materials[other])
						== (second_materials[index] == second_materials[other])
					)
				)
		check(
			"replayed rest mesh vertices exactly match authored actor " + kind,
			_same_vertices(_world_vertices(first_root), _world_vertices(second_root))
		)
		var untouched: PackedVector3Array = _world_vertices(second_root)
		EnemyRenderer3D.pose(first, 0.61, 0.24, 0.73)
		check(
			"posing one actor never moves the other rig " + kind,
			_same_vertices(untouched, _world_vertices(second_root))
		)
		EnemyRenderer3D.pose(second, 0.61, 0.24, 0.73)
		check(
			"replayed joint animation gives identical actual vertices " + kind,
			_same_vertices(_world_vertices(first_root), _world_vertices(second_root))
		)
		EnemyRenderer3D.tint(first, Color(0.3, 0.6, 0.9), 0.6, Color.RED, 0.25)
		for index: int in second_materials.size():
			check(
				"hit flash/alpha cannot contaminate shared recipe or sibling " + kind,
				(
					(second_materials[index] as StandardMaterial3D).albedo_color
					== second["colors"][index]
				)
			)
		var source_ref: WeakRef = weakref(first_root)
		first_root.free()
		check(
			"cache does not retain the source Node hierarchy " + kind, source_ref.get_ref() == null
		)
		var hot_before: Dictionary = EnemyRenderer3D.cache_stats()
		var hot_start: int = Time.get_ticks_usec()
		for iteration: int in 12:
			var fresh: Dictionary = EnemyRenderer3D.build(kind)
			var root: Node3D = fresh["root"]
			check(
				"new cache hit retains original palette after old actor flash " + kind,
				fresh["colors"] == second["colors"]
			)
			root.free()
		var hot_us: int = Time.get_ticks_usec() - hot_start
		var hot_after: Dictionary = EnemyRenderer3D.cache_stats()
		check(
			"repeated actors reuse the imported PackedScene " + kind,
			(
				int(hot_after["asset_loads"]) == int(hot_before["asset_loads"])
				and int(hot_after["cache_hits"]) - int(hot_before["cache_hits"]) == 12
			)
		)
		check(
			"a cold species loads its imported scene once " + kind,
			int(after_first["asset_loads"]) - int(before["asset_loads"]) == (1 if cold else 0)
		)
		benchmark.append(
			{
				"kind": kind,
				"first_was_cold": cold,
				"first_build_us": first_us,
				"hit_count": 12,
				"hits_total_us": hot_us,
				"hit_mean_us": float(hot_us) / 12.0,
				"cached_species": int(hot_after["cached_species"])
			}
		)
		second_root.free()

	var presenter := FloorPresenter.new()
	add_child(presenter)
	var corpse_model: Dictionary = EnemyRenderer3D.build("goblin")
	var corpse_root: Node3D = corpse_model["root"]
	add_child(corpse_root)
	var corpse: Dictionary = {
		"pos": Vector2(180, 70),
		"facing": 0.48,
		"height": 82.0,
		"time": 20.0,
		"lifetime": 30.0,
		"used": false
	}
	EnemyRenderer3D.place_corpse(presenter, corpse_model, corpse)
	var at_rest: Transform3D = corpse_root.transform
	var placements: int = int(corpse_model["_corpse_placement_updates"])
	var placement_start: int = Time.get_ticks_usec()
	for iteration: int in 60:
		EnemyRenderer3D.place_corpse(presenter, corpse_model, corpse)
	var placement_us: int = Time.get_ticks_usec() - placement_start
	check(
		"static corpse repeats no pose traversal or floor bounds placement",
		(
			int(corpse_model["_corpse_placement_updates"]) == placements
			and corpse_root.transform.is_equal_approx(at_rest)
		)
	)
	corpse["time"] = 1.5
	EnemyRenderer3D.place_corpse(presenter, corpse_model, corpse)
	check(
		"corpse fade still updates while placement is cached",
		(
			int(corpse_model["_corpse_placement_updates"]) == placements
			and is_equal_approx(
				(corpse_model["materials"][0] as StandardMaterial3D).albedo_color.a, 0.5
			)
		)
	)
	corpse["used"] = true
	EnemyRenderer3D.place_corpse(presenter, corpse_model, corpse)
	check("consumed corpse hides immediately despite cached placement", not corpse_root.visible)
	corpse["used"] = false
	presenter.floor_height = 0.75
	EnemyRenderer3D.place_corpse(presenter, corpse_model, corpse)
	check(
		"changed actual floor invalidates corpse placement",
		(
			int(corpse_model["_corpse_placement_updates"]) == placements + 1
			and is_equal_approx(corpse_root.position.y, at_rest.origin.y + 0.75)
		)
	)
	placements += 1
	corpse["pos"] = Vector2(300, -40)
	EnemyRenderer3D.place_corpse(presenter, corpse_model, corpse)
	var floor_point: Vector3 = WorldSpace3D.projected_to_world(corpse["pos"])
	check(
		"moved corpse follows the current projected ground",
		(
			int(corpse_model["_corpse_placement_updates"]) == placements + 1
			and is_equal_approx(corpse_root.position.x, floor_point.x)
			and is_equal_approx(corpse_root.position.z, floor_point.z)
		)
	)
	placements += 1
	corpse["facing"] = 1.24
	EnemyRenderer3D.place_corpse(presenter, corpse_model, corpse)
	check(
		"changed facing invalidates static corpse pose",
		int(corpse_model["_corpse_placement_updates"]) == placements + 1
	)
	placements += 1
	var old_scale: Vector3 = corpse_root.scale
	corpse["height"] = 102.5
	EnemyRenderer3D.place_corpse(presenter, corpse_model, corpse)
	check(
		"changed body height invalidates corpse scale",
		(
			int(corpse_model["_corpse_placement_updates"]) == placements + 1
			and corpse_root.scale.is_equal_approx(old_scale * 1.25)
		)
	)
	corpse["time"] = 0.0
	EnemyRenderer3D.place_corpse(presenter, corpse_model, corpse)
	check("expired cached corpse is never visible", not corpse_root.visible)
	print(
		"ART_AUDIT NATIVE_ENEMY_RECIPE_BENCH ",
		JSON.stringify(
			{
				"kinds": benchmark,
				"static_corpse_calls": 60,
				"static_corpse_total_us": placement_us,
				"static_corpse_rebuilds": 0,
				"total_placements_after_invalidation_tests":
				int(corpse_model["_corpse_placement_updates"])
			}
		)
	)
	corpse_root.free()
	presenter.free()

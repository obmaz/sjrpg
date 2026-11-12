extends TestCase
## Actual cave ownership, bounded closed torch volumes, shared batches and source-clock fire.


func _point(point: Vector3) -> String:
	return (
		"%d:%d:%d" % [roundi(point.x * 100000), roundi(point.y * 100000), roundi(point.z * 100000)]
	)


func _edge(a: Vector3, b: Vector3) -> String:
	var first := _point(a)
	var last := _point(b)
	return first + "/" + last if first < last else last + "/" + first


func _closed_volume(mesh: Mesh) -> bool:
	var faces := mesh.get_faces()
	var edges := {}
	if faces.size() < 12 or faces.size() % 3 != 0:
		return false
	for index in range(0, faces.size(), 3):
		var a := faces[index]
		var b := faces[index + 1]
		var c := faces[index + 2]
		if (
			not a.is_finite()
			or not b.is_finite()
			or not c.is_finite()
			or (b - a).cross(c - a).length_squared() <= 0.0000000001
		):
			return false
		for key in [_edge(a, b), _edge(b, c), _edge(c, a)]:
			edges[key] = int(edges.get(key, 0)) + 1
	for count: int in edges.values():
		if count != 2:
			return false
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = (
			arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		)
		if normals.size() != vertices.size():
			return false
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for index in range(0, count, 3):
			var ia := indices[index] if not indices.is_empty() else index
			var ib := indices[index + 1] if not indices.is_empty() else index + 1
			var ic := indices[index + 2] if not indices.is_empty() else index + 2
			var winding := (vertices[ib] - vertices[ia]).cross(vertices[ic] - vertices[ia])
			if (
				not normals[ia].is_finite()
				or absf(normals[ia].length() - 1.0) > 0.001
				or winding.dot(normals[ia]) >= 0.0
			):
				return false
	var size := mesh.get_aabb().size
	return size.x > 0.02 and size.y > 0.02 and size.z > 0.02


func run() -> void:
	var old_reduced := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var game := await make_game("mage")
	var renderer: WorldRenderer3D = game.world_renderer
	var environment: EnvironmentRenderer3D = renderer._world_environment
	game.player.position = game.dungeon.entry_point()
	await _frames(2)
	if not check("existing Stage1 cave still opens before torch inspection", game.dungeon.enter()):
		Prefs.reduce_motion = old_reduced
		game.queue_free()
		return
	environment.sync(0.0, true)
	var obstacles: Array = game.dungeon.layout.obstacles.duplicate(true)
	var root := environment.cave.get_node_or_null("NativeCaveLanterns") as Node3D
	if not check("native torch root replaces the legacy lantern source owner", root != null):
		Prefs.reduce_motion = old_reduced
		game.queue_free()
		return
	var report: Dictionary = root.get_meta("native_lantern_report")
	var anchors: PackedVector3Array = report["anchors"]
	var mounts: Array = report["mount_transforms"]
	var contacts: Array = report["wall_contacts"]
	var light_positions: PackedVector3Array = report["light_positions"]
	var batches: Dictionary = report["batches"]
	var owned: Dictionary = report["owned_source_ids"]
	var index := 0
	var same_sources := true
	for source: Node2D in game.dungeon.art.visuals:
		if str(source.get_meta("cave_role", "")) != "lantern":
			continue
		var expected := WorldRenderer3D.ground_position(
			source.global_position, DungeonRelief.at(source.global_position)
		)
		same_sources = (
			same_sources
			and owned.has(source.get_instance_id())
			and anchors[index].is_equal_approx(expected)
		)
		var light: OmniLight3D = environment._cave_lights[index]
		same_sources = same_sources and light.position.is_equal_approx(light_positions[index])
		same_sources = (
			same_sources
			and light.light_color.is_equal_approx(Color(1.0, 0.66, 0.29))
			and is_equal_approx(light.omni_range, 5.0)
			and not light.shadow_enabled
		)
		index += 1
	check(
		"all ten authored sources retain ownership while their existing warm lights follow the wall-mounted heads",
		(
			same_sources
			and index == 10
			and int(report["count"]) == index
			and environment._cave_lights.size() == index
		)
	)
	var mounted := (
		mounts.size() == 10 and contacts.size() == 10 and str(report["mounting"]) == "wall"
	)
	var normals := {}
	for torch_index in mounts.size():
		var mount: Transform3D = mounts[torch_index]
		var contact: Dictionary = contacts[torch_index]
		var triangle: Array = contact["triangle"]
		var hit: Variant = Geometry3D.ray_intersects_triangle(
			contact["source_origin"], contact["wall_outward"], triangle[0], triangle[1], triangle[2]
		)
		var outward: Vector3 = contact["wall_outward"]
		normals["%d:%d" % [roundi(outward.x), roundi(outward.z)]] = true
		mounted = mounted and hit is Vector3 and mount.origin.is_equal_approx(hit)
		mounted = (
			mounted
			and is_equal_approx(
				mount.origin.y, anchors[torch_index].y + CaveLanternRenderer3D.MOUNT_HEIGHT
			)
		)
		mounted = (
			mounted
			and mount.basis.z.dot(-outward) > 0.95
			and mount.basis.y.y > 0.95
			and is_equal_approx(mount.basis.determinant(), 1.0)
		)
		mounted = mounted and float(contact["wall_height"]) == CaveWallGeometry3D.CHAMBER_HEIGHT
		mounted = (
			mounted
			and light_positions[torch_index].is_equal_approx(
				(
					mount
					* Vector3(
						0,
						CaveLanternRenderer3D.FLAME_BASE + 0.24,
						CaveLanternRenderer3D.TORCH_DEPTH + 0.10
					)
				)
			)
		)
	check(
		"each backplate actually touches a rendered tall inner wall on both wall orientations",
		mounted and normals.size() == 2
	)
	var wood: MultiMeshInstance3D = batches["wood"]
	var wood_bounds := wood.multimesh.mesh.get_aabb()
	var clear_floor := true
	for mount: Transform3D in mounts:
		for x in [wood_bounds.position.x, wood_bounds.end.x]:
			for y in [wood_bounds.position.y, wood_bounds.end.y]:
				for z in [wood_bounds.position.z, wood_bounds.end.z]:
					var point := mount * Vector3(x, y, z)
					clear_floor = (
						clear_floor
						and (
							point.y - DungeonRelief.flat_height(Vector2(point.x, point.z) * 65)
							> 1.20
						)
					)
	check(
		"larger torch handles are suspended above the floor rather than standing on it",
		clear_floor and is_equal_approx(wood_bounds.size.y, 0.44 * 1.7)
	)
	var iron: MultiMeshInstance3D = batches["iron"]
	var iron_bounds := iron.multimesh.mesh.get_aabb()
	check(
		"combined iron geometry retains both wall backplate and the full raised cup",
		(
			iron_bounds.position.z <= 0.001
			and iron_bounds.end.z > 0.45
			and iron_bounds.end.y > 0.55
			and iron_bounds.size.x > 0.28
		)
	)
	var valid := (
		root.get_child_count() == 4 and batches.size() == 4 and str(report["style"]) == "torch"
	)
	var triangles := 0
	for key: String in batches:
		var batch: MultiMeshInstance3D = batches[key]
		var mesh: Mesh = batch.multimesh.mesh
		triangles += floori(float(mesh.get_faces().size()) / 3.0)
		valid = valid and batch.multimesh.instance_count == index and _closed_volume(mesh)
		valid = valid and batch.multimesh.transform_format == MultiMesh.TRANSFORM_3D
		if key in ["outer", "core"]:
			var material := batch.material_override as StandardMaterial3D
			valid = (
				valid
				and material != null
				and material.emission_enabled
				and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
			)
			valid = valid and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			valid = valid and batch.material_override == renderer._materials[key]
	check(
		"ten real wood/iron torches and opaque volume flames share four bounded batches",
		(
			valid
			and triangles < 500
			and root.find_children("*", "Light3D", true, false).is_empty()
			and root.find_children("*", "GPUParticles3D", true, false).is_empty()
		)
	)
	print(
		(
			"ART_AUDIT CAVE_TORCHES "
			+ JSON.stringify(
				{
					"sources": index,
					"shared_batches": batches.size(),
					"triangles_per_torch": triangles,
					"instanced_triangles_upper_bound": triangles * index,
					"extra_lights": root.find_children("*", "Light3D", true, false).size(),
					"opaque_flame_batches": 2
				}
			)
		)
	)
	var outer: Array = report["outer_transforms"].duplicate()
	var core: Array = report["core_transforms"].duplicate()
	var before_clock := environment._clock
	environment.sync(0.23, false)
	var changed: bool = outer != report["outer_transforms"] and core != report["core_transforms"]
	check(
		"native fire reads the existing cave clock and stays fixed at the torch head",
		changed and is_equal_approx(environment._clock, before_clock + 0.23)
	)
	var bases_match := true
	for torch_index in anchors.size():
		var transform: Transform3D = report["outer_transforms"][torch_index]
		var mount: Transform3D = mounts[torch_index]
		bases_match = (
			bases_match
			and transform.origin.is_equal_approx(
				(
					mount
					* Vector3(0, CaveLanternRenderer3D.FLAME_BASE, CaveLanternRenderer3D.TORCH_DEPTH)
				)
			)
		)
	check("flame animation cannot drift away from any source-owned torch", bases_match)
	var held: Array = report["outer_transforms"].duplicate()
	var energy := environment._cave_lights[0].light_energy
	environment.sync(10.0, true)
	check(
		"frozen cave presentation holds both flame pose and original flicker",
		held == report["outer_transforms"] and environment._cave_lights[0].light_energy == energy
	)
	Prefs.reduce_motion = true
	environment.sync(0.0, true)
	var reduced: Array = report["outer_transforms"].duplicate()
	environment.sync(0.31, false)
	check(
		"reduced motion keeps readable static volume fire while original lights remain steady",
		(
			reduced == report["outer_transforms"]
			and is_equal_approx(environment._cave_lights[0].light_energy, 2.6)
		)
	)
	var visible_cores := true
	var outer_mesh: Mesh = (batches["outer"] as MultiMeshInstance3D).multimesh.mesh
	var core_mesh: Mesh = (batches["core"] as MultiMeshInstance3D).multimesh.mesh
	for torch_index in mounts.size():
		visible_cores = (
			visible_cores
			and _exposed_core(
				outer_mesh,
				core_mesh,
				report["outer_transforms"][torch_index],
				report["core_transforms"][torch_index],
				renderer.camera.global_transform.basis.z.normalized()
			)
		)
	check(
		"opaque outer fire cannot hide every middle-ring surface of the brighter inner fire",
		visible_cores
	)
	check(
		"torch visuals add no obstacle and retain source props ownership",
		game.dungeon.layout.obstacles == obstacles and owned.size() == 10
	)
	Prefs.reduce_motion = old_reduced
	game.dungeon.leave("")
	environment.sync(0.0, true)
	check(
		"leaving the cave hides every torch with its native cave parent",
		not root.is_visible_in_tree()
	)
	game.queue_free()
	await _frames(2)


func _exposed_core(
	outer: Mesh, core: Mesh, shell: Transform3D, inside: Transform3D, toward_camera: Vector3
) -> bool:
	var outer_faces := outer.get_faces()
	for sample: Vector3 in core.get_faces():
		# Inspect the body of the flame, not an incidental exposed base or tip.
		if sample.y < 0.08 or sample.y > 0.42:
			continue
		var target := inside * sample
		var origin := target + toward_camera * 4.0
		var blocked := false
		for index in range(0, outer_faces.size(), 3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(
				origin,
				-toward_camera,
				shell * outer_faces[index],
				shell * outer_faces[index + 1],
				shell * outer_faces[index + 2]
			)
			if hit is Vector3 and origin.distance_to(hit) < 3.9999:
				blocked = true
				break
		if not blocked:
			return true
	return false

extends TestCase
## Probe actual merged triangles at joins/apertures and the real threat state,
## rather than comparing two copies of an invented footprint rectangle.

class Fixture:
	extends Node
	var game: Node
	var stage: Node3D
	var _materials: Dictionary


func _nearest(meshes: Array, origin: Vector3, direction: Vector3) -> float:
	var nearest := INF
	for mesh: MeshInstance3D in meshes:
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var count := indices.size() if not indices.is_empty() else vertices.size()
			for index in range(0, count, 3):
				var a: int = indices[index] if not indices.is_empty() else index
				var b: int = indices[index + 1] if not indices.is_empty() else index + 1
				var c: int = indices[index + 2] if not indices.is_empty() else index + 2
				var hit = Geometry3D.ray_intersects_triangle(origin, direction, mesh.global_transform * vertices[a], mesh.global_transform * vertices[b], mesh.global_transform * vertices[c])
				if hit is Vector3:
					nearest = minf(nearest, origin.distance_to(hit))
	return nearest


func _leaf_meshes(gate: Dictionary) -> Array:
	var result := []
	for leaf: Node3D in gate["leaves"]:
		result.append_array(leaf.find_children("*", "MeshInstance3D", true, false))
	return result


func run() -> void:
	var game := await make_game("mage")
	game.set_process(false)
	game.town_gates.set_process(false)
	var old_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var fixture := Fixture.new()
	fixture.game = game
	fixture.stage = Node3D.new()
	var stone := StandardMaterial3D.new()
	stone.uv1_triplanar = true
	stone.uv1_world_triplanar = true
	stone.uv1_scale = Vector3.ONE * 0.390625
	fixture._materials = {"stone": stone, "wood": StandardMaterial3D.new(), "iron": StandardMaterial3D.new()}
	add_child(fixture)
	fixture.add_child(fixture.stage)
	var controller := Ortho3DFortification.build(fixture)
	var report: Dictionary = controller.report
	check("native fortification uses all four actual gate passages and eight wing joins", controller.gates.size() == 4 and report["wing_joins"].size() == 8 and report["corners"].size() == 4)
	check("masonry geometry and material submissions stay bounded", int(report["triangles"]) < 30000 and int(report["triangles"]) > 1000 and int(report["static_surfaces"]) <= 3)
	check("the total wall datum keeps its original projected height", absf(float(report["projected_top_pixels"]) - game.village.wall_height * Iso.S) < 0.001)
	var stone_meshes := []
	var valid := true
	var winding := true
	for mesh: MeshInstance3D in report["static_meshes"]:
		if mesh.material_override == stone:
			stone_meshes.append(mesh)
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for vertex in vertices.size():
				valid = valid and vertices[vertex].is_finite() and uv[vertex].is_finite() and absf(normals[vertex].length() - 1.0) < 0.001
			for index in range(0, indices.size(), 3):
				var a := indices[index]
				var b := indices[index + 1]
				var c := indices[index + 2]
				winding = winding and (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).dot(normals[a]) <= 0.00001
	check("both wall axes wings towers and corners share the same world-scaled limestone", stone_meshes.size() == 1 and stone.uv1_world_triplanar and stone.uv1_scale.is_equal_approx(Vector3.ONE * 0.390625))
	check("fortification mesh normals UVs and winding remain valid", valid and winding)
	for wing: Dictionary in report["wing_joins"]:
		var gate: Dictionary = controller.gates[int(wing["gate"])]
		var frame: Transform3D = gate["frame"]
		var join: Vector3 = wing["join"]
		for height in [0.65, float(report["wall_height"]) * 0.90]:
			var origin: Vector3 = join + Vector3.UP * float(height) + frame.basis.z * 1.4
			check("actual wing/wall triangles cover join %s at %s" % [wing["gate"], height], _nearest(stone_meshes, origin, -frame.basis.z) < 1.5)
	var center: Vector3 = report["town_center"]
	for corner: Vector3 in report["corners"]:
		for axis in [Vector3.RIGHT * signf(corner.x - center.x), Vector3(0, 0, signf(corner.z - center.z))]:
			check("both native faces close the actual town corner", _nearest(stone_meshes, corner + Vector3.UP * 1.6 + axis * 1.4, -axis) < 1.5)
	for gate: Dictionary in controller.gates:
		var frame: Transform3D = gate["frame"]
		for across in [-0.21, 0.21]:
			var origin := frame * Vector3(float(gate["width"]) * across, 1.45, float(gate["depth"]) + 1.0)
			check("open arch is a real clear stone aperture on each gate", _nearest(stone_meshes, origin, -frame.basis.z) > float(gate["depth"]) * 2.0 + 1.0)
			check("fully open wooden leaves clear the road", not is_finite(_nearest(_leaf_meshes(gate), origin, -frame.basis.z)))
	# Drive the production threat scan rather than substituting a presentation flag.
	game.player.position = game.village.spawn_point
	var enemy := Enemy.new()
	enemy.setup(game, "goblin", 1)
	var outward: Vector2 = (game.village.gate_points[0] - game.village.spawn_point).normalized()
	enemy.position = game.village.gate_points[0] + outward * 80.0
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	enemy.set_process(false)
	game.town_gates.advance(0.60)
	controller.sync()
	check("real nearby threat closes native leaves on the production clock", game.town_gates.closed[0] and is_equal_approx(float(controller.gates[0]["progress"]), game.town_gates.progress[0]))
	var closed_gate: Dictionary = controller.gates[0]
	var closed_frame: Transform3D = closed_gate["frame"]
	var origin := closed_frame * Vector3(float(closed_gate["width"]) * 0.21, 1.45, float(closed_gate["depth"]) + 1.0)
	check("closed native leaf triangles span the actual passage", _nearest(_leaf_meshes(closed_gate), origin, -closed_frame.basis.z) < float(closed_gate["depth"]) + 1.2)
	game.player.position = game.village.gate_points[0]
	game.town_gates.advance(0.60)
	controller.sync()
	check("real hero access reopens the matching native gate", not game.town_gates.closed[0] and is_zero_approx(float(controller.gates[0]["progress"])))
	Prefs.reduce_motion = true
	game.town_gates.closed[0] = true
	game.town_gates.progress[0] = 0.25
	controller.sync()
	check("reduced motion immediately mirrors the real closed target", is_equal_approx(float(controller.gates[0]["progress"]), 1.0))
	var batch := Ortho3DStaticBatch.apply(fixture.stage)
	await _frames(1)
	var leaves_survive := true
	for gate: Dictionary in controller.gates:
		for mesh: MeshInstance3D in _leaf_meshes(gate):
			leaves_survive = leaves_survive and is_instance_valid(mesh) and mesh.has_meta("exclude_static_batch") and not mesh.is_queued_for_deletion()
	check("dynamic gate meshes cannot be absorbed into static box batches", int(batch["boxes"]) == 0 and leaves_survive)
	Prefs.reduce_motion = old_reduce
	fixture.queue_free()
	game.queue_free()
	await _frames(2)

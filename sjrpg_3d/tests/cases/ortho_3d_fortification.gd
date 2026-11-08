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


func _swept_panel_check(controller: Ortho3DFortification, game: Node, wood: Material) -> void:
	var original_progress: Array[float] = game.town_gates.progress.duplicate()
	game.town_gates.progress.assign([1.0, 1.0, 1.0, 1.0])
	controller.sync()
	var closed := {}
	var hinges := {}
	var depths := {}
	for gate: Dictionary in controller.gates:
		var outward: Vector3 = gate["outward"]
		for leaf: Node3D in gate["leaves"]:
			var hinge := leaf.get_parent() as Node3D
			hinges[leaf.get_instance_id()] = hinge.global_transform
			var depth := 0.0
			for mesh: MeshInstance3D in leaf.find_children("*", "MeshInstance3D", true, false):
				var points := PackedVector3Array()
				for surface in mesh.mesh.get_surface_count():
					var arrays := mesh.mesh.surface_get_arrays(surface)
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					for vertex in vertices:
						var point := mesh.global_transform * vertex
						points.append(point)
						depth = maxf(depth, absf((point - hinge.global_position).dot(outward)))
				closed[mesh.get_instance_id()] = points
			depths[leaf.get_instance_id()] = depth
	# Test installed mesh vertices in actual world space, including both faces,
	# arch tops, braces and hinge hardware. Thickness can straddle the hinge plane;
	# the free wood edges must travel substantially outside that finite envelope.
	for progress in [1.0, 0.5, 0.0]:
		game.town_gates.progress.assign([progress, progress, progress, progress])
		controller.sync()
		for gate_index in controller.gates.size():
			var gate: Dictionary = controller.gates[gate_index]
			var frame: Transform3D = gate["frame"]
			var outward: Vector3 = gate["outward"]
			var half := float(gate["width"]) * 0.5
			for leaf_index in 2:
				var leaf: Node3D = gate["leaves"][leaf_index]
				var hinge := leaf.get_parent() as Node3D
				var stationary := hinge.global_transform.is_equal_approx(hinges[leaf.get_instance_id()])
				var full_envelope := true
				var distal_outward := true
				var distal_count := 0
				var depth: float = depths[leaf.get_instance_id()]
				for mesh: MeshInstance3D in leaf.find_children("*", "MeshInstance3D", true, false):
					var old_points: PackedVector3Array = closed[mesh.get_instance_id()]
					var index := 0
					for surface in mesh.mesh.get_surface_count():
						var arrays := mesh.mesh.surface_get_arrays(surface)
						var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
						for vertex in vertices:
							var point := mesh.global_transform * vertex
							var original := old_points[index]
							index += 1
							var outside := (point - hinge.global_position).dot(outward)
							full_envelope = full_envelope and outside >= -depth - 0.0001 and absf(point.y - original.y) < 0.0001
							if progress == 1.0:
								full_envelope = full_envelope and point.distance_to(original) < 0.0001
							if mesh.material_override == wood and absf((original - hinge.global_position).dot(frame.basis.x)) > half * 0.8:
								distal_count += 1
								if progress < 1.0:
									distal_outward = distal_outward and outside > half * (0.45 if progress == 0.5 else 0.70) - depth
				check("gate %d leaf %d actual closed/half/open vertices sweep outside at %s" % [gate_index, leaf_index, progress], stationary and full_envelope and distal_outward and distal_count > 0)
	game.town_gates.progress.assign(original_progress)
	controller.sync()


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
	var installed: Array = report["static_meshes"].duplicate()
	for gate: Dictionary in controller.gates:
		installed.append_array(_leaf_meshes(gate))
	var actual_triangles := 0
	for mesh: MeshInstance3D in installed:
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			actual_triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
	check("fortification budget counts actual installed static and moving geometry", actual_triangles == int(report["triangles"]) and actual_triangles < 30000)
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
	_check_wall_relief(report, stone_meshes)
	var reversed_safe: PackedVector2Array = game.village.safe_zone.duplicate()
	reversed_safe.reverse()
	var town_center: Vector3 = report["town_center"]
	for gate: Dictionary in controller.gates:
		var frame: Transform3D = gate["frame"]
		var outward_normal: Vector3 = gate["outward"]
		check("gate exterior follows actual safe boundary independently of winding", outward_normal.length() > 0.999 and outward_normal.dot(frame.origin - town_center) > 0.0 and outward_normal.is_equal_approx(Ortho3DFortification._outward_normal(reversed_safe, frame.origin)))
	_swept_panel_check(controller, game, fixture._materials["wood"])
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


## Ray measurements use the installed merged stone, including both wall axes and
## inside/outside faces. Pick central fields to avoid gatehouse occlusion.
func _check_wall_relief(report: Dictionary, stone_meshes: Array) -> void:
	var piers: Array = report["wall_piers"]
	var fields: Array = report["wall_fields"]
	check("wall detail keeps its original stone and bounded face depth", is_equal_approx(float(report["wall_face_recess"]), 0.045) and piers.size() >= 8 and fields.size() >= 4)
	check("all towers have stone slit surrounds and restrained moulded bands", int(report["slit_reveals"]) == 32 and int(report["moulded_rings"]) == 16 and int(report["coped_pieces"]) > 100)
	var probes := {}
	for family: String in ["wall_piers", "wall_fields"]:
		var selected := {}
		for entry: Dictionary in report[family]:
			var frame: Transform3D = entry["frame"]
			var normal := frame.basis.z
			var key := "%d:%d" % [roundi(normal.x), roundi(normal.z)]
			var clearance := INF
			for gate: Dictionary in report["gates"]:
				var gate_frame: Transform3D = gate["frame"]
				clearance = minf(clearance, Vector2(frame.origin.x - gate_frame.origin.x, frame.origin.z - gate_frame.origin.z).length())
			if not selected.has(key) or clearance > float(selected[key]["clearance"]):
				selected[key] = {"entry": entry, "clearance": clearance}
		check("wall relief has physical samples on both inside/outside axes " + family, selected.size() == 4)
		var measurements := {}
		for key: String in selected:
			var entry: Dictionary = selected[key]["entry"]
			var frame: Transform3D = entry["frame"]
			var origin := frame.origin + Vector3.UP * float(entry["height"]) + frame.basis.z * 0.20
			var measured := _nearest(stone_meshes, origin, -frame.basis.z)
			var expected := 0.245 if family == "wall_fields" else 0.20
			measurements[key] = measured
			check("actual merged masonry preserves recessed field/pier relief " + family + " " + key, is_finite(measured) and absf(measured - expected) < 0.001)
		probes[family] = measurements
	_check_tower_recesses(report, stone_meshes)
	print("ART_AUDIT native_wall_finish " + JSON.stringify({"triangles": report["triangles"], "static_surfaces": report["static_surfaces"], "piers": piers.size(), "fields": fields.size(), "coped_pieces": report["coped_pieces"], "moulded_rings": report["moulded_rings"], "slit_reveals": report["slit_reveals"], "actual_depths": probes}))


## Natural wall attachments may cover two faces of a tower. Test every actual
## recessed back, and the visible cavities against their installed stone planes.
func _check_tower_recesses(report: Dictionary, stone_meshes: Array) -> void:
	var iron_meshes := []
	for mesh: MeshInstance3D in report["static_meshes"]:
		if mesh.material_override != report["stone"]:
			iron_meshes.append(mesh)
	var frames: Array = report["slit_frames"]
	var exposed := 0
	var depth_min := INF
	var depth_max := 0.0
	check("all eight actual towers have four real inset slot faces", frames.size() == 32 and is_equal_approx(float(report["slit_depth"]), 0.10))
	for index in frames.size():
		var frame: Transform3D = frames[index]
		var center := frame.origin + Vector3.UP * float(report["slit_height"])
		var origin := center + frame.basis.z * 0.20
		var back := _nearest(iron_meshes, origin, -frame.basis.z)
		depth_min = minf(depth_min, back)
		depth_max = maxf(depth_max, back)
		check("actual dark back is10cm behind the tower face " + str(index), is_finite(back) and absf(back - 0.30) < 0.001)
		var occluded := false
		var point := Vector2(center.x, center.z)
		for polygon: PackedVector2Array in report["wall_polygons"]:
			occluded = occluded or Geometry2D.is_point_in_polygon(point, polygon)
		if occluded:
			continue
		exposed += 1
		var stone := _nearest(stone_meshes, origin, -frame.basis.z)
		if stone <= 0.305:
			var nearby := []
			for polygon: PackedVector2Array in report["wall_polygons"]:
				var front := Vector2(center.x, center.z)
				var behind := center - frame.basis.z * 0.10
				var back_point := Vector2(behind.x, behind.z)
				var front_distance := INF
				var back_distance := INF
				for edge in polygon.size():
					front_distance = minf(front_distance, front.distance_to(Geometry2D.get_closest_point_to_segment(front, polygon[edge], polygon[(edge + 1) % polygon.size()])))
					back_distance = minf(back_distance, back_point.distance_to(Geometry2D.get_closest_point_to_segment(back_point, polygon[edge], polygon[(edge + 1) % polygon.size()])))
				if minf(front_distance, back_distance) < 0.5:
					nearby.append({"polygon": polygon, "front_inside": Geometry2D.is_point_in_polygon(front, polygon), "back_inside": Geometry2D.is_point_in_polygon(back_point, polygon), "front_distance": front_distance, "back_distance": back_distance})
			print("ART_AUDIT WALL_SLOT_DIAGNOSTIC " + JSON.stringify({"index": index, "center": center, "normal": frame.basis.z, "stone": stone, "iron": back, "nearest_stone": _nearest_detail(stone_meshes, origin, -frame.basis.z), "nearby_original_walls": nearby}))
		check("visible inset is not painted on an opaque cylinder " + str(index), stone > 0.305)
		var inside := center - frame.basis.z * 0.05
		for side in [-1.0, 1.0]:
			var reveal := _nearest(stone_meshes, inside, frame.basis.x * side)
			check("actual stone side reveals enclose the slot volume " + str(index) + " " + str(side), is_finite(reveal) and absf(reveal - 0.0375) < 0.001)
	check("at least two exposed real slot faces per tower remain readable", exposed >= 16)
	print("ART_AUDIT native_tower_recess " + JSON.stringify({"slot_faces": frames.size(), "exposed": exposed, "actual_back_distance_min": depth_min, "actual_back_distance_max": depth_max, "depth_m": report["slit_depth"], "slot_height_m": report["slit_height"]}))


func _nearest_detail(meshes: Array, origin: Vector3, direction: Vector3) -> Dictionary:
	var nearest := INF
	var result := {}
	for mesh: MeshInstance3D in meshes:
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var count := indices.size() if not indices.is_empty() else vertices.size()
			for index in range(0, count, 3):
				var a: int = indices[index] if not indices.is_empty() else index
				var b: int = indices[index + 1] if not indices.is_empty() else index + 1
				var c: int = indices[index + 2] if not indices.is_empty() else index + 2
				var p := mesh.global_transform * vertices[a]
				var q := mesh.global_transform * vertices[b]
				var r := mesh.global_transform * vertices[c]
				var hit = Geometry3D.ray_intersects_triangle(origin, direction, p, q, r)
				if hit is Vector3 and origin.distance_to(hit) < nearest:
					nearest = origin.distance_to(hit)
					result = {"distance": nearest, "hit": hit, "vertices": [p, q, r], "normal": mesh.global_basis * normals[a], "mesh": mesh.name}
	return result

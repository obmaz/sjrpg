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
	var stone: Material = StandardMaterial3D.new()
	(stone as StandardMaterial3D).uv1_triplanar = true
	(stone as StandardMaterial3D).uv1_world_triplanar = true
	(stone as StandardMaterial3D).uv1_scale = Vector3.ONE * 0.390625
	var granite: Material = stone.duplicate()
	(granite as StandardMaterial3D).albedo_color = Color(0.74, 0.76, 0.80)
	fixture._materials = {"stone": stone, "granite": granite, "wood": StandardMaterial3D.new(), "iron": StandardMaterial3D.new()}
	add_child(fixture)
	fixture.add_child(fixture.stage)
	var controller := Ortho3DFortification.build(fixture)
	var report: Dictionary = controller.report
	stone = report["stone"]
	granite = report["granite"]
	check("native fortification uses all four actual gate passages and eight wing joins", controller.gates.size() == 4 and report["wing_joins"].size() == 8 and report["corners"].size() == 4)
	check("masonry geometry and material submissions stay bounded", int(report["triangles"]) < 30000 and int(report["triangles"]) > 1000 and int(report["static_surfaces"]) <= 4)
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
		if mesh.material_override == stone or mesh.material_override == granite:
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
	# Pale ashlar body plus darker granite plinth/bands/copings: two masonry
	# surfaces sharing the same world-scaled course grid.
	check("fortress shares four generated masonry variants across two opaque lit materials", stone_meshes.size() == 2 and stone is ShaderMaterial and granite is ShaderMaterial and stone.get_shader_parameter("masonry_atlas") == load("res://assets/art/preview3d/fortress-atlas.png") and granite.get_shader_parameter("dressed") == true and report["masonry_variants"] == 4)
	check("corner crowns rise above the wall battlements", float(report["corner_top"]) > float(report["wall_top"]) + 0.60)
	check("fortification mesh normals UVs and winding remain valid", valid and winding)
	_check_corner_towers(report, stone_meshes, game)
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


## 실제 설치된 지붕·창 깊이·높은 몸체의 충돌을 측정한다.
func _check_corner_towers(report: Dictionary, masonry: Array, game: Node) -> void:
	var roofs := []
	var backs := []
	for mesh: MeshInstance3D in report["static_meshes"]:
		if mesh.material_override == report["corner_roof"]:
			roofs.append(mesh)
		if mesh.material_override == report["iron"]:
			backs.append(mesh)
	check("four corner towers share a single textured slate surface", roofs.size() == 1 and report["corner_roof"].albedo_texture == load("res://assets/art/preview3d/slate.webp"))
	for corner: Vector3 in report["corners"]:
		for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
			var from := corner + axis * 0.55 + Vector3.UP * 9.0
			var roof := _nearest(roofs, from, Vector3.DOWN)
			check("actual conical slate roof rises well above the curtain wall", roof > 2.3 and roof < 3.3)
			var roof_query := PhysicsRayQueryParameters3D.create(from, from - Vector3.UP * 5.0, SpatialWorld3D.SOLID)
			var roof_hit: Dictionary = game.spatial_world.get_world_3d().direct_space_state.intersect_ray(roof_query)
			check("roof has the same sloping native solid rather than an invisible box", not roof_hit.is_empty() and roof_hit["collider"].get_meta("physics_kind", "") == "CornerRoof" and absf(from.distance_to(roof_hit["position"]) - roof) < 0.04)
		var outward: Vector3 = ((corner - report["town_center"]) * Vector3(1, 0, 1)).normalized()
		var origin := corner + outward * 3.0 + Vector3.UP * 3.80
		var visible := _nearest(masonry, origin, -outward)
		var query := PhysicsRayQueryParameters3D.create(origin, origin - outward * 3.0, SpatialWorld3D.SOLID)
		var hit: Dictionary = game.spatial_world.get_world_3d().direct_space_state.intersect_ray(query)
		check("tall corner shaft has matching solid collision above the old wall top", is_finite(visible) and not hit.is_empty() and hit["collider"].get_meta("physics_kind", "") == "CornerBastion" and absf(origin.distance_to(hit["position"]) - visible) < 0.04)
	var windows: Array = report["corner_windows"]
	var measured := 0
	for window: Dictionary in windows:
		if float(window["height"]) < 3.1:
			continue
		var frame: Transform3D = window["frame"]
		var origin := frame.origin + Vector3.UP * float(window["height"]) + frame.basis.z * 0.20
		var back := _nearest(backs, origin, -frame.basis.z)
		check("upper tower windows have real stone openings and recessed dark backs", _nearest(masonry, origin, -frame.basis.z) > 0.305 and absf(back - 0.30) < 0.001)
		measured += 1
	check("each corner has readable upper shaft and gallery windows on all sides", measured == 32)
	print("ART_AUDIT roofed_corner_towers " + JSON.stringify({"roof_surfaces": roofs.size(), "upper_window_depths_checked": measured, "triangles": report["triangles"]}))


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
		if mesh.material_override == report["iron"]:
			iron_meshes.append(mesh)
	var frames: Array = report["slit_frames"]
	var exposed := 0
	var partial_overlaps := 0
	var partial_depths: Array[float] = []
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
		var original_entry := _original_wall_entry(report, center, frame.basis.z)
		if is_finite(original_entry):
			partial_overlaps += 1
			partial_depths.append(stone - 0.20)
			check("original wall overlap keeps the independently predicted visible slot depth " + str(index), original_entry >= 0.05 and original_entry < 0.10 and absf(stone - (0.20 + original_entry)) < 0.001)
		else:
			check("fully exposed inset has no opaque cylinder or unexpected fill " + str(index), stone > 0.305)
		var inside := center - frame.basis.z * 0.05
		for side in [-1.0, 1.0]:
			var reveal := _nearest(stone_meshes, inside, frame.basis.x * side)
			check("actual stone side reveals enclose the slot volume " + str(index) + " " + str(side), is_finite(reveal) and absf(reveal - 0.0375) < 0.001)
	check("at least sixteen exposed real slot mouths remain readable", exposed >= 16)
	print("ART_AUDIT native_tower_recess " + JSON.stringify({"slot_faces": frames.size(), "exposed_mouths": exposed, "fully_exposed": exposed - partial_overlaps, "partial_wall_overlaps": partial_overlaps, "partial_visible_depths_m": partial_depths, "actual_back_distance_min": depth_min, "actual_back_distance_max": depth_max, "nominal_back_depth_m": report["slit_depth"], "slot_height_m": report["slit_height"]}))


## Predict cavity occlusion from the unchanged original wall polygons and their
## recorded4.5cm inset. No observed ray distance or failing slot index is used.
func _original_wall_entry(report: Dictionary, mouth: Vector3, normal: Vector3) -> float:
	var first := Vector2(mouth.x, mouth.z)
	var last := first - Vector2(normal.x, normal.z) * float(report["slit_depth"])
	var nearest := INF
	for polygon: PackedVector2Array in report["wall_polygons"]:
		var crosses_original := false
		for index in polygon.size():
			var crossing: Variant = Geometry2D.segment_intersects_segment(first, last, polygon[index], polygon[(index + 1) % polygon.size()])
			crosses_original = crosses_original or crossing is Vector2
		if not crosses_original:
			continue
		for inset in Geometry2D.offset_polygon(polygon, -float(report["wall_face_recess"]), Geometry2D.JOIN_MITER):
			for index in inset.size():
				var crossing: Variant = Geometry2D.segment_intersects_segment(first, last, inset[index], inset[(index + 1) % inset.size()])
				if crossing is Vector2:
					nearest = minf(nearest, first.distance_to(crossing))
	return nearest

class_name Ortho3DFortification
extends RefCounted
## The real village's wall polygons/wing ends are the sole ground join datums.
## Static masonry is merged by shared material. Hinged leaves stay independent
## ArrayMeshes, explicitly excluded from box batching, and read the real gate clock.

const OPEN_ANGLE := 1.50
const JOINT_OVERLAP := 0.025
const CRENEL_SPACING := 0.86
var preview: Node
var root: Node3D
var dynamic_root: Node3D
var gates: Array[Dictionary] = []
var report := {}
var _materials := {}
var _tools := {}
var _box_arrays: Array
var _triangles := 0
var _target: Node3D


static func build(presenter: Node) -> Ortho3DFortification:
	var controller := Ortho3DFortification.new()
	controller.preview = presenter
	controller._build()
	controller.sync()
	return controller


func _build() -> void:
	_materials = preview._materials.duplicate()
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	_box_arrays = unit.surface_get_arrays(0)
	root = Node3D.new()
	root.name = "NativeFortification"
	preview.stage.add_child(root)
	_target = root
	dynamic_root = Node3D.new()
	dynamic_root.name = "MovingGateLeaves"
	dynamic_root.set_meta("exclude_static_batch", true)
	root.add_child(dynamic_root)
	var village: Village = preview.game.village
	# The original200-unit wall datum includes battlements, and projects to
	#200*Iso.S pixels. Do not add another merlon height on top of that datum.
	var total_height := village.wall_height / Ortho3DPreview.GROUND_PER_METER
	var height := total_height - 0.57
	var thickness := village.wall_thick / Ortho3DPreview.GROUND_PER_METER
	var polygons: Array[PackedVector2Array] = []
	for footprint in village.wall_footprints:
		polygons.append(_flat_polygon(footprint))
	var town_center := Vector3.ZERO
	for point in village.safe_zone:
		town_center += Ortho3DPreview.ground_position(point)
	town_center /= village.safe_zone.size()
	var wings: Array[Dictionary] = []
	for index in village.gate_points.size():
		var passage := _flat_polygon(village.gate_passages[index])
		var across := Vector3.RIGHT if index < 2 else Vector3(0, 0, 1)
		var basis := Basis(across, Vector3.UP, across.cross(Vector3.UP))
		var center := Vector3.ZERO
		for point in passage:
			center += Vector3(point.x, 0, point.y)
		center /= passage.size()
		var frame := Transform3D(basis, center)
		var inverse := frame.affine_inverse()
		var local := PackedVector2Array()
		for point in passage:
			var at := inverse * Vector3(point.x, 0, point.y)
			local.append(Vector2(at.x, at.z))
		var bounds := Iso.poly_bounds(local)
		var width := bounds.size.x + 0.02
		var gate_depth := maxf(thickness, bounds.size.y * 0.8)
		var shoulder := 2.55
		var outward := _outward_normal(village.safe_zone, center)
		var opening_sign := signf(basis.z.dot(outward))
		var entry := {"frame": frame, "width": width, "depth": gate_depth, "shoulder": shoulder,
			"point": Ortho3DPreview.ground_position(village.gate_points[index]), "outward": outward, "opening_sign": opening_sign, "leaves": [], "progress": 0.0}
		for native_end: Vector2 in village.gate_ends[index]:
			var join := Vector3(native_end.x, 0, native_end.y) / Ortho3DPreview.GROUND_PER_METER
			var end := inverse * join
			var side := signf(end.x)
			var start := end + Vector3(side * JOINT_OVERLAP, 0, 0)
			var finish := Vector3(side * width * 0.5, 0, end.z)
			var polygon := _strip(frame * start, frame * finish, thickness)
			polygons.append(polygon)
			wings.append({"gate": index, "join": join, "polygon": polygon})
		_gate_arch(frame, width, gate_depth, shoulder, height)
		_towers(village, index, height)
		gates.append(entry)
	var merged := _union(polygons)
	for polygon in merged:
		_horizontal(polygon, 0.0, height, "stone")
		for band in [[0.14, 0.16, 0.018], [height * 0.76, 0.08, 0.030], [height - 0.025, 0.10, 0.035]]:
			var expanded := Geometry2D.offset_polygon(polygon, float(band[2]), Geometry2D.JOIN_MITER)
			for shape in expanded:
				_horizontal(shape, float(band[0]), float(band[0]) + float(band[1]), "stone")
	var corners: Array[Vector3] = []
	for run: Array in village.data["wall_runs"]:
		var point: Array = run[1]
		var corner := Ortho3DPreview.ground_position(village.point(Vector2(point[0], point[1])))
		corners.append(corner)
		_box(corner + Vector3(0, height + 0.30, 0), Vector3(0.54, 0.54, 0.54), "stone")
	var crenels := {}
	for polygon in polygons:
		_crenels(polygon, corners, crenels, height, thickness)
	var static_meshes := _flush("Fortification")
	for index in gates.size():
		_build_leaves(index)
	report = {"wall_height": height, "wall_top": total_height, "projected_top_pixels": total_height * Ortho3DPreview.GROUND_PER_METER * Iso.S,
		"wall_thickness": thickness, "wall_polygons": merged, "wing_joins": wings,
		"corners": corners, "town_center": town_center, "gates": gates, "static_meshes": static_meshes,
		"triangles": _triangles, "static_surfaces": static_meshes.size(), "stone": _materials["stone"]}
	root.set_meta("fortification_detail", report)


## No independent tween or timer: pause, accessibility and real threat scan remain authoritative.
func sync() -> void:
	if not is_instance_valid(root) or not is_instance_valid(preview):
		return
	var state: TownGateRuntime = preview.game.town_gates
	for index in gates.size():
		var value := (1.0 if state.closed[index] else 0.0) if Prefs.reduce_motion else state.progress[index]
		value = clampf(value, 0.0, 1.0)
		var gate: Dictionary = gates[index]
		gate["progress"] = value
		var opening_sign: float = gate["opening_sign"]
		var leaves: Array = gate["leaves"]
		for leaf_index in leaves.size():
			var leaf: Node3D = leaves[leaf_index]
			var side := -1.0 if leaf_index == 0 else 1.0
			# A closed leaf extends along -side*x. Y rotation moves that span toward
			# side*sin(angle)*z, so this sign sends both leaves outside the safe zone.
			leaf.rotation.y = side * opening_sign * OPEN_ANGLE * (1.0 - value)


## Derive exterior from the actual nearest safe-zone edge, independently of camera
## and polygon winding. Town-centre guesses can flip on offset/asymmetric passages.
static func _outward_normal(safe_zone: PackedVector2Array, point: Vector3) -> Vector3:
	var polygon := _flat_polygon(safe_zone)
	var at := Vector2(point.x, point.z)
	var nearest := INF
	var outward := Vector2.ZERO
	for index in polygon.size():
		var first := polygon[index]
		var last := polygon[(index + 1) % polygon.size()]
		var edge := last - first
		if edge.length_squared() < 0.000001:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(at, first, last)
		var distance := closest.distance_squared_to(at)
		if distance >= nearest:
			continue
		nearest = distance
		outward = edge.orthogonal().normalized()
		if Geometry2D.is_point_in_polygon((first + last) * 0.5 + outward * 0.05, polygon):
			outward = -outward
	return Vector3(outward.x, 0.0, outward.y)


static func _flat_polygon(source: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in source:
		var flat := Iso.unproject(point) / Ortho3DPreview.GROUND_PER_METER
		result.append(flat)
	return result


static func _strip(a: Vector3, b: Vector3, width: float) -> PackedVector2Array:
	var first := Vector2(a.x, a.z)
	var last := Vector2(b.x, b.z)
	var offset := (last - first).normalized().orthogonal() * width * 0.5
	return PackedVector2Array([first - offset, last - offset, last + offset, first + offset])


static func _union(source: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var shapes: Array[PackedVector2Array] = source.duplicate()
	var changed := true
	while changed:
		changed = false
		for first in shapes.size():
			if changed:
				break
			for second in range(first + 1, shapes.size()):
				var result := Geometry2D.merge_polygons(shapes[first], shapes[second])
				if result.size() == 1:
					shapes[first] = result[0]
					shapes.remove_at(second)
					changed = true
					break
	return shapes


func _crenels(polygon: PackedVector2Array, corners: Array[Vector3], used: Dictionary, height: float, thickness: float) -> void:
	var bounds := Iso.poly_bounds(polygon)
	var along_x := bounds.size.x > bounds.size.y
	var first := bounds.position.x if along_x else bounds.position.y
	var last := bounds.end.x if along_x else bounds.end.y
	var cross := bounds.get_center().y if along_x else bounds.get_center().x
	for index in range(ceili(first / CRENEL_SPACING), floori(last / CRENEL_SPACING) + 1):
		var at := Vector3(index * CRENEL_SPACING, height + 0.30, cross) if along_x else Vector3(cross, height + 0.30, index * CRENEL_SPACING)
		var near_corner := false
		for corner in corners:
			near_corner = near_corner or Vector2(at.x, at.z).distance_to(Vector2(corner.x, corner.z)) < 0.62
		var key := "%d:%d" % [roundi(at.x * 20.0), roundi(at.z * 20.0)]
		if near_corner or used.has(key):
			continue
		used[key] = true
		_box(at, Vector3(0.47, 0.54, thickness) if along_x else Vector3(thickness, 0.54, 0.47), "stone")


func _gate_arch(frame: Transform3D, width: float, depth: float, shoulder: float, wall_height: float) -> void:
	var radius := width * 0.5
	var order := 0.22
	var crown := shoulder + radius + order + 0.16
	for side in [-1.0, 1.0]:
		_box(Vector3(side * (radius + order * 0.5), shoulder * 0.5, 0), Vector3(order, shoulder, depth), "stone", frame)
	for segment in 24:
		var a := segment * PI / 24.0 + 0.004
		var b := (segment + 1) * PI / 24.0 - 0.004
		var polygon := PackedVector2Array([
			Vector2(cos(a), sin(a)) * radius + Vector2(0, shoulder),
			Vector2(cos(b), sin(b)) * radius + Vector2(0, shoulder),
			Vector2(cos(b), sin(b)) * (radius + order) + Vector2(0, shoulder),
			Vector2(cos(a), sin(a)) * (radius + order) + Vector2(0, shoulder)])
		_prism(polygon, depth + 0.045, frame, "stone")
		var x0 := cos(b) * (radius + order)
		var x1 := cos(a) * (radius + order)
		var bottom := shoulder + maxf(sin(a), sin(b)) * (radius + order)
		if crown > bottom:
			_box(Vector3((x0 + x1) * 0.5, (bottom + crown) * 0.5, 0), Vector3(x1 - x0 + 0.003, crown - bottom, depth), "stone", frame)
	_box(Vector3(0, crown + 0.035, 0), Vector3(width + order * 2.0, 0.10, depth + 0.08), "stone", frame)
	for side in [-1.0, 1.0]:
		_box(Vector3(side * (radius + order * 0.5), wall_height * 0.76 + 0.04, 0), Vector3(order + 0.04, 0.08, depth + 0.06), "stone", frame)
	var count := maxi(3, roundi(width / 0.65))
	for merlon in count:
		_box(Vector3(lerpf(-radius, radius, float(merlon) / (count - 1)), crown + 0.30, 0), Vector3(0.42, 0.48, depth), "stone", frame)


func _towers(village: Village, index: int, wall_height: float) -> void:
	var key := "gate-0" if index < 2 else "gate-2"
	var definition: Dictionary = village.data["sprites"][key]
	var info: Dictionary = village.data["gates"][key]
	var pose := IsoSprite.new().setup(definition, float(definition["world_height"]))
	pose.position = village.gate_points[index]
	for tower_index in 2:
		var polygon := _flat_polygon(pose.atlas_polygon(info["solids"][tower_index]))
		var bounds := Iso.poly_bounds(polygon)
		var center := Vector3(bounds.get_center().x, 0, bounds.get_center().y)
		var radius := minf(bounds.size.x, bounds.size.y) * 0.48
		var height := wall_height + 2.0
		_cylinder(center + Vector3(0, height * 0.5, 0), radius, height, "stone")
		for level in [0.14, wall_height * 0.76, wall_height, height - 0.12]:
			_cylinder(center + Vector3(0, level, 0), radius + 0.035, 0.105, "stone")
		for tooth in 10:
			var angle := tooth * TAU / 10.0
			var at := center + Vector3(cos(angle) * radius * 0.87, height + 0.26, sin(angle) * radius * 0.87)
			_box(Vector3.ZERO, Vector3(0.32, 0.52, 0.29), "stone", Transform3D(Basis(Vector3.UP, -angle), at))
		# Small iron slit/reveal pieces use real relief and shared matte material.
		for face in 4:
			var angle := face * PI * 0.5
			var normal := Vector3(cos(angle), 0, sin(angle))
			var frame := Transform3D(Basis(Vector3.UP, PI * 0.5 - angle), center + normal * (radius + 0.008))
			_box(Vector3(0, wall_height * 0.64, 0), Vector3(0.075, 0.60, 0.025), "iron", frame)
			_box(Vector3(0, wall_height * 0.64 - 0.11, 0.02), Vector3(0.20, 0.035, 0.035), "iron", frame)
	pose.free()


func _build_leaves(index: int) -> void:
	var gate: Dictionary = gates[index]
	var frame: Transform3D = gate["frame"]
	var width: float = gate["width"]
	var shoulder: float = gate["shoulder"]
	var half := width * 0.5
	var leaves: Array = gate["leaves"]
	for side in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.name = "Gate%d_%s" % [index, "left" if side < 0 else "right"]
		hinge.set_meta("exclude_static_batch", true)
		dynamic_root.add_child(hinge)
		hinge.transform = frame * Transform3D(Basis.IDENTITY, Vector3(side * half, 0, 0))
		# A separate orientation node lets sync rotate locally without overwriting
		# the gate frame's second ground-axis direction.
		var leaf := Node3D.new()
		leaf.set_meta("exclude_static_batch", true)
		hinge.add_child(leaf)
		_target = leaf
		for plank in 7:
			var a := half * plank / 7.0 + 0.004
			var b := half * (plank + 1) / 7.0 - 0.004
			var left := minf(-side * a, -side * b)
			var right := maxf(-side * a, -side * b)
			var first_y := shoulder + sqrt(maxf(0.0, half * half - pow(side * half + left, 2.0))) - 0.07
			var last_y := shoulder + sqrt(maxf(0.0, half * half - pow(side * half + right, 2.0))) - 0.07
			_prism(PackedVector2Array([Vector2(left, 0.035), Vector2(right, 0.035), Vector2(right, last_y), Vector2(left, first_y)]), 0.10, Transform3D.IDENTITY, "wood")
		for level in [0.60, 1.70, 2.40]:
			_box(Vector3(-side * half * 0.5, level, 0.065), Vector3(half * 0.94, 0.075, 0.045), "iron")
			for rivet in 4:
				_box(Vector3(-side * half * (0.12 + rivet * 0.24), level, 0.096), Vector3(0.035, 0.035, 0.022), "iron")
		_cylinder(Vector3(0, 1.52, 0.045), 0.040, 2.20, "iron")
		_box(Vector3(-side * half * 0.82, 1.30, 0.10), Vector3(0.045, 0.19, 0.055), "iron")
		_flush("Leaf")
		leaves.append(leaf)
	_target = root


func _cylinder(at: Vector3, radius: float, height: float, material: String) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 24
	cylinder.rings = 1
	_append(cylinder.surface_get_arrays(0), Transform3D(Basis.IDENTITY, at), material)


func _box(at: Vector3, size: Vector3, material: String, frame := Transform3D.IDENTITY) -> void:
	_append(_box_arrays, frame * Transform3D(Basis.from_scale(size), at), material)


func _horizontal(polygon: PackedVector2Array, bottom: float, top: float, material: String) -> void:
	_prism(polygon, top - bottom, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, (top + bottom) * 0.5, 0)), material)


func _append(arrays: Array, transform: Transform3D, material: String) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_basis := transform.basis.inverse().transposed()
	var count := indices.size() if not indices.is_empty() else vertices.size()
	var tool := _tool(material)
	for index in count:
		var vertex := indices[index] if not indices.is_empty() else index
		tool.set_normal((normal_basis * normals[vertex]).normalized())
		tool.set_uv(uv[vertex])
		tool.add_vertex(transform * vertices[vertex])
	_triangles += count / 3


func _tool(material: String) -> SurfaceTool:
	if not _tools.has(material):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[material] = tool
	return _tools[material] as SurfaceTool


func _prism(polygon: PackedVector2Array, depth: float, frame: Transform3D, material: String) -> void:
	var triangles := Geometry2D.triangulate_polygon(polygon)
	var normal_basis := frame.basis.inverse().transposed()
	var bounds := Iso.poly_bounds(polygon)
	for side in [-1.0, 1.0]:
		for index in range(0, triangles.size(), 3):
			var vertices: Array[Vector3] = []
			var uv: Array[Vector2] = []
			for corner in 3:
				var point := polygon[triangles[index + corner]]
				vertices.append(frame * Vector3(point.x, point.y, side * depth * 0.5))
				uv.append((point - bounds.position) / bounds.size.max(Vector2.ONE * 0.001))
			_triangle(vertices, uv, (normal_basis * Vector3(0, 0, side)).normalized(), material)
	var area := 0.0
	for index in polygon.size():
		area += polygon[index].cross(polygon[(index + 1) % polygon.size()])
	for index in polygon.size():
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		var delta := b - a
		var normal := (normal_basis * Vector3(delta.y, -delta.x, 0) * signf(area)).normalized()
		var vertices := [frame * Vector3(a.x, a.y, -depth * 0.5), frame * Vector3(b.x, b.y, -depth * 0.5), frame * Vector3(b.x, b.y, depth * 0.5), frame * Vector3(a.x, a.y, depth * 0.5)]
		_triangle([vertices[0], vertices[1], vertices[2]], [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE], normal, material)
		_triangle([vertices[0], vertices[2], vertices[3]], [Vector2.ZERO, Vector2.ONE, Vector2.DOWN], normal, material)


func _triangle(vertices: Array, uv: Array, normal: Vector3, material: String) -> void:
	var tool := _tool(material)
	var order := [0, 2, 1] if (vertices[1] - vertices[0]).cross(vertices[2] - vertices[0]).dot(normal) > 0.0 else [0, 1, 2]
	for index in order:
		tool.set_normal(normal)
		tool.set_uv(uv[index])
		tool.add_vertex(vertices[index])
	_triangles += 1


func _flush(prefix: String) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for material: String in _tools:
		var tool: SurfaceTool = _tools[material]
		tool.index()
		var mesh := MeshInstance3D.new()
		mesh.name = prefix + "_" + material
		mesh.mesh = tool.commit()
		mesh.material_override = _materials[material]
		if _target != root:
			mesh.set_meta("exclude_static_batch", true)
		_target.add_child(mesh)
		meshes.append(mesh)
	_tools.clear()
	return meshes

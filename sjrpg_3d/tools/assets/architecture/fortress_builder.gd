class_name NativeFortressBuilder
extends RefCounted
## The real village's wall polygons/wing ends are the sole ground join datums.
## Static masonry is merged by shared material. Hinged leaves stay independent
## ArrayMeshes, explicitly excluded from box batching, and read the real gate clock.

const OPEN_ANGLE := 1.50
const JOINT_OVERLAP := 0.025
const CRENEL_SPACING := 0.86
const WALL_FACE_RECESS := 0.045
const PIER_SPACING := 3.44
const MedievalDetails := preload("res://tools/assets/architecture/medieval_details.gd")
var renderer: Node
var root: Node3D
var dynamic_root: Node3D
var gates: Array[Dictionary] = []
var report := {}
var _materials := {}
var _tools := {}
var _box_arrays: Array
var _triangles := 0
var _target: Node3D
var _piers: Array[Dictionary] = []
var _fields: Array[Dictionary] = []
var _coped_pieces := 0
var _mouldings := 0
var _slit_reveals := 0
var _slit_frames: Array[Transform3D] = []
var _corner_windows: Array[Dictionary] = []
var _arcades := 0
var _decks: Array[Dictionary] = []
var _heraldic_frames: Array[Transform3D] = []


static func build(presenter: Node) -> NativeFortressBuilder:
	var controller := NativeFortressBuilder.new()
	controller.renderer = presenter
	controller._build()
	controller.sync()
	return controller


func _build() -> void:
	_materials = renderer._materials.duplicate()
	# 같은 참나무 바탕에 노출된 성곽 목재만 더 차갑게 풍화시킨다.
	var oak := (_materials["wood"] as StandardMaterial3D).duplicate() as StandardMaterial3D
	oak.albedo_color *= Color(.76, .79, .80)
	_materials["wood"] = oak
	for key: String in ["stone", "granite"]:
		var material := ShaderMaterial.new()
		material.shader = load("res://assets/models/architecture/fortress/surface.gdshader")
		material.set_shader_parameter(
			"masonry_atlas", load("res://assets/materials/shared/fortress_atlas.png")
		)
		material.set_shader_parameter("dressed", key == "granite")
		_materials[key] = material
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	_box_arrays = unit.surface_get_arrays(0)
	root = Node3D.new()
	root.name = "NativeFortification"
	NativePlayerOcclusion.mark_object(root)
	renderer.stage.add_child(root)
	_target = root
	dynamic_root = Node3D.new()
	dynamic_root.name = "MovingGateLeaves"
	dynamic_root.set_meta("occlusion_dynamic", true)
	dynamic_root.set_meta("exclude_static_batch", true)
	root.add_child(dynamic_root)
	var village: Village = renderer.game.village
	# The original200-unit wall datum includes battlements, and projects to
	#200*Iso.S pixels. Do not add another merlon height on top of that datum.
	var total_height := village.wall_height / WorldRenderer3D.GROUND_PER_METER
	var height := total_height - 0.57
	var thickness := village.wall_thick / WorldRenderer3D.GROUND_PER_METER
	var polygons: Array[PackedVector2Array] = []
	for footprint in village.wall_footprints:
		polygons.append(_flat_polygon(footprint))
	var town_center := Vector3.ZERO
	for point in village.safe_zone:
		town_center += WorldRenderer3D.ground_position(point)
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
		var entry := {
			"frame": frame,
			"width": width,
			"depth": gate_depth,
			"shoulder": shoulder,
			"point": WorldRenderer3D.ground_position(village.gate_points[index]),
			"outward": outward,
			"opening_sign": opening_sign,
			"leaves": [],
			"progress": 0.0
		}
		for native_end: Vector2 in village.gate_ends[index]:
			var join := Vector3(native_end.x, 0, native_end.y) / WorldRenderer3D.GROUND_PER_METER
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
		_wall_body(polygon, height, town_center)
		for band in [
			[0.14, 0.16, 0.018], [height * 0.76, 0.08, 0.030], [height - 0.025, 0.10, 0.035]
		]:
			var expanded := Geometry2D.offset_polygon(
				polygon, float(band[2]), Geometry2D.JOIN_MITER
			)
			for shape in expanded:
				_horizontal(shape, float(band[0]), float(band[0]) + float(band[1]), "granite")
	var corners: Array[Vector3] = []
	for corner: Vector3 in FortressPlan3D.corners(village):
		corners.append(corner)
		_corner_tower(corner)
	# 성문 날개 끝의 층진 기둥머리. 지상 통로는 기존 벽 폭 그대로 둔다.
	for wing: Dictionary in wings:
		var at: Vector3 = wing["join"]
		_coped_box(at + Vector3.UP * (height + 0.13), Vector3(0.72, 0.28, 0.72), "granite")
		_coped_box(at + Vector3.UP * (height + 0.43), Vector3(0.46, 0.32, 0.46), "stone")
	var crenels := {}
	for polygon in polygons:
		_crenels(polygon, corners, crenels, height, thickness)
	var walk := FortressPlan3D.wall_walk(village)
	for part: Dictionary in walk["parts"]:
		_box(Vector3.ZERO, part["size"], part["material"], part["frame"])
	var static_meshes := _flush("Fortification")
	for index in gates.size():
		_build_leaves(index)
	report = {
		"wall_height": height,
		"wall_top": total_height,
		"projected_top_pixels": total_height * WorldRenderer3D.GROUND_PER_METER * Iso.S,
		"wall_thickness": thickness,
		"wall_polygons": merged,
		"wing_joins": wings,
		"corners": corners,
		"town_center": town_center,
		"gates": gates,
		"static_meshes": static_meshes,
		"triangles": _triangles,
		"static_surfaces": static_meshes.size(),
		"stone": _materials["stone"],
		"iron": _materials["iron"],
		"wall_face_recess": WALL_FACE_RECESS,
		"wall_piers": _piers,
		"wall_fields": _fields,
		"coped_pieces": _coped_pieces,
		"moulded_rings": _mouldings,
		"slit_reveals": _slit_reveals,
		"slit_depth": 0.10,
		"slit_height": height * 0.60,
		"slit_frames": _slit_frames
	}
	root.set_meta("fortification_detail", report)
	report["corner_top"] = FortressPlan3D.CORNER_TOP
	report["corner_windows"] = _corner_windows
	report["tower_decks"] = _decks
	report["arcade_recesses"] = _arcades
	report["reference_style"] = "open_battlement_2d"
	report["masonry_variants"] = 4
	report["granite"] = _materials["granite"]
	report["wood"] = _materials["wood"]
	report["wall_walk"] = walk
	report["craft_family"] = MedievalDetails.FAMILY
	report["heraldic_plaques"] = 8
	report["heraldic_frames"] = _heraldic_frames


func _corner_tower(at: Vector3) -> void:
	var radius := FortressPlan3D.CORNER_RADIUS
	_corner_storey(at, radius, 0.0, 2.15, 1.30, 0.10, 0.62, false)
	_corner_storey(at, radius, 2.15, FortressPlan3D.CORNER_SHAFT_TOP, 3.40, 0.14, 0.74, true)
	for level: float in [0.14, 0.54, 2.16, 3.87]:
		_cylinder(at + Vector3.UP * level, radius + 0.025, 0.105, "granite", 16)
	# 돌출된 상부를 돌 받침과 연속 경사 돌띠가 실제로 지탱한다.
	for i: int in 8:
		var angle := TAU * i / 8.0
		var frame := Transform3D(
			Basis(Vector3.UP, -angle), at + Vector3(cos(angle) * 1.31, 3.99, sin(angle) * 1.31)
		)
		_box(Vector3.ZERO, Vector3(0.22, 0.30, 0.23), "granite", frame)
	_radial_band(at, 1.30, 1.50, 4.08, FortressPlan3D.CORNER_GALLERY_BASE, "granite")
	_open_crown(
		at, FortressPlan3D.CORNER_GALLERY_RADIUS, FortressPlan3D.CORNER_GALLERY_BASE
	)


## 네 방향 모두 실제 개구부와10cm 깊이의 측면/아치/어두운 뒷면을 가진다.
func _corner_storey(
	at: Vector3,
	radius: float,
	bottom: float,
	top: float,
	window_y: float,
	width: float,
	opening_height: float,
	arched: bool
) -> void:
	var half_face := radius * sin(PI / 16.0)
	var half_slot := width * 0.5
	var sill := window_y - opening_height * 0.5
	var head := window_y + opening_height * 0.5
	var shoulder := head - half_slot if arched else head
	for segment: int in 16:
		var angle := TAU * (segment + 0.5) / 16.0
		var normal := Vector3(cos(angle), 0, sin(angle))
		var frame := Transform3D(
			Basis(Vector3(normal.z, 0, -normal.x), Vector3.UP, normal),
			at + normal * radius * cos(PI / 16.0)
		)
		if segment % 4 != 0:
			_tower_panel(frame, -half_face, half_face, bottom, top, 0.0, "stone", at)
			continue
		_tower_panel(frame, -half_face, -half_slot, bottom, top, 0.0, "stone", at)
		_tower_panel(frame, half_slot, half_face, bottom, top, 0.0, "stone", at)
		_tower_panel(frame, -half_slot, half_slot, bottom, sill, 0.0, "stone", at)
		var back := -normal * 0.10
		for side: float in [-1.0, 1.0]:
			var lower := frame * Vector3(side * half_slot, sill, 0)
			var upper := frame * Vector3(side * half_slot, shoulder, 0)
			_quad(lower, upper, upper + back, lower + back, -frame.basis.x * side, "granite")
		var left := frame * Vector3(-half_slot, sill, 0)
		var right := frame * Vector3(half_slot, sill, 0)
		_quad(left, right, right + back, left + back, Vector3.UP, "granite")
		var pieces := 4 if arched else 1
		for piece: int in pieces:
			var x0 := lerpf(-half_slot, half_slot, float(piece) / pieces)
			var x1 := lerpf(-half_slot, half_slot, float(piece + 1) / pieces)
			var y0 := (
				shoulder + sqrt(maxf(0.0, half_slot * half_slot - x0 * x0)) if arched else head
			)
			var y1 := (
				shoulder + sqrt(maxf(0.0, half_slot * half_slot - x1 * x1)) if arched else head
			)
			var a := frame * Vector3(x0, y0, 0)
			var b := frame * Vector3(x1, y1, 0)
			_quad(a, b, frame * Vector3(x1, top, 0), frame * Vector3(x0, top, 0), normal, "stone")
			_quad(
				a,
				a + back,
				b + back,
				b,
				(frame.basis.x * (y1 - y0) - Vector3.UP * (x1 - x0)).normalized(),
				"granite"
			)
		_tower_panel(frame, -half_slot, half_slot, sill, head, -0.10, "iron")
		_corner_windows.append({"frame": frame, "height": window_y, "width": width})


func _radial_band(
	at: Vector3,
	lower_radius: float,
	upper_radius: float,
	bottom: float,
	top: float,
	material: String
) -> void:
	for segment: int in 16:
		var a := TAU * segment / 16.0
		var b := TAU * (segment + 1) / 16.0
		var normal := (
			Vector3(
				cos((a + b) * 0.5) * (top - bottom),
				lower_radius - upper_radius,
				sin((a + b) * 0.5) * (top - bottom)
			)
			. normalized()
		)
		_quad(
			at + Vector3(cos(a) * lower_radius, bottom, sin(a) * lower_radius),
			at + Vector3(cos(b) * lower_radius, bottom, sin(b) * lower_radius),
			at + Vector3(cos(b) * upper_radius, top, sin(b) * upper_radius),
			at + Vector3(cos(a) * upper_radius, top, sin(a) * upper_radius),
			normal,
			material
		)


## 중앙을 비운 돌 난간과 실제 목재 바닥. 지붕/천장으로 열린 상부를 덮지 않는다.
func _open_crown(at: Vector3, radius: float, floor_y: float) -> void:
	for part: Dictionary in FortressPlan3D.crown_parts(at, radius, floor_y):
		_box(Vector3.ZERO, part["size"], part["material"], part["frame"])
	_cylinder(at + Vector3.UP * (floor_y - .034), radius - .16, .08, "wood", 24)
	_decks.append({"at": at, "radius": radius - .16, "height": floor_y + .006})


## No independent tween or timer: pause, accessibility and real threat scan remain authoritative.
func sync() -> void:
	if not is_instance_valid(root) or not is_instance_valid(renderer):
		return
	var state: TownGateRuntime = renderer.game.town_gates
	for index in gates.size():
		var value := (
			(1.0 if state.closed[index] else 0.0) if Prefs.reduce_motion else state.progress[index]
		)
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
		var flat := Iso.unproject(point) / WorldRenderer3D.GROUND_PER_METER
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


func _crenels(
	polygon: PackedVector2Array,
	corners: Array[Vector3],
	used: Dictionary,
	height: float,
	thickness: float
) -> void:
	var bounds := Iso.poly_bounds(polygon)
	var along_x := bounds.size.x > bounds.size.y
	var first := bounds.position.x if along_x else bounds.position.y
	var last := bounds.end.x if along_x else bounds.end.y
	var cross := bounds.get_center().y if along_x else bounds.get_center().x
	for index in range(ceili(first / CRENEL_SPACING), floori(last / CRENEL_SPACING) + 1):
		var at := (
			Vector3(index * CRENEL_SPACING, height + 0.30, cross)
			if along_x
			else Vector3(cross, height + 0.30, index * CRENEL_SPACING)
		)
		var near_corner := false
		for corner in corners:
			near_corner = (
				near_corner or Vector2(at.x, at.z).distance_to(Vector2(corner.x, corner.z)) < 0.62
			)
		var key := "%d:%d" % [roundi(at.x * 20.0), roundi(at.z * 20.0)]
		if near_corner or used.has(key):
			continue
		used[key] = true
		_coped_box(
			at,
			Vector3(0.47, 0.54, thickness) if along_x else Vector3(thickness, 0.54, 0.47),
			"granite"
		)


## The ground plinth keeps the original solid footprint. Recessed wall fields,
## piers and corbels stay inside that footprint, preserving every route/clearance.
func _wall_body(polygon: PackedVector2Array, height: float, town_center: Vector3) -> void:
	# Darker granite plinth, string courses and copings frame the pale ashlar.
	_horizontal(polygon, 0.0, 0.28, "granite")
	var inset := Geometry2D.offset_polygon(polygon, -WALL_FACE_RECESS, Geometry2D.JOIN_MITER)
	if inset.is_empty():
		push_error("Native wall field is too narrow for its measured relief")
		return
	for shape in inset:
		_horizontal(shape, 0.28, height, "stone")
	for index in polygon.size():
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		var edge := b - a
		var length := edge.length()
		if length < 2.2:
			continue
		var outward := edge.orthogonal().normalized()
		if Geometry2D.is_point_in_polygon((a + b) * 0.5 + outward * 0.02, polygon):
			outward = -outward
		var normal := Vector3(outward.x, 0, outward.y)
		var tangent := Vector3(normal.z, 0, -normal.x)
		var basis := Basis(tangent, Vector3.UP, normal)
		# 안쪽 통로 뒤의 보이지 않는 아치 장식은 만들지 않는다.
		if normal.dot(town_center - Vector3((a.x + b.x) * .5, 0, (a.y + b.y) * .5)) < 0:
			_arch_frieze(a, b, basis, height)
		var count := maxi(1, floori(length / PIER_SPACING))
		var bottom := 0.34
		var shoulder := height * 0.76 - 0.17
		for pier in count:
			var along := (float(pier) + 0.5) / count
			var point := a.lerp(b, along)
			var frame := Transform3D(basis, Vector3(point.x, 0, point.y))
			_box(
				Vector3(0, (bottom + shoulder) * 0.5, -0.045),
				Vector3(0.26, shoulder - bottom, 0.09),
				"stone",
				frame
			)
			_coped_box(
				Vector3(0, shoulder + 0.07, -0.05), Vector3(0.36, 0.14, 0.10), "granite", frame
			)
			_piers.append({"frame": frame, "height": (bottom + shoulder) * 0.5})
			if pier + 1 < count:
				var middle := a.lerp(b, (float(pier) + 1.0) / count)
				var field_frame := Transform3D(basis, Vector3(middle.x, 0, middle.y))
				_fields.append({"frame": field_frame, "height": (bottom + shoulder) * 0.5})
				# A shallow corbel sits below the shared stringcourse. Its front
				# never extends beyond the old solid boundary.
				_box(
					Vector3(0, height * 0.76 - 0.10, -0.035),
					Vector3(0.16, 0.20, 0.07),
					"stone",
					field_frame
				)


## 돌 벽의 기존 경계 안에 아치형 음각과 받침의 명암을 만든다.
func _arch_frieze(a: Vector2, b: Vector2, basis: Basis, height: float) -> void:
	var count := maxi(1, floori(a.distance_to(b) / .86))
	for index in count:
		var point := a.lerp(b, (float(index) + .5) / count)
		var frame := Transform3D(basis, Vector3(point.x, height - .28, point.y))
		for segment in 4:
			var first := PI * segment / 4.0
			var last := PI * (segment + 1) / 4.0
			var inner_a := Vector3(cos(first) * .17, sin(first) * .17, 0)
			var inner_b := Vector3(cos(last) * .17, sin(last) * .17, 0)
			var outer_a := Vector3(cos(first) * .24, sin(first) * .24, 0)
			var outer_b := Vector3(cos(last) * .24, sin(last) * .24, 0)
			_quad(
				frame * inner_a,
				frame * inner_b,
				frame * outer_b,
				frame * outer_a,
				basis.z,
				"granite"
			)
			var back := basis.z * -.045
			var normal := -(
				basis.x * cos((first + last) * .5) + Vector3.UP * sin((first + last) * .5)
			)
			_quad(
				frame * inner_a,
				frame * inner_a + back,
				frame * inner_b + back,
				frame * inner_b,
				normal,
				"granite"
			)
		_arcades += 1


## One closed, bevelled coping piece, appended to the existing stone surface.
## Only the top rim is chamfered: the original total height and sole stay exact.
func _coped_box(
	at: Vector3, size: Vector3, material: String, frame := Transform3D.IDENTITY
) -> void:
	var bevel := minf(0.018, minf(size.x, minf(size.y, size.z)) * 0.25)
	var half := size * 0.5
	var rings: Array[PackedVector3Array] = []
	for level in 3:
		var cut := bevel if level == 2 else 0.0
		var y := -half.y if level == 0 else half.y - bevel if level == 1 else half.y
		rings.append(
			PackedVector3Array(
				[
					Vector3(-half.x + cut, y, -half.z + cut),
					Vector3(half.x - cut, y, -half.z + cut),
					Vector3(half.x - cut, y, half.z - cut),
					Vector3(-half.x + cut, y, half.z - cut)
				]
			)
		)
	var transform := frame * Transform3D(Basis.IDENTITY, at)
	var normal_basis := frame.basis.inverse().transposed()
	for layer in 2:
		for side in 4:
			var next := (side + 1) % 4
			var normal := (rings[0][side] + rings[0][next]) * Vector3(1, 0, 1)
			normal = normal.normalized()
			if layer == 1:
				normal = (normal + Vector3.UP).normalized()
			var points := [
				transform * rings[layer][side],
				transform * rings[layer][next],
				transform * rings[layer + 1][next],
				transform * rings[layer + 1][side]
			]
			_triangle(
				[points[0], points[1], points[2]],
				[Vector2.ZERO, Vector2.RIGHT, Vector2.ONE],
				(normal_basis * normal).normalized(),
				material
			)
			_triangle(
				[points[0], points[2], points[3]],
				[Vector2.ZERO, Vector2.ONE, Vector2.DOWN],
				(normal_basis * normal).normalized(),
				material
			)
	for side in [0, 2]:
		var normal := Vector3.DOWN if side == 0 else Vector3.UP
		var points := [
			transform * rings[side][0],
			transform * rings[side][1],
			transform * rings[side][2],
			transform * rings[side][3]
		]
		_triangle(
			[points[0], points[1], points[2]],
			[Vector2.ZERO, Vector2.RIGHT, Vector2.ONE],
			(normal_basis * normal).normalized(),
			material
		)
		_triangle(
			[points[0], points[2], points[3]],
			[Vector2.ZERO, Vector2.ONE, Vector2.DOWN],
			(normal_basis * normal).normalized(),
			material
		)
	_coped_pieces += 1


## Four continuous radial rings have no internal caps or extra material draws.
func _moulded_ring(at: Vector3, radius: float, height: float) -> void:
	var bevel := minf(0.016, height * 0.25)
	var profile := [
		Vector2(radius - bevel, -height * 0.5),
		Vector2(radius, -height * 0.5 + bevel),
		Vector2(radius, height * 0.5 - bevel),
		Vector2(radius - bevel, height * 0.5)
	]
	for segment in 24:
		var first := TAU * segment / 24.0
		var last := TAU * (segment + 1) / 24.0
		var middle := (first + last) * 0.5
		var radial := Vector3(cos(middle), 0, sin(middle))
		for layer in 3:
			var lower: Vector2 = profile[layer]
			var upper: Vector2 = profile[layer + 1]
			var normal := radial * (upper.y - lower.y) + Vector3.UP * (lower.x - upper.x)
			normal = normal.normalized()
			var a := at + Vector3(cos(first) * lower.x, lower.y, sin(first) * lower.x)
			var b := at + Vector3(cos(last) * lower.x, lower.y, sin(last) * lower.x)
			var c := at + Vector3(cos(last) * upper.x, upper.y, sin(last) * upper.x)
			var d := at + Vector3(cos(first) * upper.x, upper.y, sin(first) * upper.x)
			_triangle([a, b, c], [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE], normal, "stone")
			_triangle([a, c, d], [Vector2.ZERO, Vector2.ONE, Vector2.DOWN], normal, "stone")
		for end in [0, 3]:
			var p: Vector2 = profile[end]
			var normal := Vector3.DOWN if end == 0 else Vector3.UP
			var center := at + Vector3.UP * p.y
			var a := at + Vector3(cos(first) * p.x, p.y, sin(first) * p.x)
			var b := at + Vector3(cos(last) * p.x, p.y, sin(last) * p.x)
			_triangle(
				[center, a, b], [Vector2(0.5, 0.5), Vector2.ZERO, Vector2.ONE], normal, "stone"
			)
	_mouldings += 1


func _gate_arch(
	frame: Transform3D, width: float, depth: float, shoulder: float, wall_height: float
) -> void:
	var radius := width * 0.5
	var order := 0.22
	var crown := shoulder + radius + order + 0.16
	for side in [-1.0, 1.0]:
		_box(
			Vector3(side * (radius + order * 0.5), shoulder * 0.5, 0),
			Vector3(order, shoulder, depth),
			"stone",
			frame
		)
	for segment in 24:
		var a := segment * PI / 24.0 + 0.004
		var b := (segment + 1) * PI / 24.0 - 0.004
		var polygon := PackedVector2Array(
			[
				Vector2(cos(a), sin(a)) * radius + Vector2(0, shoulder),
				Vector2(cos(b), sin(b)) * radius + Vector2(0, shoulder),
				Vector2(cos(b), sin(b)) * (radius + order) + Vector2(0, shoulder),
				Vector2(cos(a), sin(a)) * (radius + order) + Vector2(0, shoulder)
			]
		)
		_prism(polygon, depth + 0.045, frame, "stone")
		var x0 := cos(b) * (radius + order)
		var x1 := cos(a) * (radius + order)
		var bottom := shoulder + maxf(sin(a), sin(b)) * (radius + order)
		if crown > bottom:
			_box(
				Vector3((x0 + x1) * 0.5, (bottom + crown) * 0.5, 0),
				Vector3(x1 - x0 + 0.003, crown - bottom, depth),
				"stone",
				frame
			)
	_box(
		Vector3(0, crown + 0.035, 0),
		Vector3(width + order * 2.0, 0.10, depth + 0.08),
		"stone",
		frame
	)
	for side in [-1.0, 1.0]:
		_box(
			Vector3(side * (radius + order * 0.5), wall_height * 0.76 + 0.04, 0),
			Vector3(order + 0.04, 0.08, depth + 0.06),
			"stone",
			frame
		)
	var count := maxi(3, roundi(width / 0.65))
	for merlon in count:
		_coped_box(
			Vector3(lerpf(-radius, radius, float(merlon) / (count - 1)), crown + 0.30, 0),
			Vector3(0.42, 0.48, depth),
			"granite",
			frame
		)


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
		var slit_faces := _tower_shell(center, radius, height, wall_height * 0.60)
		# 곡면 탑의 실제 외측 면을 기준으로 달아 평면 성문 뒤에 묻히지 않는다.
		var outward := _outward_normal(village.safe_zone, center)
		var plaque_face: Transform3D = slit_faces[0]
		for surface_frame: Transform3D in slit_faces:
			if surface_frame.basis.z.dot(outward) > plaque_face.basis.z.dot(outward):
				plaque_face = surface_frame
		var plaque_frame := plaque_face * Transform3D(Basis.IDENTITY, Vector3(0, wall_height + .65, .018))
		MedievalDetails.plaque(self, plaque_frame, "leaf")
		_heraldic_frames.append(plaque_frame)
		for level in [0.14, wall_height * 0.76, wall_height, height - 0.12]:
			if level < 0.2 or level > height - 0.15:
				_moulded_ring(center + Vector3(0, level, 0), radius + 0.035, 0.105)
			else:
				_cylinder(center + Vector3(0, level, 0), radius + 0.035, 0.105, "granite")
		_open_crown(center, radius, height - .05)
		# The shell has real recessed slots. The dark iron is their closed back,
		# behind the stone reveals, rather than an overlay on an opaque cylinder.
		for surface_frame: Transform3D in slit_faces:
			_slit_frames.append(surface_frame)
			var frame := surface_frame * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.008))
			var slit_y := wall_height * 0.60
			for side in [-1.0, 1.0]:
				_box(
					Vector3(side * 0.071, slit_y, -0.014),
					Vector3(0.065, 0.72, 0.07),
					"stone",
					frame
				)
			for side in [-1.0, 1.0]:
				_coped_box(
					Vector3(0, slit_y + side * 0.35, -0.0165),
					Vector3(0.208, 0.07, 0.075),
					"granite",
					frame
				)
			_slit_reveals += 1
	pose.free()


## Keep the former24-segment outer cylinder and smooth radial body normals, but
## split its four cardinal facets around true10cm-deep, closed-back arrow slots.
func _tower_shell(
	center: Vector3, radius: float, height: float, slit_y: float
) -> Array[Transform3D]:
	var frames: Array[Transform3D] = []
	var half_width := radius * sin(PI / 24.0)
	var face_radius := radius * cos(PI / 24.0)
	var half_slot := 0.0375
	var bottom := slit_y - 0.30
	var top := slit_y + 0.30
	for segment in 24:
		var first := TAU * segment / 24.0
		var last := TAU * (segment + 1) / 24.0
		var middle := (first + last) * 0.5
		var normal := Vector3(cos(middle), 0, sin(middle))
		var tangent := Vector3(normal.z, 0, -normal.x)
		var frame := Transform3D(Basis(tangent, Vector3.UP, normal), center + normal * face_radius)
		if segment % 6 != 0:
			_tower_panel(frame, -half_width, half_width, 0.0, height, 0.0, "stone", center)
		else:
			_tower_panel(frame, -half_width, -half_slot, 0.0, height, 0.0, "stone", center)
			_tower_panel(frame, half_slot, half_width, 0.0, height, 0.0, "stone", center)
			_tower_panel(frame, -half_slot, half_slot, 0.0, bottom, 0.0, "stone", center)
			_tower_panel(frame, -half_slot, half_slot, top, height, 0.0, "stone", center)
			var lb := frame * Vector3(-half_slot, bottom, 0)
			var rb := frame * Vector3(half_slot, bottom, 0)
			var lt := frame * Vector3(-half_slot, top, 0)
			var rt := frame * Vector3(half_slot, top, 0)
			var back := -frame.basis.z * 0.10
			_quad(lt, lb, lb + back, lt + back, frame.basis.x, "stone")
			_quad(rb, rt, rt + back, rb + back, -frame.basis.x, "stone")
			_quad(lb, rb, rb + back, lb + back, Vector3.UP, "stone")
			_quad(rt, lt, lt + back, rt + back, Vector3.DOWN, "stone")
			_tower_panel(frame, -half_slot, half_slot, bottom, top, -0.10, "iron")
			frames.append(frame)
		var a := center + Vector3(cos(first) * radius, 0, sin(first) * radius)
		var b := center + Vector3(cos(last) * radius, 0, sin(last) * radius)
		_triangle(
			[center, a, b], [Vector2(0.5, 0.5), Vector2.ZERO, Vector2.ONE], Vector3.DOWN, "stone"
		)

	return frames


func _tower_panel(
	frame: Transform3D,
	left: float,
	right: float,
	bottom: float,
	top: float,
	depth: float,
	material: String,
	smooth_center := Vector3(INF, INF, INF)
) -> void:
	var local := PackedVector3Array(
		[
			Vector3(left, bottom, depth),
			Vector3(right, bottom, depth),
			Vector3(right, top, depth),
			Vector3(left, top, depth)
		]
	)
	var tool := _tool(material)
	for index in [0, 2, 1, 0, 3, 2]:
		var point := frame * local[index]
		var normal := frame.basis.z
		if smooth_center.is_finite():
			normal = ((point - smooth_center) * Vector3(1, 0, 1)).normalized()
		tool.set_normal(normal)
		tool.set_uv(Vector2(local[index].x, local[index].y) / 2.56)
		tool.add_vertex(point)
	_triangles += 2


func _quad(
	a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, material: String
) -> void:
	_triangle([a, b, c], [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE], normal, material)
	_triangle([a, c, d], [Vector2.ZERO, Vector2.ONE, Vector2.DOWN], normal, material)


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
			var first_y := (
				shoulder + sqrt(maxf(0.0, half * half - pow(side * half + left, 2.0))) - 0.07
			)
			var last_y := (
				shoulder + sqrt(maxf(0.0, half * half - pow(side * half + right, 2.0))) - 0.07
			)
			_prism(
				PackedVector2Array(
					[
						Vector2(left, 0.035),
						Vector2(right, 0.035),
						Vector2(right, last_y),
						Vector2(left, first_y)
					]
				),
				0.10,
				Transform3D.IDENTITY,
				"wood"
			)
		for level in [0.60, 1.70, 2.40]:
			_box(
				Vector3(-side * half * 0.5, level, 0.065),
				Vector3(half * 0.94, 0.075, 0.045),
				"iron"
			)
			for rivet in 4:
				_box(
					Vector3(-side * half * (0.12 + rivet * 0.24), level, 0.096),
					Vector3(0.035, 0.035, 0.022),
					"iron"
				)
		_cylinder(Vector3(0, 1.52, 0.045), 0.040, 2.20, "iron")
		_box(Vector3(-side * half * 0.82, 1.30, 0.10), Vector3(0.045, 0.19, 0.055), "iron")
		_flush("Leaf")
		leaves.append(leaf)
	_target = root


func _cylinder(at: Vector3, radius: float, height: float, material: String, segments := 24) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = segments
	cylinder.rings = 0
	_append(cylinder.surface_get_arrays(0), Transform3D(Basis.IDENTITY, at), material)


func _box(at: Vector3, size: Vector3, material: String, frame := Transform3D.IDENTITY) -> void:
	_append(_box_arrays, frame * Transform3D(Basis.from_scale(size), at), material)


func _horizontal(polygon: PackedVector2Array, bottom: float, top: float, material: String) -> void:
	_prism(
		polygon,
		top - bottom,
		Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, (top + bottom) * 0.5, 0)),
		material
	)


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


func _prism(
	polygon: PackedVector2Array, depth: float, frame: Transform3D, material: String
) -> void:
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
		var vertices := [
			frame * Vector3(a.x, a.y, -depth * 0.5),
			frame * Vector3(b.x, b.y, -depth * 0.5),
			frame * Vector3(b.x, b.y, depth * 0.5),
			frame * Vector3(a.x, a.y, depth * 0.5)
		]
		_triangle(
			[vertices[0], vertices[1], vertices[2]],
			[Vector2.ZERO, Vector2.RIGHT, Vector2.ONE],
			normal,
			material
		)
		_triangle(
			[vertices[0], vertices[2], vertices[3]],
			[Vector2.ZERO, Vector2.ONE, Vector2.DOWN],
			normal,
			material
		)


func _triangle(vertices: Array, uv: Array, normal: Vector3, material: String) -> void:
	var tool := _tool(material)
	var order := (
		[0, 2, 1]
		if (vertices[1] - vertices[0]).cross(vertices[2] - vertices[0]).dot(normal) > 0.0
		else [0, 1, 2]
	)
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

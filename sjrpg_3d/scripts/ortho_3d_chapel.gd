class_name Ortho3DChapel
extends RefCounted
## Native, static chapel detail within the existing rectangular placement model.
## Source mood: approved-game-reference.jpg; construction: remake/chapel-v2.png.
## Shared material surfaces are merged, including arch stones and lead tracery.

const GLASS_PATH := "res://assets/art/preview3d/chapel-glass.webp"
const ARCH_SEGMENTS := 12
const SLATE_TILE := 2.6
const SLATE_COURSES := 8
const SLATE_PITCH := SLATE_TILE / SLATE_COURSES
var _root: Node3D
var _materials := {}
var _surfaces := {}
var _box_arrays: Array
var _triangles := 0
var _pieces := 0
var _windows: Array[Dictionary] = []
var _oculi: Array[Dictionary] = []
var _roof_rows := 0


static func build(presenter: Node, root: Node3D, width: float, depth: float, height: float) -> Dictionary:
	var builder := Ortho3DChapel.new()
	builder._root = root
	builder._materials = presenter._materials.duplicate()
	return builder._build(width, depth, height)


func _build(width: float, depth: float, height: float) -> Dictionary:
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	_box_arrays = unit.surface_get_arrays(0)
	var lead := StandardMaterial3D.new()
	lead.albedo_color = Color("383b33")
	lead.roughness = 0.78
	_materials["lead"] = lead
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color("84724c")
	bronze.metallic = 0.55
	bronze.roughness = 0.57
	_materials["bronze"] = bronze
	var glass := StandardMaterial3D.new()
	glass.albedo_texture = load(GLASS_PATH)
	glass.albedo_color = Color(0.77, 0.78, 0.72)
	glass.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	glass.roughness = 0.52
	_materials["chapel_glass"] = glass
	_materials["oak"] = _materials["wood"]
	# Pale long ashlar sets the chapel apart; buttresses, bands, arches and
	# steps keep the shared limestone trim.
	_materials["wall"] = _materials["chapel_stone"]
	var floor := 0.28
	var top := height + floor
	var rise := 2.4
	var door_width := minf(1.38, width * 0.40)
	var door_height := minf(2.82, height * 0.81)
	var door := {"x": 0.0, "width": door_width, "bottom": floor, "height": door_height}
	var window_width := minf(1.20, depth * 0.27)
	var window_height := minf(2.35, height * 0.67)
	var side_openings: Array[Dictionary] = []
	for side in [-1.0, 1.0]:
		side_openings.append({"x": side * depth * 0.235, "width": window_width, "bottom": 0.74, "height": window_height})
	_box(Vector3(0, 0.12, 0), Vector3(width + 0.30, 0.24, depth + 0.30), "stone")
	# The visible landing meets the unchanged native .28m floor, rather than
	# burying actor feet under the old .33m top of a centered trim slab.
	_box(Vector3(0, 0.26, 0), Vector3(width + 0.18, 0.04, depth + 0.18), "stone")
	var front := Transform3D(Basis.IDENTITY, Vector3(0, 0, depth * 0.5 - 0.14))
	_wall(width, floor, top, [door], front)
	var rear := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -depth * 0.5 + 0.14))
	var rear_opening := {"x": -width * 0.28, "width": minf(0.72, width * 0.21), "bottom": 0.94, "height": 1.62}
	_wall(width, floor, top, [rear_opening], rear)
	_rear_window(rear_opening, rear)
	for side in [-1.0, 1.0]:
		var facade := Transform3D(Basis(Vector3.UP, side * PI * 0.5), Vector3(side * (width * 0.5 - 0.14), 0, 0))
		_wall(depth, floor, top, side_openings, facade)
		for opening: Dictionary in side_openings:
			_window(opening, facade)
	_door(door, front)
	for tier: Dictionary in NativeChapelPlan.tiers(Vector2.ZERO, width, depth):
		var rect: Rect2 = tier["rect"]
		var step_height: float = tier["height"]
		_box(Vector3(rect.get_center().x, step_height * 0.5, rect.get_center().y), Vector3(rect.size.x, step_height, rect.size.y), "stone")
	# Repeated courses and tapered buttress caps remain within the old plinth band.
	for side in [-1.0, 1.0]:
		for along in [-0.43, 0.0, 0.43]:
			var at := Vector3(side * (width * 0.5 - 0.055), 0, along * depth)
			_box(at + Vector3(0, 1.65, 0), Vector3(0.30, 3.02, 0.34), "stone")
			for course in 4:
				_box(at + Vector3(0, 0.40 + course * 0.82, 0), Vector3(0.35, 0.075, 0.39), "stone")
			_taper_cap(at + Vector3(0, 3.27, 0), Vector2(0.38, 0.43), 0.28)
	for level in [0.58, top - 0.22, top - 0.08]:
		for side in [-1.0, 1.0]:
			_box(Vector3(side * (width * 0.5 - 0.02), level, 0), Vector3(0.12, 0.075, depth + 0.12), "stone")
			if level > 1.0:
				_box(Vector3(0, level, side * (depth * 0.5 - 0.02)), Vector3(width + 0.12, 0.075, 0.12), "stone")
	# Both gables have actual circular masonry openings; glass is recessed inside.
	_gable(width, top, rise, front, 0.0)
	_gable(width, top, rise, rear, -minf(0.42, width * 0.13))
	_roof(width, depth, top, rise)
	for face in [front, rear]:
		for side in [-1.0, 1.0]:
			var x: float = side * (width * 0.5 - 0.18)
			_box(Vector3(x, 1.61, 0.10), Vector3(0.26, 2.66, 0.20), "stone", face)
			_box(Vector3(x, 0.50, 0.12), Vector3(0.32, 0.14, 0.22), "stone", face)
			_box(Vector3(x, 2.89, 0.11), Vector3(0.30, 0.10, 0.22), "stone", face)
			_taper_cap(face * Vector3(x, 3.03, 0.11), Vector2(0.28, 0.25), 0.18)

	# Keep the bell shaft inside the wall's inner surface so it cannot fill a
	# side lancet opening when the source chapel has a narrow footprint.
	var tower_x := maxf(-width * 0.27, -width * 0.5 + 1.05)
	var tower_height := _tower(Vector3(tower_x, 0, -depth * 0.25), height)
	var meshes := _flush()
	var bounds := meshes[0].mesh.get_aabb()
	for mesh in meshes:
		bounds = bounds.merge(mesh.mesh.get_aabb())
	var report := {"triangles": _triangles, "pieces": _pieces, "surfaces": meshes.size(), "meshes": meshes,
		"footprint": Vector2(width, depth), "door_width": door_width, "door_height": door_height,
		"door_bottom": Vector3(0, floor, depth * 0.5 - 0.20), "door_recess": 0.28,
		"windows": _windows, "oculi": _oculi, "roof_rows": _roof_rows, "entry_orders": 3, "entry_shafts": 2, "tower_height": tower_height, "bounds": bounds, "floor_height": floor,
		"glass_source": "assets/art/preview3d/chapel-glass.json", "reference": "assets/source/style/approved-game-reference.jpg"}
	_root.set_meta("chapel_detail", report)
	return report


func _wall(width: float, floor: float, top: float, openings: Array, transform: Transform3D) -> void:
	var cursor := -width * 0.5
	for opening: Dictionary in openings:
		var left: float = opening["x"] - opening["width"] * 0.5
		var right: float = opening["x"] + opening["width"] * 0.5
		_panel(cursor, left, floor, top, transform)
		var bottom: float = opening["bottom"]
		var shoulder: float = bottom + opening["height"] - opening["width"] * sqrt(3.0) * 0.5
		for column in 24:
			var a := lerpf(left, right, column / 24.0)
			var b := lerpf(left, right, (column + 1) / 24.0)
			var edge := maxf(_arch_y(a - opening["x"], opening["width"], shoulder), _arch_y(b - opening["x"], opening["width"], shoulder))
			edge = maxf(edge, _arch_y((a + b) * 0.5 - opening["x"], opening["width"], shoulder))
			_panel(a, b, floor, bottom, transform)
			_panel(a, b, edge, top, transform)
		cursor = right
	_panel(cursor, width * 0.5, floor, top, transform)


func _panel(left: float, right: float, bottom: float, top: float, transform: Transform3D) -> void:
	if right <= left or top <= bottom:
		return
	_box(Vector3((left + right) * 0.5, (bottom + top) * 0.5, 0), Vector3(right - left, top - bottom, 0.28), "wall", transform)


static func _arch_y(x: float, width: float, shoulder: float) -> float:
	return shoulder + sqrt(maxf(0.0, width * width - pow(absf(x) + width * 0.5, 2.0)))


static func _arch_path(width: float, bottom: float, shoulder: float) -> PackedVector2Array:
	var path := PackedVector2Array()
	var half := width * 0.5
	for step in 7:
		path.append(Vector2(-half, lerpf(bottom, shoulder, step / 6.0)))
	for step in range(1, ARCH_SEGMENTS + 1):
		var angle := lerpf(PI, PI * 2.0 / 3.0, float(step) / ARCH_SEGMENTS)
		path.append(Vector2(half + width * cos(angle), shoulder + width * sin(angle)))
	for step in range(1, ARCH_SEGMENTS + 1):
		var angle := lerpf(PI / 3.0, 0.0, float(step) / ARCH_SEGMENTS)
		path.append(Vector2(-half + width * cos(angle), shoulder + width * sin(angle)))
	for step in range(1, 7):
		path.append(Vector2(half, lerpf(shoulder, bottom, step / 6.0)))
	return path


func _arch_ring(width: float, bottom: float, shoulder: float, thickness: float, depth: float, transform: Transform3D, material := "stone") -> void:
	var inner := _arch_path(width, bottom, shoulder)
	var outer := _arch_path(width + thickness * 2.0, bottom, shoulder)
	for index in inner.size() - 1:
		# Small physical mortar joints keep the pointed curve's voussoirs legible.
		var a := outer[index].lerp(outer[index + 1], 0.015)
		var b := outer[index + 1].lerp(outer[index], 0.015)
		var c := inner[index + 1].lerp(inner[index], 0.015)
		var d := inner[index].lerp(inner[index + 1], 0.015)
		_prism(PackedVector2Array([a, b, c, d]), depth, transform, material)


func _door(opening: Dictionary, facade: Transform3D) -> void:
	var width: float = opening["width"]
	var bottom: float = opening["bottom"]
	var shoulder: float = bottom + opening["height"] - width * sqrt(3.0) * 0.5
	# Individual oak leaves occupy a true wall opening, behind three stone orders.
	for plank in 10:
		var left := lerpf(-width * 0.5, width * 0.5, plank / 10.0) + 0.004
		var right := lerpf(-width * 0.5, width * 0.5, (plank + 1) / 10.0) - 0.004
		var polygon := PackedVector2Array([Vector2(left, bottom), Vector2(right, bottom), Vector2(right, _arch_y(right, width, shoulder)), Vector2((left + right) * 0.5, _arch_y((left + right) * 0.5, width, shoulder)), Vector2(left, _arch_y(left, width, shoulder))])
		_prism(polygon, 0.07, facade * Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.175)), "oak")
	for order in 3:
		_arch_ring(width + order * 0.11, bottom, shoulder, 0.055, 0.10, facade * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.10 + order * 0.055)))
	for side in [-1.0, 1.0]:
		for level in [0.92, 1.83]:
			_box(Vector3(side * width * 0.25, level, -0.1225), Vector3(width * 0.42, 0.045, 0.035), "lead", facade)
		for level in [0.92, 1.83]:
			for end in [-1.0, 1.0]:
				_sphere(Vector3(side * width * 0.25 + end * width * 0.16, level, -0.097), 0.014, "lead", facade)
		var ring := TorusMesh.new()
		ring.inner_radius = 0.039
		ring.outer_radius = 0.061
		ring.rings = 12
		ring.ring_segments = 6
		_append_mesh(ring, facade * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(side * 0.12, 1.30, -0.095)), "lead")

	for side in [-1.0, 1.0]:
		_entry_shaft(Vector3(side * (width * 0.5 + 0.14), bottom, 0.115), shoulder - bottom, facade)


func _entry_shaft(at: Vector3, tall: float, facade: Transform3D) -> void:
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.059
	shaft.bottom_radius = 0.068
	shaft.height = tall - 0.12
	shaft.radial_segments = 12
	shaft.rings = 1
	_append_mesh(shaft, facade * Transform3D(Basis.IDENTITY, at + Vector3.UP * (tall * 0.5)), "stone")
	for y in [0.04, tall - 0.055]:
		var collar := TorusMesh.new()
		collar.inner_radius = 0.061
		collar.outer_radius = 0.088
		collar.rings = 12
		collar.ring_segments = 4
		_append_mesh(collar, facade * Transform3D(Basis.IDENTITY, at + Vector3.UP * y), "stone")
	_box(at + Vector3(0, 0.015, 0), Vector3(0.19, 0.055, 0.18), "stone", facade)
	_box(at + Vector3(0, tall - 0.015, 0), Vector3(0.18, 0.055, 0.17), "stone", facade)


func _window(opening: Dictionary, facade: Transform3D) -> void:
	var x: float = opening["x"]
	var width: float = opening["width"]
	var bottom: float = opening["bottom"]
	var total: float = opening["height"]
	var shoulder := bottom + total - width * sqrt(3.0) * 0.5
	_arch_ring(width + 0.10, bottom - 0.02, shoulder, 0.055, 0.10, facade * Transform3D(Basis.IDENTITY, Vector3(x, 0, 0.17)))
	_arch_ring(width, bottom, shoulder, 0.065, 0.12, facade * Transform3D(Basis.IDENTITY, Vector3(x, 0, 0.11)))
	_arch_ring(width - 0.08, bottom + 0.025, shoulder, 0.035, 0.08, facade * Transform3D(Basis.IDENTITY, Vector3(x, 0, 0.035)))
	var pane_width := width * 0.40
	var pane_height := total * 0.76
	for side in [-1.0, 1.0]:
		var pane_x: float = side * width * 0.225
		var pane_shoulder := bottom + pane_height - pane_width * sqrt(3.0) * 0.5
		var pane := _arch_path(pane_width, bottom + 0.06, pane_shoulder)
		var pane_transform := facade * Transform3D(Basis.IDENTITY, Vector3(x + pane_x, 0, -0.085))
		_prism(pane, 0.025, pane_transform, "chapel_glass")
		_arch_ring(pane_width, bottom + 0.04, pane_shoulder, 0.033, 0.06, facade * Transform3D(Basis.IDENTITY, Vector3(x + pane_x, 0, 0.015)))
		for row in 3:
			var y := bottom + 0.28 + row * 0.43
			_box(Vector3(x + pane_x, y, 0.002), Vector3(pane_width * 0.93, 0.018, 0.022), "lead", facade)
			var a := Vector3(x + pane_x - pane_width * 0.43, y + 0.02, 0.004)
			var b := Vector3(x + pane_x + pane_width * 0.43, y + 0.40, 0.004)
			_beam(a, b, 0.012, "lead", facade)
			_beam(Vector3(a.x, b.y, a.z), Vector3(b.x, a.y, b.z), 0.012, "lead", facade)
	_box(Vector3(x, bottom + pane_height * 0.43, 0.035), Vector3(0.055, pane_height * 0.86, 0.095), "stone", facade)
	_box(Vector3(x, bottom - 0.055, 0.13), Vector3(width + 0.28, 0.12, 0.32), "stone", facade)
	_rose_local(Vector3(x, bottom + total * 0.82, 0.015), width * 0.16, facade)
	_windows.append({"transform": facade, "center": x, "width": width, "bottom": bottom, "height": total, "recess": 0.2125, "role": "side_lancet"})


func _rear_window(opening: Dictionary, facade: Transform3D) -> void:
	var x := float(opening["x"])
	var width := float(opening["width"])
	var bottom := float(opening["bottom"])
	var tall := float(opening["height"])
	var shoulder := bottom + tall - width * sqrt(3.0) * 0.5
	_arch_ring(width, bottom, shoulder, 0.075, 0.12, facade * Transform3D(Basis.IDENTITY, Vector3(x, 0, 0.14)))
	var pane := _arch_path(width - 0.045, bottom + 0.025, shoulder)
	_prism(pane, 0.025, facade * Transform3D(Basis.IDENTITY, Vector3(x, 0, -0.085)), "chapel_glass")
	_box(Vector3(x, bottom + tall * 0.36, 0.01), Vector3(0.035, tall * 0.71, 0.06), "stone", facade)
	_box(Vector3(x, bottom - 0.05, 0.12), Vector3(width + 0.20, 0.10, 0.26), "stone", facade)
	_windows.append({"transform": facade, "center": x, "width": width, "bottom": bottom, "height": tall, "recess": 0.2125, "role": "rear_lancet"})


func _gable(width: float, bottom: float, rise: float, facade: Transform3D, center_x: float) -> void:
	var radius := minf(0.35, width * 0.10)
	var center_y := bottom + rise * 0.42
	var levels: Array[float] = [bottom]
	for index in 25:
		levels.append(center_y - radius + radius * 2.0 * index / 24.0)
	levels.append(bottom + rise)
	for index in levels.size() - 1:
		var a := levels[index]
		var b := levels[index + 1]
		var left_a := -width * 0.5 * (1.0 - (a - bottom) / rise)
		var left_b := -width * 0.5 * (1.0 - (b - bottom) / rise)
		if a >= center_y - radius - 0.00001 and b <= center_y + radius + 0.00001:
			var hole_a := sqrt(maxf(0.0, radius * radius - (a - center_y) * (a - center_y)))
			var hole_b := sqrt(maxf(0.0, radius * radius - (b - center_y) * (b - center_y)))
			_gable_piece(PackedVector2Array([Vector2(left_a, a), Vector2(center_x - hole_a, a), Vector2(center_x - hole_b, b), Vector2(left_b, b)]), facade)
			_gable_piece(PackedVector2Array([Vector2(center_x + hole_a, a), Vector2(-left_a, a), Vector2(-left_b, b), Vector2(center_x + hole_b, b)]), facade)
		else:
			_gable_piece(PackedVector2Array([Vector2(left_a, a), Vector2(-left_a, a), Vector2(-left_b, b), Vector2(left_b, b)]), facade)
	_rose_local(Vector3(center_x, center_y, 0), radius, facade, true)
	_oculi.append({"transform": facade, "center": Vector2(center_x, center_y), "radius": radius, "pane_recess": 0.2025, "actual_masonry_hole": true})


func _gable_piece(polygon: PackedVector2Array, facade: Transform3D) -> void:
	var clean := PackedVector2Array()
	for point in polygon:
		if clean.is_empty() or clean[clean.size() - 1].distance_squared_to(point) > 0.0000000001:
			clean.append(point)
	if clean.size() > 1 and clean[0].distance_squared_to(clean[clean.size() - 1]) < 0.0000000001:
		clean.remove_at(clean.size() - 1)
	if clean.size() >= 3:
		_prism(clean, 0.28, facade, "wall")


func _rose_local(at: Vector3, radius: float, transform: Transform3D, recessed := false) -> void:
	var disk := CylinderMesh.new()
	disk.top_radius = radius
	disk.bottom_radius = radius
	disk.height = 0.025
	disk.radial_segments = 24 if radius >= 0.25 else 16
	disk.rings = 1
	var pane_z := -0.075 if recessed else -0.060
	_append_mesh(disk, transform * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at + Vector3(0, 0, pane_z)), "chapel_glass")
	var outer := TorusMesh.new()
	outer.inner_radius = radius
	outer.outer_radius = radius + minf(0.06, radius * 0.24)
	outer.rings = 24 if radius >= 0.25 else 16
	outer.ring_segments = 4
	_append_mesh(outer, transform * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at + Vector3(0, 0, 0.155 if recessed else 0.055)), "stone")
	var inner := TorusMesh.new()
	inner.inner_radius = radius - 0.025
	inner.outer_radius = radius + 0.012
	inner.rings = 20 if radius >= 0.25 else 16
	inner.ring_segments = 4
	_append_mesh(inner, transform * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at + Vector3(0, 0, 0.060 if recessed else 0.020)), "stone")
	for lobe in 4:
		var angle := lobe * TAU / 4.0
		var center := at + Vector3(cos(angle), sin(angle), 0) * radius * 0.37
		var ring := TorusMesh.new()
		ring.inner_radius = radius * 0.34
		ring.outer_radius = radius * 0.34 + 0.018
		ring.rings = 12 if radius >= 0.25 else 8
		ring.ring_segments = 4
		_append_mesh(ring, transform * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), center + Vector3(0, 0, 0.072)), "stone")
	for spoke in 8:
		var angle := spoke * TAU / 8.0
		var a := at + Vector3(cos(angle), sin(angle), 0) * radius * 0.24 + Vector3(0, 0, 0.060)
		var b := at + Vector3(cos(angle), sin(angle), 0) * radius * 0.94 + Vector3(0, 0, 0.060)
		_beam(a, b, 0.014, "stone", transform)


func _roof(width: float, depth: float, top: float, rise: float) -> void:
	var half := width * 0.5 + 0.19
	var reach := depth * 0.5 + 0.20
	var length := sqrt(half * half + rise * rise)
	var rows := maxi(1, ceili(length / SLATE_PITCH))
	_roof_rows = rows
	for side in [-1.0, 1.0]:
		var normal := Vector3(side * rise / half, 1, 0).normalized()
		# A covered underlay and real raised course lips share the village slate grid.
		var base: Array[Vector3] = [Vector3(side * half, top, -reach), Vector3(side * half, top, reach), Vector3(0, top + rise, reach), Vector3(0, top + rise, -reach)]
		var base_uv: Array[Vector2] = [Vector2(-reach, 0) / SLATE_TILE, Vector2(reach, 0) / SLATE_TILE, Vector2(reach, length) / SLATE_TILE, Vector2(-reach, length) / SLATE_TILE]
		_triangle([base[0], base[1], base[2]], [base_uv[0], base_uv[1], base_uv[2]], normal, "slate")
		_triangle([base[0], base[2], base[3]], [base_uv[0], base_uv[2], base_uv[3]], normal, "slate")
		for row in rows:
			var low := row * SLATE_PITCH / length
			var high := minf(1.0, (row + 1) * SLATE_PITCH / length)
			var a := Vector3(side * half * (1.0 - low), top + rise * low, -reach) + normal * 0.028
			var b := Vector3(a.x, a.y, reach)
			var c := Vector3(side * half * (1.0 - high), top + rise * high, reach) + normal * 0.006
			var d := Vector3(c.x, c.y, -reach)
			var uv: Array[Vector2] = [Vector2(-reach, low * length) / SLATE_TILE, Vector2(reach, low * length) / SLATE_TILE, Vector2(reach, high * length) / SLATE_TILE, Vector2(-reach, high * length) / SLATE_TILE]
			var tile_normal := (b - a).cross(d - a).normalized()
			if tile_normal.y < 0.0:
				tile_normal = -tile_normal
			_triangle([a, b, c], [uv[0], uv[1], uv[2]], tile_normal, "slate")
			_triangle([a, c, d], [uv[0], uv[2], uv[3]], tile_normal, "slate")
			var low_a := a - normal * 0.022
			var low_b := b - normal * 0.022
			var edge_normal := Vector3(side * normal.y, -absf(normal.x), 0).normalized()
			var drop := Vector2(0, 0.022 / SLATE_TILE)
			_triangle([a, low_a, low_b], [uv[0], uv[0] + drop, uv[1] + drop], edge_normal, "slate")
			_triangle([a, low_b, b], [uv[0], uv[1] + drop, uv[1]], edge_normal, "slate")
		for end in [-1.0, 1.0]:
			_beam(Vector3(side * half, top + 0.04, end * (reach - 0.025)), Vector3(0, top + rise + 0.06, end * (reach - 0.025)), 0.11, "stone")
		_box(Vector3(side * (half - 0.025), top - 0.035, 0), Vector3(0.10, 0.13, depth + 0.40), "stone")
		for corbel in 9:
			_box(Vector3(side * (width * 0.5 - 0.01), top - 0.17, lerpf(-depth * 0.43, depth * 0.43, corbel / 8.0)), Vector3(0.21, 0.16, 0.10), "stone")
	var caps := ceili(depth / 0.38)
	for cap in caps:
		_box(Vector3(0, top + rise + 0.07, -depth * 0.5 + (cap + 0.5) * depth / caps), Vector3(0.22, 0.12, depth / caps - 0.012), "stone")


func _tower(center: Vector3, height: float) -> float:
	var base_top := height + 1.8
	var bay_bottom := base_top + 0.12
	var bay_top := bay_bottom + 1.55
	var half := 0.67
	_box(center + Vector3(0, base_top * 0.5, 0), Vector3(1.34, base_top, 1.34), "stone")
	for y in [height + 0.2, base_top, bay_top + 0.08]:
		_box(center + Vector3(0, y, 0), Vector3(1.49, 0.13, 1.49), "stone")
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_box(center + Vector3(x * 0.53, (bay_bottom + bay_top) * 0.5, z * 0.53), Vector3(0.28, bay_top - bay_bottom, 0.28), "stone")
	for face in 4:
		var basis := Basis(Vector3.UP, face * PI * 0.5)
		var at := center + basis * Vector3(0, 0, half)
		var opening_width := 0.78
		var shoulder := bay_top - opening_width * sqrt(3.0) * 0.5
		_arch_ring(opening_width, bay_bottom, shoulder, 0.13, 0.22, Transform3D(basis, at))
	_box(center + Vector3(0, bay_top - 0.32, 0), Vector3(1.15, 0.10, 0.14), "oak")
	_bell(center + Vector3(0, bay_bottom + 0.70, 0))
	var spire := CylinderMesh.new()
	spire.top_radius = 0.035
	spire.bottom_radius = 1.04
	spire.height = 2.35
	spire.radial_segments = 4
	var spire_bottom := bay_top + 0.18
	var spire_arrays := spire.surface_get_arrays(0)
	var spire_points: PackedVector3Array = spire_arrays[Mesh.ARRAY_VERTEX]
	var spire_normals: PackedVector3Array = spire_arrays[Mesh.ARRAY_NORMAL]
	var spire_uv: PackedVector2Array = spire_arrays[Mesh.ARRAY_TEX_UV]
	var perimeter := spire.radial_segments * 2.0 * spire.bottom_radius * sin(PI / spire.radial_segments)
	var slope := Vector2(spire.height, (spire.bottom_radius - spire.top_radius) * cos(PI / spire.radial_segments)).length()
	var side_min := Vector2(INF, INF)
	var side_max := Vector2(-INF, -INF)
	for index in spire_points.size():
		if absf(spire_normals[index].y) < 0.99:
			side_min = side_min.min(spire_uv[index])
			side_max = side_max.max(spire_uv[index])
	var side_span := side_max - side_min
	for index in spire_points.size():
		if absf(spire_normals[index].y) > 0.99:
			spire_uv[index] = Vector2(spire_points[index].x, spire_points[index].z) / SLATE_TILE
		else:
			# The primitive reserves atlas space for caps; normalize its actual side
			# chart before assigning the physical perimeter/slope repeat.
			var unit := (spire_uv[index] - side_min) / side_span
			spire_uv[index] = Vector2(unit.x * perimeter, (1.0 - unit.y) * slope) / SLATE_TILE
	spire_arrays[Mesh.ARRAY_TEX_UV] = spire_uv
	_append_arrays(spire_arrays, Transform3D(Basis(Vector3.UP, PI * 0.25), center + Vector3(0, spire_bottom + spire.height * 0.5, 0)), "slate")
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_beam(center + Vector3(x * 0.72, spire_bottom + 0.02, z * 0.72), center + Vector3(0, spire_bottom + 2.38, 0), 0.065, "stone")
	_sphere(center + Vector3(0, spire_bottom + 2.42, 0), 0.085, "bronze")
	return spire_bottom + 2.51


func _bell(at: Vector3) -> void:
	var profile := [Vector2(0.08, 0.45), Vector2(0.13, 0.36), Vector2(0.18, 0.26), Vector2(0.20, 0.02), Vector2(0.31, -0.12), Vector2(0.34, -0.15)]
	for row in profile.size() - 1:
		for segment in 16:
			var a := segment * TAU / 16.0
			var b := (segment + 1) * TAU / 16.0
			var low: Vector2 = profile[row]
			var high: Vector2 = profile[row + 1]
			var points := [at + Vector3(cos(a) * low.x, low.y, sin(a) * low.x), at + Vector3(cos(b) * low.x, low.y, sin(b) * low.x), at + Vector3(cos(b) * high.x, high.y, sin(b) * high.x), at + Vector3(cos(a) * high.x, high.y, sin(a) * high.x)]
			var normal := Vector3(cos((a + b) * 0.5), 0.2, sin((a + b) * 0.5)).normalized()
			_quad(points, normal, "bronze")
	_beam(at + Vector3(0, -0.12, 0), at + Vector3(0, 0.40, 0), 0.045, "lead")
	_sphere(at + Vector3(0, -0.16, 0), 0.063, "lead")


func _taper_cap(at: Vector3, size: Vector2, tall: float) -> void:
	var cap := CylinderMesh.new()
	cap.top_radius = 0.42
	cap.bottom_radius = 0.71
	cap.height = 1.0
	cap.radial_segments = 4
	cap.rings = 1
	_append_mesh(cap, Transform3D(Basis(Vector3.UP, PI * 0.25).scaled(Vector3(size.x, tall, size.y)), at), "stone")


func _sphere(at: Vector3, radius: float, material: String, transform := Transform3D.IDENTITY) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	_append_mesh(sphere, transform * Transform3D(Basis.IDENTITY, at), material)


func _beam(a: Vector3, b: Vector3, thickness: float, material: String, transform := Transform3D.IDENTITY) -> void:
	var direction := b - a
	var basis := Basis(Quaternion(Vector3(0, 0, 1), direction.normalized()))
	_append_arrays(_box_arrays, transform * Transform3D(basis.scaled_local(Vector3(thickness, thickness, direction.length())), (a + b) * 0.5), material)


func _box(at: Vector3, size: Vector3, material: String, transform := Transform3D.IDENTITY) -> void:
	_append_arrays(_box_arrays, transform * Transform3D(Basis.from_scale(size), at), material)


func _append_mesh(mesh: Mesh, transform: Transform3D, material: String) -> void:
	_append_arrays(mesh.surface_get_arrays(0), transform, material)


func _append_arrays(arrays: Array, transform: Transform3D, material: String) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var count := indices.size() if not indices.is_empty() else vertices.size()
	var normal_basis := transform.basis.inverse().transposed()
	var tool := _surface(material)
	for index in count:
		var source := indices[index] if not indices.is_empty() else index
		tool.set_normal((normal_basis * normals[source]).normalized())
		tool.set_uv(uvs[source])
		tool.add_vertex(transform * vertices[source])
	_triangles += count / 3
	_pieces += 1


func _surface(material: String) -> SurfaceTool:
	if not _surfaces.has(material):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_surfaces[material] = tool
	return _surfaces[material] as SurfaceTool


func _prism(polygon: PackedVector2Array, depth: float, transform: Transform3D, material: String) -> void:
	var triangles := Geometry2D.triangulate_polygon(polygon)
	var bounds := Iso.poly_bounds(polygon)
	var normal_basis := transform.basis.inverse().transposed()
	for side in [-1.0, 1.0]:
		var normal := (normal_basis * Vector3(0, 0, side)).normalized()
		for index in range(0, triangles.size(), 3):
			var points: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for corner in 3:
				var point := polygon[triangles[index + corner]]
				points.append(transform * Vector3(point.x, point.y, side * depth * 0.5))
				uvs.append(Vector2((point.x - bounds.position.x) / maxf(bounds.size.x, 0.001), 1.0 - (point.y - bounds.position.y) / maxf(bounds.size.y, 0.001)))
			_triangle(points, uvs, normal, material)
	var area := 0.0
	for index in polygon.size():
		area += polygon[index].cross(polygon[(index + 1) % polygon.size()])
	for index in polygon.size():
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		var edge := b - a
		var normal := (normal_basis * Vector3(edge.y, -edge.x, 0) * signf(area)).normalized()
		var points := [transform * Vector3(a.x, a.y, -depth * 0.5), transform * Vector3(b.x, b.y, -depth * 0.5), transform * Vector3(b.x, b.y, depth * 0.5), transform * Vector3(a.x, a.y, depth * 0.5)]
		_quad(points, normal, material)
	_pieces += 1


func _quad(points: Array, normal: Vector3, material: String) -> void:
	_triangle([points[0], points[1], points[2]], [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE], normal, material)
	_triangle([points[0], points[2], points[3]], [Vector2.ZERO, Vector2.ONE, Vector2.DOWN], normal, material)


func _triangle(points: Array, uvs: Array, normal: Vector3, material: String) -> void:
	var tool := _surface(material)
	# Godot's front winding is clockwise; explicit outward normals drive real light.
	var order := [0, 2, 1] if (points[1] - points[0]).cross(points[2] - points[0]).dot(normal) > 0.0 else [0, 1, 2]
	for index in order:
		tool.set_normal(normal)
		tool.set_uv(uvs[index])
		tool.add_vertex(points[index])
	_triangles += 1


func _flush() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for key: String in _surfaces:
		var tool: SurfaceTool = _surfaces[key]
		tool.index()
		var mesh := MeshInstance3D.new()
		mesh.name = "ChapelDetail_" + key
		mesh.mesh = tool.commit()
		mesh.material_override = _materials[key]
		_root.add_child(mesh)
		meshes.append(mesh)
	return meshes

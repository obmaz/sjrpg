class_name NativeHouse3D
extends RefCounted
## Native house family with metre-scaled timber grain and layered slate.
## Closed doors and bounded alcoves preserve the existing solid house footprint.

const WALL := 0.20
const EAVES := 0.22
const FLOOR := 0.16
const MATERIAL_KEYS := ["stone", "wall", "slate", "wood", "iron", "glass"]
## Each house reads as its own building: wall infill, trim stone and roof cover
## differ by role, while timber, iron and glass stay shared with the family.
const STYLES := {
	"nw": {"wall": "plaster", "stone": "stone", "slate": "clay", "label": "half-timbered merchant shop"},
	"ne": {"wall": "rubble", "stone": "stone", "slate": "slate_dark", "label": "fieldstone smithy"},
	"sw": {"wall": "planks", "stone": "rubble", "slate": "shingle", "label": "timber stable house"},
	"se": {"wall": "brick", "stone": "stone", "slate": "slate", "label": "brick dormer house"},
}
const TIMBER_TILE := 1.0 / 0.65
const SLATE_TILE := 2.6
const SLATE_COURSES := 8
const SLATE_PITCH := SLATE_TILE / SLATE_COURSES
const SLATE_COLUMNS := 6
const SLATE_WIDTH := SLATE_TILE / SLATE_COLUMNS
const ASHLAR_COURSE := 0.32
var _root: Node3D
var _materials := {}
var _surfaces := {}
var _box_arrays: Array
var _triangles := 0
var _pieces := 0
var _openings: Array[Dictionary] = []
var _roof_edges: Array[Dictionary] = []
var _key := ""
var _slate_tiles := 0
var _quoins := 0


static func build(presenter: Node, root: Node3D, key: String, width: float, depth: float, height: float) -> Dictionary:
	var builder := NativeHouse3D.new()
	builder._root = root
	for material: String in MATERIAL_KEYS:
		builder._materials[material] = presenter._materials[resource_key(key, material)]
	return builder._build(key, width, depth, height)


## The presenter material used for one of this house's surface roles.
static func resource_key(key: String, material: String) -> String:
	if material == "wood":
		return "door"
	var style: Dictionary = STYLES.get(key, {})
	return str(style.get(material, "stone" if material == "wall" else material))


func _build(key: String, width: float, depth: float, height: float) -> Dictionary:
	_key = key
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	_box_arrays = unit.surface_get_arrays(0)
	var eave_height := height * (1.24 if key == "nw" else (1.10 if key == "se" else 1.0)) + FLOOR
	var rise := 1.80 if key == "nw" else (1.40 if key == "ne" else (1.55 if key == "sw" else 1.90))
	var body_width := width - 0.40
	var body_depth := depth - 0.40
	var door_width := minf(1.38 if key in ["nw", "sw"] else 1.10, body_width * 0.38)
	var door_x := width * 0.18 if key == "ne" else (-width * 0.20 if key == "se" else 0.0)
	var door_height := 2.25 if key in ["nw", "sw"] else 2.12
	var door := {"x": door_x, "width": door_width, "bottom": FLOOR, "height": door_height, "arch": key != "ne", "role": "closed_door"}
	var front_openings: Array[Dictionary] = [door]
	if key == "nw":
		for side in [-1.0, 1.0]:
			front_openings.append(_opening(side * body_width * 0.28, minf(0.79, body_width * 0.23), 2.55, 0.75))
	elif key == "ne":
		front_openings.append({"x": -body_width * 0.28, "width": minf(2.60, body_width * 0.35), "bottom": 0.66, "height": 1.42, "arch": false, "role": "smith_bay"})
	elif key == "se":
		front_openings.append(_opening(body_width * 0.27, minf(0.85, body_width * 0.25), 0.95, 1.06))
	var front := Transform3D(Basis.IDENTITY, Vector3(0, 0, body_depth * 0.5))
	var back := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -body_depth * 0.5))
	_box(Vector3(0, 0.08, 0), Vector3(width, 0.16, depth), "stone")
	# The threshold remains inside the supplied collision envelope.
	_box(Vector3(door_x, 0.13, depth * 0.5 - 0.18), Vector3(door_width + 0.26, 0.10, 0.34), "stone")
	_wall(body_width, FLOOR, eave_height, front_openings, front)
	var rear_openings: Array[Dictionary] = [_opening(0.0, minf(0.72, body_width * 0.24), 1.06, 1.10)]
	_wall(body_width, FLOOR, eave_height, rear_openings, back)
	_door(door, front)
	for opening in front_openings:
		if opening.get("role", "window") == "window":
			_window(opening, front, true)
		elif opening.get("role", "") == "smith_bay":
			_smith_bay(opening, front)
	for opening in rear_openings:
		_window(opening, back, false)
	for side in [-1.0, 1.0]:
		var facade := Transform3D(Basis(Vector3.UP, side * PI * 0.5), Vector3(side * body_width * 0.5, 0, 0))
		var side_openings: Array[Dictionary] = []
		if key == "sw" and side > 0.0:
			side_openings.append({"x": 0.0, "width": minf(body_depth * 0.70, 2.12), "bottom": 0.54, "height": 1.66, "arch": false, "role": "stable_bay"})
		else:
			side_openings.append(_opening(0.0, minf(0.86, body_depth * 0.37), 1.03, 1.18))
			if key == "nw":
				side_openings.append(_opening(0.0, minf(0.75, body_depth * 0.32), 2.55, 0.75))
		_wall(body_depth, FLOOR, eave_height, side_openings, facade)
		for opening in side_openings:
			if opening.get("role", "") == "stable_bay":
				_stable_bay(opening, facade)
			else:
				_window(opening, facade, true)
		_frame(body_depth, eave_height, facade, key == "nw", side_openings)
	_frame(body_width, eave_height, front, key == "nw", front_openings)
	_frame(body_width, eave_height, back, key == "nw", rear_openings)
	var triangle := PackedVector2Array([Vector2(-body_width * 0.5, eave_height), Vector2(body_width * 0.5, eave_height), Vector2(0, eave_height + rise)])
	_prism(triangle, WALL, front, "wall")
	_prism(triangle, WALL, back, "wall")
	_corner_quoins(body_width, body_depth, minf(eave_height, 2.48) if key == "nw" else eave_height, eave_height)
	_roof(width, depth, eave_height, rise)
	for facade in [front, back]:
		_beam(Vector3(-body_width * 0.5, eave_height + 0.02, 0.12), Vector3(0, eave_height + rise - 0.02, 0.12), 0.11, "wood", facade)
		_beam(Vector3(body_width * 0.5, eave_height + 0.02, 0.12), Vector3(0, eave_height + rise - 0.02, 0.12), 0.11, "wood", facade)
		_beam(Vector3(0, eave_height + 0.02, 0.12), Vector3(0, eave_height + rise - 0.06, 0.12), 0.10, "wood", facade)
	_chimney(width, depth, eave_height, rise, key == "nw")
	if key == "se":
		for side in [-1.0, 1.0]:
			_dormer(width, depth, eave_height, rise, side)
	if key == "ne":
		_smith_hood(width, depth, eave_height)
	var meshes := _flush()
	var bounds := meshes[0].mesh.get_aabb()
	for node in meshes:
		bounds = bounds.merge(node.mesh.get_aabb())
	var report := {"key": key, "triangles": _triangles, "pieces": _pieces, "surfaces": meshes.size(), "meshes": meshes,
		"footprint": Vector2(width, depth), "body_inset": 0.10, "ground_envelope": AABB(Vector3(-width * 0.5, 0, -depth * 0.5), Vector3(width, eave_height, depth)),
		"eaves_height": eave_height, "roof_rise": rise, "roof_overhang_nominal": EAVES, "roof_overhang": maxf(maxf(-bounds.position.x - width * 0.5, bounds.end.x - width * 0.5), maxf(-bounds.position.z - depth * 0.5, bounds.end.z - depth * 0.5)), "height_max": bounds.end.y, "bounds": bounds,
		"closed_door": true, "door_x": door_x, "door_width": door_width, "door_height": door_height,
		"door_approach": Rect2(Vector2(door_x - door_width * 0.5 - 0.12, depth * 0.5), Vector2(door_width + 0.24, 0.85)),
		"openings": _openings, "roof_edges": _roof_edges, "materials": MATERIAL_KEYS, "style": STYLES.get(key, {}),
		"collision_note": "Existing whole-house footprint remains solid; doors are closed, smith/stable recesses carry blocking worktops or rails. No enterable interior is promised.",
		"timber_mapping": "beam-local longitudinal grain, shared existing door material; metre UVs",
		"timber_tile_m": TIMBER_TILE, "slate_tile_m": SLATE_TILE, "slate_tiles": _slate_tiles, "corner_quoins": _quoins,
		"projection_review": "Pending actual multi-face camera captures; geometry uses native orthogonal XYZ without sprite baking."}
	_root.set_meta("native_house", report)
	return report


func _opening(x: float, width: float, bottom: float, height: float) -> Dictionary:
	return {"x": x, "width": width, "bottom": bottom, "height": height, "arch": false, "role": "window"}


func _wall(width: float, bottom: float, top: float, openings: Array[Dictionary], facade: Transform3D) -> void:
	var splits: Array[float] = [-width * 0.5, width * 0.5]
	for opening in openings:
		var left := float(opening["x"]) - float(opening["width"]) * 0.5
		var right := left + float(opening["width"])
		var steps := 12 if opening["arch"] else 1
		for index in steps + 1:
			var x := lerpf(left, right, float(index) / steps)
			if not splits.has(x):
				splits.append(x)
		_openings.append({"transform": facade, "opening": opening.duplicate(), "wall_depth": WALL, "actual_recess": 0.12})
	splits.sort()
	for column in splits.size() - 1:
		var a := splits[column]
		var b := splits[column + 1]
		if b - a < 0.00001:
			continue
		var active: Array[Dictionary] = []
		var middle := (a + b) * 0.5
		for opening in openings:
			if absf(middle - float(opening["x"])) < float(opening["width"]) * 0.5:
				active.append(opening)
		active.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return float(left["bottom"]) < float(right["bottom"]))
		var low_a := bottom
		var low_b := bottom
		for opening in active:
			var next := float(opening["bottom"])
			_wall_column(a, b, low_a, low_b, next, facade)
			low_a = _arch_height(opening, a) if opening["arch"] else next + float(opening["height"])
			low_b = _arch_height(opening, b) if opening["arch"] else next + float(opening["height"])
		_wall_column(a, b, low_a, low_b, top, facade)


func _wall_column(a: float, b: float, low_a: float, low_b: float, top: float, facade: Transform3D) -> void:
	if top <= maxf(low_a, low_b) + 0.00001:
		return
	if absf(low_a - low_b) < 0.00001:
		_panel(a, b, low_a, top, facade)
	else:
		_prism(PackedVector2Array([Vector2(a, low_a), Vector2(b, low_b), Vector2(b, top), Vector2(a, top)]), WALL, facade, "wall")


func _panel(left: float, right: float, bottom: float, top: float, facade: Transform3D) -> void:
	if right - left <= 0.001 or top - bottom <= 0.001:
		return
	_box(Vector3((left + right) * 0.5, (bottom + top) * 0.5, 0), Vector3(right - left, top - bottom, WALL), "wall", facade, false)


func _arch_height(opening: Dictionary, x: float) -> float:
	var radius := float(opening["width"]) * 0.5
	var local := clampf(x - float(opening["x"]), -radius, radius)
	return float(opening["bottom"]) + float(opening["height"]) - radius + sqrt(maxf(0.0, radius * radius - local * local))


func _door(opening: Dictionary, facade: Transform3D) -> void:
	var x := float(opening["x"])
	var width := float(opening["width"])
	var bottom := float(opening["bottom"])
	var tall := float(opening["height"])
	var left := x - width * 0.5
	var planks := 10
	for plank in planks:
		var a := left + width * plank / planks + 0.006
		var b := left + width * (plank + 1) / planks - 0.006
		var top_a := _arch_height(opening, a) if opening["arch"] else bottom + tall
		var top_b := _arch_height(opening, b) if opening["arch"] else bottom + tall
		_prism(PackedVector2Array([Vector2(a, bottom + 0.02), Vector2(b, bottom + 0.02), Vector2(b, top_b - 0.025), Vector2(a, top_a - 0.025)]), 0.07, facade * Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.08)), "wood")
	var shoulder := bottom + tall - (width * 0.5 if opening["arch"] else 0.0)
	for side in [-1.0, 1.0]:
		_box(Vector3(x + side * (width * 0.5 + 0.065), (bottom + shoulder) * 0.5, 0.065), Vector3(0.13, shoulder - bottom, 0.15), "stone" if opening["arch"] else "wood", facade)
	if opening["arch"]:
		_arch_ring(x, shoulder, width * 0.5, 0.13, facade)
	else:
		_box(Vector3(x, bottom + tall + 0.065, 0.065), Vector3(width + 0.26, 0.13, 0.15), "wood", facade)
	for level in [0.42, 1.36]:
		_box(Vector3(x, bottom + level, -0.025), Vector3(width * 0.86, 0.06, 0.04), "iron", facade)
		for side in [-1.0, 1.0]:
			_rivet(Vector3(x + side * width * 0.35, bottom + level, 0.001), facade)
	for side in ([-1.0, 1.0] if _key in ["nw", "sw"] else [1.0]):
		var handle := TorusMesh.new()
		handle.inner_radius = 0.038
		handle.outer_radius = 0.057
		handle.rings = 12
		handle.ring_segments = 4
		_append_mesh(handle, facade * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x + side * 0.12, bottom + 1.01, 0.005)), "iron")


func _arch_ring(x: float, shoulder: float, radius: float, thick: float, facade: Transform3D) -> void:
	for index in 12:
		var a := index * PI / 12.0
		var b := (index + 1) * PI / 12.0
		var outer := radius + thick
		var polygon := PackedVector2Array([Vector2(x + cos(a) * radius, shoulder + sin(a) * radius), Vector2(x + cos(b) * radius, shoulder + sin(b) * radius), Vector2(x + cos(b) * outer, shoulder + sin(b) * outer), Vector2(x + cos(a) * outer, shoulder + sin(a) * outer)])
		_prism(polygon, 0.16, facade * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.065)), "stone")


func _window(opening: Dictionary, facade: Transform3D, shutters: bool) -> void:
	var x := float(opening["x"])
	var width := float(opening["width"])
	var bottom := float(opening["bottom"])
	var tall := float(opening["height"])
	var center := Vector3(x, bottom + tall * 0.5, -0.082)
	_box(center, Vector3(width - 0.045, tall - 0.045, 0.025), "glass", facade)
	for side in [-1.0, 1.0]:
		_box(Vector3(x + side * (width * 0.5 + 0.026), center.y, 0.045), Vector3(0.09, tall + 0.16, 0.13), "wood", facade)
	for level in [bottom - 0.035, bottom + tall + 0.035]:
		_box(Vector3(x, level, 0.045), Vector3(width + 0.14, 0.095, 0.14), "stone", facade)
	_box(Vector3(x, center.y, -0.035), Vector3(0.035, tall, 0.025), "wood", facade)
	_box(Vector3(x, center.y - 0.12, -0.035), Vector3(width, 0.035, 0.025), "wood", facade)
	for index in 5:
		var start := (index / 4.0 - 0.5) * width * 0.82
		var end := clampf(start + width * 0.46, -width * 0.46, width * 0.46)
		_beam(Vector3(x + start, bottom + 0.06, -0.032), Vector3(x + end, bottom + tall - 0.06, -0.032), 0.012, "iron", facade)
	if shutters:
		for side in [-1.0, 1.0]:
			var at := Vector3(x + side * (width * 0.5 + 0.18), center.y, 0.015)
			_box(at, Vector3(0.22, tall * 0.95, 0.055), "wood", facade)
			for level in [-0.31, 0.31]:
				_box(at + Vector3(0, tall * level, 0.035), Vector3(0.24, 0.033, 0.026), "iron", facade)
	_box(Vector3(x, bottom - 0.085, 0.055), Vector3(width + 0.20, 0.07, 0.19), "stone", facade)


func _frame(width: float, top: float, facade: Transform3D, upper: bool, openings: Array[Dictionary]) -> void:
	# Lower masonry corners are ashlar; timber posts belong to the inn upper story.
	if upper:
		var post_bottom := 2.48
		for side in [-1.0, 1.0]:
			_box(Vector3(side * (width * 0.5 - 0.05), (post_bottom + top) * 0.5, 0.11), Vector3(0.14, top - post_bottom, 0.11), "wood", facade)
	for level in [top - 0.10, (2.48 if upper else 0.43)]:
		var gaps: Array[Vector2] = []
		for opening in openings:
			if float(opening["bottom"]) < level + 0.06 and float(opening["bottom"]) + float(opening["height"]) > level - 0.06:
				gaps.append(Vector2(float(opening["x"]) - float(opening["width"]) * 0.5 - 0.08, float(opening["x"]) + float(opening["width"]) * 0.5 + 0.08))
		gaps.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var cursor := -width * 0.5 - 0.04
		for gap in gaps:
			if gap.x > cursor:
				_box(Vector3((cursor + gap.x) * 0.5, level, 0.11), Vector3(gap.x - cursor, 0.12, 0.11), "wood" if upper or level > 0.5 else "stone", facade)
			cursor = maxf(cursor, gap.y)
		if cursor < width * 0.5 + 0.04:
			_box(Vector3((cursor + width * 0.5 + 0.04) * 0.5, level, 0.11), Vector3(width * 0.5 + 0.04 - cursor, 0.12, 0.11), "wood" if upper or level > 0.5 else "stone", facade)
	var count := maxi(4, ceili(width / 0.52))
	for index in count:
		_box(Vector3(lerpf(-width * 0.44, width * 0.44, (index + 0.5) / count), top - 0.23, 0.11), Vector3(0.075, 0.22, 0.12), "wood", facade)


func _corner_quoins(width: float, depth: float, top: float, wall_top: float) -> void:
	# Small bonded corner dressings remain inside the original ground envelope.
	# They share the world's 32cm masonry courses and one stone surface.
	# Close the exterior quarter at the intersection of the two thick wall panels.
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			_box(Vector3(x * (width * 0.5 + 0.05), (FLOOR + wall_top) * 0.5, z * (depth * 0.5 + 0.05)), Vector3(0.10, wall_top - FLOOR, 0.10), "stone", Transform3D.IDENTITY, false)
	for row in ceili(top / ASHLAR_COURSE):
		var low := maxf(FLOOR, row * ASHLAR_COURSE + 0.009)
		var high := minf(top - 0.009, (row + 1) * ASHLAR_COURSE - 0.009)
		if high - low < 0.035:
			continue
		for x: float in [-1.0, 1.0]:
			for z: float in [-1.0, 1.0]:
				var front := Transform3D(Basis(Vector3.UP, 0.0 if z > 0.0 else PI), Vector3(0, 0, z * depth * 0.5))
				var side := Transform3D(Basis(Vector3.UP, x * PI * 0.5), Vector3(x * width * 0.5, 0, 0))
				var across: float = x * z
				var along: float = -x * z
				var long := 0.38 if row % 2 == 0 else 0.29
				var short := 0.29 if row % 2 == 0 else 0.38
				var end_x := width * 0.5 + 0.092
				var end_z := depth * 0.5 + 0.14
				_relief_stone(minf(across * end_x, across * (end_x - long)), maxf(across * end_x, across * (end_x - long)), low, high, front)
				_relief_stone(minf(along * end_z, along * (end_z - short)), maxf(along * end_z, along * (end_z - short)), low, high, side)
				_quoins += 1


func _relief_stone(left: float, right: float, bottom: float, top: float, facade: Transform3D) -> void:
	# A closed shallow frustum has 7mm edge relief, not a pasted unlit outline.
	var inset := 0.007
	var back: Array[Vector3] = [Vector3(left, bottom, 0.092), Vector3(right, bottom, 0.092), Vector3(right, top, 0.092), Vector3(left, top, 0.092)]
	var front: Array[Vector3] = [Vector3(left + inset, bottom + inset, 0.14), Vector3(right - inset, bottom + inset, 0.14), Vector3(right - inset, top - inset, 0.14), Vector3(left + inset, top - inset, 0.14)]
	var outer: Array[Vector3] = []
	var inner: Array[Vector3] = []
	for index in 4:
		outer.append(facade * front[index])
		inner.append(facade * back[index])
	_quad(outer, facade.basis * Vector3.BACK, "stone")
	_quad(inner, facade.basis * Vector3.FORWARD, "stone")
	for index in 4:
		var next := (index + 1) % 4
		var points: Array[Vector3] = [inner[index], inner[next], outer[next], outer[index]]
		var normal: Vector3 = (points[1] - points[0]).cross(points[2] - points[0]).normalized()
		# Use the actual sloping bevel plane for the shared directional light.
		_quad(points, normal, "stone")
	_pieces += 1


func _roof(width: float, depth: float, top: float, rise: float) -> void:
	var half := width * 0.5 + EAVES
	var reach := depth * 0.5 + EAVES
	var length := sqrt(half * half + rise * rise)
	var rows := maxi(1, ceili(length / SLATE_PITCH))
	var first_column := floori(-reach / SLATE_WIDTH) - 1
	var last_column := ceili(reach / SLATE_WIDTH) + 1
	for side in [-1.0, 1.0]:
		var normal := Vector3(side * rise / half, 1, 0).normalized()
		# Continuous underlay closes the narrow staggered joints. Course fronts sit
		# above the previous course instead of overlapping coplanar roof triangles.
		var base: Array[Vector3] = [Vector3(side * half, top, -reach), Vector3(side * half, top, reach), Vector3(0, top + rise, reach), Vector3(0, top + rise, -reach)]
		var base_uv: Array[Vector2] = [Vector2(-reach, 0) / SLATE_TILE, Vector2(reach, 0) / SLATE_TILE, Vector2(reach, length) / SLATE_TILE, Vector2(-reach, length) / SLATE_TILE]
		_quad(base, normal, "slate", base_uv)
		for row in rows:
			# The generated slate has eight physical courses per 2.6m tile.
			# Keep every eave boundary on that UV grid; only the ridge course clips.
			var low := row * SLATE_PITCH / length
			var high := minf(1.0, (row + 1) * SLATE_PITCH / length)
			var splits: Array[float] = [-reach, reach]
			for column in range(first_column, last_column + 1):
				# Anchor joint pitch and stagger to U=0, not the clipped roof edge.
				var edge := (column + (0.5 if row % 2 else 0.0)) * SLATE_WIDTH
				if edge > -reach + 0.001 and edge < reach - 0.001:
					splits.append(edge)
			splits.sort()
			for column in splits.size() - 1:
				var from := splits[column] + (0.004 if column > 0 else 0.0)
				var to := splits[column + 1] - (0.004 if column + 1 < splits.size() - 1 else 0.0)
				var a := Vector3(side * half * (1.0 - low), top + rise * low, from) + normal * 0.028
				var b := Vector3(a.x, a.y, to)
				var c := Vector3(side * half * (1.0 - high), top + rise * high, to) + normal * 0.006
				var d := Vector3(c.x, c.y, from)
				var uv: Array[Vector2] = [Vector2(from, low * length) / SLATE_TILE, Vector2(to, low * length) / SLATE_TILE, Vector2(to, high * length) / SLATE_TILE, Vector2(from, high * length) / SLATE_TILE]
				var tile_normal := (b - a).cross(d - a).normalized()
				if tile_normal.y < 0.0:
					tile_normal = -tile_normal
				_quad([a, b, c, d], tile_normal, "slate", uv)
				var edge_normal := Vector3(side * normal.y, -absf(normal.x), 0).normalized()
				_quad([a, a - normal * 0.022, b - normal * 0.022, b], edge_normal, "slate", [uv[0], uv[0] + Vector2(0, 0.022 / SLATE_TILE), uv[1] + Vector2(0, 0.022 / SLATE_TILE), uv[1]])
				_slate_tiles += 1
		_box(Vector3(side * (half - 0.055), top - 0.025, 0), Vector3(0.11, 0.16, reach * 2.0), "wood")
		for end in [-1.0, 1.0]:
			var a := Vector3(side * (half - 0.06), top + rise * 0.06 / half + 0.015, end * (reach - 0.06))
			var b := Vector3(0, top + rise + 0.03, end * (reach - 0.06))
			_beam(a, b, 0.115, "wood")
			_roof_edges.append({"a": a, "b": b, "kind": "roof_pitch"})
		_roof_edges.append({"a": Vector3(side * half, top, -reach), "b": Vector3(side * half, top, reach), "kind": "ground_axis"})
	var caps := maxi(4, ceili(reach * 2.0 / 0.38))
	for index in caps:
		_box(Vector3(0, top + rise + 0.06, lerpf(-reach, reach, (index + 0.5) / caps)), Vector3(0.19, 0.13, reach * 2.0 / caps - 0.012), "slate")

func _chimney(width: float, depth: float, top: float, rise: float, twin: bool) -> void:
	var center := Vector3(width * (-0.23 if _key == "se" else 0.23), top + rise * 0.69, -depth * 0.20)
	var bottom := center.y - 0.40
	var high := top + rise + 0.45
	var half := 0.30
	for side in [-1.0, 1.0]:
		_box(Vector3(center.x + side * (half - 0.055), (bottom + high) * 0.5, center.z), Vector3(0.11, high - bottom, half * 2.0), "stone")
		_box(Vector3(center.x, (bottom + high) * 0.5, center.z + side * (half - 0.055)), Vector3(half * 2.0 - 0.22, high - bottom, 0.11), "stone")
		_box(Vector3(center.x + side * (half - 0.04), high + 0.025, center.z), Vector3(0.15, 0.10, half * 2.0 + 0.14), "stone")
		_box(Vector3(center.x, high + 0.025, center.z + side * (half - 0.04)), Vector3(half * 2.0 - 0.22, 0.10, 0.15), "stone")
	_box(Vector3(center.x, high - 0.18, center.z), Vector3(0.35, 0.035, 0.35), "iron")
	if twin:
		for side in [-1.0, 1.0]:
			_tube(Vector3(center.x + side * 0.15, high + 0.06, center.z), 0.20, 0.105, 0.072)


func _tube(at: Vector3, tall: float, outer: float, inner: float) -> void:
	for index in 12:
		var a := index * TAU / 12.0
		var b := (index + 1) * TAU / 12.0
		var low_a := at + Vector3(cos(a) * outer, 0, sin(a) * outer)
		var low_b := at + Vector3(cos(b) * outer, 0, sin(b) * outer)
		var high_a := low_a + Vector3.UP * tall
		var high_b := low_b + Vector3.UP * tall
		var inward_a := at + Vector3(cos(a) * inner, tall, sin(a) * inner)
		var inward_b := at + Vector3(cos(b) * inner, tall, sin(b) * inner)
		var normal := Vector3(cos((a + b) * 0.5), 0, sin((a + b) * 0.5))
		_quad([low_a, low_b, high_b, high_a], normal, "stone")
		_quad([inward_a - Vector3.UP * tall, inward_b - Vector3.UP * tall, inward_b, inward_a], -normal, "stone")
		_quad([high_a, high_b, inward_b, inward_a], Vector3.UP, "stone")


func _smith_bay(opening: Dictionary, facade: Transform3D) -> void:
	var x := float(opening["x"])
	var width := float(opening["width"])
	_box(Vector3(x, 0.72, -0.12), Vector3(width * 0.98, 0.18, 0.38), "stone", facade)
	_box(Vector3(x, 1.39, -0.39), Vector3(width, 1.28, 0.10), "wood", facade)
	for side in [-1.0, 1.0]:
		_box(Vector3(x + side * (width * 0.5 + 0.035), 1.38, 0.065), Vector3(0.11, 1.58, 0.14), "wood", facade)
	_box(Vector3(x, 2.13, 0.06), Vector3(width + 0.20, 0.12, 0.14), "wood", facade)
	# Tools hang behind a worktop; this recess is deliberately not a doorway.
	for tool in [-1.0, 0.0, 1.0]:
		_box(Vector3(x + tool * width * 0.25, 1.32, -0.29), Vector3(0.035, 0.48, 0.035), "iron", facade)
		_box(Vector3(x + tool * width * 0.25, 1.54, -0.29), Vector3(0.13, 0.07, 0.055), "iron", facade)


func _stable_bay(opening: Dictionary, facade: Transform3D) -> void:
	var x := float(opening["x"])
	var width := float(opening["width"])
	for side in [-1.0, 1.0]:
		_box(Vector3(x + side * (width * 0.5 + 0.025), 1.39, 0.065), Vector3(0.12, 1.84, 0.14), "wood", facade)
	_box(Vector3(x, 2.25, 0.065), Vector3(width + 0.18, 0.14, 0.14), "wood", facade)
	_box(Vector3(x, 0.80, 0.025), Vector3(width, 0.095, 0.10), "wood", facade)
	_box(Vector3(x, 1.06, 0.025), Vector3(width, 0.075, 0.10), "wood", facade)
	for plank in 7:
		_box(Vector3(x + width * (plank / 6.0 - 0.5), 0.71, 0.015), Vector3(0.12, 0.80, 0.07), "wood", facade)
	_box(Vector3(x, 0.70, -0.42), Vector3(width * 0.90, 0.18, 0.25), "wood", facade)


func _smith_hood(width: float, depth: float, top: float) -> void:
	var center := Vector3(-width * 0.24, top - 0.37, depth * 0.5 - 0.38)
	_box(center, Vector3(0.80, 0.20, 0.45), "iron")
	_box(center + Vector3(0, 0.37, -0.08), Vector3(0.29, 0.65, 0.25), "iron")


func _dormer(width: float, depth: float, top: float, rise: float, side: float) -> void:
	var half := width * 0.5 + EAVES
	var x := half * 0.59
	var y := top + rise * 0.41 + 0.04
	var at := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, y, side * depth * 0.23))
	var opening := _opening(0.0, 0.48, 0.08, 0.61)
	_wall(0.78, 0.0, 0.82, [opening] as Array[Dictionary], at)
	_window(opening, at, false)
	for direction in [-1.0, 1.0]:
		_box(Vector3(direction * 0.37, 0.38, -0.27), Vector3(0.10, 0.76, 0.60), "wood", at)
	var polygon := PackedVector2Array([Vector2(-0.43, 0.82), Vector2(0.43, 0.82), Vector2(0, 1.18)])
	_prism(polygon, 0.12, at, "wood")
	for direction in [-1.0, 1.0]:
		_beam(Vector3(direction * 0.44, 0.83, 0.035), Vector3(0, 1.18, 0.035), 0.09, "wood", at)
		var a := at * Vector3(direction * 0.44, 0.83, 0.06)
		var b := at * Vector3(direction * 0.44, 0.83, -0.63)
		var c := at * Vector3(0, 1.19, -0.63)
		var d := at * Vector3(0, 1.19, 0.06)
		var normal := (b - a).cross(d - a).normalized()
		var slope := Vector2(0.44, 0.36).length()
		var uv: Array[Vector2] = [Vector2(0.06, 0), Vector2(-0.63, 0), Vector2(-0.63, slope), Vector2(0.06, slope)]
		for index in uv.size():
			uv[index] /= SLATE_TILE
		_quad([a, b, c, d], normal if normal.y >= 0.0 else -normal, "slate", uv)


func _rivet(at: Vector3, facade: Transform3D) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.018
	sphere.height = 0.036
	sphere.radial_segments = 6
	sphere.rings = 3
	_append_mesh(sphere, facade * Transform3D(Basis.IDENTITY, at), "iron")


func _beam(a: Vector3, b: Vector3, thickness: float, material: String, transform := Transform3D.IDENTITY) -> void:
	var direction := b - a
	if direction.length_squared() < 0.000001:
		return
	var basis := Basis(Quaternion(Vector3.FORWARD, direction.normalized()))
	_box(Vector3.ZERO, Vector3(thickness, thickness, direction.length()), material, transform * Transform3D(basis, (a + b) * 0.5))


func _box(at: Vector3, size: Vector3, material: String, transform := Transform3D.IDENTITY, chamfer := true) -> void:
	if not chamfer or material not in ["stone", "wood", "iron"]:
		_append_arrays(_box_arrays, transform * Transform3D(Basis.from_scale(size), at), material)
		return
	# Metre-sized edge relief catches the shared light; wall partition seams never
	# use it. The primitive retains exactly the requested external bounds.
	var amount := minf(0.004 if material == "iron" else (0.016 if material == "stone" else 0.012), minf(size.x, minf(size.y, size.z)) * 0.20)
	var half := size * 0.5
	var normals := transform.basis.inverse().transposed()
	var grain := size.max_axis_index()
	for axis in 3:
		var across := (axis + 1) % 3
		var along := (axis + 2) % 3
		for side in [-1.0, 1.0]:
			var points: Array[Vector3] = []
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var point := Vector3.ZERO
				point[axis] = half[axis] * side
				point[across] = (half[across] - amount) * corner.x
				point[along] = (half[along] - amount) * corner.y
				points.append(transform * (at + point))
			var normal := Vector3.ZERO
			normal[axis] = side
			_quad(points, (normals * normal).normalized(), material, _box_uvs(points, normal, transform, at, grain, material))
	for first in 3:
		for second in range(first + 1, 3):
			var third := 3 - first - second
			for sign_a in [-1.0, 1.0]:
				for sign_b in [-1.0, 1.0]:
					var points: Array[Vector3] = []
					for corner in [Vector2(0, -1), Vector2(0, 1), Vector2(1, 1), Vector2(1, -1)]:
						var point := Vector3.ZERO
						point[first] = (half[first] - amount * corner.x) * sign_a
						point[second] = (half[second] - amount * (1.0 - corner.x)) * sign_b
						point[third] = (half[third] - amount) * corner.y
						points.append(transform * (at + point))
					var normal := Vector3.ZERO
					normal[first] = sign_a
					normal[second] = sign_b
					_quad(points, (normals * normal).normalized(), material, _box_uvs(points, normal.normalized(), transform, at, grain, material))
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				var signs := Vector3(x, y, z)
				var points: Array[Vector3] = []
				for axis in 3:
					var point := (half - Vector3.ONE * amount) * signs
					point[axis] += amount * signs[axis]
					points.append(transform * (at + point))
				var coords := _box_uvs(points, signs.normalized(), transform, at, grain, material)
				_triangle(points, coords if not coords.is_empty() else [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE], (normals * signs).normalized(), material)
	_pieces += 1


func _box_uvs(points: Array, normal: Vector3, transform: Transform3D, at: Vector3, grain: int, material: String) -> Array:
	var coords := []
	if material != "wood":
		return coords
	var inverse := transform.affine_inverse()
	for point: Vector3 in points:
		coords.append(_timber_uv(inverse * point - at, normal, grain))
	return coords


func _append_mesh(mesh: Mesh, transform: Transform3D, material: String) -> void:
	_append_arrays(mesh.surface_get_arrays(0), transform, material)


func _append_arrays(arrays: Array, transform: Transform3D, material: String) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var count := indices.size() if not indices.is_empty() else vertices.size()
	var normal_basis := transform.basis.inverse().transposed()
	var tool := _surface(material)
	for index in count:
		var source := indices[index] if not indices.is_empty() else index
		tool.set_normal((normal_basis * normals[source]).normalized())
		tool.set_uv(_planar_uv(transform * vertices[source], (normal_basis * normals[source]).normalized(), material) if material == "slate" else uv[source])
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
	var normal_basis := transform.basis.inverse().transposed()
	for side in [-1.0, 1.0]:
		var normal := (normal_basis * Vector3(0, 0, side)).normalized()
		for index in range(0, triangles.size(), 3):
			var points: Array[Vector3] = []
			var uv: Array[Vector2] = []
			for corner in 3:
				var point := polygon[triangles[index + corner]]
				points.append(transform * Vector3(point.x, point.y, side * depth * 0.5))
				uv.append(Vector2(point.x, -point.y) / (TIMBER_TILE if material == "wood" else 2.6))
			_triangle(points, uv, normal, material)
	var area := 0.0
	for index in polygon.size():
		area += polygon[index].cross(polygon[(index + 1) % polygon.size()])
	for index in polygon.size():
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		var edge := b - a
		var normal := (normal_basis * Vector3(edge.y, -edge.x, 0) * signf(area)).normalized()
		_quad([transform * Vector3(a.x, a.y, -depth * 0.5), transform * Vector3(b.x, b.y, -depth * 0.5), transform * Vector3(b.x, b.y, depth * 0.5), transform * Vector3(a.x, a.y, depth * 0.5)], normal, material)
	_pieces += 1


func _quad(points: Array, normal: Vector3, material: String, uv: Array = []) -> void:
	var coords := uv
	if coords.is_empty():
		coords = []
		for point: Vector3 in points:
			coords.append(_planar_uv(point, normal, material))
	_triangle([points[0], points[1], points[2]], [coords[0], coords[1], coords[2]], normal, material)
	_triangle([points[0], points[2], points[3]], [coords[0], coords[2], coords[3]], normal, material)


func _planar_uv(point: Vector3, normal: Vector3, material: String) -> Vector2:
	if material == "wood":
		return _timber_uv(point, normal, Vector3.AXIS_Y)
	if material == "slate":
		if absf(normal.y) > 0.7:
			return Vector2(point.z, point.x) / SLATE_TILE
		# End caps face Z, so their physical horizontal axis is X rather than Z.
		return Vector2(point.z if absf(normal.x) >= absf(normal.z) else point.x, -point.y) / SLATE_TILE
	var tangent := Vector3(normal.z, 0, -normal.x)
	return Vector2(point.dot(tangent), -point.y) / 2.56


func _timber_uv(point: Vector3, normal: Vector3, grain: int) -> Vector2:
	var first := (grain + 1) % 3
	var second := (grain + 2) % 3
	if absf(normal[grain]) > 0.8:
		return Vector2(point[first], point[second]) / TIMBER_TILE
	var across := first if absf(normal[first]) <= absf(normal[second]) else second
	return Vector2(point[across], -point[grain]) / TIMBER_TILE


func _triangle(points: Array, uv: Array, normal: Vector3, material: String) -> void:
	var order := [0, 2, 1] if (points[1] - points[0]).cross(points[2] - points[0]).dot(normal) > 0.0 else [0, 1, 2]
	var tool := _surface(material)
	for index in order:
		tool.set_normal(normal)
		tool.set_uv(uv[index])
		tool.add_vertex(points[index])
	_triangles += 1


func _flush() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for material: String in _surfaces:
		var tool: SurfaceTool = _surfaces[material]
		tool.index()
		var node := MeshInstance3D.new()
		node.name = "House_" + _key + "_" + material
		node.mesh = tool.commit()
		node.material_override = _materials[material]
		_root.add_child(node)
		result.append(node)
	return result

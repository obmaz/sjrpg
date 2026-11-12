class_name Minimap
extends Control
## Round minimap (top right). Drawn in world-pixel orientation so it matches the
## quarter view; every shape is clipped to the circle.

signal open_requested

var game: Node
var radius := 70.0
const WORLD_RADIUS := 1300.0

## The terrain, dots and decoration keep their Canvas draw commands independently.
var _backdrop: Node2D
var _marker_layer: Node2D
var _player_arrow: Node2D
var _bezel: Node2D
var _dots: Array[MarkerDot] = []
var _paint_radius := -1.0
var _paint_center := Vector2.INF
var _terrain_revision := -1
var _source_valid := false
var terrain_redraw_requests := 0
var decoration_redraw_requests := 0


class MarkerDot:
	extends Node2D
	var dot_radius := -1.0
	var ink := Color.TRANSPARENT
	var redraw_requests := 0

	func configure(new_radius: float, new_ink: Color) -> void:
		if new_radius == dot_radius and new_ink == ink:
			return
		dot_radius = new_radius
		ink = new_ink
		redraw_requests += 1
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, dot_radius, ink)


var _circle := PackedVector2Array()
var _geometry: Array[Dictionary] = []
var _geometry_mesh: ArrayMesh
var _geometry_source: Array[Dictionary] = []
var _geometry_count := -1
var _geometry_hash := 0
var _geometry_origin := Vector2.INF
var _geometry_radius := -1.0
var geometry_rebuilds := 0
const PARCHMENT := Color("637153")
const COMPASS_OFFSET := Vector2(0.78, -0.40)
const COMPASS_RADIUS := 9.5


func content_radius() -> float:
	return radius - 2.0 * radius / 64.0


func rim_radius() -> float:
	return radius + 2.5 * radius / 64.0


## Painted extents include antialiasing and the offset shadow, not just the map disc.
func paint_bounds() -> Rect2:
	return painted_bounds(radius, size)


static func painted_bounds(disc_radius: float, control_size: Vector2) -> Rect2:
	var u := disc_radius / 64.0
	var c := control_size / 2.0
	var aa := maxf(1.0, u)
	var outer := disc_radius + 2.5 * u + aa
	var shadow := disc_radius + 0.25 * u + 1.25 * u + aa
	var bounds := Rect2(c - Vector2.ONE * outer, Vector2.ONE * outer * 2.0)
	bounds = bounds.merge(
		Rect2(c + Vector2(0, 1.0) * u - Vector2.ONE * shadow, Vector2.ONE * shadow * 2.0)
	)
	var stud := (COMPASS_RADIUS + 0.55) * u + aa
	var compass := c + COMPASS_OFFSET * disc_radius
	return bounds.merge(Rect2(compass - Vector2.ONE * stud, Vector2.ONE * stud * 2.0))


func marker_fits(at: Vector2, dot_radius: float) -> bool:
	# A marker's entire antialiased disc must stay inside the content, clear of the metal rim.
	return at.length() + dot_radius + maxf(1.0, radius / 64.0) <= content_radius()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_create_retained_layers()
	_sync_retained()


func _process(_delta: float) -> void:
	_sync_retained()


## 멈춘 화면에서도 새 Control 크기에 맞춰 보관한 지도 도형과 테두리를 갱신한다.
func refresh_layout() -> void:
	_sync_retained()


func _create_retained_layers() -> void:
	_backdrop = Node2D.new()
	_backdrop.name = "MapBackdrop"
	_backdrop.show_behind_parent = true
	_backdrop.draw.connect(_draw_backdrop)
	add_child(_backdrop)
	_marker_layer = Node2D.new()
	_marker_layer.name = "MapMarkers"
	add_child(_marker_layer)
	_player_arrow = Node2D.new()
	_player_arrow.name = "MapPlayer"
	_player_arrow.draw.connect(_draw_player_arrow)
	add_child(_player_arrow)
	_bezel = Node2D.new()
	_bezel.name = "MapBezel"
	_bezel.draw.connect(_draw_bezel)
	add_child(_bezel)


## Node transforms move already uploaded circles and the arrow without recreating polygons.
func _sync_retained() -> void:
	if _backdrop == null:
		return
	var valid: bool = game != null and game.player != null and game.village != null
	var was_valid := _source_valid
	for item: Node2D in [_backdrop, _marker_layer, _player_arrow, _bezel]:
		item.visible = valid
	if not valid:
		if _source_valid:
			queue_redraw()
		_source_valid = false
		return
	_source_valid = true
	if game.has_method("refresh_map") and game.process_mode != Node.PROCESS_MODE_DISABLED:
		game.refresh_map()
	var center := size / 2.0
	var layout_changed := center != _paint_center
	if layout_changed:
		_paint_center = center
		for item: Node2D in [_backdrop, _marker_layer, _player_arrow, _bezel]:
			item.position = center
	if radius != _paint_radius:
		_paint_radius = radius
		decoration_redraw_requests += 1
		_backdrop.queue_redraw()
		_player_arrow.queue_redraw()
		_bezel.queue_redraw()
	var origin: Vector2 = game.player.position
	_update_geometry(origin)
	if _terrain_revision != geometry_rebuilds or layout_changed or not was_valid:
		_terrain_revision = geometry_rebuilds
		terrain_redraw_requests += 1
		queue_redraw()
	_sync_markers(origin)
	_player_arrow.rotation = game.player.facing


func _sync_markers(origin: Vector2) -> void:
	var count := 0
	var marker_radius := maxf(2.0, radius * 0.035)
	for marker: Dictionary in MapGeometry.markers(game):
		_sync_dot(count, marker["pos"], origin, marker_radius, Color(marker["color"], 0.82))
		count += 1
	var enemy_radius := maxf(1.8, radius * 0.027)
	for enemy: Enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		_sync_dot(count, enemy.position, origin, enemy_radius, Color(0.74, 0.26, 0.18, 0.88))
		count += 1
	# Keep no actor references or historical realm markers in the retained pool.
	while _dots.size() > count:
		var spare: MarkerDot = _dots.pop_back()
		spare.free()


func _sync_dot(index: int, world: Vector2, origin: Vector2, dot_radius: float, ink: Color) -> void:
	if index == _dots.size():
		var fresh := MarkerDot.new()
		fresh.name = "MapDot%d" % index
		_marker_layer.add_child(fresh)
		_dots.append(fresh)
	var dot: MarkerDot = _dots[index]
	dot.configure(dot_radius, ink)
	dot.position = _to_map(world, origin)
	dot.visible = marker_fits(dot.position, dot_radius)


func _draw_backdrop() -> void:
	_backdrop.draw_circle(Vector2.ZERO, radius, Color(0.07, 0.08, 0.07, 0.9))


func _arrow_points() -> PackedVector2Array:
	return PackedVector2Array(
		[
			Vector2(radius * 0.09, 0),
			Vector2.from_angle(2.5) * radius * 0.055,
			Vector2(-2.0, 0),
			Vector2.from_angle(-2.5) * radius * 0.055
		]
	)


func _draw_player_arrow() -> void:
	_player_arrow.draw_colored_polygon(_arrow_points(), Color(0.96, 0.96, 0.9))


func _circle_poly(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 80:
		pts.append(Vector2.from_angle(TAU * i / 80.0) * r)
	return pts


func _to_map(world: Vector2, origin: Vector2) -> Vector2:
	return (world - origin) * (radius / WORLD_RADIUS)


func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


func _cache_shape(poly: PackedVector2Array, color: Color, origin: Vector2) -> void:
	var local := PackedVector2Array()
	for p in poly:
		local.append(_to_map(p, origin))
	for piece in Geometry2D.intersect_polygons(local, _circle):
		if piece.size() >= 3 and absf(_area(piece)) > 1.0:
			_geometry.append({"poly": piece, "color": PARCHMENT.lerp(color, 0.52)})


## Reuse the clipped terrain until movement would shift it by a quarter of a map pixel.
## Markers and the player arrow still use their current positions on every rendered frame.
func _update_geometry(origin: Vector2) -> void:
	var fingerprint: int = game.map_shapes.hash()
	var tolerance := WORLD_RADIUS / radius * 0.25
	if (
		fingerprint == _geometry_hash
		and is_same(game.map_shapes, _geometry_source)
		and game.map_shapes.size() == _geometry_count
		and is_equal_approx(radius, _geometry_radius)
		and origin.distance_squared_to(_geometry_origin) < tolerance * tolerance
	):
		return
	_geometry_source = game.map_shapes
	_geometry_count = game.map_shapes.size()
	_geometry_hash = fingerprint
	_geometry_origin = origin
	_geometry_radius = radius
	geometry_rebuilds += 1
	_circle = _circle_poly(content_radius())
	_geometry.clear()
	for shape in game.map_shapes:
		if (shape["poly"] as PackedVector2Array).size() < 3:
			continue
		var bounds: Rect2 = shape["bounds"]
		if bounds.grow(WORLD_RADIUS).has_point(origin):
			_cache_shape(shape["poly"], shape["color"], origin)
	_build_geometry_mesh()


## One persistent canvas mesh keeps the original clipped polygon order and colors.
## Replacing draw_colored_polygon calls avoids fresh GPU polygon buffers every frame.
func _build_geometry_mesh() -> void:
	var pieces: Array[Dictionary] = [{"poly": _circle, "color": PARCHMENT}]
	pieces.append_array(_geometry)
	_geometry_mesh = MapMesh.update(pieces, _geometry_mesh)


func _draw() -> void:
	# Explicit transition/preview refreshes remain correct even while processing is paused.
	_sync_retained()
	if not _source_valid:
		return
	draw_set_transform(size / 2.0, 0.0, Vector2.ONE)
	draw_mesh(_geometry_mesh, null)


func _draw_bezel() -> void:
	# The same decoration stays above terrain, markers and the player arrow.
	var u := radius / 64.0
	_bezel.draw_arc(
		Vector2(0, 1.0) * u,
		radius + 0.25 * u,
		0,
		TAU,
		80,
		Color(0.01, 0.015, 0.01, 0.75),
		2.5 * u,
		true
	)
	PresentationArt.draw_ui(_bezel, "map", Vector2.ZERO, rim_radius(), Color(0.9, 0.86, 0.76))
	var compass := COMPASS_OFFSET * radius
	_bezel.draw_circle(compass, COMPASS_RADIUS * u, Color("201d17"))
	_bezel.draw_arc(compass, COMPASS_RADIUS * u, 0, TAU, 40, Color("a28b5b"), 1.1 * u, true)
	var arrow := PackedVector2Array(
		[
			compass + Vector2(5.3, -0.7) * u,
			compass + Vector2(-4.5, -4.0) * u,
			compass + Vector2(-2.5, 1.0) * u,
			compass + Vector2(-4.0, 5.0) * u
		]
	)
	_bezel.draw_colored_polygon(arrow, Color("c6b17c"))


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		open_requested.emit()
		accept_event()

class_name Minimap
extends Control
## Round minimap (top right). Drawn in world-pixel orientation so it matches the
## quarter view; every shape is clipped to the circle.

signal open_requested

var game: Node
var radius := 70.0
const WORLD_RADIUS := 1300.0

var _circle := PackedVector2Array()
var _geometry: Array[Dictionary] = []
var _geometry_source: Array[Dictionary] = []
var _geometry_count := -1
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
	bounds = bounds.merge(Rect2(c + Vector2(0, 1.0) * u - Vector2.ONE * shadow, Vector2.ONE * shadow * 2.0))
	var stud := (COMPASS_RADIUS + 0.55) * u + aa
	var compass := c + COMPASS_OFFSET * disc_radius
	return bounds.merge(Rect2(compass - Vector2.ONE * stud, Vector2.ONE * stud * 2.0))


func marker_fits(at: Vector2, dot_radius: float) -> bool:
	# A marker's entire antialiased disc must stay inside the content, clear of the metal rim.
	return at.length() + dot_radius + maxf(1.0, radius / 64.0) <= content_radius()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta: float) -> void:
	queue_redraw()


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
	var tolerance := WORLD_RADIUS / radius * 0.25
	if is_same(game.map_shapes, _geometry_source) and game.map_shapes.size() == _geometry_count and is_equal_approx(radius, _geometry_radius) and origin.distance_squared_to(_geometry_origin) < tolerance * tolerance:
		return
	_geometry_source = game.map_shapes
	_geometry_count = game.map_shapes.size()
	_geometry_origin = origin
	_geometry_radius = radius
	geometry_rebuilds += 1
	_circle = _circle_poly(content_radius())
	_geometry.clear()
	for shape in game.map_shapes:
		var bounds: Rect2 = shape["bounds"]
		if bounds.grow(WORLD_RADIUS).has_point(origin):
			_cache_shape(shape["poly"], shape["color"], origin)


func _draw() -> void:
	if game == null or game.player == null or game.village == null:
		return
	var c := size / 2.0
	draw_set_transform(c, 0.0, Vector2.ONE)
	var origin: Vector2 = game.player.position
	_update_geometry(origin)
	draw_circle(Vector2.ZERO, radius, Color(0.07, 0.08, 0.07, 0.9))
	draw_colored_polygon(_circle, PARCHMENT)
	for shape in _geometry:
		draw_colored_polygon(shape["poly"], shape["color"])
	for marker in MapGeometry.markers(game):
		var marker_at := _to_map(marker["pos"], origin)
		var marker_radius := maxf(2.0, radius * 0.035)
		if marker_fits(marker_at, marker_radius):
			draw_circle(marker_at, marker_radius, Color(marker["color"], 0.82))
	for e in game.enemies:
		if e.dead:
			continue
		var ep := _to_map(e.position, origin)
		var enemy_radius := maxf(1.8, radius * 0.027)
		if marker_fits(ep, enemy_radius):
			draw_circle(ep, enemy_radius, Color(0.74, 0.26, 0.18, 0.88))
	# Player arrow.
	var f: float = game.player.facing
	var tip := Vector2.from_angle(f) * radius * 0.09
	var l := Vector2.from_angle(f + 2.5) * radius * 0.055
	var r := Vector2.from_angle(f - 2.5) * radius * 0.055
	draw_colored_polygon(PackedVector2Array([tip, l, Vector2.from_angle(f + PI) * 2.0, r]), Color(0.96, 0.96, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The generated metal stays within the same measured outer rim and marker inset.
	var u := radius / 64.0
	draw_arc(c + Vector2(0, 1.0) * u, radius + 0.25 * u, 0, TAU, 80, Color(0.01, 0.015, 0.01, 0.75), 2.5 * u, true)
	PresentationArt.draw_ui(self, "map", c, rim_radius(), Color(0.9, 0.86, 0.76))
	# The small compass stud sits on the rim like the approved composition.
	var compass := c + COMPASS_OFFSET * radius
	draw_circle(compass, COMPASS_RADIUS * u, Color("201d17"))
	draw_arc(compass, COMPASS_RADIUS * u, 0, TAU, 40, Color("a28b5b"), 1.1 * u, true)
	var arrow := PackedVector2Array([compass + Vector2(5.3, -0.7) * u, compass + Vector2(-4.5, -4.0) * u, compass + Vector2(-2.5, 1.0) * u, compass + Vector2(-4.0, 5.0) * u])
	draw_colored_polygon(arrow, Color("c6b17c"))


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		open_requested.emit()
		accept_event()

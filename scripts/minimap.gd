class_name Minimap
extends Control
## Round minimap (top right). Drawn in world-pixel orientation so it matches the
## quarter view; every shape is clipped to the circle.

signal open_requested

var game: Node
var radius := 70.0
const WORLD_RADIUS := 1300.0

var _circle := PackedVector2Array()
const PARCHMENT := Color("637153")


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


func _fill(poly: PackedVector2Array, color: Color, origin: Vector2) -> void:
	var local := PackedVector2Array()
	for p in poly:
		local.append(_to_map(p, origin))
	for piece in Geometry2D.intersect_polygons(local, _circle):
		if piece.size() >= 3 and absf(_area(piece)) > 1.0:
			draw_colored_polygon(piece, PARCHMENT.lerp(color, 0.52))


func _draw() -> void:
	if game == null or game.player == null or game.village == null:
		return
	_circle = _circle_poly(radius - 2.0)
	var c := size / 2.0
	draw_set_transform(c, 0.0, Vector2.ONE)
	var origin: Vector2 = game.player.position
	var v: Village = game.village
	draw_circle(Vector2.ZERO, radius, Color(0.07, 0.08, 0.07, 0.9))
	draw_colored_polygon(_circle, PARCHMENT)
	for shape in game.map_shapes:
		var bounds: Rect2 = shape["bounds"]
		if not bounds.grow(WORLD_RADIUS).has_point(origin):
			continue
		_fill(shape["poly"], shape["color"], origin)
	for marker in MapGeometry.markers(game):
		var marker_at := _to_map(marker["pos"], origin)
		if marker_at.length() < radius - 5.0:
			draw_circle(marker_at, maxf(2.0, radius * 0.035), Color(marker["color"], 0.82))
	for e in game.enemies:
		if e.dead:
			continue
		var ep := _to_map(e.position, origin)
		if ep.length() < radius - 4.0:
			draw_circle(ep, maxf(1.8, radius * 0.027), Color(0.74, 0.26, 0.18, 0.88))
	# Player arrow.
	var f: float = game.player.facing
	var tip := Vector2.from_angle(f) * radius * 0.09
	var l := Vector2.from_angle(f + 2.5) * radius * 0.055
	var r := Vector2.from_angle(f - 2.5) * radius * 0.055
	draw_colored_polygon(PackedVector2Array([tip, l, Vector2.from_angle(f + PI) * 2.0, r]), Color(0.96, 0.96, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Muted antique bronze, with fine lit edges rather than a broad gold ring.
	var u := radius / 64.0
	draw_arc(c + Vector2(0, 1.5) * u, radius + 1.0 * u, 0, TAU, 80, Color(0.01, 0.015, 0.01, 0.75), 4.5 * u, true)
	draw_arc(c, radius, 0, TAU, 80, Color("39352a"), 3.0 * u, true)
	draw_arc(c, radius - 0.7 * u, 0, TAU, 80, Color("8e7b55"), 1.2 * u, true)
	draw_arc(c, radius - 2.4 * u, 0, TAU, 80, Color(0.78, 0.72, 0.54, 0.3), 0.7 * u, true)
	# The small compass stud sits on the rim like the approved composition.
	var compass := c + Vector2(0.78, -0.40) * radius
	draw_circle(compass, 9.5 * u, Color("201d17"))
	draw_arc(compass, 9.5 * u, 0, TAU, 40, Color("a28b5b"), 1.1 * u, true)
	var arrow := PackedVector2Array([compass + Vector2(5.3, -0.7) * u, compass + Vector2(-4.5, -4.0) * u, compass + Vector2(-2.5, 1.0) * u, compass + Vector2(-4.0, 5.0) * u])
	draw_colored_polygon(arrow, Color("c6b17c"))


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		open_requested.emit()
		accept_event()

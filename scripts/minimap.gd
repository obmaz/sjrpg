class_name Minimap
extends Control
## Round minimap (top right). Drawn in world-pixel orientation so it matches the
## quarter view; every shape is clipped to the circle.

signal open_requested

var game: Node
var radius := 70.0
const WORLD_RADIUS := 1300.0

var _circle := PackedVector2Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta: float) -> void:
	queue_redraw()


func _circle_poly(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 40:
		pts.append(Vector2.from_angle(TAU * i / 40.0) * r)
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
			draw_colored_polygon(piece, color)


func _draw() -> void:
	if game == null or game.player == null or game.village == null:
		return
	_circle = _circle_poly(radius - 2.0)
	var c := size / 2.0
	draw_set_transform(c, 0.0, Vector2.ONE)
	var origin: Vector2 = game.player.position
	var v: Village = game.village
	draw_circle(Vector2.ZERO, radius, Color(0.07, 0.08, 0.07, 0.9))
	draw_colored_polygon(_circle, Color(0.30, 0.37, 0.27))
	for shape in game.map_shapes:
		_fill(shape["poly"], shape["color"], origin)
	for marker in MapGeometry.markers(game):
		var marker_at := _to_map(marker["pos"], origin)
		if marker_at.length() < radius - 5.0:
			draw_circle(marker_at, 3.5, marker["color"])
	for e in game.enemies:
		if e.dead:
			continue
		var ep := _to_map(e.position, origin)
		if ep.length() < radius - 4.0:
			draw_circle(ep, 2.6, Color(0.9, 0.2, 0.18))
	if Quests.all_done() and not GameState.boss_defeated:
		var bp := _to_map(v.boss_point, origin)
		if bp.length() < radius - 5.0:
			draw_circle(bp, 4.5, Color(1, 0.5, 0.2))
	# Player arrow.
	var f: float = game.player.facing
	var tip := Vector2.from_angle(f) * 9.0
	var l := Vector2.from_angle(f + 2.5) * 6.0
	var r := Vector2.from_angle(f - 2.5) * 6.0
	draw_colored_polygon(PackedVector2Array([tip, l, Vector2.from_angle(f + PI) * 2.0, r]), Color(0.96, 0.96, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Frame.
	draw_arc(c, radius, 0, TAU, 56, Color(0.12, 0.1, 0.07), 6.0, true)
	draw_arc(c, radius - 1.0, 0, TAU, 56, Color(0.62, 0.45, 0.24), 3.0, true)
	draw_arc(c, radius - 5.0, 0, TAU, 56, Color(0.9, 0.78, 0.5, 0.35), 1.5, true)


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		open_requested.emit()
		accept_event()

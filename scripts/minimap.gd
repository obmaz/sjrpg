class_name Minimap
extends Control
## Round minimap (top right). Drawn in world-pixel orientation so it matches the
## quarter view; every shape is clipped to the circle.

var game: Node
var radius := 70.0
const WORLD_RADIUS := 1300.0

var _circle := PackedVector2Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _circle_poly(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 40:
		pts.append(Vector2.from_angle(TAU * i / 40.0) * r)
	return pts


func _to_map(world: Vector2, origin: Vector2) -> Vector2:
	return (world - origin) * (radius / WORLD_RADIUS)


func _fill(poly: PackedVector2Array, color: Color, origin: Vector2) -> void:
	var local := PackedVector2Array()
	for p in poly:
		local.append(_to_map(p, origin))
	for piece in Geometry2D.intersect_polygons(local, _circle):
		if piece.size() >= 3:
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
	_fill(v.map_water, Color(0.25, 0.5, 0.62), origin)
	_fill(v.bridge.deck_polygon(), Color(0.62, 0.55, 0.42), origin)
	_fill(v.safe_zone, Color(0.52, 0.52, 0.47), origin)
	var inner: Array = Geometry2D.offset_polygon(v.safe_zone, -22.0)
	if inner.size() > 0:
		_fill(inner[0], Color(0.40, 0.46, 0.34), origin)
	# Paved cross roads inside the town.
	for road in [[Vector2(0.04, 0.5), Vector2(0.94, 0.5)], [Vector2(0.5, 0.10), Vector2(0.5, 0.90)]]:
		var a := v.point(road[0])
		var b := v.point(road[1])
		var n := (b - a).orthogonal().normalized() * 55.0
		_fill(PackedVector2Array([a + n, b + n, b - n, a - n]), Color(0.58, 0.58, 0.55), origin)
	# Wall ring: one thin quad per wall edge (a hollow polygon would fill solid).
	for i in v.safe_zone.size():
		var a: Vector2 = v.safe_zone[i]
		var b: Vector2 = v.safe_zone[(i + 1) % v.safe_zone.size()]
		var n := (b - a).orthogonal().normalized() * 26.0
		_fill(PackedVector2Array([a + n, b + n, b - n, a - n]), Color(0.22, 0.21, 0.2), origin)
	# Buildings.
	for key in v.buildings:
		var b: IsoSprite = v.buildings[key]
		var p := _to_map(b.position, origin)
		if p.length() < radius - 6.0:
			draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(0.78, 0.7, 0.55))
	var pp := _to_map(v.portal_point, origin)
	if pp.length() < radius - 5.0:
		draw_circle(pp, 3.5, Color(0.4, 0.9, 1.0))
	for e in game.enemies:
		if e.dead:
			continue
		var ep := _to_map(e.position, origin)
		if ep.length() < radius - 4.0:
			draw_circle(ep, 2.6, Color(0.9, 0.2, 0.18))
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

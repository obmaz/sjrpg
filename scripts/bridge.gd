class_name Bridge
extends Node2D
## 동문 밖 돌다리 (assets/source/bridge-new.png). The deck axis climbs at -30° on
## screen; the near parapet and corner posts redraw above actors, the rest sits
## below them, so heroes walk on the deck and behind the front rail.

const SOURCE := Vector2(1536, 1024)
const DECK_CENTER := Vector2(772.5, 507.5)
const DECK_SPAN := 1080.0
const AXIS_START := Vector2(232.5, 820)
const AXIS_END := Vector2(1312.5, 195)
const BANK_CLEARANCE := 100.0
const DECK := [Vector2(110, 750), Vector2(1190, 125), Vector2(1435, 265), Vector2(355, 890)]
## The foreground starts at the actual coping top, above the occluded deck-floor edge.
const FRONT_TOP := [Vector2(410, 805), Vector2(1400, 235)]
const POSTS := [
	[Vector2(326, 815), Vector2(369, 788), Vector2(411, 815), Vector2(411, 901), Vector2(361, 930)],
	[Vector2(1390, 196), Vector2(1430, 174), Vector2(1475, 197), Vector2(1475, 275), Vector2(1420, 300)],
]
const ABUTMENTS := [
	[Vector2(360, 915), Vector2(414, 875), Vector2(730, 695), Vector2(700, 820), Vector2(400, 1000)],
	[Vector2(1210, 425), Vector2(1480, 260), Vector2(1500, 540), Vector2(1220, 660)],
]

static var texture: Texture2D

var k := 1.0  # world pixels per source pixel
var front: Node2D


static func axis_direction() -> Vector2:
	return (AXIS_END - AXIS_START).normalized()


static func front_edge(x: float) -> float:
	var slope: float = (FRONT_TOP[1].y - FRONT_TOP[0].y) / (FRONT_TOP[1].x - FRONT_TOP[0].x)
	return FRONT_TOP[0].y + (x - FRONT_TOP[0].x) * slope


## `forecourt` is the road end on the near bank in world pixels.
func setup(forecourt: Vector2) -> Bridge:
	if texture == null:
		texture = load("res://assets/art/village/bridge.webp")
	k = 600.0 / DECK_SPAN * Iso.S
	position = forecourt - (AXIS_START - DECK_CENTER) * k + axis_direction() * BANK_CLEARANCE * Iso.S
	z_index = -2
	front = _Front.new()
	front.bridge = self
	front.z_index = 3  # relative to this node: above actors
	add_child(front)
	return self


func point(pixel: Vector2) -> Vector2:
	return position + (pixel - DECK_CENTER) * k


func axis_point(t: float) -> Vector2:
	return point(AXIS_START.lerp(AXIS_END, t))


func local(pixel: Vector2) -> Vector2:
	return (pixel - DECK_CENTER) * k


func deck_polygon() -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in DECK:
		out.append(point(p))
	return out


## Parapets along both long deck edges and the two end abutments.
func solids() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for pair in [[DECK[0], DECK[1]], [DECK[3], DECK[2]]]:
		var a: Vector2 = pair[0]
		var b: Vector2 = pair[1]
		var n := (b - a).orthogonal().normalized() * 20.0
		out.append(PackedVector2Array([point(a + n), point(b + n), point(b - n), point(a - n)]))
	for poly in ABUTMENTS:
		var pts := PackedVector2Array()
		for p in poly:
			pts.append(point(p))
		out.append(pts)
	return out


func _draw() -> void:
	draw_texture_rect(texture, Rect2(local(Vector2.ZERO), SOURCE * k), false)


class _Front:
	extends Node2D
	var bridge: Bridge

	func _draw() -> void:
		var size := Bridge.SOURCE
		var band := PackedVector2Array([
			Vector2(0, Bridge.front_edge(0.0) - 2.0), Vector2(size.x, Bridge.front_edge(size.x) - 2.0),
			Vector2(size.x, size.y + 400.0), Vector2(0, size.y + 400.0),
		])
		var image := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
		var shapes: Array = []
		for piece in Geometry2D.intersect_polygons(band, image):
			shapes.append(piece)
		for post in Bridge.POSTS:
			shapes.append(post)
		for shape in shapes:
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			for p in shape:
				pts.append(bridge.local(p))
				uvs.append(p / size)
			draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, Bridge.texture)

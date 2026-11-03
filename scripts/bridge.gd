class_name Bridge
extends Node2D
## 동문 밖 돌다리 (원본 QuarterViewBridgeArt). The deck axis climbs at -30° on
## screen; the near parapet and corner posts redraw above actors, the rest sits
## below them, so heroes walk on the deck and behind the front rail.

const SOURCE := Vector2(1536, 1024)
const DECK_CENTER := Vector2(812, 490.5)
const DECK_SPAN := 1096.0
const AXIS_START := Vector2(264, 806.5)
const AXIS_END := Vector2(1360, 174.5)
const BANK_CLEARANCE := 100.0
const SLOPE := -632.0 / 1096.0
const DECK := [Vector2(114, 720), Vector2(1210, 88), Vector2(1510, 261), Vector2(414, 893)]
const POSTS := [
	[Vector2(335, 835), Vector2(375, 803), Vector2(412, 828), Vector2(412, 900), Vector2(360, 925)],
	[Vector2(1412, 205), Vector2(1450, 173), Vector2(1487, 199), Vector2(1487, 272), Vector2(1435, 296)],
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
	return 893.0 + (x - 414.0) * SLOPE


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
			Vector2(0, Bridge.front_edge(0.0) - 18.0), Vector2(size.x, Bridge.front_edge(size.x) - 18.0),
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

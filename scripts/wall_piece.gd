class_name WallPiece
extends Node2D
## One vertical strip of a crenellated wall span (assets/source/wall-seg-a|b.png, packed in walls.webp). The art is generated
## with the front face's bottom edge on a ±30° ground axis; a span maps that edge onto two ground points, so consecutive
## spans (same art, whole battlement periods) join without a seam. Each strip depth-sorts by its own point on the front
## bottom edge, so an actor walking beside the wall is never covered by the far end of the span.

var _texture: Texture2D
var _src: Rect2  # atlas pixels of this strip
var _local: Rect2  # same strip in span-local art pixels
var _xf: Transform2D


## `def` is data["wall"]["segs"][a|b]; `sa`/`sb` are the span's front-bottom end points in world pixels (sa.x < sb.x).
static func add_span(parent: Node2D, tex: Texture2D, def: Dictionary, strip_px: float, sa: Vector2, sb: Vector2) -> void:
	var src: Array = def["source"]
	var full_width := float(src[2])
	var k: float = def["k"]
	var gvs: float = def.get("gvs", 1.0)
	# Preserve horizontal/vertical scale; clip the final repeat rather than stretching its corners.
	var w := minf(full_width, (sb.x - sa.x) / k)
	var y0: float = def["y0"]
	var y1: float = def["y1"]
	# Art pixel (x, y) → world: along the front edge by x/w, then straight up/down from that edge by the height above it.
	var x_axis := (sb - sa) / w + Vector2(0.0, -(y1 - y0) / full_width * k * gvs)
	var origin := sa - Vector2(0.0, y0 * k * gvs)
	var x := 0.0
	while x < w - 0.01:
		var x1 := minf(x + strip_px, w)
		var piece := WallPiece.new()
		piece._texture = tex
		piece._src = Rect2(float(src[0]) + x, float(src[1]), x1 - x, float(src[3]))
		piece._local = Rect2(x, float(src[1]), x1 - x, float(src[3]))
		piece.position = sa + (sb - sa) * ((x + x1) * 0.5 / w)
		piece._xf = Transform2D(x_axis, Vector2(0.0, k * gvs), origin - piece.position)
		parent.add_child(piece)
		x = x1


func _draw() -> void:
	draw_set_transform_matrix(_xf)
	draw_texture_rect_region(_texture, _local, _src)


func _ready() -> void:
	var transform := _xf
	transform.origin += global_position
	WorldOcclusion.attach(self, WorldOcclusion.bounds_of(_local, transform))

class_name ActorSprite
extends Node2D
## Draws one atlas frame with its feet anchor at the node origin.

var atlas: ActorAtlas
var frame := 0
var body_height := 64.0
var flash := 0.0
var tint := Color.WHITE
var shadow := true


func set_frame(a: ActorAtlas, index: int) -> void:
	if a != atlas or index != frame:
		atlas = a
		frame = index
		queue_redraw()


func _process(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 4.0)
		queue_redraw()


func _draw() -> void:
	if shadow:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.42))
		draw_circle(Vector2.ZERO, body_height * 0.36, Color(0, 0, 0, 0.28))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if atlas == null or atlas.texture == null or frame >= atlas.regions.size():
		return
	var scale_factor := body_height / atlas.ref_height
	var region := atlas.regions[frame]
	var dest := Rect2(-atlas.anchors[frame] * scale_factor, region.size * scale_factor)
	var color := tint
	if flash > 0.0:
		color = tint.lerp(Color(1.0, 0.45, 0.4, tint.a), flash)
	draw_texture_rect_region(atlas.texture, dest, region, color)

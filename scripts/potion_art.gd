class_name PotionArt
extends RefCounted
## Potion belt art exactly as the Flutter PotionBelt builds it:
##  - healing: cinematic-interface cell 5 (row 1, col 1), inset 6, clipped to a circle
##  - energy:  shared atlas cell (col 3, row 1) with the original blue colour matrix

const CELL := Vector2(256, 256)
const INSET := 6.0

static var _cinematic: Texture2D
static var _atlas_blue: ImageTexture


static func healing_texture() -> Texture2D:
	if _cinematic == null:
		_cinematic = load("res://assets/art/hud/icons.webp")
	return _cinematic


## Source rect of the healing flask cell (index 5 of the 4x3 sheet), inset like the original.
static func healing_rect() -> Rect2:
	var col := 1
	var row := 1
	return Rect2(Vector2(col, row) * CELL + Vector2(INSET, INSET), CELL - Vector2(INSET, INSET) * 2.0)


static func energy_texture() -> Texture2D:
	if _atlas_blue == null:
		var tex: Texture2D = load("res://assets/art/hud/atlas.webp")
		var img := tex.get_image()
		var cell := img.get_width() / 4
		var part := img.get_region(Rect2i(cell * 3, cell, cell, cell))
		part.convert(Image.FORMAT_RGBA8)
		# ColorFilter.matrix from PotionPainter(blue: true): rows give new R, G, B.
		for y in part.get_height():
			for x in part.get_width():
				var c := part.get_pixel(x, y)
				part.set_pixel(x, y, Color(
					clampf(c.r * 0.3 + c.g * 0.25 + c.b * 0.45, 0, 1),
					clampf(c.r * 0.3 + c.g * 0.4 + c.b * 0.3, 0, 1),
					clampf(c.r * 0.7 + c.g * 0.2 + c.b * 0.1, 0, 1),
					c.a))
		_atlas_blue = ImageTexture.create_from_image(part)
	return _atlas_blue


## One potion button: dark disc, grey rim, 1.16x-scaled icon clipped to a circle
## and the dark count badge at the bottom-right (PotionBelt._potion).
static func draw(canvas: CanvasItem, center: Vector2, radius: float, energy: bool, count: int, pressed := false) -> void:
	canvas.draw_circle(center, radius, Color(0.043, 0.067, 0.09, 0.6))
	var inner := radius - 2.0
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var tex: Texture2D
	var src: Rect2
	if energy:
		tex = energy_texture()
		src = Rect2(Vector2.ZERO, tex.get_size())
	else:
		tex = healing_texture()
		src = healing_rect()
	var size := tex.get_size()
	var mid := src.get_center()
	var half := src.size * 0.5 / 1.16
	for i in 40:
		var d := Vector2.from_angle(TAU * i / 40.0)
		pts.append(center + d * inner)
		uvs.append((mid + d * half) / size)
	canvas.draw_polygon(pts, PackedColorArray([Color(1, 1, 1, 1.0 if not pressed else 0.8)]), uvs, tex)
	canvas.draw_arc(center, radius - 0.6, 0, TAU, 40, Color(0.647, 0.694, 0.71), 1.5, true)
	var badge := Rect2(center + Vector2(radius * 0.18, radius * 0.38), Vector2(radius * 0.8, radius * 0.62))
	canvas.draw_rect(badge, Color(0.06, 0.14, 0.13), true)
	canvas.draw_string(UiKit.BOLD_FONT, badge.position + Vector2(0, badge.size.y * 0.8), str(count), HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, int(radius * 0.52), Color(0.93, 0.89, 0.8))

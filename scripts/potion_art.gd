class_name PotionArt
extends RefCounted
## Two illustrated glass vials over fine bronze sockets. Counts remain outside
## the lower-right rim so a dark block never covers the potion illustration.

static var _sheet: Texture2D


static func texture() -> Texture2D:
	if _sheet == null:
		_sheet = load("res://assets/art/hud/potions.webp")
	return _sheet


static func draw(canvas: CanvasItem, center: Vector2, radius: float, energy: bool, count: int, pressed := false) -> void:
	var u := radius / 30.0
	canvas.draw_circle(center + Vector2(0, u), radius + u, Color(0, 0, 0, 0.32))
	canvas.draw_circle(center, radius, Color(0.05, 0.043, 0.032, 0.78))
	canvas.draw_arc(center, radius + 0.4 * u, 0, TAU, 64, Color(0.18, 0.15, 0.1, 0.95), 1.4 * u, true)
	canvas.draw_arc(center, radius - 0.6 * u, 0, TAU, 64, Color(0.56, 0.46, 0.29, 0.8), 0.8 * u, true)
	canvas.draw_arc(center, radius - 2.0 * u, PI * 1.1, PI * 1.7, 24, Color(0.84, 0.75, 0.5, 0.42), 0.7 * u, true)
	var tex := texture()
	var cell := Vector2(tex.get_width() / 2.0, tex.get_height())
	var source := Rect2(Vector2(cell.x if energy else 0.0, 0.0), cell)
	var destination := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	canvas.draw_texture_rect_region(tex, destination, source, Color(0.84, 0.84, 0.84) if pressed else Color.WHITE)
	if count >= 0:
		HudArt.text_outlined(canvas, str(count), center + Vector2(radius * 0.45, radius * 0.9), radius * 0.6, int(17.0 * u), Color(0.92, 0.87, 0.75))

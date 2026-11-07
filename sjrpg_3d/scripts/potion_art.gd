class_name PotionArt
extends RefCounted
## Painted vials with measured, high-contrast count ribbons inside their input circles.

static var _sheet: Texture2D


static func texture() -> Texture2D:
	if _sheet == null:
		_sheet = UiToneArt.icons()
	return _sheet


static func draw(canvas: CanvasItem, center: Vector2, radius: float, energy: bool, count: int, pressed := false, hit_radius := -1.0) -> void:
	var u := radius / 30.0
	canvas.draw_circle(center + Vector2(0, u), radius + u, Color(0, 0, 0, 0.32))
	canvas.draw_circle(center, radius, Color(0.05, 0.043, 0.032, 0.78))
	canvas.draw_arc(center, radius + 0.4 * u, 0, TAU, 64, Color(0.18, 0.15, 0.1, 0.95), 1.4 * u, true)
	canvas.draw_arc(center, radius - 0.6 * u, 0, TAU, 64, Color(0.56, 0.46, 0.29, 0.8), 0.8 * u, true)
	canvas.draw_arc(center, radius - 2.0 * u, PI * 1.1, PI * 1.7, 24, Color(0.84, 0.75, 0.5, 0.42), 0.7 * u, true)
	UiToneArt.draw_icon(canvas, "mp" if energy else "hp", center, radius, Color(0.84, 0.84, 0.84) if pressed else Color.WHITE)
	if count >= 0:
		var geometry := count_geometry(center, radius, count, css_scale(canvas), hit_radius)
		var rect: Rect2 = geometry["rect"]
		canvas.draw_style_box(UiKit.panel_style(UiToneArt.CHARCOAL, UiToneArt.BRONZE.darkened(0.25), 4), rect)
		HudArt.text_in_rect(canvas, str(geometry["text"]), rect.grow(-2.0 * u), int(geometry["font_size"]), UiToneArt.IVORY)


static func css_scale(canvas: CanvasItem) -> float:
	if OS.has_feature("web"):
		var width: Variant = JavaScriptBridge.eval("window.innerWidth", true)
		if (width is float or width is int) and float(width) > 0.0:
			return canvas.get_viewport().get_visible_rect().size.x / float(width)
	if DisplayServer.get_name() == "headless":
		return 1.0
	return canvas.get_viewport().get_visible_rect().size.x / maxf(1.0, float(canvas.get_window().size.x))


static func count_geometry(center: Vector2, radius: float, count: int, scale: float, hit_radius := -1.0) -> Dictionary:
	var u := radius / 30.0
	var pixels := maxi(roundi(17.0 * u), ceili(12.0 * scale))
	# Keep unusually large inventories readable without changing the authoritative quantity.
	var text := "999+" if count > 999 else str(maxi(count, 0))
	var size := Vector2(HudArt.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x + 8.0 * u, HudArt.FONT.get_height(pixels) + 4.0 * u)
	var target := hit_radius if hit_radius > 0.0 else maxf(radius, 22.0 * scale)
	var limit := maxf(1.0, target - 2.0 * u)
	var maximum_y := maxf(0.0, sqrt(maxf(0.0, limit * limit - size.x * size.x * 0.25)) - size.y * 0.5)
	var offset := minf(radius * 0.95, maximum_y)
	return {"text": text, "font_size": pixels, "rect": Rect2(center + Vector2(0, offset) - size * 0.5, size), "target_radius": target}

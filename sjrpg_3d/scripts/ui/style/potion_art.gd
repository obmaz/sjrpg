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
	canvas.draw_circle(center + Vector2(0, u), radius + 0.5 * u, Color(0, 0, 0, 0.22))
	UiToneArt.draw_icon(canvas, "mp" if energy else "hp", center, radius, Color(0.84, 0.84, 0.84) if pressed else Color.WHITE)
	if count >= 0:
		var geometry := count_geometry(center, radius, count, css_scale(canvas), hit_radius)
		var rect: Rect2 = geometry["rect"]
		var skin := StyleBoxFlat.new()
		skin.bg_color = Color(UiToneArt.CHARCOAL, 0.96)
		skin.border_color = Color(UiToneArt.BRONZE, 0.7)
		skin.set_border_width_all(1)
		skin.set_corner_radius_all(3)
		canvas.draw_style_box(skin, rect)
		HudArt.text_in_rect(canvas, str(geometry["text"]), rect.grow(-u), int(geometry["font_size"]), UiToneArt.IVORY)


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
	var size := Vector2(HudArt.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x + 4.0 * u, HudArt.FONT.get_height(pixels) + 2.0 * u)
	var target := hit_radius if hit_radius > 0.0 else maxf(radius, 22.0 * scale)
	var limit := maxf(1.0, target - 2.0 * u)
	# Move the compact count diagonally off the vial centre. Solve the far-corner
	# circle constraint so even long quantities remain inside the existing input.
	var half := size * 0.5
	var diagonal := maxf(0.0, (sqrt(maxf(0.0, 2.0 * limit * limit - pow(half.x - half.y, 2.0))) - half.x - half.y) * 0.5)
	var offset := minf(radius * 0.7, diagonal)
	return {"text": text, "font_size": pixels, "rect": Rect2(center + Vector2.ONE * offset - half, size), "target_radius": target}

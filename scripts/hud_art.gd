class_name HudArt
extends RefCounted
## Shared HUD drawing in the reference style: dark bronze-rimmed round plaques
## from the original sheets (cinematic-interface.webp), slanted bars and rune rings.

const BRONZE := Color(0.62, 0.45, 0.24)
const BRONZE_DARK := Color(0.18, 0.12, 0.07)
const FONT := UiKit.BOLD_FONT

static var _sheet: Texture2D
static var _rects: Dictionary
static var _portraits := {}


static func _load() -> void:
	if _sheet != null:
		return
	_sheet = load("res://assets/art/hud/icons.webp")
	var data: Dictionary = JSON.parse_string(FileAccess.open("res://assets/data/hud_icons.json", FileAccess.READ).get_as_text())
	_rects = data["cinematic"]


## Draws a bronze-rimmed plaque icon (backpack, book, scroll, gear, potion, dodge ...).
static func plaque(canvas: CanvasItem, name: String, center: Vector2, radius: float, tint := Color.WHITE) -> void:
	_load()
	var r: Array = _rects[name]
	var src := Rect2(r[0], r[1], r[2], r[3])
	canvas.draw_texture_rect_region(_sheet, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), src, tint)


static func portrait(cls: String) -> Texture2D:
	if not _portraits.has(cls):
		_portraits[cls] = load("res://assets/art/hud/portrait-warrior.webp" if cls == "warrior" else "res://assets/art/hud/portrait-mage.png")
	return _portraits[cls]


## Glowing ring for an equipped combat button (blue for casters, amber for fighters).
static func glow_ring(canvas: CanvasItem, center: Vector2, radius: float, color: Color, strength := 1.0) -> void:
	canvas.draw_arc(center, radius + 5.0, 0, TAU, 56, Color(color, 0.22 * strength), 10.0, true)
	canvas.draw_arc(center, radius + 1.5, 0, TAU, 56, Color(color, 0.85 * strength), 3.0, true)
	canvas.draw_arc(center, radius - 3.0, 0, TAU, 56, Color(BRONZE, 0.9), 3.0, true)


static func text_outlined(canvas: CanvasItem, text: String, at: Vector2, width: float, size: int, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	canvas.draw_string_outline(FONT, at, text, align, width, size, maxi(3, size / 4), Color(0, 0, 0, 0.9))
	canvas.draw_string(FONT, at, text, align, width, size, color)


## Slanted bar (parallelogram, right end cut like the reference).
static func slanted_bar(canvas: CanvasItem, rect: Rect2, ratio: float, fill_top: Color, fill_bottom: Color, back: Color, slant := 10.0) -> void:
	var back_poly := _bar_poly(rect, 1.0, slant)
	canvas.draw_colored_polygon(back_poly, back)
	ratio = clampf(ratio, 0.0, 1.0)
	if ratio > 0.0:
		var fill := _bar_poly(rect, ratio, slant)
		canvas.draw_colored_polygon(fill, fill_bottom)
		var top := _bar_poly(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.5)), ratio, slant * 0.5)
		canvas.draw_colored_polygon(top, Color(fill_top, 0.75))
	canvas.draw_polyline(PackedVector2Array([back_poly[0], back_poly[1], back_poly[2], back_poly[3], back_poly[0]]), Color(0.5, 0.5, 0.48, 0.9), 2.0, true)


static func _bar_poly(rect: Rect2, ratio: float, slant: float) -> PackedVector2Array:
	var w := rect.size.x * ratio
	var s := slant if ratio >= 0.999 else minf(slant, w)
	return PackedVector2Array([
		rect.position,
		rect.position + Vector2(w, 0),
		rect.position + Vector2(maxf(0.0, w - s), rect.size.y),
		rect.position + Vector2(0, rect.size.y),
	])


static func fmt(n: float) -> String:
	var s := str(roundi(n))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out

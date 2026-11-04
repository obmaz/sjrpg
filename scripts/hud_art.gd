class_name HudArt
extends RefCounted
## Shared HUD drawing in the reference style: dark bronze-rimmed round plaques
## from the original sheets (cinematic-interface.webp), slanted bars and rune rings.

const FONT := preload("res://assets/fonts/NanumGothic-Regular.ttf")

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


## Same source icon, clipped to its medallion so square atlas corners never show.
static func round_plaque(canvas: CanvasItem, name: String, center: Vector2, radius: float, tint := Color.WHITE) -> void:
	_load()
	var r: Array = _rects[name]
	var source := Rect2(r[0], r[1], r[2], r[3])
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in 64:
		var direction := Vector2.from_angle(TAU * i / 64.0)
		points.append(center + direction * radius)
		uvs.append((source.position + source.size * (Vector2.ONE + direction) * 0.5) / _sheet.get_size())
	canvas.draw_polygon(points, PackedColorArray([tint]), uvs, _sheet)


## Class-specific portraits are cover-fit inside the shared metal medallion.
static func portrait(cls: String) -> Texture2D:
	if not _portraits.has(cls):
		_portraits[cls] = load("res://assets/art/hud/portrait-warrior.webp" if cls == "warrior" else "res://assets/art/hud/portrait-mage.webp")
	return _portraits[cls]


static func portrait_uv(_cls: String) -> Rect2:
	return Rect2(0, 0, 1, 1)


static func text_outlined(canvas: CanvasItem, text: String, at: Vector2, width: float, size: int, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	canvas.draw_string_outline(FONT, at + Vector2(0, 0.6), text, align, width, size, maxi(1, size / 16), Color(0.015, 0.012, 0.01, 0.78))
	canvas.draw_string(FONT, at, text, align, width, size, color)


## Slanted bar (parallelogram, right end cut like the reference).
static func slanted_bar(canvas: CanvasItem, rect: Rect2, ratio: float, fill_top: Color, fill_bottom: Color, back: Color, slant := 10.0) -> void:
	var back_poly := _bar_poly(rect, 1.0, slant)
	canvas.draw_colored_polygon(back_poly, back)
	ratio = clampf(ratio, 0.0, 1.0)
	if ratio > 0.0:
		var fill := _bar_poly(rect, ratio, slant)
		canvas.draw_polygon(fill, PackedColorArray([fill_top, fill_top, fill_bottom, fill_bottom]))
		var end := rect.position + Vector2(rect.size.x * ratio - (1.0 if ratio >= 0.999 else 0.0), 1.0)
		canvas.draw_line(rect.position + Vector2(0, 1.0), end, Color(fill_top.lightened(0.45), 0.58), 0.8, true)
	canvas.draw_polyline(PackedVector2Array([back_poly[0], back_poly[1], back_poly[2], back_poly[3], back_poly[0]]), Color(0.54, 0.49, 0.4, 0.95), 0.9, true)
	canvas.draw_line(back_poly[3] + Vector2(0, 1.0), back_poly[2] + Vector2(0, 1.0), Color(0.015, 0.012, 0.012, 0.9), 1.0, true)


static func _bar_poly(rect: Rect2, ratio: float, slant: float) -> PackedVector2Array:
	var w := rect.size.x * ratio
	var s := slant if ratio >= 0.999 else 0.0
	return PackedVector2Array([
		rect.position,
		rect.position + Vector2(w, 0),
		rect.position + Vector2(maxf(0.0, w - s), rect.size.y),
		rect.position + Vector2(0, rect.size.y),
	])


## Original CombatUnit: health/damage ×100, resources ×10 (rounded up).
static func stat(n: float) -> String:
	return fmt(ceilf(n * 100.0))


static func res(n: float) -> String:
	return fmt(ceilf(n * 10.0))


static func fmt(n: float) -> String:
	var s := str(roundi(n))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out

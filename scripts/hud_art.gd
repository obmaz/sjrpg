class_name HudArt
extends RefCounted
## Shared HUD drawing in the reference style: dark bronze-rimmed round plaques
## from the original sheets (cinematic-interface.webp), slanted bars and rune rings.

const FONT := preload("res://assets/fonts/NanumGothic-Regular.ttf")

static var _sheet: Texture2D
static var _rects: Dictionary
static var _portraits := {}
static var _level_badge: Texture2D


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


static func level_badge() -> Texture2D:
	if _level_badge == null:
		_level_badge = load("res://assets/art/hud/level-badge.webp")
	return _level_badge


static func text_outlined(canvas: CanvasItem, text: String, at: Vector2, width: float, size: int, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	canvas.draw_string_outline(FONT, at + Vector2(0, 0.6), text, align, width, size, maxi(1, size / 16), Color(0.015, 0.012, 0.01, 0.78))
	canvas.draw_string(FONT, at, text, align, width, size, color)


## Slanted bar (parallelogram, right end cut like the reference).
static func slanted_bar(canvas: CanvasItem, rect: Rect2, ratio: float, fill_top: Color, fill_bottom: Color, back: Color, slant := 10.0, visible_start := -1.0, trail := -1.0) -> void:
	var back_poly := _bar_poly(rect, 1.0, slant, visible_start)
	# The shared ribbon owns the curved portrait join; meters never paint rectangular left caps.
	canvas.draw_colored_polygon(back_poly, back)
	ratio = clampf(ratio, 0.0, 1.0)
	if trail > ratio + 0.001:
		canvas.draw_colored_polygon(_bar_poly(rect, clampf(trail, 0, 1), slant, visible_start), Color(0.84, 0.57, 0.32, 0.7))
	if ratio > 0.0:
		var fill := _bar_poly(rect, ratio, slant, visible_start)
		var colors := PackedColorArray()
		for p in fill:
			colors.append(fill_top.lerp(fill_bottom, (p.y - rect.position.y) / rect.size.y))
		canvas.draw_polygon(fill, colors)
		var end := Vector2(fill[1].x - (1.0 if ratio >= 0.999 else 0.0), rect.position.y + 1.0)
		canvas.draw_line(fill[0] + Vector2(0, 1.0), end, Color(fill_top.lightened(0.45), 0.58), 0.8, true)
	canvas.draw_polyline(PackedVector2Array([back_poly[0], back_poly[1], back_poly[2], back_poly[3], back_poly[0]]), Color(0.54, 0.49, 0.4, 0.95), 0.9, true)
	canvas.draw_line(back_poly[3] + Vector2(0, 1.0), back_poly[2] + Vector2(0, 1.0), Color(0.015, 0.012, 0.012, 0.9), 1.0, true)


## A single ribbon follows the portrait's right rim instead of exposing square
## left corners above/below it. The first four vertices retain the bevel corners.
static func joined_ribbon(center: Vector2, radius: float, top: float, right: float, bottom: float, slope: float, overlap: float) -> PackedVector2Array:
	var at := func(y: float) -> Vector2:
		var dy := y - center.y
		var chord := sqrt(maxf(0.0, radius * radius - dy * dy))
		return Vector2(center.x + maxf(0.0, chord - overlap), y)
	var points := PackedVector2Array([at.call(top), Vector2(right, top), Vector2(right - (bottom - top) * slope, bottom), at.call(bottom)])
	for step in range(1, 16):
		points.append(at.call(lerpf(bottom, top, float(step) / 16.0)))
	return points


static func fill_end(rect: Rect2, ratio: float, visible_start := -1.0) -> float:
	var start := rect.position.x if visible_start < 0 else clampf(visible_start, rect.position.x, rect.end.x)
	return lerpf(start, rect.end.x, clampf(ratio, 0.0, 1.0))


static func _bar_poly(rect: Rect2, ratio: float, slant: float, visible_start := -1.0) -> PackedVector2Array:
	if ratio <= 0.0:
		return PackedVector2Array()
	var cut := fill_end(rect, ratio, visible_start)
	var left := rect.position.x if visible_start < 0 else clampf(visible_start, rect.position.x, rect.end.x)
	var bottom := rect.end.x - minf(slant, rect.size.x)
	var points := PackedVector2Array([Vector2(left, rect.position.y), Vector2(cut, rect.position.y)])
	# Intersect the horizontal fill with the full frame's slope. Near-full fills
	# need a fifth corner; a rectangle would spill out under the beveled end.
	if cut > bottom and ratio < 1.0 and slant > 0.0:
		points.append(Vector2(cut, rect.position.y + (rect.end.x - cut) / slant * rect.size.y))
	points.append(Vector2(minf(cut, bottom), rect.end.y))
	points.append(Vector2(left, rect.end.y))
	return points


static func fit_text_size(text: String, rect: Rect2, preferred: int) -> int:
	var size := maxi(1, preferred)
	while size > 1 and (FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > rect.size.x or FONT.get_height(size) > rect.size.y):
		size -= 1
	return size


static func text_in_rect(canvas: CanvasItem, text: String, rect: Rect2, preferred: int, color: Color) -> void:
	var size := fit_text_size(text, rect, preferred)
	var baseline := rect.position.y + (rect.size.y - FONT.get_height(size)) * 0.5 + FONT.get_ascent(size)
	text_outlined(canvas, text, Vector2(rect.position.x, baseline), rect.size.x, size, color)


static func elide(text: String, width: float, size: int) -> String:
	if FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
		return text
	var low := 0
	var high := text.length()
	while low < high:
		var middle := (low + high + 1) / 2
		if FONT.get_string_size(text.left(middle) + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
			low = middle
		else:
			high = middle - 1
	return text.left(low) + "…" if FONT.get_string_size("…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width else ""


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

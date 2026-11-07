class_name HudArt
extends RefCounted
## Shared HUD drawing in the reference style: dark bronze-rimmed round plaques
## from the original sheets (cinematic-interface.webp), slanted bars and rune rings.

const FONT := preload("res://assets/fonts/NanumGothic-Regular.ttf")
const BAR_STEPS := 16

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
		_portraits[cls] = UiToneArt.portraits()
	return _portraits[cls]


static func portrait_uv(cls: String) -> Rect2:
	return UiToneArt.portrait_uv(cls)


static func level_badge() -> Texture2D:
	if _level_badge == null:
		_level_badge = load("res://assets/art/hud/level-badge.webp")
	return _level_badge


static func text_outlined(canvas: CanvasItem, text: String, at: Vector2, width: float, size: int, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	canvas.draw_string_outline(FONT, at + Vector2(0, 0.6), text, align, width, size, maxi(1, size / 16), Color(0.015, 0.012, 0.01, 0.78))
	canvas.draw_string(FONT, at, text, align, width, size, color)


## Slanted bar (parallelogram, right end cut like the reference).
static func slanted_bar(canvas: CanvasItem, rect: Rect2, ratio: float, fill_top: Color, fill_bottom: Color, back: Color, slant: float, center: Vector2, radius: float, trail := -1.0) -> void:
	var back_poly := _bar_poly(rect, 1.0, slant, center, radius)
	canvas.draw_colored_polygon(back_poly, back)
	_draw_join_edge(canvas, back_poly, back, back)
	ratio = clampf(ratio, 0.0, 1.0)
	if trail > ratio + 0.001:
		var trail_poly := _bar_poly(rect, clampf(trail, 0, 1), slant, center, radius)
		if not trail_poly.is_empty():
			var trail_color := Color(0.84, 0.57, 0.32, 0.7)
			canvas.draw_colored_polygon(trail_poly, trail_color)
			_draw_join_edge(canvas, trail_poly, trail_color, trail_color)
	var fill := _bar_poly(rect, ratio, slant, center, radius)
	if not fill.is_empty():
		var colors := PackedColorArray()
		for p in fill:
			colors.append(fill_top.lerp(fill_bottom, (p.y - rect.position.y) / rect.size.y))
		canvas.draw_polygon(fill, colors)
		_draw_join_edge(canvas, fill, fill_top, fill_bottom)
		var end := Vector2(fill[1].x - (1.0 if ratio >= 0.999 else 0.0), rect.position.y + 1.0)
		canvas.draw_line(fill[0] + Vector2(0, 1.0), end, Color(fill_top.lightened(0.45), 0.58), 0.8, true)
	var outline := bar_outline(back_poly)
	# The portrait ring owns the curved edge; only top/right/bottom have a second metal stroke.
	canvas.draw_polyline(outline, Color(0.54, 0.49, 0.4, 0.95), 0.9, true)
	canvas.draw_line(outline[-1] + Vector2(0, 1.0), outline[-2] + Vector2(0, 1.0), Color(0.015, 0.012, 0.012, 0.9), 1.0, true)


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


## Every horizontal section fills the same fraction of its visible width. This keeps
## tiny values honest even where the portrait cuts a curved bite out of the meter.
static func fill_point(rect: Rect2, ratio: float, height_fraction: float, slant: float, center: Vector2, radius: float) -> Vector2:
	var y := lerpf(rect.position.y, rect.end.y, height_fraction)
	var dy := y - center.y
	var left := maxf(rect.position.x, center.x + sqrt(maxf(0.0, radius * radius - dy * dy)))
	var right := rect.end.x - slant * height_fraction
	return Vector2(lerpf(left, right, clampf(ratio, 0.0, 1.0)), y)


static func bar_outline(poly: PackedVector2Array) -> PackedVector2Array:
	return poly.slice(0, BAR_STEPS + 3)


static func _draw_join_edge(canvas: CanvasItem, poly: PackedVector2Array, top: Color, bottom: Color) -> void:
	# Smooth the colour boundary, without adding another metal rim or making tiny fills wider.
	if poly.is_empty() or poly[1].x - poly[0].x < 1.0:
		return
	var edge := PackedVector2Array([poly[0]])
	for index in range(poly.size() - 1, BAR_STEPS + 1, -1):
		edge.append(poly[index])
	var colors := PackedColorArray()
	for point in edge:
		colors.append(top.lerp(bottom, (point.y - edge[0].y) / (edge[-1].y - edge[0].y)))
	canvas.draw_polyline_colors(edge, colors, 1.0, true)


static func _bar_poly(rect: Rect2, ratio: float, slant: float, center: Vector2, radius: float) -> PackedVector2Array:
	if ratio <= 0.0:
		return PackedVector2Array()
	# Resource decay can leave a positive floating-point remainder at zero. Do not
	# submit collapsed float32 polygons (or their highlights) to the triangulator.
	if fill_point(rect, ratio, 0.5, slant, center, radius).x - fill_point(rect, 0.0, 0.5, slant, center, radius).x < 0.01:
		return PackedVector2Array()
	var points := PackedVector2Array([fill_point(rect, 0.0, 0.0, slant, center, radius)])
	for step in range(BAR_STEPS + 1):
		points.append(fill_point(rect, ratio, float(step) / BAR_STEPS, slant, center, radius))
	for step in range(BAR_STEPS, 0, -1):
		points.append(fill_point(rect, 0.0, float(step) / BAR_STEPS, slant, center, radius))
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

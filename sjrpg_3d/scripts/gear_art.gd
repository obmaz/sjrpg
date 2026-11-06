class_name GearArt
extends RefCounted
## 장비 아이콘. 처음 24칸은 원본 gear-icons.png(6열 시트); 시트에 없는 열 종류는
## 원본 GearIconArt.paintExpanded처럼 벡터로 그립니다.

const SHEET := preload("res://assets/art/hud/gear-icons.png")
const EXPANDED := ["dualblades", "rapier", "katana", "halberd", "warhammer", "flail", "glaive", "falchion", "throwingaxes", "javelin"]

const STEEL := Color("c9d6d8")
const STEEL_DARK := Color("4e6670")
const OUTLINE := Color("182b2c")
const GOLD := Color("d1a65c")
const WOOD := Color("725039")


static func draw(canvas: CanvasItem, base: Dictionary, rect: Rect2, tint := Color.WHITE) -> void:
	var index: int = base["index"]
	if EXPANDED.has(base["id"]) or index >= 24:
		_expanded(canvas, base["id"], rect, tint)
		return
	var cell := SHEET.get_width() / 6.0
	var src := Rect2((index % 6) * cell, (index / 6) * cell, cell, cell)
	var side := minf(rect.size.x, rect.size.y)
	var dest := Rect2(rect.get_center() - Vector2(side, side) / 2.0, Vector2(side, side))
	canvas.draw_texture_rect_region(SHEET, dest, src, tint)


static func _blade(c: CanvasItem, tf: Transform2D, w: float, top: float, bottom: float, curve := 0.0, tint := Color.WHITE) -> void:
	var pts := PackedVector2Array([
		tf * Vector2(-w, bottom), tf * Vector2(-w + curve, top + 8), tf * Vector2(curve, top),
		tf * Vector2(w + curve, top + 8), tf * Vector2(w, bottom)])
	c.draw_colored_polygon(pts, STEEL * tint)
	c.draw_polyline(pts + PackedVector2Array([pts[0]]), OUTLINE * tint, 2.0, true)
	c.draw_line(tf * Vector2(0, bottom), tf * Vector2(curve * 0.6, top + 6), Color(1, 1, 1, 0.55) * tint, 1.5, true)


static func _hilt(c: CanvasItem, tf: Transform2D, y: float, length: float, guard: float, tint: Color) -> void:
	c.draw_line(tf * Vector2(0, y), tf * Vector2(0, y + length), WOOD * tint, 5.0, true)
	c.draw_line(tf * Vector2(-guard, y), tf * Vector2(guard, y), GOLD * tint, 5.0, true)
	c.draw_circle(tf * Vector2(0, y + length), 3.5, GOLD * tint)


static func _expanded(c: CanvasItem, id: String, rect: Rect2, tint: Color) -> void:
	var side := minf(rect.size.x, rect.size.y)
	var k := side / 100.0
	var tf := Transform2D(-PI / 4.0, rect.get_center()).scaled_local(Vector2(k, k))
	match id:
		"dualblades":
			for o in [-14.0, 14.0]:
				var t2 := tf.translated_local(Vector2(o, 0))
				_blade(c, t2, 4.5, -38.0, 14.0, 0.0, tint)
				_hilt(c, t2, 14.0, 18.0, 9.0, tint)
		"rapier":
			_blade(c, tf, 2.5, -42.0, 14.0, 0.0, tint)
			_hilt(c, tf, 14.0, 20.0, 12.0, tint)
			c.draw_arc(tf * Vector2(0, 15), 11.0 * k, 0, PI, 12, GOLD * tint, 2.0, true)
		"katana":
			_blade(c, tf, 3.5, -42.0, 14.0, 6.0, tint)
			_hilt(c, tf, 14.0, 22.0, 7.0, tint)
		"falchion":
			_blade(c, tf, 7.5, -36.0, 14.0, 9.0, tint)
			_hilt(c, tf, 14.0, 20.0, 9.0, tint)
		"halberd", "glaive":
			c.draw_line(tf * Vector2(0, 40), tf * Vector2(0, -30), WOOD * tint, 5.0, true)
			var head := PackedVector2Array([tf * Vector2(0, -44), tf * Vector2(16, -30), tf * Vector2(4, -20), tf * Vector2(0, -26)]) if id == "halberd" else PackedVector2Array([tf * Vector2(0, -46), tf * Vector2(12, -34), tf * Vector2(2, -14), tf * Vector2(-3, -26)])
			c.draw_colored_polygon(head, STEEL * tint)
			c.draw_polyline(head + PackedVector2Array([head[0]]), OUTLINE * tint, 2.0, true)
			c.draw_colored_polygon(PackedVector2Array([tf * Vector2(0, -44), tf * Vector2(-5, -34), tf * Vector2(0, -28)]), STEEL_DARK * tint)
		"javelin":
			c.draw_line(tf * Vector2(0, 42), tf * Vector2(0, -34), WOOD * tint, 4.0, true)
			var tip := PackedVector2Array([tf * Vector2(0, -50), tf * Vector2(6, -34), tf * Vector2(-6, -34)])
			c.draw_colored_polygon(tip, STEEL * tint)
			c.draw_polyline(tip + PackedVector2Array([tip[0]]), OUTLINE * tint, 2.0, true)
		"warhammer":
			c.draw_line(tf * Vector2(0, 42), tf * Vector2(0, -22), WOOD * tint, 6.0, true)
			var block := PackedVector2Array([tf * Vector2(-18, -42), tf * Vector2(18, -42), tf * Vector2(18, -20), tf * Vector2(-18, -20)])
			c.draw_colored_polygon(block, STEEL * tint)
			c.draw_polyline(block + PackedVector2Array([block[0]]), OUTLINE * tint, 2.5, true)
		"flail":
			c.draw_line(tf * Vector2(0, 42), tf * Vector2(0, -8), WOOD * tint, 5.0, true)
			c.draw_line(tf * Vector2(0, -8), tf * Vector2(12, -30), STEEL_DARK * tint, 2.5, true)
			c.draw_circle(tf * Vector2(14, -36), 10.0 * k, STEEL * tint)
			c.draw_arc(tf * Vector2(14, -36), 10.0 * k, 0, TAU, 16, OUTLINE * tint, 2.0, true)
		"throwingaxes":
			for o in [-15.0, 13.0]:
				var t2 := tf.translated_local(Vector2(o, 8)).rotated_local(o * 0.01)
				c.draw_line(t2 * Vector2(0, 24), t2 * Vector2(0, -22), WOOD * tint, 4.0, true)
				var h := PackedVector2Array([t2 * Vector2(0, -26), t2 * Vector2(16, -22), t2 * Vector2(14, -6), t2 * Vector2(0, -10)])
				c.draw_colored_polygon(h, STEEL * tint)
				c.draw_polyline(h + PackedVector2Array([h[0]]), OUTLINE * tint, 2.0, true)
		_:
			_blade(c, tf, 5.0, -38.0, 14.0, 0.0, tint)
			_hilt(c, tf, 14.0, 20.0, 10.0, tint)

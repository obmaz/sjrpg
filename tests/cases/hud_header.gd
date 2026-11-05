extends TestCase
## Validate the actual painted header, visible fill and shaped labels, including safe insets.


func run() -> void:
	var map := Minimap.new()
	for view in [Vector2(540, 960), Vector2(720, 1280), Vector2(1280, 720), Vector2(720, 1600), Vector2(1600, 720), Vector2(1440, 2560)]:
		for safe in [Vector4.ZERO, Vector4(44, 30, 20, 16)]:
			var geometry := Hud.header_geometry(view, safe)
			var u: float = geometry["unit"]
			var available := Rect2(Vector2(safe.x, safe.y), view - Vector2(safe.x + safe.z, safe.y + safe.w))
			check("all portrait crests and plate shadows fit safe screen %s/%s" % [view, safe], available.encloses(geometry["paint_bounds"]))
			var portrait_ink: Rect2 = geometry["portrait_bounds"]
			check("small fluid amounts clear the portrait rim and shadow", float(geometry["visible_start"]) > portrait_ink.end.x)
			var map_rect: Rect2 = geometry["map"]
			map.size = map_rect.size
			map.radius = 64.0 * float(geometry["map_unit"])
			var map_ink := map.paint_bounds()
			map_ink.position += map_rect.position
			check("entire map rim fits and avoids the portrait/status ribbon", available.encloses(map_ink) and not map_ink.intersects(geometry["paint_bounds"]))
			var plate: PackedVector2Array = geometry["plate"]
			var avatar: Vector2 = geometry["portrait"]
			var join_radius: float = float(geometry["radius"]) + 2.0 * u
			check("portrait join has a rounded contour instead of a square cap", plate.size() > 8)
			for index in [0, 3] + range(4, plate.size()):
				check("ribbon's left contour stays under the portrait rim", plate[index].distance_to(avatar) <= join_radius + 0.01 and plate[index].x >= avatar.x)
			var slope := (plate[1].x - plate[2].x) / (plate[2].y - plate[1].y)
			var gaps: Array[float] = []
			for key in ["hp", "mp", "xp"]:
				var rect: Rect2 = geometry[key]
				var slant := rect.size.y * float(geometry["slope"])
				var label: Rect2 = geometry[key + "_label"]
				check("numbers clear the full portrait: " + key, label.position.x > float(geometry["visible_start"]) and label.size.x > 0)
				for point in [Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x - slant, rect.end.y)]:
					var outside: float = plate[1].x - (point.y - plate[1].y) * slope
					gaps.append(outside - point.x)
				for ratio in [0.0, 0.001, 0.01, 0.05, 0.5, 0.979, 0.99, 0.999, 1.0]:
					var poly := HudArt._bar_poly(rect, ratio, slant, geometry["visible_start"])
					if ratio == 0.0:
						check("empty fluid draws no sliver: " + key, poly.is_empty())
						continue
					var visible := (poly[1].x - float(geometry["visible_start"])) / (rect.end.x - float(geometry["visible_start"]))
					check("uncovered fluid shows its actual fraction %s/%.3f" % [key, ratio], absf(visible - ratio) < 0.0001)
					check("tiny fills have no exposed join wedge: " + key, is_equal_approx(poly[0].x, geometry["visible_start"]) and is_equal_approx(poly[poly.size() - 1].x, geometry["visible_start"]))
					for point in poly:
						var edge: float = rect.end.x - (point.y - rect.position.y) / rect.size.y * slant
						check("fluid stays inside the bevel %s/%.3f" % [key, ratio], point.x <= edge + 0.001 and point.x >= rect.position.x - 0.001 and point.y >= rect.position.y - 0.001 and point.y <= rect.end.y + 0.001)
				var preferred := roundi((23 if key == "hp" else 18 if key == "mp" else 11) * u)
				var text := "9,999,999 / 9,999,999" if key == "hp" else "마나 999,999" if key == "mp" else "EXP 100%"
				var font_size := HudArt.fit_text_size(text, label, preferred)
				var shaped := HudArt.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				check("long numeric label fits its own row: " + key, shaped.x <= label.size.x + 0.01 and HudArt.FONT.get_height(font_size) <= label.size.y + 0.01)
			check("all ribbon bevels are collinear with equal metal margins", gaps.min() > 0.0 and float(gaps.max()) - float(gaps.min()) < 0.01)
	var reference := Hud.header_geometry(Vector2(720, 1280), Vector4.ZERO)
	var bounds: Rect2 = reference["paint_bounds"]
	check("avatar and gauges grow ten percent from the approved compact header", is_equal_approx(float(reference["radius"]), 50.0 * 0.82 * 1.1) and is_equal_approx(float(reference["unit"]), 0.82 * 1.1))
	check("larger header still leaves the scene visible", bounds.size.x < 420.0 and float(reference["radius"]) < 46.0)
	check("header enlargement keeps the existing minimap scale", is_equal_approx(float(reference["map_unit"]), 1.0) and reference["map"].size == Vector2.ONE * 136.0)
	var badge: Rect2 = reference["level_badge"]
	var portrait: Vector2 = reference["portrait"]
	check("level medallion sits on the upper-left rim", badge.get_center().distance_to(portrait) < float(reference["radius"]) + badge.size.x * 0.25 and badge.size.x / (2.0 * float(reference["radius"])) >= 0.3)
	var tall := Hud.header_geometry(Vector2(720, 1600), Vector4.ZERO)
	check("tall phones preserve the approved top anchor", reference["origin"] == tall["origin"])
	var objective := HudArt.elide("아주 긴 의뢰의 설명도 미니맵 이름이나 화면 바깥으로 넘어가면 안 됩니다", 280, 16)
	check("long objectives stay within the header width", objective.ends_with("…") and HudArt.FONT.get_string_size(objective, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x <= 280)
	map.free()

extends TestCase
## Generated frames must keep HUD holes clear and avoid luminous rectangular effect plates.


func run() -> void:
	var art := PresentationArt.data()
	for item in art["sources"] + [art["reference"], art["generation"], art["ui"], art["impact"]]:
		check("presentation pixels match reviewed source: " + str(item["path"]), FileAccess.get_sha256("res://" + str(item["path"])) == item["sha256"])
	var trim := Image.load_from_file("res://" + str(art["ui"]["path"]))
	for key in ["active", "empty", "map"]:
		var rect := PresentationArt.ui_frame(key)
		var center := Vector2i(rect.get_center())
		check("generated %s ring leaves the real icon/map visible" % key, trim.get_pixelv(center).a < 0.02)
		check("trim has no square matte outside its metal", trim.get_pixelv(Vector2i(rect.position) + Vector2i(1, 1)).a < 0.02)
	var map_rect := PresentationArt.ui_frame("map")
	var map_half: float = art["ui"]["frames"]["map"]["paint_half"]
	var minimap := Minimap.new()
	minimap.radius = 64.0
	var marker_edge_clear := true
	for step in 64:
		var at := map_rect.get_center() + Vector2.from_angle(step * TAU / 64.0) * (minimap.content_radius() / minimap.rim_radius()) * map_half
		marker_edge_clear = marker_edge_clear and trim.get_pixelv(Vector2i(at)).a < 0.04
	check("generated map metal cannot cover the existing content/marker boundary", marker_edge_clear)
	minimap.free()
	var effects := Image.load_from_file("res://" + str(art["impact"]["path"]))
	for element in 4:
		var peak := _energy(effects, PresentationArt.impact_frame(element, 1))
		var tail := _energy(effects, PresentationArt.impact_frame(element, 3))
		check("element %d has a bright peak and a quieter authored tail" % element, peak > 1.0 and tail < peak * 0.7)
		for frame in 4:
			var rect := PresentationArt.impact_frame(element, frame)
			var clear := true
			for offset in [Vector2i(1, 1), Vector2i(254, 1), Vector2i(1, 254), Vector2i(254, 254)]:
				var pixel := effects.get_pixelv(Vector2i(rect.position) + offset)
				clear = clear and maxf(pixel.r, maxf(pixel.g, pixel.b)) < 0.02
			check("FX cell padding emits no matte or neighbouring texture", clear)
	var start := PresentationArt.impact_columns(-1.0)
	var end := PresentationArt.impact_columns(2.0)
	check("late frames never wrap back to another impact", start.x == 0 and end.x == 3 and end.y == 3)


func _energy(image: Image, rect: Rect2) -> float:
	var sum := 0.0
	for y in range(0, int(rect.size.y), 4):
		for x in range(0, int(rect.size.x), 4):
			var pixel := image.get_pixelv(Vector2i(rect.position) + Vector2i(x, y))
			sum += pixel.r + pixel.g + pixel.b
	return sum

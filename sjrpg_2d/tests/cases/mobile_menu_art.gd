extends TestCase
## New menu art must survive mobile sizing without an opaque square or lost glyph.


func run() -> void:
	var data := MobileMenuArt.data()
	var records: Array = data["sources"].duplicate()
	records.append(data["generation"])
	records.append(data["measure"])
	records.append(data["atlas"])
	for record: Dictionary in records:
		check("mobile menu source/runtime provenance is fixed", FileAccess.get_sha256("res://" + str(record["path"])) == str(record["sha256"]))
	var texture := load("res://" + str(data["atlas"]["path"])) as Texture2D
	var image := texture.get_image()
	var signatures := {}
	for key in ["bag", "skills", "quests", "settings"]:
		var region := Rect2i(MobileMenuArt.frame(key))
		var tile := image.get_region(region)
		var last := tile.get_width() - 1
		var clear := true
		for point in [Vector2i(0, 0), Vector2i(last, 0), Vector2i(0, last), Vector2i(last, last)]:
			clear = clear and tile.get_pixelv(point).a < 0.02
		check("menu %s keeps transparent outer corners" % key, clear)
		signatures[hash(tile.get_data())] = true
		tile.resize(48, 48, Image.INTERPOLATE_LANCZOS)
		var bright := 0
		for y in 48:
			for x in 48:
				var color := tile.get_pixel(x, y)
				if color.a > 0.8 and color.get_luminance() > 0.38:
					bright += 1
		check("menu %s retains a substantial light glyph at 48px" % key, bright >= 75 and bright < 48 * 48 * 0.65, str(bright))
	check("the four menu symbols use distinct pixels", signatures.size() == 4)

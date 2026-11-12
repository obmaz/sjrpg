extends TestCase
## Test actual visible bodies and rendered foreground wall quads, not only footprint separation.


func _rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


func _covered_by_front_wall(game: Node, polygon: PackedVector2Array, sort_y: float, z: int) -> bool:
	for child in game.world.get_children():
		var wall := child as WallPiece
		if wall == null or wall.z_index < z or wall.position.y <= sort_y:
			continue
		var quad := PackedVector2Array()
		for point in _rect_polygon(wall._local):
			quad.append(wall.global_position + wall._xf * point)
		if not Geometry2D.intersect_polygons(polygon, quad).is_empty():
			return true
	return false


func _painted_outline(building: IsoSprite) -> PackedVector2Array:
	var image := building.texture.get_image()
	var source: Array = building.def["source"]
	var points := PackedVector2Array()
	# Sample both actual painted sides of each scanline, excluding transparent
	# atlas corners. Eight atlas pixels are less than the24worldpixel safety margin.
	for y in range(int(source[1]), int(source[1] + source[3]), 8):
		var first := -1
		var last := -1
		for x in range(int(source[0]), int(source[0] + source[2]), 8):
			if image.get_pixel(x, y).a > 0.25:
				if first < 0:
					first = x
				last = x
		if first >= 0:
			points.append(building.atlas_point(Vector2(first, y)))
			points.append(building.atlas_point(Vector2(last, y)))
	return Geometry2D.convex_hull(points)


func run() -> void:
	var art := NpcArt.data()
	for record: Dictionary in [art["source"], art["generation"], art["measure"], art["atlas"]] + art["references"]:
		check("NPC art provenance matches reviewed pixels", FileAccess.get_sha256("res://" + str(record["path"])) == str(record["sha256"]))
	var unique := {}
	for label in art["labels"]:
		var identity: String = NpcArt.identity(label)
		var definition: Dictionary = art["people"][identity]
		unique[str(definition["pixels_sha256"])] = true
		check("each named resident has its own identity: " + label, identity != "" and definition["body_height"] == Villager.BODY_HEIGHT)
	check("all eight residents have different drawn bodies", unique.size() == 8 and art["labels"].size() == 8)
	var image := Image.load_from_file("res://" + str(art["atlas"]["path"]))
	for definition: Dictionary in art["people"].values():
		var source: Array = definition["source"]
		var origin := Vector2i(source[0], source[1])
		check("NPC padding retains real transparent alpha", image.get_pixelv(origin + Vector2i(1, 1)).a < 0.02 and image.get_pixelv(origin + Vector2i(source[2] - 2, source[3] - 2)).a < 0.02)

	var game := await make_game()
	var residents: Array[Villager] = []
	for node in game.world.get_children():
		if node is Villager:
			residents.append(node)
	check("town and field use eight named service/quest residents", residents.size() == 8)
	var painted_hero_heights: Array[float] = []
	for key in ["warrior", "mage"]:
		var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/actors/" + key + ".json"))
		var texture := ActorAtlas.get_atlas(key).texture
		var pixels := texture.get_image()
		var region: Array = metadata["frames"][0]
		var min_y := int(region[3])
		var max_y := -1
		for y in int(region[3]):
			for x in int(region[2]):
				if pixels.get_pixel(int(region[0]) + x, int(region[1]) + y).a > 0.25:
					min_y = mini(min_y, y)
					max_y = maxi(max_y, y)
		painted_hero_heights.append(float(max_y - min_y + 1) * game.player.sprite.body_height / float(metadata["sizes"][0][1]))
	for npc in residents:
		var body := npc.body_rect()
		for hero_height in painted_hero_heights:
			check("resident body matches the painted human scale: " + npc.display_name, body.size.y / hero_height >= 0.90 and body.size.y / hero_height <= 1.08, "npc=%.2f hero=%.2f" % [body.size.y, hero_height])
		check("resident keeps its feet on the actual world anchor", body.end.y >= -1.0 and body.end.y < 4.0, str(body))
		check("foreground wall cannot cover resident: " + npc.display_name, not _covered_by_front_wall(game, _rect_polygon(Rect2(npc.global_position + body.position, body.size)), npc.position.y, npc.z_index))

	var measure: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/extract/town_art_measure.json"))
	for key in ["nw", "ne", "sw", "se", "chapel"]:
		var building: IsoSprite = game.village.buildings[key]
		var footprint := building.atlas_polygon(game.village.data["frames"][key]["ground"])
		var center := Vector2.ZERO
		for point in footprint:
			center += point
		center /= footprint.size()
		var expected: Array = measure["reference"][key]["center"]
		check("perimeter expansion preserves measured building world centre: " + key, center.distance_to(Vector2(expected[0], expected[1])) < 0.3, str(center))
		var whole := _painted_outline(building)
		check("foreground walls leave the building illustration clear: " + key, not _covered_by_front_wall(game, whole, building.position.y, building.z_index))
	for key in ["nw", "ne", "sw", "se"]:
		var building: IsoSprite = game.village.buildings[key]
		var approach: Array = game.village.data["approaches"][key]
		var position := building.native_point(Vector2(approach[0], approach[1]))
		check("service resident stays beyond the actual painted front foot: " + key, position.y >= building.position.y + 11.9)
		check("door approach remains reachable without entering a building: " + key, not game._blocked(position + Vector2(0, 42), Player.RADIUS))
	game.queue_free()
	await _frames(2)

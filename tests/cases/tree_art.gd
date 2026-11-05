extends TestCase
## Organic camera consistency is reviewed in the illustration, not invented from a collision box.
## Lock that review to the actual pixels and verify their ground contacts in the live forest.


func run() -> void:
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/tree_art.json"))
	check("tree source matches the reviewed crown and roots", FileAccess.get_sha256("res://" + art["source"]) == art["source_sha256"])
	check("tree atlas matches the reviewed shadow-free pixels", FileAccess.get_sha256("res://" + art["render"]) == art["render_sha256"])
	check("the mixed legacy families are fully replaced", art["variants"].size() == 18 and art["frames"].size() == 4)
	var image := Image.load_from_file("res://" + art["render"])
	for key in art["frames"]:
		var frame: Dictionary = art["frames"][key]
		var source: Array = frame["source"]
		var foot: Array = frame["foot"]
		check("tree root contacts stay inside their packed illustration: " + key, Rect2(source[0], source[1], source[2], source[3]).has_point(Vector2(foot[0], foot[1])))
		var root_alpha := 0.0
		for y in range(-2, 3):
			for x in range(-2, 3):
				root_alpha = maxf(root_alpha, image.get_pixel(roundi(foot[0]) + x, roundi(foot[1]) + y).a)
		check("tree contact touches painted roots: " + key, root_alpha > 0.5)
	var game := await make_game()
	for key in art["variants"]:
		var expected: Dictionary = art["frames"][art["variants"][key]]
		var actual: Dictionary = game.village.data["sprites"][key]
		check("legacy tree ID resolves to reviewed pixels: " + key, actual["source"] == expected["source"] and actual["foot"] == expected["foot"] and actual["sheet"] == "forest-isometric-trees")
	var trees := 0
	var contacts_match := true
	var bases_blocked := true
	for child in game.world.get_children():
		if not child is IsoSprite or child.def["sheet"] != "forest-isometric-trees":
			continue
		var tree: IsoSprite = child
		var foot := Vector2(tree.def["foot"][0], tree.def["foot"][1])
		contacts_match = contacts_match and tree.atlas_point(foot).is_equal_approx(tree.position)
		bases_blocked = bases_blocked and game._blocked(tree.position, Player.RADIUS)
		trees += 1
	check("all live trees sort and collide at their painted contacts", contacts_match)
	check("all live tree trunks block walking through their root bases", bases_blocked)
	check("town and surrounding forest both use the reviewed trees", trees > 200)
	# Read the actual ready-node bounds/draw order and the live NPC positions,
	# rather than checking only that trunks clear an authored doorway point.
	for npc_name in ["상인", "대장장이", "탈것 상인", "촌장"]:
		var npc: Vector2 = game.village.npc_points[npc_name]
		var visible := true
		for tree in game.village.town_trees:
			var bounds: Rect2 = tree.get_meta("occlusion_bounds")
			if tree.position.y > npc.y + 4.0 and bounds.intersects(Rect2(npc - Vector2(42, 90), Vector2(84, 110))):
				visible = false
		check("service NPC stays readable below all foreground crowns: " + npc_name, visible)
	for service in Village.NPCS:
		var npc: Vector2 = game.village.npc_points[service[1]]
		var building: IsoSprite = game.village.buildings[service[0]]
		check("service resident stands in front of the actual building sort point: " + service[1], npc.y >= building.position.y + 8.0)
		var clear := true
		for solid in game.village.solids:
			clear = clear and not Geometry2D.is_point_in_polygon(npc, solid)
		check("the readable service position remains on walkable ground: " + service[1], clear)
	game.queue_free()
	await _frames(2)

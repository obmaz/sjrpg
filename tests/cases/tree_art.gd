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
	game.queue_free()
	await _frames(2)

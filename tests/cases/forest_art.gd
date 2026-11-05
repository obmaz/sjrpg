extends TestCase
## Reference flora must use the reviewed pixels and leave routes, interactions and RNG intact.


func run() -> void:
	var art := ForestArt.data()
	for source in art["sources"]:
		check("forest source matches reviewed pixels", FileAccess.get_sha256("res://" + str(source["path"])) == source["sha256"])
	for key in art["textures"]:
		var record: Dictionary = art["textures"][key]
		check("forest runtime matches reviewed pixels: " + key, FileAccess.get_sha256("res://" + str(record["path"])) == record["sha256"])
	var game := await make_game()
	check("path borders gain bounded natural detail", game.forest_details.size() > 40 and game.forest_details.size() <= 420)
	var clear_borders := true
	var grounded := true
	var raised := 0
	for plant in game.forest_details:
		if plant.z_index == 1:
			raised += 1
		clear_borders = clear_borders and ForestArt.clear(game.village, plant.position, plant.z_index == 1)
		var foot := Vector2(plant.def["foot"][0], plant.def["foot"][1])
		grounded = grounded and plant.atlas_point(foot).is_equal_approx(plant.position) and plant.get_parent() == game.world
	check("flowers preserve doors, residents, chests, gates and chapel steps", clear_borders)
	check("flora sort at their painted ground contacts", grounded)
	check("chapel front gains flowers on its raised surface", raised >= 4, str(raised))
	var state: int = game._rng.state
	var circle_count: int = game.village.circles.size()
	var solid_count: int = game.village.solids.size()
	var scratch := Node2D.new()
	add_child(scratch)
	var repeat := ForestArt.decorate(game.village, scratch)
	var identical: bool = repeat.size() == game.forest_details.size()
	for index in mini(repeat.size(), game.forest_details.size()):
		identical = identical and repeat[index].position == game.forest_details[index].position
	check("flora layout is repeatable without consuming gameplay RNG", identical and game._rng.state == state)
	check("decorations add no invisible movement blockers", circle_count == game.village.circles.size() and solid_count == game.village.solids.size())
	scratch.queue_free()
	game.queue_free()
	await _frames(2)

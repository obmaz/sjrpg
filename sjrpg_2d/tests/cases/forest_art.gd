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
	var chapel_flowers := 0
	var chapel_ground := 0
	var understory := 0
	var nearby_ground := true
	var nearby_trees := true
	var species := {}
	var chapel: IsoSprite = game.village.buildings["chapel"]
	var garden := chapel.atlas_polygon(game.village.data["frames"]["chapel"]["ground"])
	for plant in game.forest_details:
		var group: String = plant.get_meta("forest_cluster", "")
		var kind: String = plant.get_meta("forest_species", "")
		species[kind] = true
		if group == "chapel_ground":
			chapel_ground += 1
			if kind.begins_with("flowers"):
				chapel_flowers += 1
			nearby_ground = nearby_ground and plant.z_index == 0 and ForestArt.near_polygon(plant.position, garden, 160.0)
		if group == "understory":
			understory += 1
			var near_tree := false
			for tree in game.village.town_trees:
				near_tree = near_tree or plant.position.distance_to(tree.position) < 160.0
			nearby_trees = nearby_trees and near_tree
		clear_borders = clear_borders and ForestArt.clear(game.village, plant.position, plant.z_index == 1)
		var foot := Vector2(plant.def["foot"][0], plant.def["foot"][1])
		grounded = grounded and plant.atlas_point(foot).is_equal_approx(plant.position) and plant.get_parent() == game.world
	check("flowers preserve doors, residents, chests, gates and chapel steps", clear_borders)
	check("flora sort at their painted ground contacts", grounded)
	check("chapel gains an actual ground wildflower garden", chapel_flowers >= 4 and chapel_ground >= 8 and nearby_ground, "flowers=%d ground=%d nearby=%s" % [chapel_flowers, chapel_ground, nearby_ground])
	check("town tree roots gain clustered low understory", understory >= 8 and understory <= ForestArt.UNDERSTORY_BUDGET and nearby_trees, str(understory))
	check("ground patches mix generated flowers ferns and grass", species.size() == 4)
	var paired_path_plants := 0
	for plant in game.forest_details:
		if plant.get_meta("forest_cluster", "") != "path_edge":
			continue
		for other in game.forest_details:
			if other != plant and other.get_meta("forest_cluster", "") == "path_edge" and plant.position.distance_to(other.position) < 70.0:
				paired_path_plants += 1
				break
	check("pathside detail forms clumps instead of isolated evenly spaced dots", paired_path_plants >= 12, str(paired_path_plants))
	for road in game.village.map_roads:
		var triangles := Geometry2D.triangulate_polygon(road)
		if triangles.size() >= 3:
			var route_center: Vector2 = (road[triangles[0]] + road[triangles[1]] + road[triangles[2]]) / 3.0
			check("flora never roots inside a playable road", not ForestArt.clear(game.village, route_center))
	check("new journey approach remains clear of decoration", not ForestArt.clear(game.village, game.village.spawn_point))
	var state: int = game._rng.state
	var circle_count: int = game.village.circles.size()
	var solid_count: int = game.village.solids.size()
	var scratch := Node2D.new()
	add_child(scratch)
	var repeat := ForestArt.decorate(game.village, scratch)
	var identical: bool = repeat.size() == game.forest_details.size()
	for index in mini(repeat.size(), game.forest_details.size()):
		identical = identical and repeat[index].position == game.forest_details[index].position and repeat[index].def == game.forest_details[index].def and is_equal_approx(repeat[index].k, game.forest_details[index].k)
	check("flora layout is repeatable without consuming gameplay RNG", identical and game._rng.state == state)
	check("decorations add no invisible movement blockers", circle_count == game.village.circles.size() and solid_count == game.village.solids.size())
	scratch.queue_free()
	game.queue_free()
	await _frames(2)

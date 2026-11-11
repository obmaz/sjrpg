extends TestCase

func run() -> void:
	var game := await make_game()
	var travel: Exploration = game.exploration
	check("only town is initially discovered", GameState.discovered_sanctuaries == ["town"])
	check("unknown sanctuary cannot be used", not travel.travel("tree"))
	for id in Exploration.NAMES:
		var point := travel.safe_point(id)
		check("safe sanctuary arrival: " + id, not game._blocked(point, Player.RADIUS) and point.distance_to(game.village.sanctuary_points[id]) < 200.0)
	game.player.position = travel.safe_point("tree")
	travel._process(0.1)
	check("physical visit unlocks checkpoint", GameState.discovered_sanctuaries.has("tree") and GameState.last_sanctuary == "tree")
	check("checkpoint survives reload", GameState.load_game() and GameState.discovered_sanctuaries.has("tree") and GameState.last_sanctuary == "tree")
	var enemy := Enemy.new()
	enemy.setup(game, "goblin", 1)
	enemy.position = game.player.position + Vector2(100, 0)
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	check("nearby enemies block travel", not travel.travel("town"))
	game.enemies.erase(enemy)
	enemy.queue_free()
	check("quiet sanctuary permits free travel", travel.travel("town") and GameState.last_sanctuary == "town" and game.player.hp == game.player.max_hp)
	game.player.position += Vector2(400, 0)
	check("cannot travel from an arbitrary field point", not travel.travel("tree"))
	var waterfall: Landmark = game.village.landmarks[3]
	check("fourth landmark is the waterfall", waterfall.index == 3 and waterfall.water.size() == 2)
	for water in waterfall.water:
		var center := Vector2.ZERO
		for point in water:
			center += point
		center /= water.size()
		check("waterfall pool blocks movement", game._blocked(center, Player.RADIUS))
	check("waterfall treasure is on a dry path", waterfall.contains_top(game.chests[8].position) and not game._blocked(game.chests[8].position + Vector2(Chest.COLLISION_RADIUS + Player.RADIUS + 10.0, 0), Player.RADIUS))
	var roads := 0
	for shape in game.map_shapes:
		if shape["poly"] == game.village.map_roads[0]:
			roads += 1
	check("map shares actual paving geometry", roads == 1)
	game.hud.open_map()
	await _frames(2)
	var panel: MapPanel = game.hud._panel
	panel._tab = 1
	panel._rebuild()
	await _frames(2)
	game.hud.close_panel()
	game.queue_free()
	await _frames(2)

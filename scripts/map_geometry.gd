class_name MapGeometry
extends RefCounted
## Both maps use the same projected polygons that build the world and its collisions.

static func build(village: Village) -> Array[Dictionary]:
	var shapes: Array[Dictionary] = []
	shapes.append({"poly": village.safe_zone, "color": Color("667654")})
	shapes.append({"poly": village.map_water, "color": Color("40809e")})
	for road in village.map_roads:
		shapes.append({"poly": road, "color": Color("958b70")})
	shapes.append({"poly": village.bridge.deck_polygon(), "color": Color("b3a17c")})
	for wall in village.wall_footprints:
		shapes.append({"poly": wall, "color": Color("42423c")})
	for landmark in village.landmarks:
		shapes.append({"poly": landmark.top, "color": Color("8a9566")})
		for water in landmark.water:
			shapes.append({"poly": water, "color": Color("40809e")})
	for key in village.buildings:
		var building: IsoSprite = village.buildings[key]
		shapes.append({"poly": building.atlas_polygon(village.data["frames"][key]["ground"]), "color": Color("c0aa7d")})
	for shape in shapes:
		shape["bounds"] = Iso.poly_bounds(shape["poly"])
	return shapes


static func markers(game: Node) -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	if game.dungeon.active:
		return [{"pos": Vector2.ZERO, "label": "입구", "color": Color("7edbcc")}, {"pos": Iso.project(DungeonLayout.EXIT), "label": "귀환문", "color": Color("ffe197")}]
	for definition in Quests.DEFS:
		var id: String = definition["id"]
		if Quests.phase(id) != "completed":
			var at: Vector2 = game.village.quest_sites[id]
			if id == "moon" and (Quests.phase(id) == "offered" or (Quests.phase(id) == "accepted" and not Quests.state(id)["parcel"])):
				at = game.village.npc_points["보급원 미라"]
			var label: String = "약초사 노아" if id == "moon" and at == game.village.quest_sites[id] else definition["giver"]
			markers.append({"pos": at, "label": label, "color": Color("ffe197")})
	for id in game.village.sanctuary_points:
		if GameState.discovered_sanctuaries.has(id):
			markers.append({"pos": game.village.sanctuary_points[id], "label": Exploration.NAMES[id], "color": Color("bfa0ff")})
	for name in ["상인", "대장장이"]:
		markers.append({"pos": game.village.npc_points[name], "label": name, "color": Color("7edbcc")})
	markers.append({"pos": Iso.project(game.village.cave_ground), "label": "바람 동굴", "color": Color("7edbcc")})
	if Quests.all_done() and not GameState.boss_defeated:
		markers.append({"pos": game.village.boss_point, "label": "파수꾼", "color": Color("ff9e65")})
	return markers

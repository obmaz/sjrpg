extends TestCase
## The generated cave design must be the deployed pixels, with the original routes and transient lifecycle.


func run() -> void:
	var data := DungeonArt.data()
	_check_hash("complete cave design", data["concept"])
	for source in data["sources"]:
		_check_hash("generated cave source", source)
	for key in data["textures"]:
		_check_hash("deployed cave texture: " + key, data["textures"][key])
	var previous_quality := Prefs.low_resolution
	var previous_motion := Prefs.reduce_motion
	Prefs.reduce_motion = false
	Prefs.set_low_resolution(false)
	var game := await make_game()
	var forest_map: Array[Dictionary] = game.map_shapes.duplicate(true)
	var cave: DungeonRuntime = game.dungeon
	var controls: TouchControls = game.hud.controls
	game.player.position = game.village.sanctuary_points["town"]
	controls._layout()
	var forest_target := controls._near_name
	var forest_button: Dictionary = controls._buttons.get("near_shop", {})
	var forest_touch: Vector2 = forest_button.get("center", Vector2.ZERO)
	check("forest provides a real cached interaction before entering the cave", forest_target != "" and not forest_button.is_empty())
	game.player.position = cave.entry_point()
	check("cave enters with its generated design", cave.enter())
	_check_live_interactions(game, forest_target, forest_touch)
	await _frames(2)
	var art: DungeonArt = cave.art
	check("generated cave art belongs to the transient instance", art != null and cave._root.is_ancestor_of(art))
	var floor_count_matches := art.floor_nodes.size() == cave.layout.polygons.size()
	check("every walkable polygon uses the generated cave floor", floor_count_matches)
	var floor_record: Dictionary = data["textures"]["floor"]
	var floor_texture: Texture2D = load("res://" + str(floor_record["path"]))
	var floors_match := floor_count_matches
	var maps_match: bool = game.map_shapes.size() == cave.layout.polygons.size()
	for index in mini(art.floor_nodes.size(), cave.layout.polygons.size()):
		var floor_piece: Polygon2D = art.floor_nodes[index]
		floors_match = floors_match and floor_piece.texture == floor_texture and floor_piece.polygon == cave.layout.polygons[index]
		if index < game.map_shapes.size():
			maps_match = maps_match and game.map_shapes[index]["poly"] == floor_piece.polygon
	check("visible floors match the collision layout", floors_match)
	check("both maps use the actual visible floors", maps_match)
	var boundaries_match := not art.boundary_segments.is_empty()
	var boundary_failures: Array[String] = []
	for boundary in art.boundary_segments:
		var a: Vector2 = boundary["a"]
		var b: Vector2 = boundary["b"]
		var outward: Vector2 = boundary["outward"]
		var middle := (a + b) * 0.5
		var inside := cave.layout.contains(Iso.project(middle - outward * 4.0))
		var outside := not cave.layout.contains(Iso.project(middle + outward * 4.0))
		if not inside or not outside:
			boundary_failures.append("%s to %s, outward %s: inner clear=%s, outer blocked=%s" % [a, b, outward, inside, outside])
		boundaries_match = boundaries_match and inside and outside
	check("cave walls follow only the outside of the connected floor", boundaries_match, "; ".join(boundary_failures))
	_check_return_portal(game, cave)
	var walls := 0
	var lights: Array[PointLight2D] = []
	var visual_roots_match := true
	var wall_bases_outside := true
	for visual in art.visuals:
		visual_roots_match = visual_roots_match and visual.get_parent() == game.world and cave._root.is_ancestor_of(visual)
		if visual.get_meta("cave_role", "") == "wall":
			walls += 1
			wall_bases_outside = wall_bases_outside and not cave.layout.contains(visual.position)
		elif visual.get_meta("cave_role", "") == "lantern":
			for child in visual.get_children():
				if child is PointLight2D:
					lights.append(child)
	check("the generated walls and props use world depth sorting", not art.visuals.is_empty() and visual_roots_match)
	check("walls leave room and passage interiors clear", walls > 0 and wall_bases_outside)
	check("new art preserves all five combat rooms and twenty-two enemies", cave.total == 22 and game.enemies.size() == 22)
	check("all five rooms have two real lantern lights", lights.size() == 10)
	var initial_phases: Array[float] = []
	for light in lights:
		initial_phases.append(float(light.get("phase")))
	await _frames(2)
	var animated := not lights.is_empty()
	for index in lights.size():
		animated = animated and not is_equal_approx(float(lights[index].get("phase")), initial_phases[index])
	check("lantern light animation advances during exploration", animated)
	var instance: WeakRef = weakref(cave._root)
	var design: WeakRef = weakref(art)
	game.hud.open_settings()
	await _frames(2)
	var remaining := cave.remaining
	var paused_lights: Array[Vector2] = []
	for light in lights:
		paused_lights.append(Vector2(float(light.get("phase")), light.energy))
	for low in [true, false]:
		Prefs.set_low_resolution(low)
		await _frames(3)
		var viewports_match: bool = art.get_viewport() == game.scene_view
		for visual in art.visuals:
			viewports_match = viewports_match and visual.get_viewport() == game.scene_view
		check("paused quality changes move all generated cave art together", cave._root.get_parent() == game.scene_root and viewports_match and game.player.get_viewport() == game.scene_view)
		check("art quality changes keep exploration paused", get_tree().paused and cave.remaining == remaining)
		var lights_still := true
		for index in lights.size():
			var current := Vector2(float(lights[index].get("phase")), lights[index].energy)
			lights_still = lights_still and current.is_equal_approx(paused_lights[index])
		check("paused quality changes preserve every lantern's phase and brightness", lights_still)
	game.hud.close_panel()
	Prefs.reduce_motion = true
	await _frames(2)
	var reduced := not lights.is_empty()
	for light in lights:
		reduced = reduced and is_zero_approx(float(light.get("phase"))) and is_equal_approx(light.energy, 0.45)
	check("reduced motion holds lantern light at a steady brightness", reduced)
	cave.leave("동굴 원화 검증")
	await _frames(2)
	check("leaving removes the generated cave instance and its world props", cave.art == null and instance.get_ref() == null and design.get_ref() == null)
	check("leaving restores the forest map and world", game.field_root.visible and game.map_shapes == forest_map and game.player.get_parent() == game.world)
	check("reentry creates a new generated cave instance", cave.enter() and cave.art != null and cave.defeated == 0 and cave.total == 22)
	cave.leave("동굴 원화 재입장 검증")
	game.queue_free()
	await _frames(2)
	Prefs.reduce_motion = previous_motion
	Prefs.set_low_resolution(previous_quality)


func _check_hash(label: String, record: Dictionary) -> void:
	var path: String = record["path"]
	check(label + " matches the reviewed pixels", FileAccess.get_sha256("res://" + path) == str(record["sha256"]))


func _check_return_portal(game: Node, cave: DungeonRuntime) -> void:
	var portal := game.world.get_node_or_null("CaveReturnPortal") as IsoSprite
	if not check("the return portal uses its actual measured base", portal != null):
		return
	var base := Village.portal_base(portal)
	check("the return portal's visible base is its collision obstacle", cave.layout.obstacles.has(base))
	# The new asymmetric base reaches farther left from its foot than the old art.
	# Every vertex must fit inside the final chamber with a 20-ground-unit wall lip.
	var safe_chamber := Rect2(4520, -200, 380, 400)
	var fits := not base.is_empty()
	var outside_vertices: Array[String] = []
	for point in base:
		var ground := Iso.unproject(point)
		if not safe_chamber.has_point(ground):
			fits = false
			outside_vertices.append(str(ground))
	check("the full return portal base clears every exit chamber wall lip", fits, "; ".join(outside_vertices))
	var target := Iso.project(DungeonLayout.EXIT)
	var reached := cave.layout.resolve(Iso.project(DungeonLayout.ROOMS[4]), target, Player.RADIUS)
	check("the measured return portal leaves the incoming exit route open", reached.distance_to(target) < 1.0)


func _check_live_interactions(game: Node, forest_target: String, forest_touch: Vector2) -> void:
	var controls: TouchControls = game.hud.controls
	# Stay in the same frame: the old forest button is still painted at its old coordinates.
	game.player.position = Iso.project(DungeonLayout.ROOMS[0])
	check("the transition test still holds the painted forest target", controls._near_name == forest_target and controls._buttons.has("near_shop"))
	controls._press(-1, forest_touch)
	check("a stale forest button cannot open a panel inside a combat room", not game.hud.panel_open())
	game.hud.close_panel()
	controls.release_all()
	controls._layout()
	check("combat rooms remove the forest interaction button", controls._near_name == "" and not controls._buttons.has("near_shop"))
	game.player.position = Vector2.ZERO
	controls._layout()
	var entrance_button: Dictionary = controls._buttons.get("near_shop", {})
	var entrance_touch: Vector2 = entrance_button.get("center", Vector2.ZERO)
	check("the actual cave entrance offers the cave exit interaction", controls._near_name == "동굴 출구" and not entrance_button.is_empty())
	controls._press(-1, entrance_touch)
	check("the current cave interaction opens the real dungeon panel", game.hud._panel is DungeonPanel)
	game.hud.close_panel()
	game.player.position = Iso.project(DungeonLayout.EXIT)
	controls._layout()
	check("the return portal offers the cave exit interaction", controls._near_name == "동굴 출구" and controls._buttons.has("near_shop"))
	game.player.position = Vector2.ZERO
	controls.release_all()
	controls._layout()

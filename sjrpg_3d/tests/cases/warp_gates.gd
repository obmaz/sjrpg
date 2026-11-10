extends TestCase
## Physical gates share discovery and safe travel without permitting remote or combat escapes.


func run() -> void:
	var game := await make_game()
	var route: Exploration = game.exploration
	game._spawn_timer = 10000.0
	game.player.set_process(false)
	route.set_process(false)
	game.quest_runtime.set_process(false)
	var town_portal: IsoSprite = game.village.portal_sprites["town"]
	var town_footprint: PackedVector2Array = game.village.portal_footprints["town"]
	var guardian_portal: IsoSprite = game.world.get_node("GuardianPortal")
	check("the guardian gate also uses the shared portal art scale", is_equal_approx(guardian_portal.k, town_portal.k) and guardian_portal.def == town_portal.def and game.village.solids.has(Village.portal_base(guardian_portal)))
	check("exactly the three functional warp gates share a registry", game.village.portal_sprites.size() == 3)
	for id in Exploration.NAMES:
		var portal: IsoSprite = game.village.portal_sprites[id]
		var base: PackedVector2Array = game.village.portal_footprints[id]
		check("field gate matches the town gate's actual drawing scale: " + id, is_equal_approx(portal.k, town_portal.k) and portal.def == town_portal.def and portal.position == route.gate_point(id))
		if id == "town":
			check("town gate keeps its upright stone blocker",game.village.solids.has(base))
		else:
			check("field waypoint is a walkable ground seal",not game.village.solids.has(base) and not game._blocked(portal.position,Player.RADIUS))
		if id == "tree":
			var terrace_clear := true
			for landmark in game.village.landmarks:
				terrace_clear = terrace_clear and Geometry2D.intersect_polygons(base, landmark.top).is_empty()
				for face in landmark.blockers:
					terrace_clear = terrace_clear and Geometry2D.intersect_polygons(base, face).is_empty()
			check("full-size tree gate base stays clear of the raised entrance", terrace_clear)
		check("warp animation keeps the same geometry and source: " + id, portal.get_child(0) is PlazaWater and portal.get_child(0).surface == portal)
		var approach := route.gate_approach(id)
		check("all three gate approaches are safe: " + id, approach.is_finite() and not game._blocked(approach, Player.RADIUS) and approach.distance_to(route.gate_point(id)) < Exploration.GATE_RANGE)
	game.player.position = game.village.npc_points["보급원 미라"] + Vector2(0, 25)
	check("gate does not steal Mira's first interaction", game.near_npc() == "보급원 미라")
	game.player.position = route.gate_approach()
	check("the real town gate offers a named interaction", route.gate_origin() == "town" and game.near_npc() == "워프게이트")
	check("a new adventure cannot warp to unexplored or later stages", not route.warp("tree") and not route.warp("stage2") and not route.warp("town"))
	game.hud.interact("워프게이트")
	await _frames(2)
	check("gate opens its destination panel and pauses safely", game.hud._panel is WarpGatePanel and get_tree().paused)
	var panel: WarpGatePanel = game.hud._panel
	panel._choose("tree")
	check("locked destination cannot move the hero through the panel", game.player.position.distance_to(route.gate_point("town")) < Exploration.GATE_RANGE and game.hud.panel_open())
	game.hud.close_panel()
	game.player.position = route.gate_approach("tree")
	game.hud.interact("워프게이트")
	await _frames(2)
	check("opening a physically visited field gate discovers it before the pause", GameState.discovered_sanctuaries.has("tree") and route.gate_origin() == "tree")
	check("gate discovery and checkpoint survive reload", GameState.load_game() and GameState.discovered_sanctuaries.has("tree") and GameState.last_sanctuary == "tree")
	game.hud.close_panel()
	game.player.position = route.gate_approach()
	var enemy := Enemy.new()
	enemy.setup(game, "goblin", 1)
	enemy.position = game.player.position + Vector2(60, 0)
	enemy.set_process(false)
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	check("nearby combat blocks the gate", route.gate_block_reason() != "" and not route.warp("tree"))
	game.enemies.erase(enemy)
	enemy.queue_free()
	GameState.boss_summoned = true
	GameState.boss_defeated = false
	check("an active guardian challenge blocks warp", not route.warp("tree"))
	GameState.boss_summoned = false
	var protection := Quests.state("sun")
	protection["phase"] = "accepted"
	protection["started"] = true
	protection["defender_hp"] = 100.0
	check("an active protection quest blocks warp", not route.warp("tree"))
	protection["started"] = false
	game.player.dead = true
	check("a dead hero cannot warp", not route.warp("tree"))
	game.player.dead = false
	var blocked_shape := CylinderShape3D.new()
	blocked_shape.radius = SpatialWorld3D.radius_metres(350.0)
	blocked_shape.height = 8.0
	var blocked_at := SpatialWorld3D.native_point(route.gate_point("tree"), 4.0)
	var blocked_fixture: StaticBody3D = game.spatial_world._shape_body(blocked_shape, Transform3D(Basis.IDENTITY, blocked_at), SpatialWorld3D.SOLID, "BlockedWarpDestination")
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Collider registration advances gameplay time; capture the no-cost/no-move
	# baseline immediately before the actual rejected warp attempt.
	game.player.hp = game.player.max_hp - 10.0
	game.player.resource = 0.0
	var position: Vector2 = game.player.position
	check("blocked destination refuses to fall back onto arbitrary ground", not route.warp("tree") and game.player.position == position and game.player.hp == game.player.max_hp - 10.0 and game.player.resource == 0.0)
	blocked_fixture.collision_layer = 0
	blocked_fixture.queue_free()
	await get_tree().physics_frame
	game.hud.interact("워프게이트")
	await _frames(2)
	panel = game.hud._panel
	game.player.position = position + Vector2(600, 450)
	panel._choose("tree")
	check("a stale open panel revalidates physical gate range", game.hud.panel_open() and game.player.position == position + Vector2(600, 450))
	game.hud.close_panel()
	game.player.position = route.gate_approach()
	var delayed := {"called": false}
	game.player._pending = func(): delayed["called"] = true
	game.player._attack_time = 0.4
	game.player.held_slots[0] = true
	game.player.move_input = Vector2.ONE
	Input.action_press("attack")
	Input.action_press("move_right")
	var gold := GameState.gold
	check("a quiet discovered gate performs the actual warp", route.warp("tree"))
	check("arrival is safely in front of the selected physical gate", not game._blocked(game.player.position, Player.RADIUS) and route.gate_origin() == "tree" and GameState.last_sanctuary == "tree")
	check("warp restores health and resource without charging gold", game.player.hp == game.player.max_hp and game.player.resource == game.player.resource_max and GameState.gold == gold)
	check("warp clears pending and held attacks before the next game tick", not game.player._pending.is_valid() and game.player._attack_time == 0.0 and not delayed["called"] and game.player.held_slots.is_empty() and game.player.move_input == Vector2.ZERO and not Input.is_action_pressed("attack") and not Input.is_action_pressed("move_right"))
	check("arrival camera matches the destination without an old shake", game.camera.position == game.player.position and game.camera.offset == Vector2.ZERO)
	game.hud.interact("워프게이트")
	await _frames(2)
	panel = game.hud._panel
	panel._choose("town")
	check("the destination button returns to the town gate and resumes play", not game.hud.panel_open() and not get_tree().paused and route.gate_origin() == "town")
	game.player.position = game.dungeon.entry_point()
	check("warp cave test can enter the existing Stage1 cave", game.dungeon.enter())
	game.spatial_world.sync_scope()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var cave_portal: IsoSprite = game.world.get_node("CaveReturnPortal")
	check("the cave return gate uses the town portal's scale", is_equal_approx(cave_portal.k, town_portal.k) and cave_portal.def == town_portal.def and cave_portal.get_child(0) is PlazaWater)
	var cave_base := Village.portal_base(cave_portal)
	var cave_base_center := Vector2.ZERO
	for point in cave_base:
		cave_base_center += point
	cave_base_center /= cave_base.size()
	var exit_approach := Iso.project(DungeonLayout.EXIT)
	var stopped: Vector2 = game.move_actor(exit_approach, cave_base_center, Player.RADIUS)
	check("the cave gate stone base blocks real actor movement", game._blocked(cave_base_center, Player.RADIUS) and stopped.distance_to(cave_base_center) > Player.RADIUS * 0.5 and not Geometry2D.is_point_in_polygon(stopped, cave_base))
	game.player.position = exit_approach
	check("the cave return interaction remains approachable", game.dungeon.layout.contains(exit_approach, Player.RADIUS) and game.near_npc() == "동굴 출구")
	check("the cave prevents using world gates remotely", route.gate_origin() == "" and not route.warp("town") and not route.travel("town"))
	game.dungeon.leave("워프 검사")
	game.queue_free()
	await _frames(2)

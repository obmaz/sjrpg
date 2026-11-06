extends TestCase

func run() -> void:
	var game := await make_game()
	var cave: DungeonRuntime = game.dungeon
	check("entry requires the cave entrance", not cave.enter())
	game.player.position = cave.entry_point()
	Quests.state("sun")["phase"] = "accepted"
	Quests.state("sun")["started"] = true
	check("defense blocks cave entry", not cave.enter())
	Quests.state("sun")["started"] = false
	check("cave starts at entrance", cave.enter())
	game.spatial_world.sync_scope()
	# Native static bodies become query-visible on the physics clock. Manual
	# AI ticks below do not advance that clock by themselves.
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("five rooms contain twenty-two enemies", game.enemies.size() == 22 and cave.total == 22)
	# Idle monsters must not drift down the unchosen branch before the hero arrives.
	var idle: Enemy = game.enemies[0]
	idle.position = idle.patrol_center + Vector2(169, 0)
	idle._state = "idle"
	idle._timer = 100.0
	idle._wander = Vector2(0.4, 0)
	var stayed_in_room := true
	for step in 200:
		idle._process(0.1)
		stayed_in_room = stayed_in_room and idle.position.distance_to(idle.patrol_center) <= 170.01
	check("waiting cave enemies stay in their room instead of wandering into branches", stayed_in_room)
	idle.position = idle.patrol_center + Vector2(169, 0)
	game.player.position = idle.patrol_center + Vector2(260, 0)
	idle.force_chase()
	idle._process(0.1)
	check("room patrol bounds do not tether active pursuit", idle.position.distance_to(idle.patrol_center) > 170.0)
	game.player.position = Vector2.ZERO
	check("cave level is fixed on entry", cave.entry_level == GameState.level + 2)
	var hp: float = game.enemies[0].max_hp
	GameState.level += 1
	check("leveling does not rescale existing cave enemies", game.enemies[0].max_hp == hp)
	check("sanctuary travel is disabled in cave", not game.exploration.travel("town"))
	check("cave has only its own map markers", MapGeometry.markers(game).size() == 2)
	# Walk both branch choices through actual collision resolution, without teleporting through walls.
	for side in [-500.0, 500.0]:
		var current := Vector2.ZERO
		for point in [Vector2(700, 0), Vector2(700, side), Vector2(1550, side), Vector2(1550, 0), Vector2(2400, 0), Vector2(2400, -side), Vector2(3250, -side), Vector2(3250, 0), Vector2(4100, 0), DungeonLayout.EXIT]:
			var target := Iso.project(point)
			current = game.resolve_movement(current, target, Player.RADIUS)
			check("cave route reaches %s via %.0f" % [point, side], current.distance_to(target) < 1.0)
	check("off-path space is blocked", game._blocked(Iso.project(Vector2(1100, 0)), Player.RADIUS))
	game.player.position = Vector2.ZERO
	game.hud.open_settings()
	await _frames(3)
	var time_before := cave.remaining
	await _frames(6)
	check("pause stops dungeon timer", cave.remaining == time_before)
	game.hud.close_panel()
	check("cannot finish with live enemies", not cave.complete())
	var quest_kills := GameState.stage_kills
	var xp := GameState.xp
	for enemy in game.enemies.duplicate():
		enemy.take_damage(999999.0, null)
	check("cave kills do not count toward forest quests", GameState.stage_kills == quest_kills)
	check("cave loot and experience are retained", GameState.gold > 0 and (GameState.xp != xp or GameState.level > 2))
	check("must reach the final portal", not cave.complete())
	game.player.position = Iso.project(DungeonLayout.EXIT)
	var gold := GameState.gold
	check("cleared cave completes at the portal", cave.complete() and not cave.active and GameState.gold == gold + 100 + cave.entry_level * 20)
	check("completion reward is paid once", not cave.complete())
	await _frames(2)
	check("exit returns outside and restores the native forest", game.player.position.distance_to(cave.entry_point()) < 1.0 and game.field_root.visibility_layer == 0 and game.ortho_preview._world_environment.forest.visible and not game.ortho_preview._world_environment.cave.visible)
	check("reentry creates a fresh instance", cave.enter() and cave.remaining == 300.0 and cave.defeated == 0 and game.enemies.size() == 22)
	gold = GameState.gold
	cave.tick(301.0)
	check("timeout returns outside without taking earned gold", not cave.active and GameState.gold == gold)
	cave.enter()
	game.player._invulnerable = 0.0
	game.player.take_damage(999999.0)
	await get_tree().create_timer(2.7).timeout
	check("death returns outside with no equipment loss", not cave.active and not game.player.dead and GameState.inventory.size() >= 2)
	game.player.position = cave.entry_point()
	cave.enter()
	GameState.gold = 123
	GameState.save_game()
	game.queue_free()
	await _frames(2)
	check("interrupted cave save requests an outside return", GameState.load_game() and GameState.return_to_cave_entrance and GameState.gold == 123)
	game = preload("res://scripts/game.gd").new()
	add_child(game)
	await _frames(2)
	check("reconnect starts outside the cave", not game.dungeon.active and game.player.position.distance_to(game.dungeon.entry_point()) < 1.0 and GameState.gold == 123)
	game.queue_free()
	await _frames(2)

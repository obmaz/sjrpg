extends TestCase
## Fixed forest sites retain their own packs, real-time charges and surviving members.
const NativeFixture := preload("res://tests/native_combat_fixture.gd")


func run() -> void:
	var original_path := GameState.save_path
	GameState.save_path = "user://tests/encounters-runtime.json"
	GameState.delete_save()
	await _check_initial_and_far_packs()
	await _check_budget_and_space()
	await _check_recharge_clock()
	await _check_live_restore()
	GameState.encounter_capture = Callable()
	GameState.delete_save()
	GameState.save_path = original_path


func _freeze(game: Node) -> void:
	game.set_process(false)
	game.encounters.set_process(false)
	game.player.set_process(false)
	game.exploration.set_process(false)
	for enemy: Enemy in game.enemies:
		enemy.set_process(false)
		enemy.sprite.set_process(false)


func _approach(game: Node, id: String) -> Vector2:
	var stone: EncounterStone = game.encounters.stones[id]
	for radius in [90.0, 120.0, 160.0]:
		for index in 32:
			var at: Vector2 = stone.position + Vector2.from_angle(float(index) * TAU / 32.0) * radius
			if not game.in_town(at) and not game._blocked(at, Player.RADIUS) and game.encounters.clear_line(at, stone.position):
				return at
	check("encounter site has a safe player approach: " + id, false)
	return stone.position + Vector2(90, 0)


func _retire(game: Node) -> void:
	game.queue_free()
	await _frames(2)


func _clear_members(game: Node, id: String) -> void:
	_freeze(game)
	await _frames(2)  # A newly summoned pack is immune only in its creation frame.
	for member in game.encounters._members[id].duplicate():
		if is_instance_valid(member) and not member.dead:
			member.take_damage(999999.0, game.player)
	await _frames(2)


func _check_positions(game: Node, id: String) -> void:
	var valid := true
	var separated := true
	var members: Array[Enemy] = []
	for member in game.encounters._members[id]:
		if is_instance_valid(member) and not member.dead:
			members.append(member)
	for i in members.size():
		var enemy: Enemy = members[i]
		valid = valid and not game.in_town(enemy.position) and game._inside_field(enemy.position, 80.0)
		valid = valid and not game.spatial_world.blocked(enemy.position, enemy.radius + 10.0, true)
		valid = valid and enemy.position.distance_to(game.player.position) > 135.0
		valid = valid and enemy.encounter_id == id and enemy.spawn_level in [1, 3, 5, 7]
		for j in range(i):
			separated = separated and enemy.position.distance_to(members[j].position) >= enemy.radius + members[j].radius + 8.0
	check("pack uses free forest positions and the area's fixed levels: " + id, valid)
	check("pack members do not overlap one another: " + id, separated)


func _check_initial_and_far_packs() -> void:
	var game := await make_game()
	_freeze(game)
	var runtime: EncounterRuntime = game.encounters
	var fresh: bool = runtime.states.size() == 6 and runtime.stones.size() == 6
	for state: Dictionary in runtime.states.values():
		fresh = fresh and int(state["charges"]) == 3 and not state["initial_spawned"] and state["members"].is_empty()
	check("fresh forest registers six unspent encounter sites", fresh)
	game.player.position = _approach(game, "west")
	var stone: EncounterStone = runtime.stones["west"]
	check("a dormant site cannot bypass its first pack by being hit", not stone.take_damage(1.0, game.player) and int(runtime.states["west"]["charges"]) == 3)
	var initial := runtime.spawn_wave("west", true)
	_freeze(game)
	check("first nearby encounter creates four enemies without spending a charge", initial == 4 and runtime.living("west") == 4 and int(runtime.states["west"]["charges"]) == 3 and runtime.states["west"]["initial_spawned"])
	_check_positions(game, "west")
	check("a site's surviving pack prevents another summon", not runtime.can_summon("west") and not stone.take_damage(1.0, game.player) and int(runtime.states["west"]["charges"]) == 3)
	await _clear_members(game, "west")
	check("clearing a pack arms its stone without automatically spawning replacements", runtime.can_summon("west") and runtime.living("west") == 0 and int(runtime.states["west"]["charges"]) == 3)
	GameState.level = 15
	game.player.position = _approach(game, "deep_west")
	var far_initial := runtime.spawn_wave("deep_west", true)
	_freeze(game)
	check("first distant encounter creates six enemies and keeps all charges", far_initial == 6 and runtime.living("deep_west") == 6 and int(runtime.states["deep_west"]["charges"]) == 3)
	_check_positions(game, "deep_west")
	await _clear_members(game, "deep_west")
	check("a resolved hit at a cleared distant site summons eight and spends one charge", runtime.stones["deep_west"].take_damage(1.0, game.player) and runtime.living("deep_west") == 8 and int(runtime.states["deep_west"]["charges"]) == 2)
	_freeze(game)
	_check_positions(game, "deep_west")
	await _retire(game)


func _ambient_fixture(game: Node, index: int) -> Enemy:
	var enemy := Enemy.new()
	enemy.setup(game, "goblin", 1)
	enemy.position = game.player.position + Vector2(800 + index * 65, 600)
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	enemy.set_process(false)
	enemy.sprite.set_process(false)
	return enemy


func _rectangle(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


func _check_budget_and_space() -> void:
	var game := await make_game()
	_freeze(game)
	var runtime: EncounterRuntime = game.encounters
	game.player.position = _approach(game, "west")
	runtime.states["west"]["initial_spawned"] = true
	var fillers: Array[Enemy] = []
	for index in 30:
		fillers.append(_ambient_fixture(game, index))
	check("the global thirty-enemy cap rejects a summon without spending a charge", not runtime.stones["west"].take_damage(1.0, game.player) and int(runtime.states["west"]["charges"]) == 3 and game.enemies.size() == 30)
	game.enemies.erase(fillers[0])
	fillers[0].queue_free()
	check("the last available slot creates one enemy without exceeding the global cap", runtime.stones["west"].take_damage(1.0, game.player) and runtime.living("west") == 1 and game.enemies.size() == 30 and int(runtime.states["west"]["charges"]) == 2)
	_freeze(game)
	await _retire(game)
	game = await make_game()
	_freeze(game)
	runtime = game.encounters
	game.player.position = _approach(game, "west")
	var contact: Vector2 = game.player.position.move_toward(runtime.stones["west"].position, 30.0)
	check("no-space fixture has a clear close native approach", not game._blocked(contact, Player.RADIUS) and runtime.clear_line(contact, runtime.stones["west"].position))
	game.spatial_world.teleport_source_actor(game.player, contact, Player.RADIUS)
	runtime.states["west"]["initial_spawned"] = true
	# Leave only a 180px square around the hero open. It permits the stone's
	# short contact ray, but no point in it is >135px away as spawning requires.
	var at: Vector2 = game.player.position
	var blockers: Array[StaticBody3D] = []
	for rect in [Rect2(-10000, -10000, at.x - 90 + 10000, 20000),
			Rect2(at.x + 90, -10000, 10000 - at.x - 90, 20000),
			Rect2(at.x - 90, -10000, 180, at.y - 90 + 10000),
			Rect2(at.x - 90, at.y + 90, 180, 10000 - at.y - 90)]:
		blockers.append(NativeFixture.prism(game.spatial_world, _rectangle(rect)))
	await NativeFixture.settle(get_tree())
	check("no-space fixture blocks actual native spawn capsules", game._blocked(at + Vector2(180, 0), Enemy.RADIUS + 10.0))
	check("no-space fixture leaves a valid strike ray", runtime.clear_line(at, runtime.stones["west"].position))
	check("a valid hit with no free spawn position retains its charge", not runtime.stones["west"].take_damage(1.0, game.player) and runtime.living("west") == 0 and int(runtime.states["west"]["charges"]) == 3)
	NativeFixture.remove(blockers)
	await NativeFixture.settle(get_tree())
	check("a later resolved hit succeeds after space becomes available", runtime.stones["west"].take_damage(1.0, game.player) and runtime.living("west") == 6 and int(runtime.states["west"]["charges"]) == 2)
	_freeze(game)
	await _retire(game)


func _check_recharge_clock() -> void:
	var game := await make_game()
	_freeze(game)
	var runtime: EncounterRuntime = game.encounters
	var state: Dictionary = runtime.states["west"]
	state["charges"] = 1
	runtime._process(299.75)
	check("faster combat never shortens the real five-minute recharge", int(state["charges"]) == 1 and is_equal_approx(float(state["recharge"]), 299.75))
	runtime._process(0.25)
	check("one charge is restored at exactly three hundred active seconds", int(state["charges"]) == 2 and is_zero_approx(float(state["recharge"])))
	runtime._process(900.0)
	check("long active updates cap at three and discard full-stock overflow", int(state["charges"]) == 3 and is_zero_approx(float(state["recharge"])))
	state["charges"] = 0
	state["recharge"] = 42.5
	game.dungeon.active = true
	runtime._process(500.0)
	check("time spent inside the cave does not recharge forest encounters", int(state["charges"]) == 0 and is_equal_approx(float(state["recharge"]), 42.5))
	game.dungeon.active = false
	runtime.set_process(true)
	await _frames(2)
	game.hud.open_settings()
	var paused_recharge: float = state["recharge"]
	await _frames(5)
	check("the real pause menu freezes encounter recharge", float(state["recharge"]) == paused_recharge)
	game.hud.close_panel()
	await _frames(2)
	runtime.set_process(false)
	check("active forest recharge resumes after closing the pause menu", float(state["recharge"]) > paused_recharge)
	await _retire(game)


func _check_live_restore() -> void:
	var game := await make_game()
	_freeze(game)
	var runtime: EncounterRuntime = game.encounters
	game.player.position = _approach(game, "west")
	var spawned := runtime.spawn_wave("west", true)
	_freeze(game)
	if not check("restore fixture creates its first nearby pack", spawned == 4):
		await _retire(game)
		return
	await _frames(2)
	var survivor: Enemy = runtime._members["west"][0]
	for candidate: Enemy in runtime._members["west"]:
		if candidate.radius > survivor.radius:
			survivor = candidate
	survivor.hp = survivor.max_hp * 0.55
	for enemy: Enemy in runtime._members["west"].duplicate():
		if enemy != survivor:
			enemy.take_damage(999999.0, game.player)
	runtime.states["west"]["charges"] = 1
	runtime.states["west"]["recharge"] = 121.25
	check("saving captures the actual surviving pack", GameState.save_game())
	var expected: Dictionary = runtime.states["west"]["members"][0].duplicate(true)
	check("snapshot excludes defeated members", runtime.states["west"]["members"].size() == 1)
	check("saved survivor state can be restored while the old world still exists", GameState.load_game())
	var loaded: Dictionary = GameState.encounters["west"].duplicate(true)
	runtime.states["west"]["charges"] = 0
	runtime._process(600.0)
	check("a detached old runtime cannot recharge the restored state", GameState.encounters["west"] == loaded and not GameState.encounter_capture.is_valid())
	await _retire(game)
	await _frames(3)
	check("offline frames do not grant recharge on reload", GameState.load_game() and is_equal_approx(float(GameState.encounters["west"]["recharge"]), 121.25) and int(GameState.encounters["west"]["charges"]) == 1)
	game = preload("res://scripts/game.gd").new()
	add_child(game)
	await _native_ready(game)
	_freeze(game)
	await _frames(2)
	runtime = game.encounters
	check("the saved initial pack is not recreated on continuation", runtime.living("west") == 1 and runtime.states["west"]["initial_spawned"] and int(runtime.states["west"]["charges"]) == 1)
	if runtime.living("west") == 1:
		var restored: Enemy = runtime._members["west"][0]
		check("the live survivor keeps its species, level and exact health", restored.kind == expected["kind"] and restored.spawn_level == int(expected["level"]) and is_equal_approx(restored.hp, float(expected["hp"])))
		var restored_body: CharacterBody3D = game.spatial_world.actor_bodies[restored.get_instance_id()]
		check("restored species uses its current canonical footprint", restored.radius == Enemy.radius_for(str(expected["kind"])) and is_equal_approx(float(restored_body.get_meta("radius_pixels")), restored.radius))
		check("survivor restore uses an unblocked forest position", not game.in_town(restored.position) and not game.spatial_world.blocked(restored.position, restored.radius + 10.0, true))
	await _retire(game)
	GameState.encounter_capture = Callable()
	GameState.delete_save()
	var legacy := FileAccess.open(GameState.save_path, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"class": "warrior", "level": 2, "gold": 17}))
	legacy.close()
	check("pre-encounter saves load successfully", GameState.load_game())
	game = preload("res://scripts/game.gd").new()
	add_child(game)
	await _native_ready(game)
	_freeze(game)
	var fresh: bool = game.encounters.states.size() == 6
	for state: Dictionary in game.encounters.states.values():
		fresh = fresh and int(state["charges"]) == 3 and not state["initial_spawned"] and state["members"].is_empty()
	check("continuing a legacy save creates six fresh sites", fresh and GameState.gold == 17)
	await _retire(game)


func _native_ready(game: Node) -> void:
	while not game.native_ready:
		await get_tree().physics_frame
		await _frames(1)

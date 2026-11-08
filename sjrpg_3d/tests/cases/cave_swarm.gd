extends TestCase
## Real stone contacts create an atomic twenty-sprite pack with bounded native physics.
const NativeFixture := preload("res://tests/native_combat_fixture.gd")
const SITE := EncounterRuntime.CAVE_SITE


func run() -> void:
	var previous_path := GameState.save_path
	GameState.save_path = "user://tests/cave-swarm.json"
	GameState.delete_save()
	await _check_real_contact_and_restore()
	await _check_reserved_budget()
	await _check_no_space()
	GameState.encounter_capture = Callable()
	GameState.delete_save()
	GameState.save_path = previous_path


func _freeze(game: Node) -> void:
	game.set_process(false)
	game.encounters.set_process(false)
	game.player.set_process(false)
	game.exploration.set_process(false)
	for enemy: Enemy in game.enemies:
		enemy.set_process(false)
		enemy.sprite.set_process(false)


func _approach(game: Node) -> Vector2:
	var stone: EncounterStone = game.encounters.stones[SITE]
	for distance: float in [60.0, 90.0, 120.0]:
		for index in 32:
			var at := stone.position + Vector2.from_angle(float(index) * TAU / 32.0) * distance
			if not game.in_town(at) and not game._blocked(at, Player.RADIUS) and game.encounters.clear_line(at, stone.position):
				return at
	check("the cave marker has an actual clear player attack approach", false)
	return stone.position + Vector2(90, 0)


func _prepare(game: Node) -> void:
	_freeze(game)
	game.spatial_world.teleport_source_actor(game.player, _approach(game), Player.RADIUS)
	await NativeFixture.settle(get_tree())


func _retire(game: Node) -> void:
	game.queue_free()
	await _frames(3)


func _check_pack(game: Node, expected: int, phase: String) -> void:
	var members: Array = game.encounters._members[SITE]
	var actual := 0
	var violations: Array[Dictionary] = []
	for index in members.size():
		var enemy: Enemy = members[index]
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		actual += 1
		var town: bool = game.in_town(enemy.position)
		var inside: bool = game._inside_field(enemy.position, 80.0)
		var blocked: bool = game.spatial_world.blocked(enemy.position, enemy.radius + 10.0, true)
		var player_distance: float = enemy.position.distance_to(game.player.position)
		var identity_ok := enemy.kind == "goblin" and enemy.encounter_id == SITE and str(enemy.get_meta("visual_variant", "")) == EncounterRuntime.CAVE_VISUAL_VARIANT
		if not identity_ok or town or not inside or blocked or player_distance <= 135.0:
			violations.append({"index": index, "position": [enemy.position.x, enemy.position.y], "identity_ok": identity_ok, "in_town": town, "inside_field": inside, "blocked": blocked, "player_distance": player_distance})
		for previous in range(index):
			var peer: Enemy = members[previous]
			if is_instance_valid(peer) and not peer.dead:
				var distance := enemy.position.distance_to(peer.position)
				var required := enemy.radius + peer.radius + 8.0
				if distance < required:
					violations.append({"index": index, "peer": previous, "position": [enemy.position.x, enemy.position.y], "peer_position": [peer.position.x, peer.position.y], "distance": distance, "required": required})
	check(phase + " cave wave retains exactly the requested living member count", actual == expected)
	check(phase + " sprite enemies retain distinct native bodies on free supported forest ground", violations.is_empty(), JSON.stringify({"phase": phase, "player": [game.player.position.x, game.player.position.y], "violations": violations}))


func _check_real_contact_and_restore() -> void:
	var game := await make_game()
	await _prepare(game)
	var runtime: EncounterRuntime = game.encounters
	var stone: EncounterStone = runtime.stones[SITE]
	check("new cave marker is beside the real entrance and outside the castle", stone.position.distance_to(game.dungeon.entry_point()) < 700.0 and not game.in_town(stone.position) and not game.spatial_world.blocked(game.player.position, Player.RADIUS))
	check("walking to the marker does not automatically spawn the demonstration wave", runtime.living(SITE) == 0 and runtime.states[SITE]["initial_spawned"] and runtime.spawn_wave(SITE, true) == 0)
	game.player.facing = (game.player.position - stone.position).angle()
	check("the real basic attack can target the cave marker", game.player.cast_slot(0))
	check("an accepted button press does not spawn before its contact frame", runtime.living(SITE) == 0)
	game.player._process(game.player._attack_duration * 0.46)
	_freeze(game)
	if not check("one resolved melee contact summons all twenty at once", runtime.living(SITE) == 20):
		await _retire(game)
		return
	_check_pack(game, 20, "fresh")
	check("the unlimited demonstration marker does not consume a five-minute charge", int(runtime.states[SITE]["charges"]) == 3 and is_zero_approx(float(runtime.states[SITE]["recharge"])))
	check("further hits cannot stack a second live wave", not stone.take_damage(1.0, game.player) and runtime.living(SITE) == 20)
	await _frames(2)
	var survivor: Enemy = runtime._members[SITE][0]
	survivor.take_damage(1.0, game.player)
	var saved_health := survivor.hp
	check("twenty cave members serialize through the actual save validator", GameState.save_game())
	var saved: Array = runtime.states[SITE]["members"].duplicate(true)
	check("the saved pack contains all twenty members", saved.size() == 20)
	check("the same save loads without changing in-memory source references", GameState.load_game())
	await _retire(game)
	game = preload("res://scripts/game.gd").new()
	add_child(game)
	var saw_loading_pack := false
	var quiet_loading_pack := true
	var loading_positions: Array[Vector2] = []
	while not game.native_ready:
		if game.encounters._members.has(SITE):
			var loading_members: Array = game.encounters._members[SITE]
			if not saw_loading_pack:
				saw_loading_pack = true
				for member: Enemy in loading_members:
					loading_positions.append(member.position)
			game.encounters._process(0.5)
			for index in loading_members.size():
				var member: Enemy = loading_members[index]
				quiet_loading_pack = quiet_loading_pack and not member.is_processing() and not member.sprite.is_processing()
				quiet_loading_pack = quiet_loading_pack and member.position.distance_to(loading_positions[index]) < 0.01
				quiet_loading_pack = quiet_loading_pack and member._state == "idle" and is_zero_approx(member._walk_cycle) and is_zero_approx(member._timer)
		await get_tree().process_frame
	_freeze(game)
	check("continuation actually observes the restored pack before native startup completes", saw_loading_pack)
	check("restored enemies keep their positions and idle clocks behind the loading overlay", quiet_loading_pack)
	runtime = game.encounters
	check("continuing restores the surviving twenty-pack without auto-summoning more", runtime.living(SITE) == 20)
	if runtime.living(SITE) == 20:
		var restored: Enemy = runtime._members[SITE][0]
		check("continuation restores actual damage and the sprite variant", is_equal_approx(restored.hp, saved_health) and str(restored.get_meta("visual_variant", "")) == EncounterRuntime.CAVE_VISUAL_VARIANT)
		_check_pack(game, 20, "restored")
		await _prepare(game)
		await _frames(2)
		for member: Enemy in runtime._members[SITE].duplicate():
			member.take_damage(999999.0, game.player)
		check("the swing clearing the last member cannot immediately re-summon", runtime.living(SITE) == 0 and not runtime.stones[SITE].take_damage(1.0, game.player))
		await _frames(2)
		check("a later deliberate hit re-summons another complete twenty-pack", runtime.stones[SITE].take_damage(1.0, game.player) and runtime.living(SITE) == 20 and int(runtime.states[SITE]["charges"]) == 3)
		_freeze(game)
	await _retire(game)


func _filler(game: Node, index: int, site_id := "") -> Enemy:
	var at: Vector2 = game.player.position + Vector2(850 + index * 12, 650)
	var enemy: Enemy
	if site_id != "":
		game.encounters.states[site_id]["initial_spawned"] = true
		enemy = game.encounters._create_enemy(site_id, "goblin", 1, at)
	else:
		enemy = Enemy.new()
		enemy.setup(game, "goblin", 1)
		enemy.position = at
		enemy.is_threat = true
		game.world.add_child(enemy)
		game.enemies.append(enemy)
	enemy.set_process(false)
	enemy.sprite.set_process(false)
	return enemy


func _check_reserved_budget() -> void:
	var game := await make_game()
	await _prepare(game)
	var runtime: EncounterRuntime = game.encounters
	for index in EncounterRuntime.MAX_ENEMIES:
		var site_id: String = ["north", "east", "south"][mini(2, floori(float(index) / 12.0))]
		_filler(game, index, site_id)
	check("the twenty reserved sprite slots work even while all thirty ordinary slots are occupied", runtime.stones[SITE].take_damage(1.0, game.player) and runtime.living(SITE) == 20 and game.enemies.size() == EncounterRuntime.CAVE_ENEMY_LIMIT)
	_freeze(game)
	check("the actual save accepts twenty cave members alongside thirty ordinary saved members", GameState.save_game())
	var stored_members := 0
	for state: Dictionary in runtime.states.values():
		stored_members += (state["members"] as Array).size()
	check("the serialized fifty-member snapshot retains every pack", stored_members == 50 and (runtime.states[SITE]["members"] as Array).size() == 20)
	game.player.position = runtime.stones["west"].position + Vector2(90, 0)
	runtime.states["west"]["initial_spawned"] = true
	check("ordinary encounter spawning still obeys its original thirty-enemy ceiling", runtime.spawn_wave("west", false) == 0 and runtime.living("west") == 0 and int(runtime.states["west"]["charges"]) == 3)
	await _retire(game)

	game = await make_game()
	await _prepare(game)
	runtime = game.encounters
	for index in range(EncounterRuntime.MAX_ENEMIES + 1):
		_filler(game, index)
	var before: int = game.enemies.size()
	check("a protected battlefield with only nineteen reserved slots rejects the entire wave", not runtime.stones[SITE].take_damage(1.0, game.player) and runtime.living(SITE) == 0 and game.enemies.size() == before and int(runtime.states[SITE]["charges"]) == 3)
	await _retire(game)


func _rectangle(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


func _check_no_space() -> void:
	var game := await make_game()
	await _prepare(game)
	var runtime: EncounterRuntime = game.encounters
	var at: Vector2 = game.player.position
	var blockers: Array[StaticBody3D] = []
	for rect in [Rect2(-10000, -10000, at.x - 90 + 10000, 20000),
			Rect2(at.x + 90, -10000, 10000 - at.x - 90, 20000),
			Rect2(at.x - 90, -10000, 180, at.y - 90 + 10000),
			Rect2(at.x - 90, at.y + 90, 180, 10000 - at.y - 90)]:
		blockers.append(NativeFixture.prism(game.spatial_world, _rectangle(rect)))
	await NativeFixture.settle(get_tree())
	check("the cramped fixture keeps the real strike ray open", runtime.clear_line(at, runtime.stones[SITE].position))
	check("insufficient native floor space never creates a partial wave or spends a charge", not runtime.stones[SITE].take_damage(1.0, game.player) and runtime.living(SITE) == 0 and game.enemies.is_empty() and int(runtime.states[SITE]["charges"]) == 3)
	NativeFixture.remove(blockers)
	await NativeFixture.settle(get_tree())
	check("a later hit summons exactly twenty once real space is restored", runtime.stones[SITE].take_damage(1.0, game.player) and runtime.living(SITE) == 20)
	_freeze(game)
	await _retire(game)

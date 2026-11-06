extends TestCase
## Summoning requires a resolved player contact, with the same targeting as real attacks.


func run() -> void:
	var original_path := GameState.save_path
	GameState.save_path = "user://tests/encounter-combat.json"
	GameState.delete_save()
	await _check_rejected_contacts()
	await _check_real_melee_and_clear_frame()
	await _check_actual_spell_projectile()
	await _check_exploding_projectile()
	await _check_chain_target()
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


func _approach(game: Node, distance: float) -> Vector2:
	var stone: EncounterStone = game.encounters.stones["west"]
	for index in 32:
		var at := stone.position + Vector2.from_angle(float(index) * TAU / 32.0) * distance
		if not game.in_town(at) and not game._blocked(at, Player.RADIUS) and game.encounters.clear_line(at, stone.position):
			return at
	check("west stone has an unobstructed combat approach", false)
	return stone.position + Vector2(distance, 0)


func _retire(game: Node) -> void:
	game.queue_free()
	await _frames(2)


func _ready_site(game: Node, distance: float) -> void:
	_freeze(game)
	game.encounters.states["west"]["initial_spawned"] = true
	game.player.position = _approach(game, distance)


func _projectile(game: Node, ground: Vector2, direction: Vector2, owner: Node2D) -> Effect:
	var shot := Effect.new()
	shot.kind = "proj"
	shot.position = ground - Vector2(0, 34)
	shot.velocity = direction * 600.0
	shot.damage = 5.0
	shot.life = 1.0
	shot.owner_node = owner
	game._add_effect(shot)
	shot.set_process(false)
	return shot


func _check_rejected_contacts() -> void:
	var game := await make_game()
	_ready_site(game, 160.0)
	var runtime: EncounterRuntime = game.encounters
	var stone: EncounterStone = runtime.stones["west"]
	var player: Player = game.player
	check("zero damage and ownerless contacts cannot spend a charge", not stone.take_damage(0.0, player) and not stone.take_damage(5.0, null) and int(runtime.states["west"]["charges"]) == 3)
	var enemy := Enemy.new()
	enemy.setup(game, "goblin", 1)
	enemy.position = player.position + Vector2(700, 400)
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	enemy.set_process(false)
	var hostile := _projectile(game, player.position, Vector2.RIGHT, enemy)
	check("enemy melee and enemy-owned effects cannot activate a player encounter", not stone.take_damage(5.0, enemy) and not stone.take_damage(5.0, hostile) and int(runtime.states["west"]["charges"]) == 3)
	var direction := (stone.position - player.position).normalized()
	game.break_chests_in_arc(player.position, direction.angle() + PI, 200.0, 0.2, player)
	check("a stone inside the radius but outside the actual attack arc stays unspent", int(runtime.states["west"]["charges"]) == 3 and runtime.living("west") == 0)
	var miss_start := player.position + direction.orthogonal() * 140.0
	var miss := _projectile(game, miss_start, direction, player)
	check("a passing projectile does not acquire a false stone contact", runtime.projectile_contacts(miss_start, miss_start + direction * 400.0).is_empty())
	miss._process(0.4)
	check("a real projectile miss leaves charges intact", int(runtime.states["west"]["charges"]) == 3 and runtime.living("west") == 0)
	var middle := player.position.lerp(stone.position, 0.5)
	var side := direction.orthogonal() * 70.0
	var thickness := direction * 6.0
	game.village.solids.append(PackedVector2Array([middle - side - thickness, middle + side - thickness, middle + side + thickness, middle - side + thickness]))
	check("wall fixture really blocks the contact ray", not runtime.clear_line(player.position, stone.position))
	check("damage naming the player cannot activate a stone through a wall", not stone.take_damage(5.0, player) and int(runtime.states["west"]["charges"]) == 3)
	var blocked := _projectile(game, player.position, direction, player)
	blocked._process(0.4)
	check("a swept player projectile also respects the wall before spending a charge", int(runtime.states["west"]["charges"]) == 3 and runtime.living("west") == 0)
	game.village.solids.pop_back()
	runtime.states["west"]["charges"] = 0
	check("an empty stone rejects a valid player contact", not stone.take_damage(5.0, player) and runtime.living("west") == 0)
	await _retire(game)


func _finish_action(player: Player) -> void:
	player._hitstop.clear()
	player._process(1.0)


func _check_real_melee_and_clear_frame() -> void:
	var game := await make_game()
	_ready_site(game, 60.0)
	var runtime: EncounterRuntime = game.encounters
	var stone: EncounterStone = runtime.stones["west"]
	var player: Player = game.player
	player.facing = (player.position - stone.position).angle()
	check("the basic attack can aim at a cleared encounter stone", player.cast_slot(0))
	check("an accepted button press does not spend a charge during windup", int(runtime.states["west"]["charges"]) == 3 and runtime.living("west") == 0)
	player._process(player._attack_duration * 0.46)
	_freeze(game)
	check("the actual basic attack's impact summons six nearby enemies and spends one", int(runtime.states["west"]["charges"]) == 2 and runtime.living("west") == 6)
	if runtime.living("west") != 6:
		await _retire(game)
		return
	var target: Enemy = runtime._members["west"][0]
	var before := target.hp
	target.take_damage(999999.0, player)
	check("a new summon survives all damage in its creation process frame", not target.dead and target.hp == before)
	await _frames(2)
	target.take_damage(1.0, player)
	check("spawn protection expires on later resolved contacts", is_equal_approx(target.hp, before - 1.0))
	var current: Array[Enemy] = []
	for member: Enemy in runtime._members["west"]:
		if is_instance_valid(member) and not member.dead:
			current.append(member)
	var last: Enemy = current.back()
	for member in current:
		if member != last:
			member.take_damage(999999.0, player)
	var toward := (stone.position - player.position).normalized()
	last.position = player.position + toward * 26.0
	last.hp = 0.01
	_finish_action(player)
	check("a new basic attack resolves against the last surviving enemy", player.cast_slot(0))
	player._process(player._attack_duration * 0.46)
	check("killing the last enemy does not let the same swing re-summon its pack", last.dead and runtime.living("west") == 0 and int(runtime.states["west"]["charges"]) == 2)
	check("the cleared-frame guard prevents another contact in that process frame", not stone.take_damage(5.0, player) and int(runtime.states["west"]["charges"]) == 2)
	await _frames(2)
	_finish_action(player)
	check("a later deliberate attack can target the newly armed stone", player.cast_slot(0))
	player._process(player._attack_duration * 0.46)
	_freeze(game)
	check("the next resolved swing spends exactly one further charge", runtime.living("west") == 6 and int(runtime.states["west"]["charges"]) == 1)
	check("further contacts while that pack is alive cannot spend another", not stone.take_damage(5.0, player) and int(runtime.states["west"]["charges"]) == 1)
	await _retire(game)


func _check_actual_spell_projectile() -> void:
	var game := await make_game("mage")
	_ready_site(game, 160.0)
	var runtime: EncounterRuntime = game.encounters
	var player: Player = game.player
	check("the real firebolt can target a cleared stone without an enemy", player.cast_slot(0))
	player._process(player._attack_duration * 0.46)
	var shots: Array[Effect] = []
	for child in game.world.get_children():
		if child is Effect and child.kind == "proj" and child.owner_node == player:
			child.set_process(false)
			shots.append(child)
	check("spell release creates an actual owned projectile without pre-spending", not shots.is_empty() and int(runtime.states["west"]["charges"]) == 3)
	if not shots.is_empty():
		var shot: Effect = shots[0]
		shot._process(0.4)
		_freeze(game)
		check("the actual swept firebolt contact spends one charge and stops at the stone", int(runtime.states["west"]["charges"]) == 2 and runtime.living("west") == 6 and shot.is_queued_for_deletion())
		var all_fresh := true
		for member: Enemy in runtime._members["west"]:
			all_fresh = all_fresh and not member.dead and member.hp == member.max_hp
		check("the projectile that summons a pack cannot also wound its new members", all_fresh)
	await _retire(game)


func _check_exploding_projectile() -> void:
	var game := await make_game("mage")
	_ready_site(game, 160.0)
	var stone: EncounterStone = game.encounters.stones["west"]
	var direction: Vector2 = (stone.position - game.player.position).normalized()
	var victim := Enemy.new()
	victim.setup(game, "goblin", 1)
	victim.hp = 1000.0
	victim.max_hp = 1000.0
	victim.position = stone.position + direction * 65.0
	game.world.add_child(victim)
	game.enemies.append(victim)
	victim.set_process(false)
	var shot := _projectile(game, game.player.position, direction, game.player)
	shot.params["explode"] = 140.0
	shot._process(0.5)
	check("a stone collision still explodes against existing nearby enemies", is_equal_approx(victim.hp, 995.0) and shot.is_queued_for_deletion())
	check("explosive stone contact keeps its visible blast", game.cosmetic_effects.any(func(effect: Effect): return effect.kind == "nova" and is_equal_approx(effect.radius, 140.0)))
	check("the explosive contact spends exactly one charge", int(game.encounters.states["west"]["charges"]) == 2)
	var fresh_alive := true
	for enemy in game.encounters._members["west"]:
		fresh_alive = fresh_alive and enemy.hp == enemy.max_hp
	check("the same explosion does not damage its newly summoned wave", fresh_alive)
	await _retire(game)


func _check_chain_target() -> void:
	var game := await make_game("mage")
	_ready_site(game, 160.0)
	var runtime: EncounterRuntime = game.encounters
	var player: Player = game.player
	GameState.ranks["chainLightning"] = 1
	GameState.slots[1] = "chainLightning"
	player.resource = player.resource_max
	check("chain lightning accepts a ready stone as its first contact", player.cast_slot(1))
	check("chain targeting keeps the charge until its release", int(runtime.states["west"]["charges"]) == 3)
	player._process(player._attack_duration * 0.46)
	_freeze(game)
	check("the actual deferred chain release summons its target's pack once", int(runtime.states["west"]["charges"]) == 2 and runtime.living("west") == 6)
	await _retire(game)

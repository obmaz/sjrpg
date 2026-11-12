extends TestCase
## Actual walkable geometry, not drawing Z, separates melee across raised ledges.
const NativeFixture := preload("res://tests/native_combat_fixture.gd")


class StoneContactProbe:
	extends EncounterStone
	var contacts := 0

	func take_damage(_amount: float, _source: Node2D) -> bool:
		contacts += 1
		return false

	func _process(_delta: float) -> void:
		pass

	func _draw() -> void:
		pass


func _ledge_pair(game: Node) -> PackedVector2Array:
	for landmark: Landmark in game.village.landmarks:
		var center := Vector2.ZERO
		for point in landmark.top:
			center += point
		center /= landmark.top.size()
		var definition: Dictionary = Landmark.data()[landmark.index]
		for index in landmark.top.size():
			if index == int(definition["entrance"]):
				continue
			var a := landmark.top[index]
			var b := landmark.top[(index + 1) % landmark.top.size()]
			if a.distance_to(b) < 100.0:
				continue
			var middle := (a + b) * 0.5
			var outward := (middle - center).normalized()
			var upper := middle - outward * 22.0
			var lower := middle + outward * 30.0
			if landmark.contains_top(upper) and not landmark.contains_top(lower) and not game._blocked(upper, 10.0) and not game._blocked(lower, 10.0) and float(TerrainLevels.sample(game.village, upper)["height"]) > TerrainLevels.STEP_REACH:
				return PackedVector2Array([upper, lower, center])
	return PackedVector2Array()


func _target(game: Node, at: Vector2) -> Enemy:
	var enemy := Enemy.new()
	enemy.setup(game, "goblin", 1)
	enemy.position = at
	enemy.hp = 100000.0
	enemy.max_hp = enemy.hp
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	enemy.set_process(false)
	return enemy


func _enemy_swing(enemy: Enemy) -> void:
	enemy._state = "windup"
	enemy._timer = 0.0
	enemy._windup_duration = 0.1
	enemy._hitstop.clear()
	enemy._freeze_time = 0.0
	enemy._stun_time = 0.0
	enemy._process(0.01)


func _area_arena(game: Node) -> Dictionary:
	# Five metres exceeds warcry's 200+26px spatial budget (about3.58m).
	# A low ledge may legitimately be within an area attack's3D range.
	var bodies: Array[StaticBody3D] = []
	bodies.append(NativeFixture.box(game.spatial_world, NativeFixture.remote_at(Vector3(120, -0.5, 120)), Vector3(20, 1, 20), SpatialWorld3D.FLOOR))
	bodies.append(NativeFixture.box(game.spatial_world, NativeFixture.remote_at(Vector3(122, 4.9, 120)), Vector3(4, 0.2, 4), SpatialWorld3D.FLOOR))
	await NativeFixture.settle(get_tree())
	var upper := WorldSpace3D.world_to_projected(NativeFixture.remote_at(Vector3(120.6, 5, 120)))
	var lower := WorldSpace3D.world_to_projected(NativeFixture.remote_at(Vector3(119.4, 0, 120)))
	var center := WorldSpace3D.world_to_projected(NativeFixture.remote_at(Vector3(122, 5, 120)))
	var anchor := _target(game, upper.lerp(center, 0.08))
	game.spatial_world.teleport_source_actor(anchor, anchor.position, Enemy.RADIUS, true)
	check("area fixture uses a real five-metre native floor separation", is_equal_approx(game.spatial_world.height_at(upper), 5.0) and is_zero_approx(game.spatial_world.height_at(lower)))
	check("native area range excludes another storey but retains same-floor targets", not game.enemies_in_radius(lower, 100.0).has(anchor) and game.enemies_in_radius(upper, 100.0).has(anchor))
	return {"bodies": bodies, "upper": upper, "lower": lower, "anchor": anchor}


func run() -> void:
	var game := await make_game()
	game.set_process(false)
	game.encounters.set_process(false)
	game.quest_runtime.set_process(false)
	game.exploration.set_process(false)
	var hero: Player = game.player
	hero.set_process(false)
	game._spawn_timer = 10000.0
	var pair := _ledge_pair(game)
	check("fixture finds clear close positions above and below a real measured ledge", pair.size() == 3)
	if pair.size() != 3:
		game.queue_free()
		await _frames(2)
		return
	var upper := pair[0]
	var lower := pair[1]
	var center := pair[2]
	check("measured raised surface has actual native floor separation", absf(game.spatial_world.height_at(upper) - game.spatial_world.height_at(lower)) > TerrainLevels.STEP_REACH / WorldSpace3D.VERTICAL_PIXELS_PER_METER)
	check("melee reach is symmetric across the raised ledge", not game.can_melee_reach(upper, lower) and not game.can_melee_reach(lower, upper))
	hero.position = upper
	hero.z_index = 0  # Deliberately wrong drawing Z must not change physical reach.
	var enemy := _target(game, lower)
	enemy.z_index = 1
	hero.facing = (lower - upper).angle()
	var before := enemy.hp
	hero._melee("cleave", SkillDefs.get_def("cleave"), 1, 1.0)
	check("actual weapon swing cannot hurt the lower monster", enemy.hp == before)
	var hero_before := hero.hp
	_enemy_swing(enemy)
	check("lower monster cannot resolve a melee hit against the upper hero", hero.hp == hero_before)
	hero._spin("whirlwind", SkillDefs.get_def("whirlwind"), 1.0)
	await get_tree().create_timer(0.35, false).timeout
	check("all actual whirlwind ticks respect the raised ledge", enemy.hp == before)
	# Reverse the real participants, then verify equal-height contact still works.
	hero.position = lower
	enemy.position = upper
	hero.facing = (upper - lower).angle()
	hero._melee("cleave", SkillDefs.get_def("cleave"), 1, 1.0)
	check("lower hero cannot melee the upper monster either", enemy.hp == before)
	hero_before = hero.hp
	_enemy_swing(enemy)
	check("upper monster cannot melee the lower hero", hero.hp == hero_before)
	hero.position = upper
	enemy.position = upper.lerp(center, 0.08)
	hero.facing = (enemy.position - hero.position).angle()
	check("nearby equal-height platform positions remain reachable", game.can_melee_reach(hero.position, enemy.position))
	hero._melee("cleave", SkillDefs.get_def("cleave"), 1, 1.0)
	check("actual equal-height weapon contact still deals damage", enemy.hp < before)
	hero._invulnerable = 0.0
	hero_before = hero.hp
	_enemy_swing(enemy)
	check("actual equal-height monster melee still deals damage", hero.hp < hero_before)
	_check_stairs_and_bridge(game)
	_check_walls_and_flat_faces(game)
	var arena := await _area_arena(game)
	await _check_melee_props(game, arena["upper"], arena["lower"])
	var anchor: Enemy = arena["anchor"]
	game.enemies.erase(anchor)
	anchor.queue_free()
	NativeFixture.remove(arena["bodies"])
	await NativeFixture.settle(get_tree())
	# The cave owns a separate flat floor even where its projected coordinates overlap town art.
	hero.position = game.dungeon.entry_point()
	check("cave entry succeeds for elevation regression", game.dungeon.enter())
	await NativeFixture.settle(get_tree())
	var cave_a := Iso.project(Vector2(-20, 0))
	var cave_b := Iso.project(Vector2(20, 0))
	check("forest elevation records do not leak into the separate native cave floor", game.spatial_world.realm == "cave" and is_zero_approx(game.spatial_world.height_at(cave_a)) and is_zero_approx(game.spatial_world.height_at(cave_b)) and game.can_melee_reach(cave_a, cave_b))
	game.dungeon.leave("")
	await NativeFixture.settle(get_tree())
	check("leaving the cave restores forest elevation separation", not game.can_melee_reach(upper, lower))
	game.queue_free()
	await _frames(2)


func _check_stairs_and_bridge(game: Node) -> void:
	var landmark: Landmark = game.village.landmarks[0]
	var definition: Dictionary = Landmark.data()[0]
	var outline: Array = definition["outline"]
	var bottom := (landmark._pt(outline[0]) + landmark._pt(outline[1])) * 0.5
	var upper := (landmark._pt(outline[2]) + landmark._pt(outline[outline.size() - 1])) * 0.5
	var forward := (upper - bottom).normalized()
	check("adjacent combat across the actual stair entrance remains possible", game.can_melee_reach(bottom - forward * 12.0, bottom + forward * 12.0) and game.can_melee_reach(bottom + forward * 12.0, bottom - forward * 12.0))
	var bridge: Bridge = game.village.bridge
	var deck := bridge.deck_polygon()
	var middle := (deck[0] + deck[1]) * 0.5
	var center := bridge.axis_point(0.5)
	var outward := (middle - center).normalized()
	check("bridge parapet separates deck melee from the lower side", not game.can_melee_reach(middle - outward * 25.0, middle + outward * 35.0))
	var entry := bridge.axis_point(0.0)
	var axis := Bridge.axis_direction()
	check("bridge and bank stay connected through their open end", game.can_melee_reach(entry - axis * 20.0, entry + axis * 20.0) and game.can_melee_reach(entry + axis * 20.0, entry - axis * 20.0))


func _check_walls_and_flat_faces(game: Node) -> void:
	var walls: Array[PackedVector2Array] = game.village.wall_footprints
	check("town has measured wall footprints for melee occlusion", not walls.is_empty())
	if not walls.is_empty():
		var wall := walls[0]
		var a := (wall[0] + wall[1]) * 0.5
		var b := (wall[2] + wall[3]) * 0.5
		var across := (b - a).normalized()
		check("same-ground melee cannot pass through a permanent town wall", not game.can_melee_reach(a - across * 12.0, b + across * 12.0) and not game.can_melee_reach(b + across * 12.0, a - across * 12.0))
	var passage: PackedVector2Array = game.village.gate_passages[0]
	var center := Vector2.ZERO
	for point in passage:
		center += point
	center /= passage.size()
	var axis := passage[3] - passage[0]
	var near := center - axis.normalized() * (axis.length() * 0.5 + 8.0)
	var far := center + axis.normalized() * (axis.length() * 0.5 + 8.0)
	check("permanent wall occlusion preserves the actual open gate passage", game.can_melee_reach(near, far) and game.can_melee_reach(far, near))
	var flat_faces: Array[PackedVector2Array] = []
	check("absent cliff faces cannot invent a raised height", is_zero_approx(TerrainLevels.measured_rise(flat_faces)))
	var slope: Array[PackedVector2Array] = [PackedVector2Array([Vector2(0, 0), Vector2(30, 0), Vector2(50, 40), Vector2(20, 40)])]
	check("sloped cliff walls retain measured top-to-bottom rise", is_equal_approx(TerrainLevels.measured_rise(slope), 40.0))


func _coin_chest(game: Node, at: Vector2) -> Chest:
	var index := 100
	while GameState.opened_chests.has(index) or GameState.chest_content(index) != "coins":
		index += 1
	var definition: Dictionary = game.village.data["sprites"]["chest"]
	var broken: Dictionary = game.village.data["sprites"]["chest-broken"]
	var chest := Chest.new().setup(game, index, at, definition, broken)
	game.world.add_child(chest)
	game.chests.append(chest)
	return chest


func _discard_chest(game: Node, chest: Chest) -> void:
	game.chests.erase(chest)
	chest.queue_free()


func _check_melee_props(game: Node, upper: Vector2, lower: Vector2) -> void:
	var hero: Player = game.player
	var runtime: EncounterRuntime = game.encounters
	var runtime_processing := runtime.is_processing()
	runtime.set_process(false)
	# Observe real contact dispatch without spawning an unrelated encounter pack.
	# Stone authorization/charges/projectiles are exercised in encounter_combat.
	var original_stones := runtime.stones
	var stone := StoneContactProbe.new()
	game.world.add_child(stone)
	runtime.stones = {"west": stone}
	for sides in [PackedVector2Array([upper, lower]), PackedVector2Array([lower, upper])]:
		hero.position = sides[0]
		hero.facing = (sides[1] - sides[0]).angle()
		stone.position = sides[1]
		stone.contacts = 0
		var chest := _coin_chest(game, sides[1])
		var gold := GameState.gold
		hero._melee("cleave", SkillDefs.get_def("cleave"), 1, 1.0)
		check("resolved weapon swing cannot loot or strike a stone across a raised ledge", not chest.dead and stone.contacts == 0 and GameState.gold == gold)
		hero._spin("whirlwind", SkillDefs.get_def("whirlwind"), 1.0)
		await get_tree().create_timer(0.35, false).timeout
		check("all whirlwind contacts respect prop elevation in both directions", not chest.dead and stone.contacts == 0 and GameState.gold == gold)
		# Area attacks now share native height/solid occlusion instead of crossing the cliff.
		hero._nova("warcry", SkillDefs.get_def("warcry"), 1, 1.0)
		check("area spell cannot loot or strike props through the native ledge", not chest.dead and stone.contacts == 0 and GameState.gold == gold)
		_discard_chest(game, chest)
	hero.position = upper
	stone.position = lower
	stone.contacts = 0
	var landing_chest := _coin_chest(game, lower)
	var landing := hero._prepare("leapAttack", SkillDefs.get_def("leapAttack"), 1)
	check("native targeted landing has a live equal-height anchor", landing.is_valid())
	if landing.is_valid():
		landing.call()
		check("actual landing cannot loot or strike a lower-level stone", not landing_chest.dead and stone.contacts == 0)
	_discard_chest(game, landing_chest)
	# The same live chest still opens and the same stone dispatches on flat ground.
	hero.position = game.village.spawn_point
	stone.position = hero.position + Vector2(40, 0)
	stone.contacts = 0
	hero.facing = 0.0
	var flat_chest := _coin_chest(game, stone.position)
	hero._melee("cleave", SkillDefs.get_def("cleave"), 1, 1.0)
	check("same-ground real weapon contact still loots and strikes stones", flat_chest.dead and stone.contacts == 1)
	_discard_chest(game, flat_chest)
	stone.contacts = 0
	var area_chest := _coin_chest(game, stone.position)
	var area_gold := GameState.gold
	hero._nova("warcry", SkillDefs.get_def("warcry"), 1, 1.0)
	check("same-ground real area spell still loots and strikes visible props", area_chest.dead and stone.contacts > 0 and GameState.gold > area_gold)
	_discard_chest(game, area_chest)
	# A closed passage must protect props just as it protects actors.
	var gates: TownGateRuntime = game.town_gates
	var gate_processing := gates.is_processing()
	var original_closed := gates.closed.duplicate()
	gates.set_process(false)
	gates.closed[0] = true
	var passage: PackedVector2Array = game.village.gate_passages[0]
	var center := Vector2.ZERO
	for point in passage:
		center += point
	center /= passage.size()
	var axis := passage[3] - passage[0]
	var reach := axis.length() * 0.5 + 8.0
	hero.position = center - axis.normalized() * reach
	stone.position = center + axis.normalized() * reach
	stone.contacts = 0
	var gate_chest := _coin_chest(game, stone.position)
	check("gate prop fixture lies within the native whirlwind radius", hero.position.distance_to(stone.position) <= float(SkillDefs.get_def("whirlwind")["radius"]) + 26.0)
	hero._spin("whirlwind", SkillDefs.get_def("whirlwind"), 1.0)
	await get_tree().create_timer(0.35, false).timeout
	check("closed gate blocks actual whirlwind loot and stone contacts", not gate_chest.dead and stone.contacts == 0)
	gates.closed[0] = false
	game.break_chests_in_radius(hero.position, float(SkillDefs.get_def("whirlwind")["radius"]), hero, true)
	check("opening the same gate restores prop melee contact", gate_chest.dead and stone.contacts == 1)
	_discard_chest(game, gate_chest)
	gates.closed = original_closed
	gates.set_process(gate_processing)
	runtime.stones = original_stones
	stone.queue_free()
	runtime.set_process(runtime_processing)

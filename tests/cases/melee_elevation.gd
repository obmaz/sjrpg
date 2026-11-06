extends TestCase
## Actual walkable geometry, not drawing Z, separates melee across raised ledges.


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


func run() -> void:
	var game := await make_game()
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
	check("measured raised surface has physical rise", float(TerrainLevels.sample(game.village, upper)["height"]) > 0.0)
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
	check("ranged and area radius queries retain their existing targets", game.enemies_in_radius(upper, 100.0).has(enemy) and not game.enemies_in_radius(upper, 100.0, true).has(enemy))
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
	# The cave owns a separate flat floor even where its projected coordinates overlap town art.
	hero.position = game.dungeon.entry_point()
	check("cave entry succeeds for elevation regression", game.dungeon.enter())
	check("forest elevation records do not leak into the separate cave floor", game.can_melee_reach(upper, lower))
	game.dungeon.leave("")
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
	check("absent cliff faces cannot invent a raised height", is_zero_approx(TerrainLevels._rise(flat_faces)))
	var slope: Array[PackedVector2Array] = [PackedVector2Array([Vector2(0, 0), Vector2(30, 0), Vector2(50, 40), Vector2(20, 40)])]
	check("sloped cliff walls retain measured top-to-bottom rise", is_equal_approx(TerrainLevels._rise(slope), 40.0))

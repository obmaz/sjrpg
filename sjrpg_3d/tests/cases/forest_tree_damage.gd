extends TestCase
## 실제 공격·충돌·가림·저장·지역 전환의 나무 수명을 확인한다.


func run() -> void:
	var game := await make_game("mage")
	game._spawn_timer = 100000.0
	game.encounters.set_process(false)
	var trees: ForestTreeRuntime = game.forest_trees
	seed(4137)
	var expected_roll := randf()
	seed(4137)
	game.player._tree_arc({"range": 90.0, "arc": 70.0}, "cleave", 1.0, SkillDefs.STEEL)
	check("scenery checks leave combat RNG untouched", is_equal_approx(randf(), expected_roll))
	var keys := trees.entries.keys()
	check("ordinary outer trees are registered", keys.size() >= 260)
	var protected := true
	for source: IsoSprite in game.village.town_trees:
		protected = protected and trees.key_for(source).is_empty()
	check("town and quest trees stay protected", protected)
	var key: String = keys[0]
	trees.hit(key, "", "swing-1")
	trees.hit(key, "", "swing-1")
	check("one action only consumes durability once", trees.record(key)["hits"] == 1)
	trees.hit(key, "", "swing-2")
	check(
		"two light hits leave a living blocker", trees.state(key) == "healthy" and trees.blocks(key)
	)
	trees.hit(key, "", "swing-3")
	check(
		"third light hit removes walking collision",
		trees.state(key) == "felled" and _body(trees, key).collision_layer == 0
	)
	key = keys[1]
	trees.hit(key, "", "heavy-1", 100.0)
	check("even overwhelming damage cannot one-shot a healthy tree", trees.state(key) == "healthy")
	trees.hit(key, "", "heavy-2", 100.0)
	check("two distinct strong attacks fell the tree", trees.state(key) == "felled")
	key = keys[2]
	trees.hit(key, "cold", "frost-1")
	trees.hit(key, "cold", "frost-1")
	trees.hit(key, "fire", "frost-1")
	check("same cast cannot freeze then shatter", trees.state(key) == "frozen")
	trees.hit(key, "cold", "frost-2")
	check("new ice attack shatters frozen wood", trees.state(key) == "felled")
	key = keys[3]
	trees.hit(key, "lightning", "lightning-1")
	check(
		"lightning leaves charred blocking wood",
		trees.state(key) == "charred" and trees.blocks(key)
	)
	trees.hit(key, "cold", "ice-on-char")
	check("ice shatters rather than refreezes charred wood", trees.state(key) == "felled")
	key = keys[4]
	trees.hit(key, "fire", "flame-1")
	trees.tick(ForestTreeRuntime.BURN_SECONDS + 0.1)
	check(
		"four seconds of fire leaves attackable nonblocking ash",
		trees.state(key) == "ash" and not trees.blocks(key)
	)
	trees.hit(key, "cold", "ice-on-ash")
	check("any new attack including ice clears ash", trees.state(key) == "felled")
	key = keys[5]
	trees.hit(key, "fire", "burn-before-frost")
	trees.hit(key, "cold", "extinguish")
	check("ice extinguishes a burning tree", trees.state(key) == "frozen")
	trees.tick(ForestTreeRuntime.FREEZE_SECONDS + 0.1)
	check("untouched ice thaws to a living tree", trees.state(key) == "healthy")
	await _attack_paths(game)
	await _occlusion_and_regrowth(game, str(keys[0]))
	await _cave_round_trip(game, str(keys[6]))
	var fx: TreeDebris3D = game.world_renderer._tree_damage.debris
	var previous_motion := Prefs.reduce_motion
	Prefs.reduce_motion = false
	for index in 100:
		fx.burst(Vector3.ZERO, "frozen")
	check("debris stays inside the 48-fragment pool", fx._particles.size() == TreeDebris3D.LIMIT)
	fx.sync(1.0, [])
	check("expired fragments retire", fx._particles.is_empty())
	Prefs.reduce_motion = true
	fx.burst(Vector3.ZERO, "charred")
	check("reduce-motion omits flying debris", fx._particles.is_empty())
	Prefs.reduce_motion = previous_motion
	var snapshot: Dictionary = GameState.forest_trees.duplicate(true)
	GameState.save_game()
	GameState.forest_trees.clear()
	GameState.load_game()
	check(
		"modified states survive saving and loading",
		_same_records(GameState.forest_trees, snapshot)
	)
	game.queue_free()
	await _frames(3)


func _body(trees: ForestTreeRuntime, key: String) -> StaticBody3D:
	return trees._bodies[key].get_ref()


func _attack_paths(game: Node) -> void:
	var trees: ForestTreeRuntime = game.forest_trees
	var key := _place_for_attack(game)
	if not check("a real tree has a reachable attack side", not key.is_empty()):
		return
	var point: Vector2 = trees.entries[key]["point"]
	var player: Player = game.player
	player._action_serial += 1
	var spell := SkillDefs.get_def("iceBolt")
	player._projectiles("iceBolt", spell, 1, 1.0)
	for frame in 90:
		await get_tree().physics_frame
		if trees.state(key) == "frozen":
			break
	check("real fixed-height projectile freezes the blocking tree", trees.state(key) == "frozen")
	player._projectiles("iceBolt", spell, 1, 1.0)
	await _frames(20)
	check("another projectile from the same cast cannot shatter", trees.state(key) == "frozen")
	player._action_serial += 1
	player._melee("sorceressAttack", {"range": 130.0, "arc": 90.0}, 1, 1.0)
	check("subsequent real melee shatters the frozen tree", trees.state(key) == "felled")
	trees._transition(key, "healthy")
	player._action_serial += 1
	game.spawn_zone(
		{
			"pos": point,
			"radius": 70.0,
			"duration": 1.0,
			"tick": 0.05,
			"damage": 10.0,
			"color": SkillDefs.COLD
		}
	)
	await _frames(20)
	check("damage-zone ticks cannot shatter their own freeze", trees.state(key) == "frozen")
	player._action_serial += 1
	game.spawn_beam(player.position, player.facing, 160.0, 10.0, SkillDefs.LIGHT, player)
	check("a new beam shatters brittle wood", trees.state(key) == "felled")
	trees._transition(key, "healthy")
	var blocker := CylinderShape3D.new()
	blocker.radius = 0.12
	blocker.height = 2.2
	var center := WorldSpace3D.projected_to_world((point + player.position) * 0.5)
	center.y = SpatialCombat3D.floor_at(game, player.position) + 1.1
	var wall: StaticBody3D = game.spatial_world._shape_body(
		blocker, Transform3D(Basis.IDENTITY, center), SpatialWorld3D.SOLID, "TreeTestWall"
	)
	await get_tree().physics_frame
	player._action_serial += 1
	game.spawn_beam(player.position, player.facing, 300.0, 10.0, SkillDefs.LIGHT, player)
	check("an intervening wall prevents tree damage", trees.state(key) == "healthy")
	wall.queue_free()
	await get_tree().physics_frame
	player._buff("blaze", SkillDefs.get_def("blaze"), 1)
	var blaze_action: String = player.buffs["blaze"]["tree_action"]
	player._action_serial += 1
	player._drop_blaze(40.0)
	var inherited := false
	for child in game.world.get_children():
		if child is Effect and child.kind == "zone" and child.color == SkillDefs.FIRE:
			inherited = child.params["tree_action"] == blaze_action
	check("fire trails retain their cast ID across unrelated attacks", inherited)


func _place_for_attack(game: Node) -> String:
	var trees: ForestTreeRuntime = game.forest_trees
	for key: String in trees.entries:
		if trees.state(key) != "healthy":
			continue
		var point: Vector2 = trees.entries[key]["point"]
		for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN, Vector2.UP]:
			var at: Vector2 = point + direction * 75.0
			if game._blocked(at, Player.RADIUS) or not game.spatial_world.can_melee(at, point):
				continue
			game.spatial_world.teleport_source_actor(game.player, at, Player.RADIUS)
			game.player.facing = (point - game.player.position).angle()
			return key
	return ""


func _occlusion_and_regrowth(game: Node, key: String) -> void:
	var trees: ForestTreeRuntime = game.forest_trees
	var renderer: WorldRenderer3D = game.world_renderer
	var entry: Dictionary = renderer._tree_damage._entries[key]
	var batch: MultiMeshInstance3D = entry["batch"]
	var index: int = entry["index"]
	trees._transition(key, "healthy")
	renderer._tree_damage.sync(0.0)
	var occlusion: NativePlayerOcclusion = renderer._occlusion
	occlusion._collect()
	var target: Dictionary
	for candidate: Dictionary in occlusion._entries:
		if candidate["node"] == batch and candidate["index"] == index:
			target = candidate
			break
	if not check("tree has a native instance occlusion entry", not target.is_empty()):
		return
	var faded := occlusion._activate(target)
	occlusion._active["%d:%d" % [batch.get_instance_id(), index]] = faded
	trees.hit(key, "lightning", "fade-char")
	renderer._tree_damage.sync(0.0)
	occlusion._restore(faded)
	check(
		"fade restore cannot resurrect a replaced tree or proxy",
		not occlusion.instance_enabled(batch, index) and not faded["draw"].visible
	)
	trees.hit(key, "", "fade-break")
	renderer._tree_damage.sync(0.0)
	var charred: MultiMeshInstance3D = renderer._tree_damage._state_batch(entry, "charred")
	check("empty damage batches stop drawing", not charred.visible)
	game.player.position = trees.entries[key]["point"]
	check("regrowth waits while the player overlaps", not trees.can_regrow(key))
	trees.record(key)["respawn"] = 0.0
	trees.tick(0.2)
	check("an expired occupied tree stays felled", trees.state(key) == "felled")
	game.dungeon.active = true
	trees.tick(0.2)
	game.dungeon.active = false
	renderer._tree_damage.sync(0.0)
	# Dummy rendering has no GPU buffer readback: assert the canonical slot and collider.
	check(
		"offscreen regrowth restores canonical transform and solid body",
		(
			trees.state(key) == "healthy"
			and _body(trees, key).collision_layer == SpatialWorld3D.SOLID
			and occlusion.instance_enabled(batch, index)
			and batch.get_meta("occlusion_transforms")[index].is_equal_approx(
				entry["local_transform"]
			)
		)
	)


func _same_records(actual: Dictionary, expected: Dictionary) -> bool:
	if actual.size() != expected.size():
		return false
	for key: String in expected:
		if not actual.has(key) or actual[key]["state"] != expected[key]["state"]:
			return false
		for field in ["hits", "durability", "timer", "respawn"]:
			if not is_equal_approx(float(actual[key][field]), float(expected[key][field])):
				return false
	return true


func _cave_round_trip(game: Node, key: String) -> void:
	var trees: ForestTreeRuntime = game.forest_trees
	trees.hit(key, "lightning", "before-cave")
	var body := _body(trees, key)
	var builds: int = game.spatial_world.forest_builds
	game.player.position = game.dungeon.entry_point()
	if not check("tree fixture enters the real cave", game.dungeon.enter()):
		return
	for enemy: Enemy in game.enemies:
		enemy.set_process(false)
	await get_tree().physics_frame
	await _frames(2)
	trees.hit(key, "", "cannot-hit-forest-from-cave")
	check("cave attacks cannot change stowed trees", trees.state(key) == "charred")
	game.dungeon.leave("", false)
	await get_tree().physics_frame
	await _frames(2)
	check(
		"cave return keeps the same tree state and collision cache",
		(
			trees.state(key) == "charred"
			and _body(trees, key) == body
			and game.spatial_world.forest_builds == builds
		)
	)

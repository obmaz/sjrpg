extends TestCase
## A corpse's illustration and skill target expire together, including cave map swaps.


func _enemy(game: Node, kind: String) -> Enemy:
	var enemy := Enemy.new()
	enemy.setup(game, kind, 1)
	enemy.position = game.player.position + Vector2(40, 0)
	enemy.xp_reward = 0
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	enemy.set_process(false)
	return enemy


func _clear(game: Node) -> void:
	for corpse in game.corpses.duplicate():
		game.remove_corpse(corpse)


func run() -> void:
	var sheet: Texture2D = load("res://assets/art/actors/corpses.webp")
	check("corpse atlas contains the five generated enemy images", sheet != null and sheet.get_size() == Vector2(1280, 256))
	check("new corpse crossfades from the actor", CorpseArt.opacity(30.0) == 0.0 and is_equal_approx(CorpseArt.opacity(29.82), 1.0))
	var game := await make_game()
	game._spawn_timer = 10000.0
	game.player.set_process(false)
	var kills := GameState.kills
	var kill_xp := GameState.xp
	var standing: Enemy
	for kind in Enemy.KINDS:
		var enemy := _enemy(game, kind)
		enemy.xp_reward = 1
		enemy.take_damage(enemy.hp + 1.0, game.player)
		var count: int = game.corpses.size()
		enemy._die()
		enemy.take_damage(100.0, game.player)
		check("repeat death cannot duplicate corpse: " + kind, game.corpses.size() == count)
		var corpse: Dictionary = game.corpses.back()
		check("death records its own illustration: " + kind, corpse["kind"] == kind and corpse["pos"] == enemy.position and corpse["height"] == enemy.sprite.body_height)
		check("every corpse uses the same complete lifetime: " + kind, corpse["time"] == game.CORPSE_LIFETIME and corpse["lifetime"] == game.CORPSE_LIFETIME)
		standing = enemy
	check("all enemy kinds leave one body and one kill", game.corpses.size() == Enemy.KINDS.size() and GameState.kills == kills + Enemy.KINDS.size())
	check("repeat death pays experience only once", GameState.xp == kill_xp + Enemy.KINDS.size())
	await get_tree().create_timer(0.25).timeout
	check("standing actor is freed after the short death transition", not is_instance_valid(standing))
	_clear(game)
	var template := _enemy(game, "goblin")
	var decoration: Dictionary = game.add_corpse(template, false)
	var ground_visual: Node2D = decoration["visual"]
	check("normal corpse belongs to the active world below actors", ground_visual.get_parent() == game.world and ground_visual.position == template.position and ground_visual.z_index == -1)
	template.position = game.village.bridge.axis_point(0.5)
	var bridge_body: Dictionary = game.add_corpse(template, false)
	var bridge_visual: Node2D = bridge_body["visual"]
	var bridge: Bridge = game.village.bridge
	check("bridge corpse clears the deck and remains behind the front rail", bridge_visual.z_index == -1 and bridge_visual.z_index > bridge.z_index and bridge_visual.z_index < bridge.z_index + bridge.front.z_index)
	game.remove_corpse(bridge_body)
	template.position = game.village.chapel_steps[game.village.chapel_steps.size() - 1]
	var chapel_body: Dictionary = game.add_corpse(template, false)
	check("chapel-yard corpse draws above the raised patio", Geometry2D.is_point_in_polygon(template.position, game.village.terrace) and chapel_body["visual"].z_index == 1)
	game.remove_corpse(chapel_body)
	var landmark: Landmark = game.village.landmarks[1]
	var top_center := Vector2.ZERO
	for point in landmark.top:
		top_center += point
	template.position = top_center / landmark.top.size()
	var landmark_body: Dictionary = game.add_corpse(template, false)
	check("landmark corpse shares the raised surface elevation", landmark.contains_top(template.position) and landmark_body["visual"].z_index == 1)
	game.remove_corpse(landmark_body)
	template.position = game.player.position + Vector2(40, 0)
	check("non-searchable bodies remain visual without adding loot opportunities", not game.corpse_available(decoration) and game.nearest_corpse(game.player.position, 170.0) == null)
	var searchable: Dictionary = game.add_corpse(template, true)
	check("eligible body remains available to the corpse skills", game.nearest_corpse(game.player.position, 170.0) == searchable)
	check("body is opaque until its final three seconds", is_equal_approx(CorpseArt.opacity(3.0), 1.0) and is_equal_approx(CorpseArt.opacity(1.5), 0.5) and CorpseArt.opacity(0.0) == 0.0)
	game.hud.open_settings()
	var paused_time: float = searchable["time"]
	await _frames(4)
	check("pausing preserves the corpse image and target lifetime", searchable["time"] == paused_time)
	game.hud.close_panel()
	# Capture the real delayed preparation closure, then expire its target before contact.
	var guaranteed_item := {"type": "corpse", "reward": "item", "chance": 1.0, "chance_cap": 1.0}
	var expired_action: Callable = game.player._prepare("findItem", guaranteed_item, 1)
	var xp := GameState.xp
	var expired_visual: Node2D = searchable["visual"]
	game._tick_corpses(game.CORPSE_LIFETIME)
	check("expiry removes image and invalidates captured target", game.corpses.is_empty() and searchable["used"] and searchable["time"] == 0.0)
	check("expiry immediately hides and frees the visual record", expired_visual.is_queued_for_deletion() and not expired_visual.visible and not searchable.has("visual"))
	expired_action.call()
	check("expired pending corpse skill gives no reward", GameState.xp == xp)
	var consumed: Dictionary = game.add_corpse(template, true)
	var first_action: Callable = game.player._prepare("findItem", guaranteed_item, 1)
	var repeated_action: Callable = game.player._prepare("findItem", guaranteed_item, 1)
	first_action.call()
	var rewarded_xp := GameState.xp
	repeated_action.call()
	check("consumed corpse can pay only once", rewarded_xp > xp and GameState.xp == rewarded_xp and consumed["used"] and not game.corpses.has(consumed))
	var evicted: Dictionary = game.add_corpse(template, true)
	for i in game.CORPSE_LIMIT + 5:
		game.add_corpse(template, false)
	check("rapid kills stay bounded and invalidate evicted targets", game.corpses.size() == game.CORPSE_LIMIT and evicted["used"] and evicted["time"] == 0.0)
	_clear(game)
	var forest_body: Dictionary = game.add_corpse(template, true)
	var forest_visual: Node2D = forest_body["visual"]
	game.player.position = game.dungeon.entry_point()
	check("corpse map test enters the cave", game.dungeon.enter())
	check("cave has no forest corpse illustrations or targets", game.corpses.is_empty() and game.nearest_corpse(Vector2.ZERO, 100000.0) == null)
	var cave_enemy := _enemy(game, "skeleton")
	var cave_body: Dictionary = game.add_corpse(cave_enemy, true)
	var cave_visual: Node2D = cave_body["visual"]
	check("map swap culls the forest body and parents the cave body locally", game.field_root.visibility_layer == 0 and forest_visual.is_inside_tree() and cave_visual.get_parent() == game.world and cave_visual.z_index == -1)
	game.dungeon.tick(1.0)
	check("cave uses the same timer while hidden forest bodies stay frozen", cave_body["time"] == game.CORPSE_LIFETIME - 1.0 and forest_body["time"] == game.CORPSE_LIFETIME)
	var cave_action: Callable = game.player._prepare("findItem", guaranteed_item, 1)
	game.dungeon.leave("시체 검사")
	check("leaving cave restores only forest bodies and invalidates cave targets", game.corpses.size() == 1 and game.corpses.has(forest_body) and cave_body["used"] and cave_body["time"] == 0.0)
	xp = GameState.xp
	cave_action.call()
	check("a pending cave skill cannot award loot after leaving", GameState.xp == xp)
	await _frames(2)
	var native_corpses: Dictionary = game.ortho_preview._world_environment._corpses
	# Native corpse entries are dictionaries ({"root": Node3D, ...}), not bare meshes.
	var restored_entry: Dictionary = native_corpses.get(forest_visual.get_instance_id(), {})
	var restored_card: Node3D = restored_entry.get("root")
	check("cave body visual is freed while the native forest corpse is restored", not is_instance_valid(cave_visual) and restored_card != null and restored_card.is_visible_in_tree() and game.field_root.visibility_layer == 0)
	game._tick_corpses(game.CORPSE_LIFETIME)
	check("restored forest corpse expires on the same schedule", game.corpses.is_empty() and forest_body["used"])
	game.queue_free()
	await _frames(2)

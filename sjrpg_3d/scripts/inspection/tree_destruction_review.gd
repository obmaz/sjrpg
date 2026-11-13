class_name TreeDestructionReview
extends RefCounted
## 검수 전용. 실제 슬롯 시전과 실제 숲 나무를 사용하며 임의 상태 그림을 만들지 않는다.


static func run(game: Node, which: String) -> void:
	game._spawn_timer = 100000.0
	game.encounters.set_process(false)
	for foe: Enemy in game.enemies:
		foe.queue_free()
	game.enemies.clear()
	await game.get_tree().create_timer(1.0, false).timeout
	var key := _place(game, which in ["ash", "felled"])
	if key.is_empty():
		push_error("Tree destruction review requires an accessible native tree")
		return
	var point: Vector2 = game.forest_trees.entries[key]["point"]
	game.inspection.focus_point = point + Vector2(0.0, -90.0)
	game.camera.position = game.inspection.focus_point
	game.camera.reset_smoothing()
	var skill := "sorceressAttack"
	if which == "frozen":
		skill = "iceBolt"
	elif which in ["burning", "ash"]:
		skill = "firebolt"
	elif which == "charred":
		skill = "lightning"
	GameState.ranks[skill] = 1
	GameState.slots[0] = skill
	var attacks := 3 if which == "felled" else 1
	if which == "healthy":
		attacks = 0
	for index in attacks:
		game.player.facing = (point - game.player.position).angle()
		game.player.cooldowns.clear()
		game.player.resource = game.player.resource_max
		game.player.cast_slot(0, true)
		var settle := 0.4 if which == "felled" and index == attacks - 1 else 0.75
		await game.get_tree().create_timer(settle, false).timeout
	if which == "ash":
		# Software-GPU harnesses advance the real burn timer after confirming the actual cast.
		game.forest_trees.tick(ForestTreeRuntime.BURN_SECONDS + 0.1)
	for frame in 3:
		await game.get_tree().process_frame
	game.world_renderer.request_redraw()
	game.world_renderer._tree_damage.sync(0.0)
	var data := {
		"ready": true,
		"expected": which,
		"state": game.forest_trees.state(key),
		"actual_cast": attacks > 0,
		"tree": key,
		"effects": game.world_renderer._tree_damage.snapshot()
	}
	JavaScriptBridge.eval("window.__sjrpgTreeReview = " + JSON.stringify(data))
	# Snapshot holds while the harness changes device orientation.
	game.get_tree().paused = true


static func _place(game: Node, side_view := false) -> String:
	var keys: Array = game.forest_trees.entries.keys()
	keys.sort_custom(
		func(a: String, b: String):
			return (
				game.forest_trees.entries[a]["point"].distance_squared_to(game.player.position)
				< game.forest_trees.entries[b]["point"].distance_squared_to(game.player.position)
			)
	)
	for key: String in keys:
		var point: Vector2 = game.forest_trees.entries[key]["point"]
		var directions := [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]
		if side_view:
			directions = [Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN, Vector2.UP]
		for direction: Vector2 in directions:
			var at: Vector2 = point + direction * 75.0
			if game._blocked(at, Player.RADIUS) or not game.spatial_world.can_melee(at, point):
				continue
			game.spatial_world.teleport_source_actor(game.player, at, Player.RADIUS)
			return key
	return ""

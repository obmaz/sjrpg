class_name TreeDestructionReview
extends RefCounted
## 검수 전용. 실제 슬롯 시전과 실제 숲 나무를 사용하며 임의 상태 그림을 만들지 않는다.

const SCENES := ["healthy", "frozen", "burning", "charred", "burned", "felled", "frozen_break", "charred_break"]


static func run(game: Node, which: String) -> void:
	game._spawn_timer = 100000.0
	game.encounters.set_process(false)
	for foe: Enemy in game.enemies:
		foe.queue_free()
	game.enemies.clear()
	await game.get_tree().create_timer(1.0, false).timeout
	var breaking := which.ends_with("_break")
	var key := _place(game, which in ["burned", "felled"] or breaking)
	if key.is_empty():
		push_error("Tree destruction review requires an accessible native tree")
		return
	var point: Vector2 = game.forest_trees.entries[key]["point"]
	game.inspection.focus_point = point + Vector2(0.0, -90.0)
	game.camera.position = game.inspection.focus_point
	game.camera.reset_smoothing()
	var skill := "sorceressAttack"
	if which.begins_with("frozen"):
		skill = "iceBolt"
	elif which in ["burning", "burned"]:
		skill = "firebolt"
	elif which.begins_with("charred"):
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
	if which == "burned":
		# Software-GPU harnesses advance the real burn timer after confirming the actual cast.
		game.forest_trees.tick(ForestTreeRuntime.BURN_SECONDS + 0.1)
	if breaking:
		GameState.slots[0] = "sorceressAttack"
		game.player.cooldowns.clear()
		game.player.cast_slot(0, true)
		for frame in 90:
			if game.forest_trees.state(key) == "felled":
				break
			await game.get_tree().physics_frame
	# 실제 새 공격의 명중 직후 정지하고 같은 애니메이션의 중간 자세를 표시한다.
	game.get_tree().paused = true
	for frame in 3:
		await game.get_tree().process_frame
	game.world_renderer.request_redraw()
	game.world_renderer._tree_damage.sync(0.0)
	if breaking:
		game.world_renderer._tree_damage.breakup.sync(0.24)
	var data := {
		"ready": true,
		"expected": "felled" if breaking else ("charred" if which == "burned" else which),
		"state": game.forest_trees.state(key),
		"actual_cast": attacks > 0,
		"tree": key,
		"effects": game.world_renderer._tree_damage.snapshot()
	}
	JavaScriptBridge.eval("window.__sjrpgTreeReview = " + JSON.stringify(data))
	# Snapshot holds while the harness changes device orientation.


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

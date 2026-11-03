extends Node
## Headless smoke test: casts every skill of both classes and opens every tree tab.
## Run: godot --headless res://tests/skill_smoke.tscn

var failures := 0


func _ready() -> void:
	await _run()
	print("SMOKE DONE failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	for cls in ["warrior", "mage"]:
		GameState.new_game(cls)
		GameState.level = 60
		GameState.skill_points = 2000
		# Learn everything through the real rules (prerequisites first).
		var progress := true
		while progress:
			progress = false
			for s in GameState.skills():
				while GameState.learn(s["id"]):
					progress = true
		for s in GameState.skills():
			if GameState.rank(s["id"]) != int(s["limit"]):
				print("FAIL %s not maxed: %s" % [s["id"], GameState.learn_block_reason(s)])
				failures += 1
			if SkillDefs.get_def(s["id"]).is_empty():
				print("FAIL %s has no behaviour" % s["id"])
				failures += 1
			if SkillDefs.describe(s["id"], 1) == "":
				print("FAIL %s has no description" % s["id"])
				failures += 1
		var game := preload("res://scripts/game.gd").new()
		add_child(game)
		await _frames(2)
		var player: Player = game.player
		for s in GameState.skills():
			if not GameState.is_assignable(s):
				continue
			# Fresh enemies around the hero for every cast.
			for i in 4:
				var e := Enemy.new()
				e.setup(game, "goblin", 3)
				e.position = player.position + Vector2.from_angle(i * TAU / 4.0) * 90.0
				game.world.add_child(e)
				game.enemies.append(e)
			game.corpses.append({"pos": player.position + Vector2(40, 0), "time": 30.0, "used": false})
			GameState.assign_slot(1, s["id"])
			player.cooldowns.clear()
			player._attack_time = 0.0
			player.resource = player.resource_max
			player.hp = player.max_hp
			var ok := player.cast_slot(1)
			await _frames(40)
			print("cast %-18s %s" % [s["id"], "ok" if ok else "NOT CAST"])
			if not ok:
				failures += 1
		player.take_damage(5.0, game.enemies[0] if game.enemies.size() > 0 else null)
		player.try_roll()
		await _frames(30)
		game.hud.open_skill_tree()
		await _frames(2)
		var panel: SkillTreePanel = game.hud._tree_panel
		for t in panel._tab_labels().size():
			panel._tab = t
			panel._refresh()
			for id in panel._tab_slots(t):
				panel._selected = id[0]
				panel._build_detail()
			await _frames(2)
		game.hud.close_skill_tree()
		game.queue_free()
		await _frames(2)
		print("class %s done" % cls)

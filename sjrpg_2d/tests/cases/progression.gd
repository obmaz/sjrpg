extends TestCase

func run() -> void:
	var game := await make_game()
	GameState.opened_chests.assign([5, 6])
	var before := GameState.skill_points
	game.chests[7].take_damage(1.0, game.player)
	var saved := SaveStore.read(GameState.save_path, GameState._valid_save)
	var data: Dictionary = saved["data"]
	check("last memory persists its point in the same save", data["memory_rewarded"] and int(data["skill_points"]) == before + 1)
	check("memory reward cannot be collected twice", not GameState.collect_memory_reward())
	await _frames(60)
	if game.hud.panel_open():
		game.hud.close_panel()
	game.queue_free()
	await _frames(2)
	# Older saves may contain all chest flags without the point because the old write preceded the award.
	data["memory_rewarded"] = false
	data["skill_points"] = before
	var file := FileAccess.open(GameState.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	check("interrupted older reward is recovered", GameState.load_game() and GameState.memory_rewarded and GameState.skill_points == before + 1)
	check("repeated reads do not duplicate the recovery", GameState.load_game() and GameState.skill_points == before + 1)
	GameState.save_game()
	check("recovered reward remains stable after saving", GameState.load_game() and GameState.skill_points == before + 1)

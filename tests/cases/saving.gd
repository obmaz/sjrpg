extends TestCase
## Interrupted writes, corrupt saves and repeated quest actions must preserve progress.

func run() -> void:
	var original_path := GameState.save_path
	GameState.save_path = "user://tests/recovery.json"
	GameState.delete_save()
	GameState.new_game("warrior")
	GameState.gold = 123
	check("save returns success", GameState.save_game())
	GameState.gold = 456
	check("second save returns success", GameState.save_game())
	_write(GameState.save_path, "{broken")
	GameState.gold = 0
	check("corrupt primary recovers previous backup", GameState.load_game() and GameState.loaded_backup and GameState.gold == 123)
	GameState.gold = 789
	check("recovery can save again", GameState.save_game() and GameState.load_game() and GameState.gold == 789)
	check("corrupt primary does not replace good backup", int(SaveStore._read_one(GameState.save_path + ".bak").get("gold", -1)) == 123)
	GameState.delete_save()
	# Pre-version Godot saves still load; missing fields receive their defaults.
	_write(GameState.save_path, JSON.stringify({"class": "mage", "level": 3, "gold": 42}))
	check("legacy save gets defaults", GameState.load_game() and GameState.level == 3 and GameState.gold == 42 and GameState.inventory.size() == 2)
	_write(GameState.save_path, JSON.stringify({"class": "mage", "version": 999}))
	check("future save is not applied", not GameState.load_game() and GameState.gold == 42)
	_write(GameState.save_path, JSON.stringify({"class": "mage", "inventory": [12]}))
	check("malformed inventory is rejected before applying", not GameState.load_game() and GameState.gold == 42)
	GameState.delete_save()
	GameState.new_game("warrior")
	var state := Quests.state("sun")
	state["phase"] = "accepted"
	state["started"] = true
	state["defeated"] = 17
	state["protected_for"] = 42.0
	Quests.state("roots")["phase"] = "completed"
	GameState.save_game()
	check("interrupted defense becomes retryable", GameState.load_game() and Quests.phase("sun") == "accepted" and not Quests.state("sun")["started"] and Quests.state("sun")["defeated"] == 0)
	check("other quest progress survives recovery", Quests.phase("roots") == "completed")
	var game := preload("res://scripts/game.gd").new()
	add_child(game)
	await _frames(2)
	game.quest_runtime.report("moon")
	check("unearned reward refused", GameState.gold == 0)
	Quests.state("moon")["phase"] = "ready"
	game.quest_runtime.report("moon")
	var gold := GameState.gold
	var xp := GameState.xp
	game.quest_runtime.report("moon")
	game.quest_runtime.accept("moon")
	check("completed quest cannot pay twice or reset", GameState.gold == gold and GameState.xp == xp and Quests.phase("moon") == "completed")
	game.player.revive(game.village.spawn_point)
	check("revive protects for three seconds", game.player._invulnerable == 3.0 and game.player.hp == game.player.max_hp)
	game.queue_free()
	await _frames(2)
	var good_path := GameState.save_path
	GameState.save_path = "user://tests/absent-directory/save.json"
	check("write failure is reported", not GameState.save_game() and not GameState.save_error.is_empty())
	GameState.save_path = good_path
	check("manual retry clears error", GameState.save_game() and GameState.save_error.is_empty())
	GameState.delete_save()
	check("delete removes primary and backup", not GameState.has_save())
	GameState.save_path = original_path


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

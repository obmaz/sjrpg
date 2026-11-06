extends TestCase

func run() -> void:
	for hero in ["warrior", "mage"]:
		var game := await make_game(hero)
		var runtime: QuestRuntime = game.quest_runtime
		check(hero + " starts with the village delivery", Quests.next_quest() == "moon" and "보급원 미라" in Quests.main_objective())
		var mira: Vector2 = game.village.npc_points["보급원 미라"]
		var approach: Vector2 = game.village.spawn_point.lerp(mira, 0.55)
		game.player.position = game.resolve_movement(game.village.spawn_point, approach, Player.RADIUS)
		check(hero + " nearby resident is not hidden by sanctuary interaction", game.near_npc() == "보급원 미라")
		game.player.position = game.village.spawn_point
		check("sanctuary remains available when it is closest", game.near_npc() == "안식처")
		runtime.accept("roots")
		check("player choice takes precedence over an offered delivery", Quests.next_quest() == "roots")
		runtime.accept("moon")
		runtime.receive_parcel()
		check("accepted delivery points toward its recipient", Quests.next_quest() == "moon" and "노아" in Quests.main_objective())
		runtime.deliver()
		runtime.accept("sun")
		runtime.start_protection()
		check("active protection takes priority over a ready report", Quests.next_quest() == "sun" and "보호" in Quests.main_objective())
		runtime._fail(Quests.state("sun"))
		check("ready delivery takes priority over retrying a failed defense", Quests.next_quest() == "moon")
		Quests.state("sun")["phase"] = "ready"
		check("finished defense prompts immediate reporting", Quests.next_quest() == "sun")
		runtime.report("sun")
		runtime.report("moon")
		check("remaining accepted quest is resumed", Quests.next_quest() == "roots")
		Quests.state("roots")["phase"] = "completed"
		check("finished requests point to the boss without extra kills", Quests.next_quest() == "" and "파수꾼" in Quests.main_objective())
		game.queue_free()
		await _frames(2)

extends TestCase
## 실제 숲 어댑터를 거쳐 원정 선택, 보상, 저장 복원, 봉인/보스/귀환을 검증한다.


func run() -> void:
	var game := await make_game("mage")
	game.set_process(false)
	game.player.set_process(false)
	game.encounters.set_process(false)
	game.expedition.set_process(false)
	GameState.discovered_sanctuaries.append("tree")
	GameState.last_sanctuary = "tree"
	GameState.level = 17
	GameState.gold = 321
	GameState.ranks["fireball"] = 7
	GameState.save_game()
	var original := ExpeditionProfile.capture()
	check("contract only starts from town", game.in_town(game.player.position))
	check(
		"contract starts a separate level-one run",
		(
			game.expedition.start("hearth")
			and GameState.level == 1
			and GameState.gold == 0
			and GameState.rank("fireball") == 0
		)
	)
	# Tests retain the world adapter; the operational Main reloads it via the signal.
	game.process_mode = Node.PROCESS_MODE_INHERIT
	game.player.dead = false
	game.expedition.set_process(false)
	GameState.encounter_capture = game.encounters.capture
	game.encounters.states = GameState.encounters
	for id: String in game.encounters.stones:
		GameState.encounters[id] = {
			"charges": 3, "recharge": 0.0, "initial_spawned": true, "members": []
		}
	var cards := RunBuild.offer().duplicate(true)
	check("starter has three choices", cards.size() == 3)
	check("saved draft resumes identically", GameState.load_game() and RunBuild.offer() == cards)
	game.encounters.states = GameState.encounters
	GameState.encounter_capture = game.encounters.capture
	var chosen: Dictionary = cards[0]
	check(
		"choice grants a free signature without prerequisites",
		(
			game.expedition.choose(chosen["key"])
			and GameState.rank(chosen["id"]) == 1
			and SkillDefs.cost(GameState.skill(chosen["id"]), 1) == 0
		)
	)
	check("stale double-tap cannot take another reward", not game.expedition.choose(chosen["key"]))
	check(
		"unselected quests and boss remain locked",
		not game.quest_runtime.boss_ready() and not ExpeditionState.quest_allowed("sun")
	)
	check(
		"delivery can be selected with supplies", game.expedition.select_mission("moon", "supplies")
	)
	game.quest_runtime.receive_parcel()
	game.quest_runtime.deliver()
	var potions := GameState.potions
	game.quest_runtime.report("moon")
	check(
		"actual quest report advances run and awards supplies",
		ExpeditionState.phase() == "mission_reward" and GameState.potions == potions + 2
	)
	_take_drafts(game)
	check(
		"same mission cannot be repeated",
		(
			ExpeditionState.phase() == "missions"
			and not game.expedition.select_mission("moon", "draft")
		)
	)
	check("second mission accepts growth reward", game.expedition.select_mission("roots", "draft"))
	for index in Quests.ALTAR_KILL_GOAL:
		var enemy := Enemy.new()
		enemy.setup(game, "goblin", 1)
		enemy.position = game.quest_runtime.site("roots") + Vector2(index, 0)
		game.world.add_child(enemy)
		game.enemies.append(enemy)
		enemy.take_damage(99999, game.player)
	game.quest_runtime.cleanse()
	game.quest_runtime.report("roots")
	check(
		"real altar combat and report complete selected mission",
		GameState.expedition["missions"].size() == 2 and ExpeditionState.phase() == "mission_reward"
	)
	_take_drafts(game)
	check("two missions lead to optional branch", ExpeditionState.phase() == "branch")
	check("optional elite branch can be selected", game.expedition.branch("elite"))
	game.player.position = game.encounters.stones["deep_east"].position + Vector2(250, 150)
	game.expedition._spawn_elite()
	var elite: Enemy = game.expedition._elite
	if not check("elite spawns at its real field anchor", is_instance_valid(elite)):
		game.queue_free()
		return
	elite.take_damage(999999, game.player)
	check("actual elite death grants optional reward", ExpeditionState.phase() == "bonus_reward")
	_take_drafts(game)
	check("optional reward leads to seals", ExpeditionState.phase() == "seals")

	game.expedition.wave_cleared("deep_west")
	check("random kills cannot clear an unarmed seal", GameState.expedition["seals"].is_empty())
	for id: String in ExpeditionState.chapter()["seals"]:
		game.player.position = game.encounters.stones[id].position + Vector2(200, 120)
		var count: int = game.encounters.spawn_wave(id, false)
		check("seal requires a real summoned pack: " + id, count > 0)
		await _frames(2)
		for member: Enemy in game.encounters._members[id].duplicate():
			member.take_damage(999999, game.player)
		_take_drafts(game)
	check(
		"two complete packs unlock boss after reward",
		ExpeditionState.phase() == "boss" and game.quest_runtime.boss_ready()
	)
	game.player.position = game.village.boss_point + Vector2(0, 130)
	check("run boss can be challenged", game.quest_runtime.start_boss())
	game.quest_runtime._boss.take_damage(999999, game.player)
	check(
		"boss death requires a return to town",
		ExpeditionState.phase() == "return" and not game.expedition.settle(true)
	)
	game.player.position = game.village.npc_points["촌장"]
	check("town report settles run", game.expedition.settle(true))
	check(
		"original hero and gear are restored",
		(
			GameState.level == 17
			and GameState.gold == 321
			and GameState.rank("fireball") == 7
			and ExpeditionProfile.capture()["inventory"] == original["inventory"]
		)
	)
	check(
		"success persists renown and town supply recovery",
		(
			GameState.expedition_meta.get("renown") == 6
			and GameState.expedition_meta["clears"]["forest_1"] == 1
		)
	)
	check(
		"debrief returns to town without losing discovered waypoints",
		GameState.last_sanctuary == "town" and GameState.discovered_sanctuaries.has("tree")
	)
	check(
		"settlement cannot be claimed twice",
		(
			not game.expedition.settle(true)
			and GameState.load_game()
			and ExpeditionState.phase() == "debrief"
		)
	)
	check(
		"new abilities unlock through renown",
		(
			ExpeditionContent.pool("mage", 6).has("stormLance")
			and not ExpeditionContent.pool("mage", 0).has("stormLance")
		)
	)
	game.queue_free()
	get_tree().paused = false
	await _frames(2)


func _take_drafts(game: Node) -> void:
	for index in 20:
		if GameState.expedition.get("drafts", []).is_empty():
			return
		var cards := RunBuild.offer()
		if not check("reward offers three distinct choices", cards.size() == 3):
			return
		if not check("reward commits", game.expedition.choose(cards[0]["key"])):
			return

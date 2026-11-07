extends TestCase
## 제1장 퀘스트 3종, 실패·재도전, 파수꾼, 대화·일지 패널


func run() -> void:
	# Native startup spans physics/process frames and creates ambient packs last.
	# Clear enemies only after that real readiness barrier, as other game fixtures do.
	var game := await make_game("warrior")
	var qr: QuestRuntime = game.quest_runtime
	var player: Player = game.player
	var level0 := GameState.level
	var gold0 := GameState.gold
	# 1) 제단 정화: accept, kill 18 near the altar, cleanse, report.
	qr.accept("roots")
	for i in Quests.ALTAR_KILL_GOAL:
		var e := Enemy.new()
		e.setup(game, "goblin", 1)
		e.position = qr.site("roots") + Vector2(80 + i, 0)
		game.world.add_child(e)
		game.enemies.append(e)
		e.take_damage(9999.0, null)
	await _frames(2)
	var blocked := qr.cleanse_blocked_reason()
	if blocked == "":
		qr.cleanse()
		qr.report("roots")
	check("altar quest completes after the actual kill and cleanse sequence", Quests.phase("roots") == "completed", "blocked=%s; kills=%d; phase=%s" % [blocked, Quests.state("roots")["altar_kills"], Quests.phase("roots")])
	# 2) 약초 배달.
	qr.accept("moon")
	qr.receive_parcel()
	qr.deliver()
	qr.report("moon")
	print("quest moon: %s" % ("ok" if Quests.phase("moon") == "completed" else "FAIL"))
	if Quests.phase("moon") != "completed":
		failures += 1
	# 3) 조사관 보호: lose once, retry, then win.
	qr.accept("sun")
	qr.start_protection()
	await _frames(6)
	Quests.state("sun")["defender_hp"] = 0.0
	await _frames(3)
	var failed := Quests.phase("sun") == "failed"
	qr.retry("sun")
	qr.start_protection()
	for i in 900:
		qr._wave_pause = 0.0
		for e in game.enemies:
			if e.is_threat and not e.dead:
				e.take_damage(99999.0, null)
		if Quests.state("sun")["defeated"] >= Quests.THREAT_COUNT:
			Quests.state("sun")["protected_for"] = Quests.PROTECT_SECONDS + 1.0
		await get_tree().process_frame
		if Quests.phase("sun") == "ready":
			break
	var won := Quests.phase("sun") == "ready"
	if won:
		qr.report("sun")
	print("quest sun: fail path %s, win path %s (defeated %d)" % ["ok" if failed else "FAIL", "ok" if won else "FAIL", Quests.state("sun")["defeated"]])
	if not failed or not won:
		failures += 1
	var paid := GameState.gold - gold0 == 120 + 80 + 300 and GameState.level > level0
	print("quest rewards: %s (gold +%d, level %d -> %d)" % ["ok" if paid else "FAIL", GameState.gold - gold0, level0, GameState.level])
	if not paid:
		failures += 1
	# 4) 파수꾼.
	GameState.stage_kills = 0
	check("boss unlock does not require extra kills", qr.boss_ready())
	check("cannot start boss from town", not qr.start_boss())
	player.position = game.village.boss_point + Vector2(0, 130)
	check("start boss at the clearing", qr.start_boss())
	check("cannot summon a second boss", not qr.start_boss())
	qr.reset_boss()
	check("boss can be retried", qr.boss_ready() and qr.start_boss())
	await _frames(4)
	var boss: Enemy = null
	for e in game.enemies:
		if e.is_boss:
			boss = e
	print("boss summoned: %s" % ("ok" if boss != null else "FAIL"))
	if boss == null:
		failures += 1
	else:
		boss.take_damage(9999999.0, null)
		await _frames(100)
		var has_heart := false
		for g in GameState.inventory:
			if g.base["id"] == "sentinel":
				has_heart = true
		var cleared := GameState.boss_defeated and has_heart
		print("boss defeated: %s, victory panel %s" % ["ok" if cleared else "FAIL", "open" if game.hud.panel_open() else "NOT OPEN"])
		if not cleared:
			failures += 1
	# 5) Dialogue / journal panels build for every NPC.
	if game.hud.panel_open():
		game.hud.close_panel()
	for npc in ["수녀 엘린", "보급원 미라", "약초사 노아", "조사관 로웬", "촌장"]:
		game.hud.interact(npc)
		await _frames(2)
		game.hud.close_panel()
	game.hud.open_journal()
	await _frames(2)
	game.hud.close_panel()
	game.queue_free()
	await _frames(2)

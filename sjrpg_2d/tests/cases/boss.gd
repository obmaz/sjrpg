extends TestCase

func run() -> void:
	var game := await make_game()
	for definition in Quests.DEFS:
		Quests.state(definition["id"])["phase"] = "completed"
	game.player.position = game.village.boss_point + Vector2(0, 130)
	check("clearing is walkable", not game._blocked(game.village.boss_point, Enemy.RADIUS))
	check("explicit boss challenge starts", game.quest_runtime.start_boss())
	var boss: Enemy = game.quest_runtime._boss
	check("warning ellipse contains the actual hit", boss.attack_distance(boss.position + Vector2(0, 209.0 * 0.55)) < 210.0)
	check("outside warning ellipse is safe", boss.attack_distance(boss.position + Vector2(0, 211.0 * 0.55)) > 210.0)
	game.player.position = game.village.spawn_point
	game.quest_runtime._tick_boss(0.0)
	check("leaving the clearing permits retry", not GameState.boss_summoned and game.quest_runtime.boss_ready())
	game.player.position = game.village.boss_point + Vector2(0, 130)
	game.quest_runtime.start_boss()
	boss = game.quest_runtime._boss
	while GameState.inventory.size() < Gear.CAPACITY:
		GameState.add_gear(GameState.new_gear("shortsword"))
	boss.take_damage(999999.0, null)
	check("full bag preserves unique reward", GameState.boss_defeated and GameState.boss_heart_pending)
	GameState.save_game()
	check("pending reward survives reload", GameState.load_game() and GameState.boss_heart_pending)
	check("full bag cannot claim", not GameState.claim_boss_heart())
	var spare: Gear = GameState.inventory.back()
	GameState.sell(spare)
	check("unique reward can be claimed after clearing a slot", GameState.claim_boss_heart() and not GameState.boss_heart_pending)
	check("unique reward cannot be claimed twice", not GameState.claim_boss_heart())
	var count := 0
	for gear in GameState.inventory:
		if gear.base["id"] == "sentinel":
			count += 1
	check("exactly one heart awarded", count == 1)
	# Let the victory presentation finish before freeing its game.
	await _frames(100)
	if game.hud.panel_open():
		game.hud.close_panel()
	game.queue_free()
	await _frames(2)

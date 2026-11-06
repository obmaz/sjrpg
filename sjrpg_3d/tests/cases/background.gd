extends TestCase

func run() -> void:
	var previous := Prefs.low_resolution
	for low in [false, true]:
		Prefs.set_low_resolution(low)
		var game := await make_game()
		var runtime: QuestRuntime = game.quest_runtime
		runtime.accept("sun")
		runtime.start_protection()
		var controls: TouchControls = game.hud.controls
		controls._layout()
		controls._press(10, controls._stick_center)
		controls._drag(10, controls._stick_center + Vector2(50, 0))
		controls._press(11, controls._buttons["slot0"]["center"])
		Input.action_press("move_right")
		Input.action_press("attack")
		GameState.gold = 317
		game.notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
		check("focus loss pauses and releases touch and keyboard", get_tree().paused and game.hud.panel_open() and controls._held.is_empty() and game.player.held_slots.is_empty() and game.player.move_input == Vector2.ZERO and not Input.is_action_pressed("move_right") and not Input.is_action_pressed("attack"))
		var saved := SaveStore.read(GameState.save_path, GameState._valid_save)
		check("background entry saves current progress", saved["data"]["gold"] == 317)
		var panel: PanelFrame = game.hud._panel
		game.notification(NOTIFICATION_APPLICATION_PAUSED)
		check("duplicate background signals keep the same pause panel", game.hud._panel == panel)
		var time: float = Quests.state("sun")["protected_for"]
		await get_tree().create_timer(0.25).timeout
		check("protection clock freezes in both render qualities", Quests.state("sun")["protected_for"] == time)
		game.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
		check("returning to the app waits for explicit resume", get_tree().paused)
		game.hud.close_panel()
		await _frames(3)
		check("protection clock resumes after closing pause", float(Quests.state("sun")["protected_for"]) > time)
		runtime._fail(Quests.state("sun"))
		game.player.position = game.dungeon.entry_point()
		check("cave opens after ending protection", game.dungeon.enter())
		game.hud.open_map()
		panel = game.hud._panel
		game.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		time = game.dungeon.remaining
		await get_tree().create_timer(0.25).timeout
		check("background preserves an existing map and freezes the cave clock", game.hud._panel == panel and game.dungeon.remaining == time)
		game.hud.close_panel()
		game.dungeon.leave("테스트")
		game.queue_free()
		await _frames(2)
	Prefs.set_low_resolution(previous)
	await _delayed_actions()


func _delayed_actions() -> void:
	var game := await make_game()
	var target := Enemy.new()
	target.setup(game, "boar", 1)
	target.position = game.player.position + Vector2(40, 0)
	game.world.add_child(target)
	game.enemies.append(target)
	target.set_process(false)
	game.player._spin("whirlwind", SkillDefs.get_def("whirlwind"), 1.0)
	game.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var health := target.hp
	await get_tree().create_timer(0.45).timeout
	check("delayed spin hits wait while paused", target.hp == health)
	game.hud.close_panel()
	await get_tree().create_timer(0.45).timeout
	check("delayed spin continues after resume", target.hp < health)
	game.player._invulnerable = 0.0
	game.player.take_damage(999999.0)
	game.notification(NOTIFICATION_APPLICATION_PAUSED)
	await get_tree().create_timer(2.7).timeout
	check("respawn countdown waits while paused", game.player.dead)
	game.hud.close_panel()
	await get_tree().create_timer(2.7).timeout
	check("respawn countdown continues after resume", not game.player.dead)
	game.queue_free()
	await _frames(2)

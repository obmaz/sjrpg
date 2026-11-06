extends TestCase

func _cues(game: Node, large := false) -> int:
	var count := 0
	for effect in game.cosmetic_effects:
		if not effect.is_queued_for_deletion() and effect.kind == "reward" and bool(effect.params.get("large", false)) == large:
			count += 1
	return count

func run() -> void:
	var game := await make_game()
	game.grant_xp(0)
	check("zero XP cannot emit level-up reward", _cues(game, true) == 0)
	var points: int = GameState.skill_points
	game.grant_xp(GameState.xp_to_next())
	check("level up grants actual points and one cue", GameState.level == 2 and GameState.skill_points == points + 1 and _cues(game, true) == 1)
	var banner: LevelUpBanner = game.hud._level_up
	check("level up uses nonblocking English banner", is_instance_valid(banner) and banner.active and banner.level == GameState.level and LevelUpBanner.TITLE == "LEVEL UP" and banner.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var queued_level_text := false
	for notice in game.hud._toast_queue:
		if str(notice.get("text", "")).contains("레벨 업"):
			queued_level_text = true
	check("level up no longer queues text plaque", not game.hud._toast.text.contains("레벨 업") and not queued_level_text)
	game.grant_xp(1000)
	check("multi-level grant emits one additional level cue", GameState.level > 3 and _cues(game, true) == 2)
	check("consecutive level grants reuse one banner with latest level", game.hud._level_up == banner and banner.level == GameState.level and banner.age == 0.0)
	for view in [Vector2(720, 1280), Vector2(1280, 720), Vector2(720, 1560), Vector2(568, 320)]:
		var margins := Vector4(8, 26, 8, 16)
		var safe := Rect2(Vector2(8, 26), view - Vector2(16, 42))
		check("level banner stays within safe portrait/landscape area %s" % view, safe.encloses(LevelUpBanner.banner_rect(view, margins)))
	var following: RewardFx = RewardFx.spawn(game, game.player.position + Vector2(0, -32), 1, true)
	var hero_start: Vector2 = game.player.position
	game.player.position += Vector2(80, 20)
	following._process(0.05)
	check("level celebration follows moving hero at its original height", following.position.is_equal_approx(game.player.position + Vector2(0, -32)))
	game.player.position = hero_start
	following.queue_free()
	var chest: Chest = game.chests[0]
	var gold: int = GameState.gold
	chest.take_damage(1, game.player)
	var collected: int = GameState.gold
	var cues := _cues(game)
	chest.take_damage(1, game.player)
	check("opening chest twice cannot duplicate gold or cue", collected > gold and GameState.gold == collected and _cues(game) == cues)
	var hud: Hud = game.hud
	hud._toast_time = 0
	hud._toast_queue.clear()
	hud.toast("획득 확인")
	hud.toast("레벨 업 확인")
	hud.toast("레벨 업 확인")
	await _frames(3)
	check("confirmation text has visible layout inside its plaque", hud._toast.size.x > 0 and hud._toast.size.y > 0 and hud._toast_plaque.get_global_rect().encloses(hud._toast.get_global_rect()) and hud._toast.get_visible_line_count() > 0, "label=%s plaque=%s lines=%d visible=%s" % [hud._toast.get_global_rect(), hud._toast_plaque.get_global_rect(), hud._toast.get_visible_line_count(), hud._toast.visible])
	check("simultaneous confirmations wait without duplicate spam", hud._toast.text == "획득 확인" and hud._toast_queue.size() == 1)
	hud._tick_toasts(4.0)
	check("next confirmation is delivered", hud._toast.text == "레벨 업 확인")
	for i in 12:
		hud.toast("알림 %d" % i)
	check("pending confirmations remain bounded", hud._toast_queue.size() <= 4)
	hud._tick_toasts(10.0)
	check("stale confirmations expire", hud._toast_queue.is_empty() and hud._toast.text.is_empty())
	var old_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = true
	banner.show_level(7)
	banner._process(0.8)
	check("slow first frame still presents level banner", banner.active and banner.age <= 0.061)
	check("reduced motion removes banner drift", banner.rise_offset() == 0.0)
	banner._process(2.0)
	check("banner expires without rendering or input blocking", not banner.active and not banner.visible and banner.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var cue := RewardFx.spawn(game, game.player.position, 2)
	var original := cue.position
	cue._process(0.1)
	check("reduced motion keeps reward cue stationary", cue.position == original)
	cue._process(2.0)
	check("reward cue expires even without rendering", cue.is_queued_for_deletion())
	for i in 100:
		RewardFx.spawn(game, game.player.position)
	check("reward effects share the cosmetic budget", game.cosmetic_effects.size() <= 64)
	Prefs.reduce_motion = old_reduce
	game.queue_free()
	await _frames(2)

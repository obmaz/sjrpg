extends TestCase

func run() -> void:
	var game := await make_game()
	game.hud.open_smith()
	await _frames(2)
	var smith: BlacksmithPanel = game.hud._panel
	var weapon: Gear = GameState.equipped["weapon"]
	GameState.gold = 10000
	var cost := BlacksmithPanel.price(weapon)
	var level := weapon.weapon_level
	smith._enhance(weapon, 0.0, cost)
	check("failed enhancement preserves equipped weapon and level", GameState.inventory.has(weapon) and GameState.equipped["weapon"] == weapon and weapon.weapon_level == level and GameState.gold == 10000 - cost)
	weapon.locked = true
	smith._enhance(weapon, 1.0, cost)
	check("locked weapon cannot consume gold or upgrade", GameState.gold == 10000 - cost and weapon.weapon_level == level)
	weapon.locked = false
	smith._enhance(weapon, 1.0, cost)
	check("successful enhancement adds one level", weapon.weapon_level == level + 1)
	game.hud.close_panel()
	# Use real attack execution to verify the displayed weapon interval and reach.
	game.player.set_process(false)
	# 확대된 광장 우물과 무관하게 무기 자체의 사거리/간격을 검사한다.
	game.spatial_world.teleport_source_actor(game.player, game.village.spawn_point + Vector2(0, 180), Player.RADIUS)
	for id in ["rapier", "spear", "greatsword"]:
		weapon = Gear.make(GameState.next_serial, id)
		GameState.next_serial += 1
		GameState.inventory.append(weapon)
		GameState.equipped["weapon"] = weapon
		game.player._attack_time = 0.0
		game.player.facing = 0.0
		var target := Enemy.new()
		target.setup(game, "goblin", 1)
		target.position = game.player.position + Vector2(float(weapon.melee_profile()["range"]) - 1.0, 0)
		game.world.add_child(target)
		game.enemies.append(target)
		var hp := target.hp
		check("weapon attack starts: " + id, game.player.cast_slot(0))
		check("actual interval matches weapon: " + id, is_equal_approx(game.player._attack_duration, float(weapon.melee_profile()["tempo"])))
		var action: Callable = game.player._pending
		game.player._pending = Callable()
		action.call()
		check("target inside stated reach takes damage: " + id, target.hp < hp)
		if game.enemies.has(target):
			game.enemies.erase(target)
		if is_instance_valid(target) and not target.is_queued_for_deletion():
			target.queue_free()
	var gold := GameState.gold
	GameState.level = 5
	GameState.skill_points = 10
	GameState.learn("bash")
	var total := GameState.skill_points + GameState.invested_points()
	GameState.reset_skills()
	check("free reset refunds all investment", GameState.gold == gold and GameState.skill_points == total and GameState.rank("cleave") == 1)
	check("area difficulty does not follow hero level", ForestBalance.area_level(0) == 1 and ForestBalance.area_level(3) == 7)
	game.queue_free()
	await _frames(2)

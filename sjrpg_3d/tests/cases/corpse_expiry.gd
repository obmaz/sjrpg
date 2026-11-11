extends TestCase
## 실제 모험 프레임으로 수명이 끝나면 스킬 대상과 3D 시체를 모두 없앤다.


func run() -> void:
	var game := await make_game("mage")
	game._spawn_timer = 10000.0
	game.player.set_process(false)
	var enemy := Enemy.new()
	enemy.setup(game, "wolf", 1)
	enemy.position = game.player.position + Vector2(80, 0)
	game.world.add_child(enemy)
	enemy.set_process(false)
	var corpse: Dictionary = game.add_corpse(enemy, true)
	check(
		"fresh bodies have a bounded fifteen-second lifetime",
		corpse["time"] == 15.0 and corpse["lifetime"] == 15.0
	)
	await _frames(3)
	var id: int = corpse["visual"].get_instance_id()
	var entry: Dictionary = game.ortho_preview._world_environment._corpses.get(id, {})
	check("the real native corpse is registered before expiry", not entry.is_empty())
	corpse["time"] = .12
	await get_tree().create_timer(.30, false).timeout
	check(
		"normal frame ticks remove expired targets and 3D bodies",
		(
			not game.corpses.has(corpse)
			and corpse["used"]
			and not game.corpse_available(corpse)
			and not game.ortho_preview._world_environment._corpses.has(id)
		)
	)
	var hidden: Dictionary = game.add_corpse(enemy, true)
	hidden["time"] = 1.0
	game.player.position = game.dungeon.entry_point()
	if check("expiry check enters the actual cave", game.dungeon.enter()):
		game.dungeon.tick(1.1)
		check(
			"hidden field bodies also expire while exploring another area",
			hidden["used"] and game.dungeon._forest_corpses.is_empty()
		)
		game.dungeon.leave("", false)
		check("returning never resurrects an expired field body", game.corpses.is_empty())
	game.queue_free()
	await _frames(2)

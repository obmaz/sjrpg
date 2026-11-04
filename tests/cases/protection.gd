extends TestCase

func run() -> void:
	var game := await make_game()
	game.set_process(false)
	game.player.set_process(false)
	var runtime: QuestRuntime = game.quest_runtime
	runtime.set_process(false)
	runtime.accept("sun")
	runtime.start_protection()
	var defense := Quests.state("sun")
	var center := runtime.defender_position()
	game.player.position = center + Vector2(75, 0)
	var enemy := Enemy.new()
	enemy.setup(game, "goblin", 1)
	enemy.position = center + Vector2(30, 0)
	enemy.is_threat = true
	enemy.force_chase()
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	enemy.set_process(false)
	# Both targets are in reach, and the investigator is closer.
	var health: float = defense["defender_hp"]
	enemy._process(0.01)
	enemy._process(0.56)
	check("unprovoked threat attacks the closer investigator", float(defense["defender_hp"]) < health)
	GameState.level = 6
	check("warrior can learn protection taunt", GameState.learn("taunt"))
	GameState.assign_slot(2, "taunt")
	game.player.resource = game.player.resource_max
	check("real taunt skill casts", game.player.cast_slot(2))
	game.player._process(0.3)
	health = defense["defender_hp"]
	var hero_health: float = game.player.hp
	enemy._process(0.01)
	enemy._process(0.56)
	check("taunted threat leaves the closer investigator unharmed", float(defense["defender_hp"]) == health)
	check("taunted threat attacks the warrior instead", game.player.hp < hero_health)
	# Expiration restores normal target choice without another skill or wave.
	enemy._taunt_time = 0.01
	enemy.force_chase()
	enemy._process(0.02)
	enemy._process(0.56)
	check("expired taunt restores the closer investigator target", float(defense["defender_hp"]) < health)
	# A dead taunter cannot make the investigator immune to threats.
	enemy.taunt(6.0)
	game.player.dead = true
	health = defense["defender_hp"]
	enemy._process(0.01)
	enemy._process(0.56)
	check("dead taunter does not prevent attacks on the investigator", float(defense["defender_hp"]) < health)
	game.queue_free()
	await _frames(2)

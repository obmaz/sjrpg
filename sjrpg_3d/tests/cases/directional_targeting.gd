extends TestCase
## 입력 의도·표시·실제 타격이 같은 전방을 사용하고 근접 뒤쪽 예외가 되살아나지 않는다.


class ChestProbe:
	extends Chest
	var contacts := 0

	func take_damage(_amount: float, _source: Node2D) -> void:
		contacts += 1


func _foe(game: Node, offset: Vector2) -> Enemy:
	var foe := Enemy.new()
	foe.setup(game, "wolf", 1)
	foe.position = game.player.position + offset
	foe.hp = 100000.0
	foe.max_hp = foe.hp
	game.world.add_child(foe)
	game.enemies.append(foe)
	foe.set_process(false)
	return foe


func run() -> void:
	var game := await make_game()
	game.set_process(false)
	game.encounters.set_process(false)
	var player: Player = game.player
	player.set_process(false)
	var origin := player.position
	var foes: Array[Enemy] = []
	for direction: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		foes.append(_foe(game, direction * 60.0))
	for index in foes.size():
		player.facing = float(index) * PI / 2.0
		player._assisted_facing = INF
		check(
			"four-way enemies follow the player's facing %d" % index,
			player.aim_target(170.0) == foes[index]
		)
	player.facing = 0.0
	foes[2].position = origin + Vector2(-10, 0)
	check("a closer enemy behind cannot steal forward aim", player.aim_target(170.0) == foes[0])
	foes[0].position = origin + Vector2(80, 0)
	foes[1].position = origin + Vector2(30, 29)
	check(
		"alignment takes priority over a nearer edge-of-cone enemy",
		player.aim_target(170.0) == foes[0]
	)
	player.move_input = Vector2.UP
	check(
		"fresh joystick input works before the next movement frame",
		player.aim_target(170.0) == foes[3]
	)
	player.move_input = Vector2.ZERO
	player.set_move_target(origin + Vector2(0, -100))
	check("point movement also supplies the intended bearing", player.aim_target(170.0) == foes[3])
	player.clear_move_target()
	Input.action_press("move_up")
	check("fresh keyboard input shares directional targeting", player.aim_target(170.0) == foes[3])
	Input.action_release("move_up")
	player.move_input = Vector2.LEFT
	player.set_pointer_aim(origin + Vector2(100, 0))
	check(
		"world pointer aim overrides movement for desktop attacks",
		player.aim_target(170.0) == foes[0]
	)
	player._process(0.01)
	check("moving does not overwrite a held world pointer bearing", absf(player.facing) < 0.01)
	game.hud.controls._release(-1)
	check("mouse release clears its temporary bearing", not player._pointer_aim_at.is_finite())
	player.move_input = Vector2.ZERO
	player.position = origin
	for foe in foes:
		foe.dead = true
	foes[1].dead = false
	foes[1].position = origin + Vector2(60, 20)
	player.facing = 0.0
	player._assisted_facing = INF
	player._aim(170.0)
	check(
		"one forward enemy receives a small aim correction",
		player.facing > 0.0 and player.facing < PI / 4.0
	)
	check(
		"aim assistance does not become the player's next input",
		absf(player.aim_direction().angle()) < 0.0001
	)
	foes[1].position = origin + Vector2(10, 60)
	check(
		"repeated attacks cannot drift around the cone toward side enemies",
		player._aim(170.0) == null and absf(player.facing) < 0.0001
	)
	foes[1].position = origin + Vector2(-20, 0)
	check(
		"no forward enemy leaves the original bearing unchanged",
		player._aim(170.0) == null and is_zero_approx(player.facing)
	)
	check(
		"rear contact is excluded even at less than 30px",
		game.enemies_in_arc(origin, 0.0, 100.0, PI / 3.0).is_empty()
	)
	foes[1].position = origin + Vector2(20, 0)
	check(
		"forward close contact is retained",
		game.enemies_in_arc(origin, 0.0, 100.0, PI / 3.0).has(foes[1])
	)
	foes[1].position = origin + Vector2(-90, 0)
	player._attack_lunges = true
	player._attack_duration = 0.4
	player._pending = func(): pass
	var reduced := Prefs.reduce_motion
	Prefs.reduce_motion = false
	player._lunge(0.03, 0.1)
	Prefs.reduce_motion = reduced
	check("wind-up cannot pull the player toward a rear enemy", player.position == origin)
	var old_chests: Array[Chest] = game.chests.duplicate()
	game.chests.clear()
	var chest := ChestProbe.new()
	chest.position = origin + Vector2(-20, 0)
	game.world.add_child(chest)
	game.chests.append(chest)
	check(
		"prop fallback also ignores rear chests", player._front_prop(170.0, Vector2.RIGHT) == null
	)
	game.break_chests_in_arc(origin, 0.0, 100.0, PI / 3.0, player)
	check("very close rear chests are protected from forward swings", chest.contacts == 0)
	chest.position = origin + Vector2(20, 0)
	game.break_chests_in_arc(origin, 0.0, 100.0, PI / 3.0, player)
	check("the same forward swing still hits a front chest", chest.contacts == 1)
	game.chests = old_chests
	chest.queue_free()
	player._pending = Callable()
	player._cancel_actions()
	player.cooldowns.clear()
	player.facing = 0.0
	player.resource = player.resource_max
	check(
		"an empty forward direction still allows an attack",
		player.cast_slot(0) and is_zero_approx(player.facing) and player._aimed_enemy == null
	)
	player._pending = Callable()
	player._process(1.0)
	check("attack completion restores the last input heading", is_zero_approx(player.facing))
	check(
		"the front cone wraps across negative pi",
		DirectionalAim.contains(Vector2.from_angle(-PI + 0.1), Vector2.from_angle(PI - 0.1))
	)
	player._cancel_actions()
	player.facing = 0.0
	foes[0].dead = false
	foes[0].position = origin + Vector2(60, 0)
	var chain := player._prepare("chainLightning", SkillDefs.get_def("chainLightning"), 1)
	foes[0].dead = true
	var rear_hp := foes[1].hp
	if chain.is_valid():
		chain.call()
	check(
		"a lost chain-lightning first target cannot fall back behind",
		chain.is_valid() and foes[1].hp == rear_hp
	)
	player._cancel_actions()
	player.facing = 0.0
	foes[0].dead = false
	var leap := player._prepare("leapAttack", SkillDefs.get_def("leapAttack"), 1)
	foes[0].position = origin + Vector2(-60, 0)
	var before_leap := player.position
	if leap.is_valid():
		leap.call()
	check(
		"a captured leap target moving behind cannot turn the player around",
		leap.is_valid() and player.position == before_leap
	)
	player._cancel_actions()
	player.facing = 0.0
	player._shadow("shadowStrike", {"range": 300.0, "targets": 3}, 1.0)
	check(
		"shadow-strike hops never find targets behind",
		player.position == before_leap and foes[1].hp == rear_hp
	)
	game.queue_free()
	await _frames(3)

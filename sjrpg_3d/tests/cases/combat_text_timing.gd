extends TestCase
## 같은 프레임의 실제 피해는 즉시 적용하고 숫자만 짧게 나눠 표시한다.


func run() -> void:
	var game := await make_game("mage")
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var labels: Array[Effect] = []
	var targets: Array[Enemy] = []
	var immediate := true
	for index in 12:
		var enemy := Enemy.new()
		enemy.setup(game, "goblin", 1)
		enemy.position = Vector2(-2300 + index * 100, 2000)
		enemy.hp = 1000.0
		enemy.max_hp = enemy.hp
		game.world.add_child(enemy)
		game.enemies.append(enemy)
		targets.append(enemy)
		enemy.take_damage(10.0 + index, null)
		immediate = immediate and is_equal_approx(enemy.hp, 990.0 - index)
		labels.append(game.cosmetic_effects.back())
	check("all simultaneous victims lose their exact HP immediately", immediate)
	var preview: Ortho3DPreview = game.ortho_preview
	preview._sync_cards()
	var first_only := preview._labels.has(labels[0].get_instance_id())
	var bounded := true
	var ordered := true
	var schedule: Array[int] = []
	for index in labels.size():
		var label := labels[index]
		schedule.append(roundi(-label.age * 1000.0))
		bounded = bounded and label.age >= -Effect.TEXT_STAGGER_MAX
		if index > 0:
			ordered = ordered and label.age < labels[index - 1].age
			first_only = (
				first_only and label.age < 0.0 and not preview._labels.has(label.get_instance_id())
			)
	check("only the first damage number is drawn on the contact frame", first_only)
	check("a dense group never delays any number beyond 200 ms", bounded)
	check("dense groups keep distinct ordered release times instead of a final clump", ordered)
	print("ART_AUDIT damage_number_schedule_ms ", schedule)
	game.float_text(targets[0].position, "+9 XP", Color.WHITE)
	var reward: Effect = game.cosmetic_effects.back()
	check("reward text does not enter the damage presentation queue", reward.age == 0.0)
	var second := labels[1]
	var before := second.position
	second._process(0.02)
	preview._sync_cards()
	check(
		"a waiting number follows its anchor without rising or rendering",
		(
			second.age < 0.0
			and second.position == before
			and not preview._labels.has(second.get_instance_id())
		)
	)
	second._process(0.02)
	preview._sync_cards()
	check(
		"the second number starts its full pop after 40 ms",
		second.age == 0.0 and preview._labels.has(second.get_instance_id())
	)
	var third := labels[2]
	third.process_mode = Node.PROCESS_MODE_PAUSABLE
	var paused_age := third.age
	get_tree().paused = true
	await _frames(2)
	check("pause freezes an unreleased number's presentation delay", third.age == paused_age)
	get_tree().paused = false
	third.process_mode = Node.PROCESS_MODE_DISABLED
	var pending_ages: Array[float] = []
	for label in labels:
		label._process(0.03)
		pending_ages.append(label.age)
	targets[0].take_damage(3.0, null)
	var never_postponed := true
	for index in labels.size():
		never_postponed = never_postponed and labels[index].age >= pending_ages[index]
	check("a later hit cannot restart or extend older numbers' waiting time", never_postponed)
	for label in labels:
		label._process(Effect.TEXT_STAGGER_MAX)
	preview._sync_cards()
	var released := true
	for label in labels:
		released = (
			released
			and label.age >= 0.0
			and (preview._labels[label.get_instance_id()]["node"] as Label3D).visible
		)
	check("all bounded damage numbers are visible by the delay limit", released)
	for label in labels:
		label._process(label.life)
	preview._sync_cards()
	var retired := true
	for label in labels:
		retired = retired and not preview._labels.has(label.get_instance_id())
	check("released numbers retain their lifetime and retire their native labels", retired)
	var forest_pending: Effect = game.cosmetic_effects.back()
	var forest_age := forest_pending.age
	game.player.position = game.dungeon.entry_point()
	check("a pending forest number permits ordinary cave entry", game.dungeon.enter())
	var cave_target: Enemy = game.enemies[0]
	cave_target.take_damage(1.0, null)
	var cave_first: Effect = game.cosmetic_effects.back()
	preview._sync_cards()
	check(
		"the cave starts an independent immediate number without the frozen forest queue",
		cave_first.age == 0.0 and preview._labels.has(cave_first.get_instance_id())
	)
	for index in 8:
		cave_target.take_damage(1.0, null)
	check("dense cave hits never retime a frozen forest number", forest_pending.age == forest_age)
	game.dungeon.leave("검수 복귀", false)
	game.queue_free()
	await _frames(2)

extends TestCase
## 실제 쇠 상자의 피격·개봉 시계와 네이티브 힌지, 일시정지·동작 줄이기를 검사한다.


func run() -> void:
	var game := await make_game("mage")
	game.set_process(false)
	game.player.set_process(false)
	game.player.position = game.dungeon.entry_point()
	check("response fixture enters the actual cave", game.dungeon.enter())
	await _frames(4)
	for enemy: Enemy in game.enemies:
		enemy.set_process(false)
	var preview: Ortho3DPreview = game.ortho_preview
	preview.set_process(false)
	var props: NativeEncounterProps3D = preview._encounter_props
	props.sync()
	var iron: Chest
	var gold: Chest
	for chest: Chest in game.chests:
		if chest.variant == "iron":
			iron = chest
		elif chest.variant == "gold":
			gold = chest
	var reduced := Prefs.reduce_motion
	Prefs.set_reduce_motion(false)
	check(
		"closed chests do no idle script processing",
		not iron.is_processing() and not gold.is_processing()
	)
	var entry: Dictionary = props._entries[iron.get_instance_id()]
	var lid: Node3D = entry["lid"]
	var anchor: Transform3D = entry["root"].transform
	var money := GameState.gold
	iron.take_damage(1, game.player)
	check(
		"a resisted hit starts feedback without paying loot",
		iron.hp == 3 and not iron.dead and iron.is_processing() and GameState.gold == money
	)
	iron._process(.04)
	props.sync()
	check(
		"resisted impact rattles only inside the existing full lid sweep",
		(
			lid.rotation.x < 0
			and lid.rotation.x > deg_to_rad(NativeEncounterMesh3D.OPEN_ANGLE)
			and entry["root"].transform == anchor
		)
	)
	get_tree().paused = true
	var held := iron.lid_fraction()
	await _frames(3)
	iron._process(.1)
	check(
		"pause holds actual impact state even on an explicit refresh",
		is_equal_approx(held, iron.lid_fraction())
	)
	get_tree().paused = false
	iron._process(Chest.RATTLE_SECONDS)
	check(
		"impact settles closed and stops its processing",
		is_zero_approx(iron.lid_fraction()) and not iron.is_processing()
	)
	iron.take_damage(1, game.player)
	Prefs.set_reduce_motion(true)
	iron._process(0)
	check(
		"reduce motion ends a running rattle without changing durability",
		iron.hp == 2 and is_zero_approx(iron.lid_fraction()) and not iron.is_processing()
	)
	Prefs.set_reduce_motion(false)
	iron.take_damage(1, game.player)
	iron.take_damage(1, game.player)
	check(
		"final hit pays once while visual opening starts closed",
		iron.dead and is_zero_approx(iron.lid_fraction()) and iron.is_processing()
	)
	var paid := GameState.gold
	iron._process(.08)
	props.sync()
	check(
		"real opening passes through a visible intermediate hinge pose",
		(
			lid.rotation.x < -.01
			and lid.rotation.x > deg_to_rad(NativeEncounterMesh3D.OPEN_ANGLE) + .01
		)
	)
	get_tree().paused = true
	held = iron.lid_fraction()
	await _frames(3)
	iron._process(1)
	check("menu pause also holds the opening", is_equal_approx(held, iron.lid_fraction()))
	get_tree().paused = false
	iron._process(Chest.OPEN_SECONDS)
	props.sync()
	iron.take_damage(1, game.player)
	check(
		"opening settles once without another reward or continuing process",
		(
			is_equal_approx(lid.rotation.x, deg_to_rad(NativeEncounterMesh3D.OPEN_ANGLE))
			and not iron.is_processing()
			and GameState.gold == paid
			and entry["root"].transform == anchor
		)
	)
	Prefs.set_reduce_motion(true)
	gold.take_damage(1, game.player)
	props.sync()
	var gold_entry: Dictionary = props._entries[gold.get_instance_id()]
	check(
		"reduce motion opens new treasure immediately with no response clock",
		(
			gold.dead
			and is_equal_approx(gold.lid_fraction(), 1.0)
			and not gold.is_processing()
			and is_equal_approx(
				(gold_entry["lid"] as Node3D).rotation.x,
				deg_to_rad(NativeEncounterMesh3D.OPEN_ANGLE)
			)
		)
	)
	Prefs.set_reduce_motion(reduced)
	game.queue_free()
	await _frames(2)

extends TestCase
## 저장 실패는 선택/결산을 되돌리고, 지원 룬은 실제 투사체와 명중에서 동작한다.
const ROOT := "user://tests/expedition-storage"
const HIDDEN := "user://tests/expedition-storage-unavailable"


func run() -> void:
	var previous := GameState.save_path
	DirAccess.make_dir_recursive_absolute(ROOT)
	GameState.save_path = ROOT + "/hero.json"
	var game := await make_game("warrior")
	game.set_process(false)
	game.player.set_process(false)
	game.encounters.set_process(false)
	game.expedition.set_process(false)
	GameState.level = 13
	GameState.save_game()
	var before := ExpeditionProfile.capture()
	check(
		"storage failure can be exercised without changing slot",
		DirAccess.rename_absolute(ROOT, HIDDEN) == OK
	)
	check(
		"failed contract preserves original progress and mode",
		(
			not game.expedition.start("lore")
			and GameState.level == 13
			and GameState.expedition.is_empty()
			and game.process_mode != Node.PROCESS_MODE_DISABLED
		)
	)
	DirAccess.rename_absolute(HIDDEN, ROOT)
	check("contract succeeds after storage recovery", game.expedition.start("lore"))
	game.process_mode = Node.PROCESS_MODE_INHERIT
	game.player.dead = false
	game.expedition.set_process(false)
	GameState.encounter_capture = Callable()
	var cards := RunBuild.offer()
	var key: String = cards[0]["key"]
	DirAccess.rename_absolute(ROOT, HIDDEN)
	check(
		"failed draft leaves same offer, rank and token",
		(
			not game.expedition.choose(key)
			and GameState.rank(cards[0]["id"]) == 0
			and GameState.expedition["offered"] == cards
			and GameState.expedition["drafts"] == ["starter"]
		)
	)
	DirAccess.rename_absolute(HIDDEN, ROOT)
	check("same choice can be retried once", game.expedition.choose(key))
	var runes := RunBuild.offer()
	check(
		"lore contract offers support runes immediately",
		runes.size() == 3 and runes.all(func(card): return card["kind"] == "rune")
	)
	check("rune draft can be taken", game.expedition.choose(runes[0]["key"]))
	GameState.ranks["doubleThrow"] = 1
	GameState.expedition["rune_inventory"] = ["fork", "pierce", "siphon", "reach"]
	GameState.expedition["runes"] = {}
	check(
		"two compatible runes can be equipped",
		RunBuild.equip_rune("doubleThrow", "fork") and RunBuild.equip_rune("doubleThrow", "pierce")
	)
	var bindings: Dictionary = GameState.expedition["runes"].duplicate(true)
	check(
		"third or incompatible binding is atomic",
		(
			not RunBuild.equip_rune("doubleThrow", "siphon")
			and not RunBuild.equip_rune("doubleThrow", "reach")
			and GameState.expedition["runes"] == bindings
		)
	)
	check(
		"runes with no improvement are excluded",
		(
			not RunBuild.can_support("steelWave", "pierce")
			and not RunBuild.can_support("iceBolt", "frost")
			and not RunBuild.can_support("fireball", "blast")
		)
	)
	var definition := SkillDefs.get_def("doubleThrow")
	var base := SkillDefs.base_def("doubleThrow")
	check(
		"fork and pierce affect combat definition",
		definition["pierce"] and definition["count"] == mini(5, int(base["count"]) + 2)
	)
	var effects0: int = game.world.get_child_count()
	game.player._projectiles("doubleThrow", definition, 1, 1.0)
	var projectiles: Array[Effect] = []
	for child in game.world.get_children():
		if child is Effect and child.kind == "proj":
			projectiles.append(child)
	check(
		"actual projectiles carry pierce and cast identity",
		projectiles.size() == int(definition["count"]) and projectiles.all(_projectile_bound),
		str(effects0)
	)
	RunBuild.equip_rune("", "pierce")
	RunBuild.equip_rune("doubleThrow", "siphon")
	var enemy := Enemy.new()
	enemy.setup(game, "golem", 10)
	enemy.position = game.player.position + Vector2(200, 0)
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	game.player.resource = 10
	game.player._action_serial += 1
	var effect := Effect.new()
	effect.owner_node = game.player
	effect.params = {"run_skill_id": "doubleThrow", "run_action_serial": game.player._action_serial}
	effect._apply(enemy, 1)
	effect._apply(enemy, 1)
	check("resource rune pays once per actual cast, not projectile", game.player.resource == 14)
	effect.params["run_action_serial"] = game.player._action_serial + 1
	effect._apply(enemy, 1)
	effect.params["run_action_serial"] = game.player._action_serial
	effect._apply(enemy, 1)
	check("late projectiles cannot repay an earlier cast", game.player.resource == 18)
	effect.free()
	GameState.expedition["drafts"] = ["rune"]
	GameState.expedition["offered"] = []
	GameState.expedition["rune_inventory"] = ExpeditionContent.runes().keys()
	var fallback := RunBuild.offer()
	check(
		"exhausted rune rewards fall back to three new skills",
		fallback.size() == 3 and fallback.all(func(card): return card["kind"] == "skill")
	)
	check("run save with new skills/runes remains valid", GameState.save_game())
	var saved := SaveStore._read_one(GameState.save_path)
	var malformed := saved.duplicate(true)
	malformed["expedition"].erase("elapsed")
	check("malformed run cannot partially replace hero", not GameState._valid_save(malformed))
	malformed = saved.duplicate(true)
	malformed["expedition"]["profile"]["expedition"] = {}
	check("nested run backups are rejected", not GameState._valid_save(malformed))
	DirAccess.rename_absolute(ROOT, HIDDEN)
	check(
		"failed death settlement preserves live run",
		not game.expedition.settle(false) and ExpeditionState.active() and GameState.level == 1
	)
	DirAccess.rename_absolute(HIDDEN, ROOT)
	check(
		"death ends run without renown or profile loss",
		(
			game.expedition.settle(false)
			and ExpeditionProfile.capture()["inventory"] == before["inventory"]
			and GameState.level == 13
			and int(GameState.expedition_meta.get("renown", 0)) == 0
		)
	)
	game.queue_free()
	get_tree().paused = false
	await _frames(2)
	GameState.encounter_capture = Callable()
	GameState.delete_save()
	GameState.save_path = previous


func _projectile_bound(effect: Effect) -> bool:
	return effect.params["pierce"] and effect.params["run_skill_id"] == "doubleThrow"

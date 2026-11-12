extends TestCase
## 원정 복구 자료 손상, 실제 투사체의 지연 명중, 적 수 상한에서 발견한 회귀 경로.


func run() -> void:
	var previous := GameState.save_path
	GameState.save_path = "user://tests/expedition-review.json"
	var game := await make_game("mage")
	game.set_process(false)
	game.player.set_process(false)
	game.encounters.set_process(false)
	game.expedition.set_process(false)
	GameState.level = 12
	check("review fixture starts a real expedition", game.expedition.start("hearth"))
	game.process_mode = Node.PROCESS_MODE_INHERIT
	game.player.dead = false
	GameState.encounter_capture = Callable()
	game.encounters.states = GameState.encounters
	for id: String in game.encounters.stones:
		GameState.encounters[id] = {
			"charges": 3, "recharge": 0.0, "initial_spawned": true, "members": []
		}
	var cards := RunBuild.offer()
	check("review fixture chooses a real starter", game.expedition.choose(cards[0]["key"]))
	check("review fixture persists", GameState.save_game())
	var prepared := SaveStore._read_one(GameState.save_path)
	var broken := prepared.duplicate(true)
	broken["expedition"]["profile"]["discovered_sanctuaries"] = [123]
	_backup_recovery(
		"invalid original waypoint type uses backup before restoration", prepared, broken
	)
	broken = prepared.duplicate(true)
	broken["expedition"]["profile"]["inventory"][0]["base"] = "missing-item"
	_backup_recovery(
		"unknown original gear cannot be silently discarded on settlement", prepared, broken
	)
	broken = prepared.duplicate(true)
	broken["expedition"]["profile"]["equipped"][0]["slot"] = "missing-slot"
	_backup_recovery("invalid original equipped slot uses backup", prepared, broken)
	broken = prepared.duplicate(true)
	broken["expedition"]["profile"]["quests"]["sun"] = {}
	_backup_recovery("incomplete original quest cannot crash the restored world", prepared, broken)

	broken = prepared.duplicate(true)
	broken["slots"] = []
	_write(GameState.save_path, prepared)
	_write(GameState.save_path + ".bak", prepared)
	var primary_bytes := FileAccess.get_file_as_bytes(GameState.save_path)
	var backup_bytes := FileAccess.get_file_as_bytes(GameState.save_path + ".bak")
	check(
		"invalid new save preserves both prior documents",
		(
			SaveStore.write(GameState.save_path, broken, GameState._valid_save) == ERR_INVALID_DATA
			and FileAccess.get_file_as_bytes(GameState.save_path) == primary_bytes
			and FileAccess.get_file_as_bytes(GameState.save_path + ".bak") == backup_bytes
		)
	)
	_backup_recovery("missing locked primary slot cannot strand a resumed run", prepared, broken)
	_restore(game, prepared)
	check("review fixture accepts mission", game.expedition.select_mission("moon", "draft"))
	var accepted := SaveStore._read_one(GameState.save_path)
	broken = accepted.duplicate(true)
	broken["expedition"].erase("reward")
	_backup_recovery("missing mission reward is rejected before report", accepted, broken)
	_restore(game, accepted)
	game.quest_runtime.receive_parcel()
	game.quest_runtime.deliver()
	game.quest_runtime.report("moon")
	var rewarded := SaveStore._read_one(GameState.save_path)
	broken = rewarded.duplicate(true)
	broken["expedition"].erase("reward_remaining")
	_backup_recovery("missing remaining choices cannot advance phase early", rewarded, broken)
	broken = rewarded.duplicate(true)
	broken["expedition"]["reward_remaining"] = 0
	_backup_recovery("zero remaining choices cannot leave a reward phase stuck", rewarded, broken)
	_restore(game, prepared)
	_check_inflight_runes(game)
	_restore(game, prepared)
	await _check_elite_budget(game)
	GameState.expedition["phase"] = "return"
	GameState.expedition["seals"] = ExpeditionState.chapter()["seals"].duplicate()
	GameState.boss_defeated = true
	check(
		"remote report explains why it cannot settle",
		not game.expedition.settle(true) and not game.expedition.error.is_empty()
	)
	game.hud.open_expedition()
	var reported := false
	for label: Label in game.hud._panel.find_children("*", "Label", true, false):
		if label.text == game.expedition.error:
			reported = true
	check("remote-report reason is visible in the actual panel", reported)
	game.hud.close_panel(false)
	game.queue_free()
	get_tree().paused = false
	await _frames(2)
	GameState.encounter_capture = Callable()
	GameState.delete_save()
	GameState.save_path = previous


func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))


func _backup_recovery(label: String, good: Dictionary, broken: Dictionary) -> void:
	_write(GameState.save_path + ".bak", good)
	_write(GameState.save_path, broken)
	check(label, GameState.load_game() and GameState.loaded_backup)


func _restore(game: Node, data: Dictionary) -> void:
	_write(GameState.save_path, data)
	check("review fixture restores valid snapshot", GameState.load_game())
	game.encounters.states = GameState.encounters


func _projectile(game: Node, id: String) -> Effect:
	game.player._action_serial += 1
	game.player._projectiles(id, SkillDefs.get_def(id), 1, 1)
	var found: Effect
	for node in game.world.get_children():
		if (
			node is Effect
			and node.kind == "proj"
			and node.params.get("run_action_serial") == game.player._action_serial
		):
			found = node
	return found


func _check_inflight_runes(game: Node) -> void:
	var id := "iceBolt" if GameState.expedition["signature"] == "firebolt" else "firebolt"
	GameState.ranks[id] = 1
	GameState.expedition["rune_inventory"] = ["siphon"]
	GameState.expedition["runes"] = {}
	RunBuild.equip_rune(id, "siphon")
	var enemy := Enemy.new()
	enemy.setup(game, "golem", 10)
	enemy.set_process(false)
	enemy.position = game.player.position + Vector2(200, 0)
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	var first := _projectile(game, id)
	RunBuild.equip_rune("", "siphon")
	game.player.resource = 10
	first._apply(enemy, 1)
	check("removing a rune cannot change an already fired projectile", game.player.resource == 14)
	var second := _projectile(game, id)
	RunBuild.equip_rune(id, "siphon")
	game.player.resource = 10
	second._apply(enemy, 1)
	check("adding a rune cannot upgrade an already fired projectile", game.player.resource == 10)
	for node in game.world.get_children():
		if node is Effect and node.kind == "proj":
			node.queue_free()
	game.enemies.erase(enemy)
	enemy.queue_free()


func _check_elite_budget(game: Node) -> void:
	GameState.expedition["phase"] = "optional"
	GameState.expedition["branch"] = "elite"
	GameState.expedition["missions"] = ["moon", "roots"]
	GameState.expedition["drafts"] = []
	GameState.expedition["offered"] = []
	for id: String in ["moon", "roots"]:
		GameState.quests[id] = Quests.fresh(id)
		GameState.quests[id]["phase"] = "completed"
	game.player.position = game.encounters.stones["deep_east"].position + Vector2(250, 150)
	for index in EncounterRuntime.CAVE_ENEMY_LIMIT:
		var enemy := Enemy.new()
		enemy.setup(game, "goblin", 1)
		enemy.encounter_id = "west" if index < EncounterRuntime.MAX_ENEMIES else "cave_swarm"
		enemy.set_process(false)
		enemy.position = Iso.project(Vector2(2000 + index * 60, 2000))
		game.world.add_child(enemy)
		game.enemies.append(enemy)
	game.expedition._spawn_elite()
	check(
		"elite has one reserved actor even when all saved encounter slots are occupied",
		is_instance_valid(game.expedition._elite)
	)
	check(
		"reserved elite stays inside a finite 51-actor limit",
		game.enemies.size() <= EncounterRuntime.CAVE_ENEMY_LIMIT + 1
	)
	var count: int = game.enemies.size()
	game.expedition._spawn_elite()
	check("reserved elite cannot be duplicated", game.enemies.size() == count)
	await _frames(1)

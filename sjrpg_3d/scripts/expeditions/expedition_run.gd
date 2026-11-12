class_name ExpeditionRun
extends Node
## 챕터 규칙과 기존 숲/의뢰/전투 사이의 어댑터. 영속 상태는 GameState에만 둔다.
# 선택 정예는 저장된 무리 50개를 지우지 않고 전용 슬롯 하나만 추가한다.
const ELITE_ACTOR_LIMIT := EncounterRuntime.CAVE_ENEMY_LIMIT + 1

var game: Node
var _shown := ""
var _elite: Enemy
var _elite_timer := 0.0
var error := ""


func setup(value: Node) -> ExpeditionRun:
	game = value
	return self


func _process(delta: float) -> void:
	if not game.native_ready or game.player.dead:
		return
	if ExpeditionState.active():
		GameState.expedition["elapsed"] = float(GameState.expedition["elapsed"]) + delta
		if ExpeditionState.phase() == "optional" and GameState.expedition.get("branch") == "elite":
			_elite_timer -= delta
			if _elite_timer <= 0:
				_elite_timer = 1.0
				_spawn_elite()
	var signature := (
		"%s:%s" % [ExpeditionState.phase(), GameState.expedition.get("draft_serial", 0)]
	)
	var required: bool = (
		(
			ExpeditionState.phase()
			in [
				"starter",
				"missions",
				"mission_reward",
				"branch",
				"bonus_reward",
				"seal_reward",
				"debrief"
			]
		)
		or not GameState.expedition.get("drafts", []).is_empty()
	)
	if (
		required
		and signature != _shown
		and not game.hud.panel_open()
		and not game.player.warp_locked
	):
		_shown = signature
		game.hud.open_expedition()


func _snapshot() -> Dictionary:
	return {
		"profile": ExpeditionProfile.capture(),
		"state": GameState.expedition.duplicate(true),
		"meta": GameState.expedition_meta.duplicate(true),
		"capture": GameState.encounter_capture,
		"bonus_ranks": GameState.bonus_ranks,
		"boss_summoned": GameState.boss_summoned
	}


func _rollback(before: Dictionary) -> void:
	ExpeditionProfile.restore(before["profile"])
	GameState.expedition = before["state"]
	GameState.expedition_meta = before["meta"]
	GameState.encounter_capture = before["capture"]
	GameState.boss_summoned = before["boss_summoned"]
	GameState.bonus_ranks = before["bonus_ranks"]
	game.encounters.states = GameState.encounters


func _commit(before: Dictionary) -> bool:
	if GameState.save_game():
		error = ""
		return true
	error = GameState.save_error
	_rollback(before)
	return false


func start(contract_id: String) -> bool:
	if (
		ExpeditionState.active()
		or game.dungeon.active
		or game.player.dead
		or not game.in_town(game.player.position)
	):
		error = "마을에서 준비를 마치고 계약을 시작하세요."
		return false
	var chapter_id := str(GameState.expedition.get("chapter", "forest_1"))
	var contract := ExpeditionContent.contract(chapter_id, contract_id)
	if contract.is_empty():
		return false
	if GameState.encounter_capture.is_valid():
		GameState.encounter_capture.call()
	var before := _snapshot()
	GameState.encounter_capture = Callable()
	var profile: Dictionary = before["profile"]
	GameState.level = 1
	GameState.xp = 0
	GameState.gold = 0
	GameState.kills = 0
	GameState.stage_kills = 0
	GameState.bonus_attack = 0
	GameState.bonus_health = 0
	GameState.bonus_ranks = 0
	GameState.skill_points = 0
	GameState.quests = {}
	GameState.encounters = {}
	GameState.opened_chests.clear()
	GameState.chest_seed = randi() % 0x7fffffff
	GameState.boss_defeated = false
	GameState.boss_summoned = false
	GameState.boss_heart_pending = false
	GameState.memory_rewarded = false
	GameState.location_mode = "forest"
	GameState.last_sanctuary = "town"
	GameState.discovered_sanctuaries.assign(["town"])
	GameState.potions = 3 + int(contract.get("potions", 0))
	GameState.mana_potions = 2
	if not GameState.expedition_meta.get("clears", {}).is_empty():
		GameState.potions += 1
		GameState.mana_potions += 1
	var basic := "sorceressAttack" if GameState.hero_class == "mage" else "cleave"
	GameState.ranks = {basic: 1}
	GameState.slots = [basic, "", "", "", ""]
	GameState._starting_gear()
	var serial := int(GameState.expedition_meta.get("runs", 0)) + 1
	GameState.expedition_meta["runs"] = serial
	GameState.expedition = {
		"schema": 1,
		"chapter": chapter_id,
		"phase": "starter",
		"contract": contract_id,
		"serial": serial,
		"profile": profile,
		"elapsed": 0.0,
		"missions": [],
		"seals": [],
		"drafts": [],
		"offered": [],
		"draft_serial": 0,
		"level_drafts": 0,
		"rune_inventory": [],
		"runes": {},
		"armed_seals": []
	}
	RunBuild.queue("starter")
	if not _commit(before):
		return false
	_reload()
	return true


func choose(key: String) -> bool:
	var before := _snapshot()
	var token := RunBuild.choose(key)
	if token.is_empty():
		return false
	match token:
		"starter":
			GameState.expedition["phase"] = "missions"
			var contract := ExpeditionContent.contract(
				str(GameState.expedition["chapter"]), str(GameState.expedition["contract"])
			)
			if contract.get("extra_draft", false):
				RunBuild.queue("rune")
		"mission":
			GameState.expedition["reward_remaining"] = (
				int(GameState.expedition.get("reward_remaining", 1)) - 1
			)
			if int(GameState.expedition["reward_remaining"]) == 0:
				GameState.expedition["phase"] = (
					"branch"
					if (
						GameState.expedition["missions"].size()
						>= int(ExpeditionState.chapter()["required_missions"])
					)
					else "missions"
				)
		"bonus":
			if ExpeditionState.phase() == "bonus_reward":
				_begin_seals()
		"seal":
			GameState.expedition["phase"] = "boss"
	if not _commit(before):
		return false
	game.player.refresh_stats()
	SoundFx.play("loot")
	return true


func select_mission(id: String, reward: String) -> bool:
	if (
		ExpeditionState.phase() != "missions"
		or not GameState.expedition["drafts"].is_empty()
		or not ExpeditionState.chapter()["missions"].has(id)
		or GameState.expedition["missions"].has(id)
		or not reward in ["draft", "supplies"]
	):
		return false
	var before := _snapshot()
	GameState.expedition["mission"] = id
	GameState.expedition["reward"] = reward
	GameState.expedition["phase"] = "mission"
	var quest := Quests.fresh(id)
	quest["phase"] = "accepted"
	GameState.quests[id] = quest
	return _commit(before)


func mission_completed(id: String) -> void:
	if ExpeditionState.current_mission() != id:
		return
	var state: Dictionary = GameState.expedition
	state["missions"].append(id)
	if state["reward"] == "supplies":
		GameState.potions += 2
		GameState.mana_potions += 2
	state["phase"] = "mission_reward"
	# 모든 임무에서 조합 선택을 제공하고 보급을 택하면 추가 회복약을 지급한다.
	state["reward_remaining"] = 2 if state["reward"] == "draft" else 1
	for index in int(state["reward_remaining"]):
		RunBuild.queue("mission")


func branch(id: String) -> bool:
	if ExpeditionState.phase() != "branch" or not id in ["cave", "elite", "skip"]:
		return false
	var before := _snapshot()
	if id == "skip":
		_begin_seals()
	else:
		GameState.expedition["branch"] = id
		GameState.expedition["phase"] = "optional"
	return _commit(before)


func abandon_optional() -> bool:
	if ExpeditionState.phase() != "optional" or game.dungeon.active:
		return false
	var before := _snapshot()
	_begin_seals()
	if not _commit(before):
		return false
	if is_instance_valid(_elite):
		game.enemies.erase(_elite)
		_elite.queue_free()
	return true


func optional_completed(id: String) -> void:
	if ExpeditionState.phase() != "optional" or GameState.expedition.get("branch") != id:
		return
	GameState.expedition["phase"] = "bonus_reward"
	RunBuild.queue("bonus")
	GameState.save_game()


func _begin_seals() -> void:
	GameState.expedition["phase"] = "seals"
	# 기존 비석의 생존 무리를 먼저 처리해도 된다. 이후 공격해 소환한 무리만 봉인으로 센다.
	GameState.expedition["armed_seals"] = []
	for id: String in ExpeditionState.chapter()["seals"]:
		game.encounters.states[id]["charges"] = 3
		game.encounters.states[id]["recharge"] = 0.0


func wave_started(id: String) -> void:
	if (
		ExpeditionState.phase() != "seals"
		or not ExpeditionState.chapter()["seals"].has(id)
		or GameState.expedition["seals"].has(id)
	):
		return
	if not GameState.expedition["armed_seals"].has(id):
		GameState.expedition["armed_seals"].append(id)
	GameState.save_game()


func wave_cleared(id: String) -> void:
	if (
		ExpeditionState.phase() != "seals"
		or not GameState.expedition.get("armed_seals", []).has(id)
		or GameState.expedition["seals"].has(id)
	):
		return
	GameState.expedition["seals"].append(id)
	game.toast("숲의 봉인을 되찾았습니다")
	SoundFx.play("levelup")
	if GameState.expedition["seals"].size() == ExpeditionState.chapter()["seals"].size():
		GameState.expedition["phase"] = "seal_reward"
		RunBuild.queue("seal")
	GameState.save_game()


func _spawn_elite() -> void:
	if (
		game.dungeon.active
		or is_instance_valid(_elite)
		or game.enemies.size() >= ELITE_ACTOR_LIMIT
	):
		return
	var anchor: Vector2 = game.encounters.stones["deep_east"].position
	if anchor.distance_to(game.player.position) > 1000:
		return
	var at: Vector2 = game.find_open_point(anchor, Vector2.RIGHT, 180, Enemy.radius_for("golem"))
	if (
		game.spatial_world.blocked(at, Enemy.radius_for("golem"), true)
		or at.distance_to(game.player.position) < 135
	):
		return
	_elite = Enemy.new()
	_elite.setup(game, "golem", mini(20, maxi(5, GameState.level + 2)))
	_elite.display_name = "봉인을 삼킨 정예"
	_elite.max_hp *= 1.8
	_elite.hp = _elite.max_hp
	_elite.position = at
	game.world.add_child(_elite)
	game.enemies.append(_elite)
	game.toast("정예 파수꾼 · 봉인을 삼킨 자")


func enemy_killed(enemy: Enemy) -> void:
	if enemy == _elite:
		optional_completed("elite")


func boss_defeated() -> void:
	if ExpeditionState.phase() != "boss":
		return
	GameState.expedition["phase"] = "return"
	GameState.save_game()
	game.toast("숲이 고요해졌습니다 · 마을 촌장에게 돌아가세요")


func settle(success: bool) -> bool:
	if (
		not ExpeditionState.active()
		or (
			success
			and (
				ExpeditionState.phase() != "return"
				or game.near_npc() != str(ExpeditionState.chapter()["return_npc"])
			)
		)
	):
		error = "마을 촌장 가까이에서 보고하세요." if success else "진행 중인 원정이 없습니다."
		return false
	if GameState.encounter_capture.is_valid():
		GameState.encounter_capture.call()
	var before := _snapshot()
	var state: Dictionary = GameState.expedition
	var contract := ExpeditionContent.contract(str(state["chapter"]), str(state["contract"]))
	var earned := int(contract["renown"]) if success else 0
	var result := {
		"success": success,
		"seconds": int(state["elapsed"]),
		"level": GameState.level,
		"kills": GameState.kills,
		"renown": earned,
		"missions": state["missions"].size(),
		"skills": GameState.ranks.keys(),
		"runes": state["rune_inventory"].duplicate()
	}
	GameState.encounter_capture = Callable()
	ExpeditionProfile.restore(state["profile"])
	# 결산 뒤에는 이전 캐릭터의 외곽 체크포인트가 아니라 마을에서 다음 계약을 준비한다.
	GameState.last_sanctuary = "town"
	GameState.location_mode = "forest"
	GameState.expedition_meta["renown"] = int(GameState.expedition_meta.get("renown", 0)) + earned
	if success:
		var clears: Dictionary = GameState.expedition_meta.get("clears", {})
		clears[state["chapter"]] = int(clears.get(state["chapter"], 0)) + 1
		GameState.expedition_meta["clears"] = clears
	GameState.expedition = {
		"schema": 1, "phase": "debrief", "chapter": state["chapter"], "result": result
	}
	if not _commit(before):
		return false
	_reload()
	return true


func _reload() -> void:
	# 이전 월드의 지연 공격/보상 콜백이 복구한 캐릭터에 쓰지 않도록 즉시 멈춘다.
	game.player._action_serial += 1
	game.player.dead = true
	for enemy: Enemy in game.enemies:
		enemy.dead = true
	game.ortho_preview.set_process(false)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.get_tree().paused = false
	game.reload_requested.emit()

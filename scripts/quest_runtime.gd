class_name QuestRuntime
extends Node
## 제1장 의뢰 진행 (원본 ForestQuestRuntime): 제단 근처 처치 수, 조사관 보호(90초 · 30마리 · 5차 습격),
## 보상, 그리고 모든 의뢰와 처치 목표가 끝나면 숲의 파수꾼 출현.

var game: Node
var defender: Node2D  # 조사관 로웬 (Villager)
var _threats: Array[Enemy] = []
var _wave_pause := 0.0
var _boss: Enemy


func setup(g: Node) -> QuestRuntime:
	game = g
	return self


func site(id: String) -> Vector2:
	return game.village.quest_sites[id]


func _process(delta: float) -> void:
	var sun := Quests.state("sun")
	if sun["phase"] == "accepted" and sun["started"]:
		_tick_protection(sun, delta)
	_tick_boss(delta)


# ───────── 대화에서 부르는 행동 ─────────

func accept(id: String) -> void:
	if Quests.phase(id) != "offered":
		return
	var s := Quests.state(id)
	s["phase"] = "accepted"
	if id == "roots":
		s["altar_kills"] = 0
		s["cleansed"] = false
	game.toast("의뢰 수락 · %s" % Quests.def(id)["title"])
	GameState.save_game()


func receive_parcel() -> void:
	if Quests.phase("moon") != "accepted" or Quests.state("moon")["parcel"]:
		return
	Quests.state("moon")["parcel"] = true
	game.toast("약초 꾸러미를 받았습니다")
	GameState.save_game()


func deliver() -> void:
	if Quests.phase("moon") != "accepted" or not Quests.state("moon")["parcel"]:
		return
	var s := Quests.state("moon")
	s["parcel"] = false
	s["phase"] = "ready"
	game.toast("꾸러미를 전달했습니다 · 노아에게 보고하세요")
	GameState.save_game()


## 제단 정화: 처치 수를 채우고 남은 적이 가까이 없어야 함.
func cleanse_blocked_reason() -> String:
	var s := Quests.state("roots")
	if s["altar_kills"] < Quests.ALTAR_KILL_GOAL:
		return "석조 정원 주변 적 %d/%d · 남은 적을 정리하세요." % [s["altar_kills"], Quests.ALTAR_KILL_GOAL]
	for e in game.enemies:
		if not e.dead and e.position.distance_to(site("roots")) < 300.0:
			return "정원 근처에 아직 적이 남아 있습니다."
	return ""


func cleanse() -> void:
	if Quests.phase("roots") != "accepted" or cleanse_blocked_reason() != "":
		return
	var s := Quests.state("roots")
	s["cleansed"] = true
	s["phase"] = "ready"
	game.spawn_nova(site("roots"), 260.0, Color(0.7, 1.0, 0.8))
	game.toast("봉인을 정화했습니다 · 엘린에게 보고하세요")
	SoundFx.play("loot")
	GameState.save_game()


func report(id: String) -> void:
	if Quests.phase(id) != "ready":
		return
	var d := Quests.def(id)
	var s := Quests.state(id)
	s["phase"] = "completed"
	var exp: int = d["exp"] * Quests.EXPERIENCE_MULTIPLIER
	GameState.gold += int(d["gold"])
	game.float_text(game.player.position + Vector2(0, -110), "+%d G  +%d XP" % [d["gold"], exp], Color(1, 0.9, 0.5))
	game.toast("의뢰 완료 · %s" % d["title"])
	game.grant_xp(exp)
	SoundFx.play("loot")
	Prefs.pulse("loot")
	GameState.save_game()


func retry(id: String) -> void:
	if Quests.phase(id) != "failed":
		return
	var s := Quests.fresh(id)
	s["attempt"] = int(Quests.state(id)["attempt"]) + 1
	s["phase"] = "accepted"
	GameState.quests[id] = s
	game.toast("다시 준비합니다")
	GameState.save_game()


func start_protection() -> void:
	if Quests.phase("sun") != "accepted" or Quests.state("sun")["started"]:
		return
	var s := Quests.state("sun")
	s["started"] = true
	s["protected_for"] = 0.0
	s["defender_hp"] = Quests.DEFENDER_HP
	s["defeated"] = 0
	s["spawned"] = 0
	_wave_pause = 1.5
	_clear_threats()
	game.toast("조사관을 지키세요! 90초 · 습격 5차")
	GameState.save_game()


# ───────── 보호 의뢰 ─────────

func _clear_threats() -> void:
	for e in _threats:
		if is_instance_valid(e):
			e.dead = true
			game.enemies.erase(e)
			e.queue_free()
	_threats.clear()


func _alive_threats() -> int:
	var n := 0
	for e in _threats:
		if is_instance_valid(e) and not e.dead:
			n += 1
	return n


func _tick_protection(s: Dictionary, delta: float) -> void:
	s["protected_for"] = float(s["protected_for"]) + delta
	if s["spawned"] < Quests.THREAT_COUNT and _alive_threats() == 0:
		_wave_pause -= delta
		if _wave_pause <= 0.0:
			_spawn_wave(s)
			_wave_pause = 2.5
	if float(s["defender_hp"]) <= 0.0:
		_fail(s)
		return
	if s["protected_for"] >= Quests.PROTECT_SECONDS and s["defeated"] >= Quests.THREAT_COUNT:
		s["phase"] = "ready"
		_clear_threats()
		game.toast("습격을 막아냈습니다 · 로웬에게 보고하세요")
		GameState.save_game()


func _spawn_wave(s: Dictionary) -> void:
	var count := mini(Quests.WAVE_SIZE, Quests.THREAT_COUNT - int(s["spawned"]))
	var center := site("sun")
	for i in count:
		var kind: String = ["goblin", "wolf", "boar", "skeleton"][game.rng_int(0, 3)]
		var e := Enemy.new()
		e.setup(game, kind, maxi(1, GameState.level))
		e.is_threat = true
		var ang: float = TAU * (float(i) / count) + float(game.rng_float()) * 0.6
		var spawn_at: Vector2 = center + Vector2.from_angle(ang) * float(game.rng_range(340.0, 460.0))
		e.position = game.resolve_movement(center, spawn_at, Enemy.RADIUS)
		e.force_chase()
		game.world.add_child(e)
		game.enemies.append(e)
		_threats.append(e)
	s["spawned"] = int(s["spawned"]) + count
	game.toast("습격 %d차!" % ceili(float(s["spawned"]) / Quests.WAVE_SIZE))


func _fail(s: Dictionary) -> void:
	s["phase"] = "failed"
	s["started"] = false
	_clear_threats()
	game.toast("조사관이 쓰러졌습니다 · 로웬에게 말해 다시 도전하세요")
	GameState.save_game()


## 몬스터가 조사관을 때림.
func damage_defender(amount: float) -> void:
	var s := Quests.state("sun")
	if s["phase"] != "accepted" or not s["started"]:
		return
	s["defender_hp"] = maxf(0.0, float(s["defender_hp"]) - amount)
	if defender != null:
		game.float_text(defender.position + Vector2(0, -90), HudArt.stat(amount), Color(1, 0.55, 0.45))


func defender_active() -> bool:
	var s := Quests.state("sun")
	return s["phase"] == "accepted" and s["started"] and float(s["defender_hp"]) > 0.0


func defender_position() -> Vector2:
	return site("sun")


# ───────── 처치 기록 · 보스 ─────────

func on_enemy_killed(enemy: Enemy) -> void:
	GameState.stage_kills += 1
	var roots := Quests.state("roots")
	if roots["phase"] == "accepted" and enemy.position.distance_to(site("roots")) < 900.0:
		roots["altar_kills"] = mini(int(roots["altar_kills"]) + 1, 999)
	if enemy.is_threat:
		var s := Quests.state("sun")
		if s["phase"] == "accepted" and s["started"]:
			s["defeated"] = int(s["defeated"]) + 1


func boss_ready() -> bool:
	return Quests.all_done() and not GameState.boss_defeated and not GameState.boss_summoned


func start_boss() -> bool:
	if not boss_ready() or game.player.dead or game.player.position.distance_to(game.village.boss_point) > 260.0:
		return false
	_boss = Enemy.new()
	_boss.setup(game, "golem", 8)
	_boss.make_boss()
	_boss.position = game.village.boss_point
	game.world.add_child(_boss)
	game.enemies.append(_boss)
	GameState.boss_summoned = true
	game.toast("숲의 파수꾼 · 붉은 예고를 피하세요!")
	game.spawn_nova(_boss.position, 220.0, Color(1, 0.8, 0.4))
	SoundFx.play("warcry")
	return true


func reset_boss() -> void:
	if is_instance_valid(_boss) and not _boss.dead:
		game.enemies.erase(_boss)
		_boss.queue_free()
	_boss = null
	if not GameState.boss_defeated:
		GameState.boss_summoned = false


func _tick_boss(_delta: float) -> void:
	if GameState.boss_defeated or not GameState.boss_summoned:
		return
	if game.player.dead or game.player.position.distance_to(game.village.boss_point) > 1100.0:
		reset_boss()
		game.toast("파수꾼이 공터로 돌아갔습니다 · 다시 도전할 수 있습니다")

class_name RunBuild
extends RefCounted
## 3지선다의 선택지는 저장한 뒤 보여 준다. 전투 난수와 분리한 결정적 셔플을 사용한다.
const MAX_LEVEL_DRAFTS := 6


static func queue(kind: String) -> void:
	if not ExpeditionState.active():
		return
	var state: Dictionary = GameState.expedition
	if kind == "level":
		if int(state["level_drafts"]) >= MAX_LEVEL_DRAFTS:
			return
		state["level_drafts"] = int(state["level_drafts"]) + 1
	state["drafts"].append(kind)


static func supports(id: String) -> Array:
	return GameState.expedition.get("runes", {}).get(id, []) if ExpeditionState.active() else []


static func modifiers(id: String) -> Dictionary:
	var result := {"damage": 1.0, "cost": 1.0, "cooldown": 1.0, "reach": 1.0}
	for rune: String in supports(id):
		var raw: Dictionary = ExpeditionContent.runes()[rune]["modifiers"]
		for key: String in raw:
			if key in ["damage", "cost", "cooldown", "reach"]:
				result[key] = float(result[key]) * float(raw[key])
			else:
				result[key] = raw[key]
	return result


static func definition(id: String, base: Dictionary) -> Dictionary:
	if supports(id).is_empty():
		return base
	var result := base.duplicate(true)
	var mods := modifiers(id)
	for key: String in ["range", "radius"]:
		if result.has(key):
			result[key] = float(result[key]) * float(mods["reach"])
	if mods.has("count_add"):
		result["count"] = mini(5, int(result.get("count", 1)) + int(mods["count_add"]))
		result["spread"] = maxf(float(result.get("spread", 0)), float(mods.get("spread_min", 30)))
	if mods.has("pierce"):
		result["pierce"] = true
	if mods.has("explode_min"):
		result["explode"] = maxf(float(result.get("explode", 0)), float(mods["explode_min"]))
	if mods.has("slow"):
		result["slow"] = maxf(float(result.get("slow", 0)), float(mods["slow"]))
	return result


static func cost(id: String, native: float) -> float:
	if not ExpeditionState.active():
		return native
	if GameState.expedition.get("signature", "") == id:
		return 0.0
	return native * float(modifiers(id)["cost"])


static func cooldown(id: String, native: float) -> float:
	return native * float(modifiers(id)["cooldown"])


static func contact(player: Player, target: Enemy, id: String, serial: int, impact_mods: Dictionary = {}) -> void:
	if not ExpeditionState.active() or id.is_empty() or player.dead:
		return
	var mods := modifiers(id) if impact_mods.is_empty() else impact_mods
	if not target.dead and mods.has("slow"):
		target.slow(float(mods["slow"]))
	var gain := float(mods.get("resource_on_hit", 0))
	if not player.is_mage and GameState.expedition.get("signature", "") == id:
		gain += 3.0
	var cast_key := "%s:%d" % [id, serial]
	if gain > 0 and not player.run_contact_serials.has(cast_key):
		player.run_contact_serials[cast_key] = true
		# 투사체가 역순으로 명중해도 한 시전은 한 번만 지급한다. 노드 참조는 보관하지 않는다.
		if player.run_contact_serials.size() > 128:
			player.run_contact_serials.erase(player.run_contact_serials.keys()[0])
		player.resource = minf(player.resource_max, player.resource + gain)


static func offer() -> Array:
	var state: Dictionary = GameState.expedition
	if not ExpeditionState.active() or state.get("drafts", []).is_empty():
		return []
	if not state.get("offered", []).is_empty():
		return state["offered"]
	var kind: String = state["drafts"][0]
	var candidates := []
	var pool: Array = (
		ExpeditionContent.pools()[GameState.hero_class]["starters"]
		if kind == "starter"
		else ExpeditionContent.pool(
			GameState.hero_class, int(GameState.expedition_meta.get("renown", 0))
		)
	)
	for id: String in pool:
		if kind != "rune" and GameState.rank(id) == 0:
			candidates.append({"kind": "skill", "id": id})
	if kind != "starter":
		for rune: String in ExpeditionContent.runes():
			if state["rune_inventory"].has(rune):
				continue
			for skill: String in GameState.ranks:
				if (
					GameState.rank(skill) > 0
					and supports(skill).size() < 2
					and can_support(skill, rune)
				):
					candidates.append({"kind": "rune", "id": rune, "skill": skill})
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state["serial"]) * 104729 + int(state["draft_serial"]) * 7919 + 31
	for index in range(candidates.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var swap: Variant = candidates[index]
		candidates[index] = candidates[other]
		candidates[other] = swap
	var seen := []
	var result := []
	for card: Dictionary in candidates:
		var identity := str(card["kind"]) + ":" + str(card["id"])
		if seen.has(identity):
			continue
		seen.append(identity)
		card["key"] = "%d:%s:%s" % [state["draft_serial"], identity, card.get("skill", "")]
		result.append(card)
		if result.size() == 3:
			break
	# 호환 룬을 이미 모두 보유/장착했어도 기억 보상 등 필수 선택이 막히지 않게 한다.
	if result.size() < 3 and kind == "rune":
		for id: String in pool:
			if GameState.rank(id) > 0:
				continue
			result.append(
				{"kind": "skill", "id": id, "key": "%d:skill:%s:" % [state["draft_serial"], id]}
			)
			if result.size() == 3:
				break
	state["offered"] = result
	if not GameState.save_game():
		state["offered"] = []
		return []
	return result


static func choose(key: String) -> String:
	var state: Dictionary = GameState.expedition
	if not ExpeditionState.active() or state.get("drafts", []).is_empty():
		return ""
	var selected := {}
	for card: Dictionary in state.get("offered", []):
		if card["key"] == key:
			selected = card
	if selected.is_empty():
		return ""
	var kind: String = state["drafts"][0]
	var id: String = selected["id"]
	if selected["kind"] == "skill":
		if GameState.rank(id) > 0:
			return ""
		GameState.ranks[id] = 1
		if kind == "starter":
			state["signature"] = id
			GameState.slots[0] = id
			GameState.ranks.erase("cleave")
			GameState.ranks.erase("sorceressAttack")
		else:
			for index in range(1, 5):
				if str(GameState.slots[index]).is_empty():
					GameState.slots[index] = id
					break
	else:
		if state["rune_inventory"].has(id):
			return ""
		state["rune_inventory"].append(id)
		if not equip_rune(str(selected["skill"]), id):
			state["rune_inventory"].erase(id)
			return ""
	state["drafts"].pop_front()
	state["offered"] = []
	state["draft_serial"] = int(state["draft_serial"]) + 1
	return kind


static func equip_rune(skill: String, rune: String) -> bool:
	if not ExpeditionState.active() or not GameState.expedition["rune_inventory"].has(rune):
		return false
	if (
		not skill.is_empty()
		and (
			GameState.rank(skill) == 0
			or not can_support(skill, rune)
			or (supports(skill).size() >= 2 and not supports(skill).has(rune))
		)
	):
		return false
	var bindings: Dictionary = GameState.expedition["runes"]
	for id: String in bindings:
		bindings[id].erase(rune)
	if not skill.is_empty():
		if not bindings.has(skill):
			bindings[skill] = []
		bindings[skill].append(rune)
	return true


static func can_support(skill: String, rune: String) -> bool:
	if not ExpeditionContent.compatible(skill, rune):
		return false
	var base := SkillDefs.base_def(skill)
	var mods: Dictionary = ExpeditionContent.runes()[rune]["modifiers"]
	# 원래 효과보다 나아지지 않으면 피해/비용 페널티만 남으므로 제시하지 않는다.
	if mods.has("pierce") and base.get("pierce", false):
		return false
	if mods.has("explode_min") and float(base.get("explode", 0)) >= float(mods["explode_min"]):
		return false
	if mods.has("slow") and float(base.get("slow", 0)) >= float(mods["slow"]):
		return false
	if (
		mods.has("count_add")
		and int(base.get("count", 1)) >= mini(5, int(base.get("max_count", 99)))
	):
		return false
	if rune == "haste" and SkillDefs.cooldown(GameState.skill(skill)) <= 0:
		return false
	# 자원이 들지 않는 주 공격에 비용 절감만 주는 손해 선택지를 만들지 않는다.
	if (
		rune == "thrift"
		and (
			GameState.expedition.get("signature") == skill
			or float(GameState.skill(skill).get("cost", 0)) <= 0
		)
	):
		return false
	return true

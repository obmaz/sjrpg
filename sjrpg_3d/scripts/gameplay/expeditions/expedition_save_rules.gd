class_name ExpeditionSaveRules
extends RefCounted
## 문서 내부의 필드 관계를 적용 전에 검사한다. 원본 캐릭터의 일부만 복구하지 않는다.


static func profile(data: Dictionary, cls: String) -> bool:
	for key: String in ExpeditionProfile.INTS:
		if not _integer(data.get(key), 0):
			return false
	if int(data["level"]) < 1:
		return false
	for key: String in ExpeditionProfile.FLAGS:
		if not data.get(key) is bool:
			return false
	if not build(data, cls) or not quests(data.get("quests")):
		return false
	var discovered: Array = data["discovered_sanctuaries"]
	if discovered.is_empty() or discovered.size() > Exploration.NAMES.size():
		return false
	var known := {}
	for id: Variant in discovered:
		if not id is String or not Exploration.NAMES.has(id) or known.has(id):
			return false
		known[id] = true
	if not data.get("last_sanctuary") is String or not known.has(data["last_sanctuary"]):
		return false
	if not data.get("location_mode", "") in ["forest", "cave"]:
		return false
	for key: String in ["opened_chests", "unseen"]:
		for id: Variant in data[key]:
			if not _integer(id, 0):
				return false
	if data["inventory"].size() > Gear.CAPACITY or data["equipped"].size() > Gear.SLOT_NAMES.size():
		return false
	var inventory := {}
	for gear: Dictionary in data["inventory"]:
		if not gear.get("base") is String or not _integer(gear.get("serial"), 1):
			return false
		var base := Gear.def(gear["base"])
		if base.is_empty() or inventory.has(int(gear["serial"])):
			return false
		for gift: Variant in gear.get("gifts", []):
			if not gift is String or not Gear.GIFTS.has(gift):
				return false
		inventory[int(gear["serial"])] = base
	var slots := {}
	for item: Dictionary in data["equipped"]:
		if (
			not item.get("slot") is String
			or not Gear.SLOT_NAMES.has(item["slot"])
			or not _integer(item.get("serial"), 1)
		):
			return false
		var serial := int(item["serial"])
		if slots.has(item["slot"]) or not inventory.has(serial):
			return false
		var base: Dictionary = inventory[serial]
		if base["slot"] != item["slot"] or not Gear.usable(base, cls):
			return false
		slots[item["slot"]] = true
	return true


static func build(data: Dictionary, cls: String, run := false) -> bool:
	if (
		not GameState.CLASSES.has(cls)
		or not data.get("ranks") is Dictionary
		or not data.get("slots") is Array
	):
		return false
	if data["slots"].size() != 5:
		return false
	var ranks: Dictionary = data["ranks"]
	for id: Variant in ranks:
		if not id is String:
			return false
		var skill := ExpeditionContent.skill_metadata(id, cls)
		if skill.is_empty() or not _integer(ranks[id], 0):
			return false
		if int(ranks[id]) > (1 if run else int(skill["limit"])):
			return false
	var used := {}
	for id: Variant in data["slots"]:
		if not id is String:
			return false
		if id.is_empty():
			continue
		if used.has(id) or int(ranks.get(id, 0)) <= 0:
			return false
		var skill := ExpeditionContent.skill_metadata(id, cls)
		if skill.get("passive", true) and not skill.get("basic", false):
			return false
		used[id] = true
	return true


static func phase(state: Dictionary, hero: Dictionary) -> bool:
	var stage: String = state["phase"]
	var chapter := ExpeditionState.chapter_for(state)
	if not quests(hero.get("quests")):
		return false
	if not build(hero, str(hero.get("class", "")), true):
		return false
	if stage == "starter":
		return (
			not state["drafts"].is_empty()
			and state["drafts"][0] == "starter"
			and not str(hero["slots"][0]).is_empty()
		)
	var signature: String = state.get("signature", "")
	if int(hero["ranks"].get(signature, 0)) <= 0 or hero["slots"][0] != signature:
		return false
	for skill: String in state["runes"]:
		if int(hero["ranks"].get(skill, 0)) <= 0:
			return false
	for id: String in state["missions"]:
		if hero["quests"].get(id, {}).get("phase") != "completed":
			return false
	if (
		stage == "mission"
		and not (
			hero["quests"].get(state["mission"], {}).get("phase", "")
			in ["accepted", "failed", "ready"]
		)
	):
		return false
	if stage in ["mission", "mission_reward"]:
		if not state.get("reward", "") in ["draft", "supplies"]:
			return false
	if stage == "mission_reward":
		if not state["missions"].has(state.get("mission")):
			return false
		var remaining: Variant = state.get("reward_remaining")
		if (
			not GameState._encounter_integer(remaining, 1, 2)
			or int(remaining) != state["drafts"].count("mission")
		):
			return false
	if stage in ["branch", "optional", "bonus_reward", "seals", "seal_reward", "boss", "return"]:
		if state["missions"].size() != int(chapter["required_missions"]):
			return false
	if stage == "bonus_reward" and not state["drafts"].has("bonus"):
		return false
	if stage in ["seal_reward", "boss", "return"]:
		if state["seals"].size() != chapter["seals"].size():
			return false
	if stage == "seal_reward" and not state["drafts"].has("seal"):
		return false
	if stage == "return" and hero.get("boss_defeated") != true:
		return false
	return true


static func quests(value: Variant) -> bool:
	if not value is Dictionary or value.size() > Quests.DEFS.size():
		return false
	for id: Variant in value:
		if not id is String or Quests.def(id).is_empty() or not value[id] is Dictionary:
			return false
		var state: Dictionary = value[id]
		if not state.get("phase", "") in ["offered", "accepted", "ready", "completed", "failed"]:
			return false
		for key: String in ["parcel", "cleansed", "started"]:
			if not state.get(key) is bool:
				return false
		for key: String in ["altar_kills", "defeated", "attempt", "spawned"]:
			if not _integer(state.get(key), 0):
				return false
		for key: String in ["protected_for", "defender_hp"]:
			if not GameState._number(state.get(key)) or float(state[key]) < 0:
				return false
	return true


static func _integer(value: Variant, minimum: int) -> bool:
	return (
		GameState._number(value)
		and float(value) >= minimum
		and float(value) == floorf(float(value))
	)

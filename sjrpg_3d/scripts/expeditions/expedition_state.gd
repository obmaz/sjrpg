class_name ExpeditionState
extends RefCounted
## 슬롯 안의 원정 상태. 실제 전투/월드 노드는 저장하지 않는다.
const PHASES := [
	"lobby",
	"starter",
	"missions",
	"mission",
	"mission_reward",
	"branch",
	"optional",
	"bonus_reward",
	"seals",
	"seal_reward",
	"boss",
	"return",
	"debrief"
]
const ACTIVE := [
	"starter",
	"missions",
	"mission",
	"mission_reward",
	"branch",
	"optional",
	"bonus_reward",
	"seals",
	"seal_reward",
	"boss",
	"return"
]


static func lobby() -> Dictionary:
	return {"schema": 1, "phase": "lobby", "chapter": "forest_1"}


static func mode() -> bool:
	return not GameState.expedition.is_empty()


static func active() -> bool:
	return GameState.expedition.get("phase", "") in ACTIVE


static func phase() -> String:
	return str(GameState.expedition.get("phase", "lobby"))


static func chapter() -> Dictionary:
	return ExpeditionContent.chapter(str(GameState.expedition.get("chapter", "forest_1")))


static func current_mission() -> String:
	return str(GameState.expedition.get("mission", "")) if phase() == "mission" else ""


static func quest_allowed(id: String) -> bool:
	return not mode() or current_mission() == id


static func objective() -> String:
	var state: Dictionary = GameState.expedition
	match phase():
		"lobby":
			return "보급원 미라 또는 일지에서 원정 계약을 선택하세요."
		"starter":
			return "스킬 선택 · 이번 원정의 주 공격을 고르세요."
		"missions":
			return "일지에서 다음 임무와 보상을 선택하세요."
		"mission":
			return Quests.objective(current_mission())
		"mission_reward", "bonus_reward", "seal_reward":
			return "원정 보상 · 스킬 또는 지원 룬을 선택하세요."
		"branch":
			return "동굴·엘리트에 도전하거나 봉인으로 진행하세요."
		"optional":
			return (
				"바람 동굴의 마지막 귀환문에서 완료하세요."
				if state.get("branch", "") == "cave"
				else "마지막 봉인 근처의 정예 파수꾼을 쓰러뜨리세요."
			)
		"seals":
			return (
				"봉인 %d/%d · 지도에서 금빛 봉인 비석을 찾아 공격하세요."
				% [state.get("seals", []).size(), chapter().get("seals", []).size()]
			)
		"boss":
			return "강 건너 파수꾼 공터에서 마지막 보스에 도전하세요."
		"return":
			return "마을로 돌아가 촌장에게 보고하고 종을 울리세요."
		"debrief":
			return "원정 결산 완료 · 새 계약과 다른 스킬 조합에 도전하세요."
	return ""


static func valid(value: Variant, cls: String, hero: Dictionary) -> bool:
	if not value is Dictionary:
		return false
	var state: Dictionary = value
	if state.is_empty():
		return true
	if (
		state.get("schema") != 1
		or not state.get("phase", "") in PHASES
		or ExpeditionContent.chapter(str(state.get("chapter", ""))).is_empty()
	):
		return false
	if state["phase"] in ["lobby", "debrief"]:
		if state.has("profile"):
			return false
		if state["phase"] == "lobby":
			return true
		var result: Variant = state.get("result")
		if not result is Dictionary or not result.get("success") is bool:
			return false
		for key in ["seconds", "level", "kills", "renown", "missions"]:
			if not GameState._encounter_integer(result.get(key), 0, 10000000):
				return false
		return true
	var profile: Variant = state.get("profile")
	if not profile is Dictionary or profile.has("expedition") or profile.get("class") != cls:
		return false
	for key in (
		ExpeditionProfile.INTS
		+ ExpeditionProfile.FLAGS
		+ ExpeditionProfile.MAPS
		+ ExpeditionProfile.LISTS
		+ [
			"inventory",
			"equipped",
			"unseen",
			"bonus_attack",
			"bonus_health",
			"last_sanctuary",
			"location_mode",
			"discovered_sanctuaries"
		]
	):
		if not profile.has(key):
			return false
	if not GameState._valid_save(profile) or not ExpeditionSaveRules.profile(profile, cls):
		return false
	for key in ["serial", "draft_serial", "level_drafts"]:
		if not GameState._encounter_integer(state.get(key), 0, 10000000):
			return false
	if (
		not GameState._number(state.get("elapsed"))
		or float(state["elapsed"]) < 0
		or float(state["elapsed"]) > 10000000
	):
		return false
	for key in ["missions", "seals", "drafts", "offered", "rune_inventory", "armed_seals"]:
		if not state.get(key) is Array or state[key].size() > 40:
			return false
	for key in ["missions", "seals", "rune_inventory", "armed_seals"]:
		var unique := {}
		for id: Variant in state[key]:
			if not id is String or unique.has(id):
				return false
			unique[id] = true
	for id: Variant in state["missions"]:
		if not chapter_for(state)["missions"].has(id):
			return false
	for id: Variant in state["seals"] + state["armed_seals"]:
		if not chapter_for(state)["seals"].has(id):
			return false
	for id: Variant in state["drafts"]:
		if not id in ["starter", "level", "mission", "bonus", "seal", "rune"]:
			return false
	for id: Variant in state["rune_inventory"]:
		if not ExpeditionContent.runes().has(id):
			return false
	var runes: Variant = state.get("runes")
	if not runes is Dictionary or runes.size() > 30:
		return false
	var used := []
	for skill: Variant in runes:
		if (
			not skill is String
			or not runes[skill] is Array
			or runes[skill].size() > 2
			or ExpeditionContent.skill_metadata(skill, cls).is_empty()
		):
			return false
		for rune: Variant in runes[skill]:
			if (
				not rune is String
				or used.has(rune)
				or not state["rune_inventory"].has(rune)
				or not ExpeditionContent.compatible(skill, rune)
			):
				return false
			used.append(rune)
	if (
		state["offered"].size() > 3
		or (not state["offered"].is_empty() and state["drafts"].is_empty())
	):
		return false
	for card: Variant in state["offered"]:
		if (
			not card is Dictionary
			or not card.get("key") is String
			or not card.get("id") is String
			or not card.get("kind", "") in ["skill", "rune"]
		):
			return false
		if card["kind"] == "skill" and ExpeditionContent.skill_metadata(card["id"], cls).is_empty():
			return false
		if (
			card["kind"] == "rune"
			and (
				not card.get("skill") is String
				or not ExpeditionContent.compatible(card["skill"], card["id"])
			)
		):
			return false
	if (
		state["phase"] == "mission"
		and (
			not chapter_for(state)["missions"].has(state.get("mission"))
			or state["missions"].has(state["mission"])
		)
	):
		return false
	if state["phase"] == "optional" and not state.get("branch", "") in ["cave", "elite"]:
		return false
	if (
		state["phase"] != "starter"
		and ExpeditionContent.skill_metadata(str(state.get("signature", "")), cls).is_empty()
	):
		return false
	if not ExpeditionSaveRules.phase(state, hero):
		return false
	return not (
		ExpeditionContent.contract(str(state["chapter"]), str(state.get("contract", ""))).is_empty()
	)


static func chapter_for(state: Dictionary) -> Dictionary:
	return ExpeditionContent.chapter(str(state.get("chapter", "")))


static func valid_meta(value: Variant) -> bool:
	if not value is Dictionary or value.size() > 3:
		return false
	for key in ["renown", "runs"]:
		if not GameState._encounter_integer(value.get(key, 0), 0, 10000000):
			return false
	var clears: Variant = value.get("clears", {})
	if not clears is Dictionary or clears.size() > 30:
		return false
	for id: Variant in clears:
		if not id is String or not GameState._encounter_integer(clears[id], 0, 10000000):
			return false
	return true

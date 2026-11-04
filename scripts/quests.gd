class_name Quests
extends RefCounted
## 제1장 숲의 의뢰 (원본 forest_quests.dart): 제단 정화 · 약초 배달 · 조사관 보호.
## 진행 상태는 GameState.quests에 저장됩니다. phase: offered → accepted → ready → completed
## (보호 의뢰에서 조사관이 쓰러지면 failed).

const DEFS := [
	{"id": "roots", "title": "숲의 오래된 봉인", "kind": "cleanse", "giver": "수녀 엘린", "recipient": "수녀 엘린",
		"desc": "의뢰를 받은 뒤 석조 정원 근처의 적 18마리를 처치하고 봉인을 정화해 주세요.", "gold": 120, "exp": 120},
	{"id": "moon", "title": "고목 쉼터의 약초 꾸러미", "kind": "delivery", "giver": "보급원 미라", "recipient": "약초사 노아",
		"desc": "마을에서 약초 꾸러미를 받아 북쪽 숲 고목의 쉼터에 있는 약초사에게 전해 주세요.", "gold": 80, "exp": 90},
	{"id": "sun", "title": "동굴 조사관을 지켜라", "kind": "protection", "giver": "조사관 로웬", "recipient": "조사관 로웬",
		"desc": "조사관을 90초 동안 지키며 6마리씩 다섯 차례 습격하는 적 30마리를 모두 처치하세요.", "gold": 300, "exp": 360},
]

const ALTAR_KILL_GOAL := 18
const PROTECT_SECONDS := 90.0
const THREAT_COUNT := 30
const WAVE_SIZE := 6
const DEFENDER_HP := 720.0
const EXPERIENCE_MULTIPLIER := 2


static func def(id: String) -> Dictionary:
	for d in DEFS:
		if d["id"] == id:
			return d
	return {}


static func fresh(id: String) -> Dictionary:
	return {"phase": "offered", "parcel": false, "altar_kills": 0, "cleansed": false, "started": false,
		"protected_for": 0.0, "defender_hp": DEFENDER_HP, "defeated": 0, "attempt": 0, "spawned": 0}


static func state(id: String) -> Dictionary:
	if not GameState.quests.has(id):
		GameState.quests[id] = fresh(id)
	return GameState.quests[id]


static func phase(id: String) -> String:
	return state(id)["phase"]


static func all_done() -> bool:
	for d in DEFS:
		if phase(d["id"]) != "completed":
			return false
	return true


static func objective(id: String) -> String:
	var d := def(id)
	var s := state(id)
	match s["phase"]:
		"completed":
			return "의뢰 완료"
		"offered":
			return "%s에게 의뢰를 받으세요." % d["giver"]
		"ready":
			return "%s에게 완료를 보고하세요." % d["recipient"]
		"failed":
			return "%s에게 말해 다시 준비하세요." % d["giver"]
	match d["kind"]:
		"cleanse":
			return "석조 정원 주변 적 %d/%d · 정리 후 봉인을 정화하세요." % [s["altar_kills"], ALTAR_KILL_GOAL]
		"delivery":
			return ("고목의 쉼터의 %s에게 약초 꾸러미를 전하세요." % d["recipient"]) if s["parcel"] else ("%s에게 약초 꾸러미를 받으세요." % d["giver"])
		_:
			if not s["started"]:
				return "%s에게 말을 걸어 조사를 시작하세요." % d["giver"]
			return "조사관 보호 %d/%d초 · 습격자 %d/%d명 남음" % [floori(s["protected_for"]), int(PROTECT_SECONDS), THREAT_COUNT - s["defeated"], THREAT_COUNT]
	return ""


## 지금 할 일 (mainObjective).
static func main_objective() -> String:
	for d in DEFS:
		if phase(d["id"]) != "completed":
			return objective(d["id"])
	if GameState.boss_defeated:
		return "제1장을 완료했습니다."
	return "서쪽 숲의 공터에서 파수꾼에게 도전하세요."


static func quest_progress(id: String) -> float:
	match phase(id):
		"completed":
			return 1.0
		"ready":
			return 0.8
		"accepted":
			return 0.35
	return 0.0


## "!" over an NPC: something to accept, deliver or report there.
static func marker_for(npc: String) -> bool:
	match npc:
		"수녀 엘린":
			var p := phase("roots")
			return p == "offered" or p == "ready" or p == "failed" or (p == "accepted" and state("roots")["altar_kills"] >= ALTAR_KILL_GOAL and not state("roots")["cleansed"])
		"보급원 미라":
			var m := state("moon")
			return m["phase"] == "offered" or (m["phase"] == "accepted" and not m["parcel"])
		"약초사 노아":
			var n := state("moon")
			return n["phase"] == "ready" or (n["phase"] == "accepted" and n["parcel"])
		"조사관 로웬":
			var r := phase("sun")
			var q := state("sun")
			return r == "offered" or r == "ready" or r == "failed" or (r == "accepted" and not q["started"])
	return false

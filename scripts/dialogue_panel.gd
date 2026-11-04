class_name DialoguePanel
extends PanelFrame
## NPC 대화 (원본 QuestGiver 패널): 의뢰 수락 · 짐 받기 · 전달 · 정화 · 시작 · 보고 · 재시도.

var game: Node
var npc := ""


func setup(g: Node, npc_name: String) -> DialoguePanel:
	game = g
	npc = npc_name
	return self


func _ready() -> void:
	super._ready()
	_rebuild()


func _rebuild() -> void:
	clear_body()
	for c in footer.get_children():
		c.queue_free()
	for c in trailing.get_children():
		c.queue_free()
	set_header(npc)
	match npc:
		"수녀 엘린":
			_quest("roots", true)
		"보급원 미라":
			_mira()
		"약초사 노아":
			_noah()
		"조사관 로웬":
			_quest("sun", true)
		"촌장":
			_elder()
		_:
			body.add_child(PanelFrame.wrap_label("…", 22))
	add_footer("닫기", func(): closed.emit(), true)


func _say(text: String) -> void:
	var l := PanelFrame.wrap_label(text, 21, Color(0.95, 0.93, 0.85))
	body.add_child(l)


func _reward_line(id: String) -> void:
	var d := Quests.def(id)
	body.add_child(PanelFrame.wrap_label("보상 · %d G · 경험치 %d" % [d["gold"], d["exp"] * Quests.EXPERIENCE_MULTIPLIER], 19, Color(1, 0.88, 0.5)))


func _action(text: String, on_press: Callable, enabled := true) -> void:
	var b := UiKit.button(text, 23)
	b.custom_minimum_size = Vector2(0, 76)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = not enabled
	b.pressed.connect(func():
		on_press.call()
		_rebuild())
	body.add_child(b)


func _quest(id: String, same_giver: bool) -> void:
	var d := Quests.def(id)
	var s := Quests.state(id)
	body.add_child(PanelFrame.section(d["title"]))
	match s["phase"]:
		"completed":
			_say("고맙소. 덕분에 숲이 한결 조용해졌소.")
			return
		"offered":
			_say(d["desc"])
			_reward_line(id)
			_action("수락", func(): game.quest_runtime.accept(id))
		"failed":
			_say("조사관이 쓰러졌습니다. 다시 준비하면 처음부터 도전할 수 있습니다.")
			_action("재시도", func(): game.quest_runtime.retry(id))
		"ready":
			_say("해냈구려! 약속한 보상을 받아 가시오.")
			_reward_line(id)
			_action("보고", func(): game.quest_runtime.report(id))
		_:
			_say(Quests.objective(id))
			if id == "roots":
				var reason: String = game.quest_runtime.cleanse_blocked_reason()
				_action("정화" if reason == "" else "정화 불가", func(): game.quest_runtime.cleanse(), reason == "")
				if reason != "":
					body.add_child(PanelFrame.wrap_label(reason, 18, Color(1, 0.75, 0.6)))
			elif id == "sun":
				if not s["started"]:
					_action("조사 시작", func(): game.quest_runtime.start_protection())
				else:
					body.add_child(PanelFrame.wrap_label("조사관을 지키고 습격자를 막아 주세요.", 18, Color(1, 0.75, 0.6)))


func _mira() -> void:
	var d := Quests.def("moon")
	var s := Quests.state("moon")
	body.add_child(PanelFrame.section(d["title"]))
	match s["phase"]:
		"completed":
			_say("노아에게 잘 전해 주었군요. 고마워요!")
		"offered":
			_say(d["desc"])
			_reward_line("moon")
			_action("수락", func(): game.quest_runtime.accept("moon"))
		"ready":
			_say("약초사 노아에게 꾸러미를 전달하고 보고하세요.")
		_:
			if not s["parcel"]:
				_say("약초 꾸러미예요. 북쪽 숲 고목의 쉼터에 있는 노아에게 전해 주세요.")
				_action("짐 받기", func(): game.quest_runtime.receive_parcel())
			else:
				_say("노아에게 꾸러미를 전달해 주세요. 고목의 쉼터는 북쪽 길에서 가까워요.")


func _noah() -> void:
	var d := Quests.def("moon")
	var s := Quests.state("moon")
	body.add_child(PanelFrame.section(d["title"]))
	match s["phase"]:
		"completed":
			_say("약초 덕에 한동안 걱정이 없겠소. 고맙소!")
		"offered":
			_say("마을의 보급원 미라에게 의뢰를 받으세요.")
		"ready":
			_say("꾸러미를 확인했소. 보상을 받아 가시오.")
			_reward_line("moon")
			_action("보고", func(): game.quest_runtime.report("moon"))
		_:
			if s["parcel"]:
				_say("미라가 보낸 약초 꾸러미군요! 이리 주시오.")
				_action("전달", func(): game.quest_runtime.deliver())
			else:
				_say("보급원 미라에게 약초 꾸러미를 받아 오세요.")


func _elder() -> void:
	body.add_child(PanelFrame.section("숲의 현자"))
	_say("“석조 정원의 엘린은 봉인을 지키고, 마을 보급원 미라는 약초 배달을 기다리네. 동굴의 조사관 로웬도 도움이 필요하다네. 세 의뢰와 숲길의 위협을 해결하면 파수꾼이 깨어날 걸세. 상자와 전리품을 모으고, 얻은 힘을 스스로 선택하게나. 전투를 벗어나 분수 곁에서 쉬면 생명이 회복된다네.”")
	body.add_child(PanelFrame.section("지금 할 일"))
	body.add_child(PanelFrame.wrap_label(Quests.main_objective(), 20, Color(0.78, 0.92, 0.85)))
	body.add_child(PanelFrame.wrap_label("이번 장 처치 %d / %d" % [mini(GameState.stage_kills, Quests.STAGE_KILL_GOAL), Quests.STAGE_KILL_GOAL], 19, Color(1, 0.88, 0.5)))

class_name ExpeditionPanel
extends PanelFrame
## 원정의 선택은 이 화면에서, 실제 의뢰/탐험은 월드에서 수행한다.
var game: Node


func setup(value: Node) -> ExpeditionPanel:
	game = value
	return self


func _ready() -> void:
	super._ready()
	if (
		ExpeditionState.phase() == "debrief"
		and GameState.expedition.get("result", {}).get("success", false)
	):
		SoundFx.play("town_bell")
	_rebuild()


func _rebuild() -> void:
	clear_body()
	scroll.scroll_vertical = 0
	set_header(ExpeditionState.chapter()["title"], "원정 · 계약과 성장")
	if not game.expedition.error.is_empty():
		body.add_child(wrap_label(game.expedition.error, 19, Color.SALMON))
	if not GameState.expedition.get("drafts", []).is_empty():
		_draft()
		return
	body.add_child(wrap_label(ExpeditionState.objective(), 22, UiKit.GOLD))
	match ExpeditionState.phase():
		"lobby", "debrief":
			if ExpeditionState.phase() == "debrief":
				_debrief()
			body.add_child(section("새 원정 계약"))
			if not GameState.expedition_meta.get("clears", {}).is_empty():
				body.add_child(wrap_label("마을 보급소 복구 · 출발 보급 +1 / +1", 20, UiKit.GOLD))
			(
				body
				. add_child(
					wrap_label(
						"레벨 1과 원정 장비로 시작합니다. 이번 원정의 기술·룬·장비는 결산 때 정리되고, 기존 캐릭터와 명성은 남습니다. 성공하려면 마을로 돌아와 촌장에게 보고하세요.",
						18,
						UiKit.MUTED
					)
				)
			)
			for contract: Dictionary in ExpeditionState.chapter()["contracts"]:
				body.add_child(section(contract["title"]))
				body.add_child(
					wrap_label("%s\n성공 보상 · 명성 +%d" % [contract["desc"], contract["renown"]], 19)
				)
				_action(
					"이 계약으로 출발",
					"contract_" + str(contract["id"]),
					func(): game.expedition.start(contract["id"])
				)
		"missions":
			body.add_child(
				wrap_label(
					"서로 다른 임무 2개를 선택합니다. 성장 선택 2회 또는 성장 1회와 생명·자원 회복약 각 2개 중 보상을 고르세요.",
					19,
					UiKit.MUTED
				)
			)
			for id: String in ExpeditionState.chapter()["missions"]:
				if GameState.expedition["missions"].has(id):
					continue
				var mission := Quests.def(id)
				body.add_child(section(mission["title"]))
				body.add_child(wrap_label(mission["desc"], 19))
				_action(
					"수행 · 성장 선택 2회",
					"mission_" + id,
					func(): game.expedition.select_mission(id, "draft")
				)
				_action(
					"수행 · 성장 1회와 회복약 각 2개",
					"supplies_" + id,
					func(): game.expedition.select_mission(id, "supplies")
				)
		"branch":
			body.add_child(
				wrap_label("선택 도전 완료 시 성장 선택을 한 번 더 받습니다. 어려우면 포기하고 봉인으로 진행할 수 있습니다.", 19)
			)
			_action("바람 동굴 · 제한 시간 안에 탐험 완료", "branch_cave", func(): game.expedition.branch("cave"))
			_action("정예 파수꾼 · 마지막 봉인 부근", "branch_elite", func(): game.expedition.branch("elite"))
			_action("봉인으로 바로 진행", "branch_skip", func(): game.expedition.branch("skip"))
		"optional":
			_action("선택 도전 포기 · 봉인으로 진행", "abandon_optional", game.expedition.abandon_optional)
		"return":
			_action("촌장에게 보고 · 종 울리기", "settle", func(): game.expedition.settle(true))
		"seals":
			body.add_child(
				wrap_label(
					"지도에 표시된 두 비석을 찾으세요. 기존 적을 정리한 뒤 비석을 공격하고, 소환된 무리를 모두 물리치면 봉인을 되찾습니다.", 19
				)
			)
	if ExpeditionState.active():
		body.add_child(section("원정 기록"))
		body.add_child(
			wrap_label(
				(
					"임무 %d/2 · 봉인 %d/2 · 경과 %d분\n기술과 룬은 하단 스킬 메뉴에서 바꿀 수 있습니다."
					% [
						GameState.expedition["missions"].size(),
						GameState.expedition["seals"].size(),
						int(GameState.expedition["elapsed"]) / 60
					]
				),
				18,
				UiKit.MUTED
			)
		)

		if game.in_town(game.player.position) and not game.dungeon.active:
			_action("원정 포기 · 보상 없이 종료", "forfeit", func(): return game.expedition.settle(false))


func _draft() -> void:
	body.add_child(section("이번 원정의 힘 · 셋 중 하나"))
	body.add_child(
		wrap_label(
			"바로 습득합니다. 기술은 빈 보조 슬롯에 배치되며, 지원 룬은 표시된 기술에 붙습니다. 스킬 메뉴에서 자유롭게 다시 조합하세요.",
			19,
			UiKit.MUTED
		)
	)
	var cards := RunBuild.offer()
	if cards.is_empty():
		body.add_child(wrap_label("선택지를 저장하지 못했습니다. 창을 닫고 다시 열어 주세요.", 19, Color.SALMON))
	for card: Dictionary in cards:
		body.add_child(UiKit.divider())
		var skill_id: String = card["id"] if card["kind"] == "skill" else card["skill"]
		var skill := GameState.skill(skill_id)
		var name_text: String
		var description: String
		if card["kind"] == "skill":
			name_text = str(skill["name"])
			description = str(skill["desc"]) + "\n" + SkillDefs.describe(skill_id, 1)
			if GameState.expedition["drafts"][0] == "starter":
				description += "\n주 공격 · 자원 소모 없음"
		else:
			var rune: Dictionary = ExpeditionContent.runes()[card["id"]]
			name_text = "%s · 지원 룬" % rune["name"]
			description = "%s\n부착 기술 · %s" % [rune["desc"], skill["name"]]
		body.add_child(section(name_text))
		body.add_child(skill_art(skill_id))
		body.add_child(wrap_label(description, 19))
		_action(
			"선택 · " + name_text,
			"draft_" + str(card["id"]),
			func(): game.expedition.choose(card["key"])
		)


static func skill_art(id: String) -> TextureRect:
	var source := SkillIcons.source(id)
	var texture: Texture2D = source["texture"]
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	var uv: Rect2 = source["uv"]
	atlas.region = Rect2(uv.position * texture.get_size(), uv.size * texture.get_size())
	var art := TextureRect.new()
	art.texture = atlas
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(0, 80)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art


func _debrief() -> void:
	var result: Dictionary = GameState.expedition.get("result", {})
	body.add_child(
		section("숲의 종이 다시 울립니다" if result.get("success", false) else "원정 종료 · 다음 계약을 준비하세요")
	)
	body.add_child(
		wrap_label(
			(
				"%d분 %d초 · Lv.%d · 적 %d마리 · 임무 %d개\n명성 +%d · 누적 명성 %d"
				% [
					int(result.get("seconds", 0)) / 60,
					int(result.get("seconds", 0)) % 60,
					result.get("level", 1),
					result.get("kills", 0),
					result.get("missions", 0),
					result.get("renown", 0),
					GameState.expedition_meta.get("renown", 0)
				]
			),
			21
		)
	)
	if result.get("success", false):
		(
			body
			. add_child(
				wrap_label(
					"마을 보급소가 복구되었습니다. 이후 원정은 생명·자원 회복약을 1개씩 더 받습니다. 명성 6부터 폭풍의 창 / 분쇄자의 외침이 다음 원정의 선택지에 합류합니다.",
					19,
					UiKit.GOLD
				)
			)
		)


func _action(text: String, id: String, callback: Callable) -> void:
	var button := UiKit.button(text, 21)
	button.name = id
	button.custom_minimum_size = Vector2(0, 76)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(
		func():
			if callback.call():
				if is_instance_valid(game) and game.process_mode != Node.PROCESS_MODE_DISABLED:
					_rebuild()
			else:
				_rebuild()
	)
	body.add_child(button)

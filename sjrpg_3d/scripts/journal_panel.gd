class_name JournalPanel
extends PanelFrame
## 퀘스트 일지 (원본 game_panels 'journal'): 지금 할 일 · 의뢰 진행 · 숲길 정화 · 첫 파수꾼 · 발견한 상자.


var game: Node


func setup(value: Node) -> JournalPanel:
	game = value
	return self


func _ready() -> void:
	super._ready()
	set_header("제1장 · 숲과 초원", "퀘스트 일지")
	if game != null:
		var contract := UiKit.button("원정 · 계약 / 진행 / 보상", 23)
		contract.custom_minimum_size.y = 76
		contract.pressed.connect(func(): closed.emit(); game.hud.open_expedition.call_deferred())
		body.add_child(contract)
	if ExpeditionState.mode():
		body.add_child(wrap_label(ExpeditionState.objective(), 22, UiKit.GOLD))
		return
	body.add_child(PanelFrame.section("지금 할 일"))
	body.add_child(PanelFrame.wrap_label(Quests.main_objective(), 21, Color(0.95, 0.93, 0.85)))
	for d in Quests.DEFS:
		body.add_child(_bar(d["title"], Quests.objective(d["id"]), Quests.quest_progress(d["id"]), "완료" if Quests.phase(d["id"]) == "completed" else d["giver"]))
	var status := "정화 완료" if GameState.boss_defeated else ("도전 중" if GameState.boss_summoned else "서쪽 숲 공터에서 도전" if Quests.all_done() else "의뢰 3개 완료 후 해금")
	body.add_child(_bar("첫 파수꾼", "NPC 의뢰 3개를 해결하고 파수꾼을 쓰러뜨리면 제1장을 완료합니다.", 1.0 if GameState.boss_defeated else 0.0, status))
	if GameState.boss_heart_pending:
		body.add_child(PanelFrame.wrap_label("파수꾼의 심장 보관 중 · 가방을 비우고 창을 닫으면 받습니다.", 20, UiKit.GOLD))
	body.add_child(PanelFrame.section("숲의 기억 · 선택 여정  %d / 3" % MemoryPanel.recovered()))
	body.add_child(PanelFrame.wrap_label("서쪽·북쪽·동쪽 길의 상자에서 기억 3개를 모으세요. 완성 보상: 스킬 포인트 +1.", 17, UiKit.MUTED))
	for i in MemoryPanel.MEMORIES.size():
		var m: Dictionary = MemoryPanel.MEMORIES[i]
		var opened := GameState.opened_chests.has(MemoryPanel.FIRST_CHEST + i)
		body.add_child(PanelFrame.wrap_label(("%s — %s" % [m["title"], m["story"]]) if opened else ("찾지 못한 기억 · %s" % m["hint"]), 17, Color(0.95, 0.9, 0.78) if opened else Color(0.6, 0.7, 0.66)))
	body.add_child(PanelFrame.wrap_label("발견한 상자 %d / %d" % [GameState.opened_chests.size(), 9], 20, Color(1, 0.88, 0.5)))
	body.add_child(PanelFrame.wrap_label("모험가 Lv.%d %s" % [GameState.level, GameState.class_info()["name"]], 20, Color(0.78, 0.92, 0.85)))
	add_footer("모험 계속하기", func(): closed.emit(), true)


func _bar(title: String, sub: String, ratio: float, tag: String) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.SURFACE, UiKit.EDGE, 12))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var t := UiKit.label(title, 22, Color(0.95, 0.92, 0.8), true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(t)
	head.add_child(UiKit.label(tag, 17, Color(1, 0.88, 0.5)))
	col.add_child(PanelFrame.wrap_label(sub, 17, UiKit.MUTED))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = ratio
	bar.custom_minimum_size = Vector2(0, 14)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("0f100d")
	track.border_color = UiKit.EDGE
	track.set_border_width_all(1)
	track.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", track)
	var progress := StyleBoxFlat.new()
	progress.bg_color = Color("8d8c58")
	progress.border_color = Color("c1b584")
	progress.set_border_width_all(1)
	progress.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", progress)
	col.add_child(bar)
	return card

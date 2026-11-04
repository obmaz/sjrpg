class_name VictoryPanel
extends PanelFrame
## 제1장 클리어: 숲의 파수꾼을 쓰러뜨렸습니다. 다음 장(사막 유적)은 아직 이식 전이라
## 계속 탐험하거나 새 모험을 시작할 수 있습니다.

signal restart_requested


func _ready() -> void:
	super._ready()
	set_compact()
	set_header("첫 스테이지 정화", "제1장 · 숲과 초원")
	var crest := UiKit.label("★  제1장 완료  ★", 34, UiKit.GOLD, true)
	crest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crest.custom_minimum_size = Vector2(0, 120)
	crest.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.add_child(crest)
	body.add_child(PanelFrame.wrap_label("의뢰를 해결했습니다.\n숲의 파수꾼이 잠들었습니다. 사막 유적(제2장)의 길은 아직 열리지 않았습니다.", 21))
	for line in [["모험가", "Lv.%d %s" % [GameState.level, GameState.class_info()["name"]]], ["이번 장 처치", str(GameState.stage_kills)], ["보유 골드", "%s G" % HudArt.fmt(GameState.gold)]]:
		var row := HBoxContainer.new()
		row.add_child(UiKit.label(line[0], 20, Color(0.82, 0.9, 0.85)))
		var v := UiKit.label(line[1], 22, UiKit.GOLD, true)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(v)
		body.add_child(row)
	var again := UiKit.button("다른 직업으로 새 모험", 22)
	again.custom_minimum_size = Vector2(0, 72)
	again.pressed.connect(func(): restart_requested.emit())
	body.add_child(again)
	add_footer("계속 탐험하기", func(): closed.emit(), true)

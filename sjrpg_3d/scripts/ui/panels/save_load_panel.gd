class_name SaveLoadPanel
extends PanelFrame
## 수호자 저장 슬롯(1~4)을 선택하여 모험을 이어가는 불러오기 전용 패널.
## 메인 타이틀 및 인게임 설정 모두에서 재사용 가능하며, load_only 모드 시 새 게임 없이 순수 불러오기만 제공합니다.

signal slot_loaded(slot: int)

var load_only := true
var selected_slot := -1
var _summaries: Array = []
var _slot_cards: Array[PanelContainer] = []
var _load_button: Button
var _notice_label: Label


func setup(is_load_only := true) -> SaveLoadPanel:
	load_only = is_load_only
	return self


func _ready() -> void:
	super._ready()
	set_header("모험 불러오기", "수호자 기록 보관소 (4개 슬롯)")
	_refresh_data()
	_rebuild()
	add_footer("취소 / 돌아가기", func(): closed.emit(), true)


func _refresh_data() -> void:
	_summaries = GameState.slot_summaries()


func _rebuild() -> void:
	clear_body()
	_slot_cards.clear()

	var notice_text := "이어갈 수호자 슬롯을 선택하세요." if load_only else "현재 모험을 저장하고 다른 수호자로 전환합니다."
	_notice_label = PanelFrame.wrap_label(notice_text, 17, UiKit.MUTED)
	body.add_child(_notice_label)
	body.add_child(UiKit.divider())

	for i in range(GameState.MAX_SAVE_SLOTS):
		var slot_num := i + 1
		var summary: Dictionary = {}
		for s in _summaries:
			if s.get("slot") == slot_num:
				summary = s
				break
		var card := _create_slot_card(slot_num, summary)
		_slot_cards.append(card)
		body.add_child(card)

	body.add_child(UiKit.divider())

	_load_button = UiKit.button("선택한 모험 불러오기", 24)
	_load_button.custom_minimum_size.y = 68
	UiKit.style_button(_load_button, true)
	_load_button.disabled = (selected_slot < 1)
	_load_button.pressed.connect(_on_load_pressed)
	body.add_child(_load_button)


func _create_slot_card(slot_num: int, summary: Dictionary) -> PanelContainer:
	var occupied: bool = summary.get("occupied", false)
	var valid: bool = summary.get("valid", false)
	var is_selected := (selected_slot == slot_num)

	var card := PanelContainer.new()
	var style := UiKit.panel_style(UiKit.SURFACE_RAISED if is_selected else UiKit.SURFACE, UiKit.GOLD if is_selected else UiKit.EDGE)
	if not occupied and not is_selected:
		style.border_color = UiKit.EDGE.darkened(0.25)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)

	# 슬롯 번호 배지
	var badge := Label.new()
	badge.text = "%d" % slot_num
	badge.add_theme_font_override("font", UiKit.BOLD_FONT)
	badge.add_theme_font_size_override("font_size", 28)
	badge.add_theme_color_override("font_color", Color("c9af7c") if is_selected else UiKit.MUTED)
	badge.custom_minimum_size = Vector2(36, 0)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(badge)

	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 4)
	row.add_child(info_col)

	if occupied and not valid:
		info_col.add_child(UiKit.label("슬롯 %d · 손상된 모험" % slot_num, 19, UiKit.MUTED, true))
		info_col.add_child(PanelFrame.wrap_label(
			"저장 파일을 읽지 못했습니다. 새로운 모험의 슬롯 선택에서 확인·삭제할 수 있습니다.",
			15, UiKit.MUTED))
	elif occupied:
		var hero_cls: String = summary.get("class", "warrior")
		var hero_name: String = "전사" if hero_cls == "warrior" else "마법사"
		var level: int = summary.get("level", 1)
		var loc: String = "숲 필드" if summary.get("location") == "forest" else "어두운 동굴"

		var title_text := "슬롯 %d · Lv.%d %s" % [slot_num, level, hero_name]
		var title := UiKit.label(title_text, 20, Color("f0ece1") if is_selected else UiKit.TEXT, true)
		info_col.add_child(title)

		var sub_text := "위치: %s" % loc
		if bool(summary.get("backup", false)):
			sub_text += " · 백업에서 복구"
		var ts: float = summary.get("timestamp", 0.0)
		if ts > 0:
			sub_text += " · " + SaveTimeLabel.for_device(ts)
		var sub := PanelFrame.wrap_label(sub_text, 15, UiKit.MUTED)
		info_col.add_child(sub)
	else:
		var empty_title := UiKit.label("슬롯 %d · 비어 있는 슬롯" % slot_num, 19, UiKit.MUTED, true)
		info_col.add_child(empty_title)
		var empty_sub := PanelFrame.wrap_label("저장된 모험 기록이 없습니다." if load_only else "새로운 수호자를 생성할 수 있습니다.", 14, UiKit.MUTED)
		info_col.add_child(empty_sub)

	# 손가락을 댄 순간 목록을 재생성하면 스크롤이 끊긴다. 기본 버튼의 해제/드래그 취소를 쓴다.
	var select := Button.new()
	select.name = "SelectSaveSlot%d" % slot_num
	select.tooltip_text = "슬롯 %d 선택" % slot_num
	select.disabled = load_only and not valid
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		select.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	select.pressed.connect(func():
		selected_slot = slot_num
		_rebuild()
	)
	card.add_child(select)

	return card


func _on_load_pressed() -> void:
	if selected_slot >= 1:
		slot_loaded.emit(selected_slot)
		closed.emit()

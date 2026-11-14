extends Control
## Four independent adventures; previews never load, replace or save a hero.
signal chosen(cls: String)
signal continue_requested
signal back_requested
const ROLES := {"warrior": "검과 함성 · 근접 전투", "mage": "화염과 냉기 · 원거리 주문"}
const DESCRIPTIONS := {
	"warrior": "견고한 몸과 강한 의지로, 가장 앞에서 자연을 수호하는 전사입니다.",
	"mage": "세 가지 원소와 신비로운 주문으로 자연을 지키고 전장을 지배합니다."
}
var entry_mode := "auto"
var selected_class := "mage"
var selected_slot := 1
var class_buttons: Dictionary = {}
var class_tab_icons: Dictionary = {}
var class_tab_labels: Dictionary = {}
var _class_tab_groups: Dictionary = {}
var slot_buttons: Array[Button] = []
var delete_buttons: Array[Button] = []
var start_button: Button
var continue_button: Button
var back_button: Button
var slot_switch: Button
var hero_art: TextureRect
var showcase: Control
var details: Control
var heading: Label
var subtitle: Label
var hero_name: Label
var role: Label
var description: Label
var health: Label
var resource: Label
var _summaries: Array = []
var _stage := "slots"
var _unit := 1.0
var _delete_dialog: PanelFrame

var slot_scroll: ScrollContainer
var slot_list: VBoxContainer
var slot_footer: Panel
var slot_surface: Panel
var slot_context: Label
var slot_bands: Array[HBoxContainer] = []
var slot_title_labels: Array[Label] = []
var slot_meta_labels: Array[Label] = []
var slot_number_labels: Array[Label] = []
var slot_status_labels: Array[Label] = []
var _slot_pad := 16.0
var _slot_gap := 12.0
var _slot_badge := 56.0
var _slot_touch := 80.0
var _slot_css := 1.0
var _slot_safe := Rect2()
var _delete_target := 0
var _slot_relayout_pending := false
var _slot_reveal_pending := false
var _slot_dragging := false
var _slot_overflow := false
var _probe_queued := false
var _probe_flushes := 0
var _probe_writes := 0
var _last_probe_json := ""
var brand_label: Label
var class_surface: Panel
var info_surface: Panel
var stat_boxes: Array[Panel] = []
var slot_portraits: Array[TextureRect] = []
var slot_portrait_frames: Array[Panel] = []
var slot_number_badges: Array[Panel] = []
var _hero_backdrop: TextureRect
var _class_safe := Rect2()
var _class_compact := false
var _class_back_to_slots := true
var slot_empty_marks: Array[Label] = []
var identity_icon: TextureRect
var stat_icons: Array[TextureRect] = []


func _ready() -> void:
	add_to_group("gamepad_entry")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SelectionUi.backdrop(self)
	EntryUi.shade(self, 0.52)
	back_button = _button("‹  돌아가기", _request_back)
	back_button.name = "SelectionBack"
	SelectionUi.style(back_button)
	heading = _label("모험 선택", 36, EntryUi.TEXT, true)
	subtitle = _label("네 개의 여정, 당신만의 수호자", 23, EntryUi.MUTED)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.minimum_size_changed.connect(_queue_slot_layout)
	slot_switch = _button("", show_slots)
	showcase = Control.new()
	showcase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(showcase)
	hero_art = TextureRect.new()
	hero_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	showcase.add_child(hero_art)
	details = Control.new()
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(details)
	hero_name = _label("", 40, EntryUi.TEXT, true, details)
	role = _label("", 23, SelectionUi.ROLE, false, details)
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description = _label("", 24, EntryUi.TEXT, false, details)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	health = _label("", 22, SelectionUi.MUTED, false, details)
	resource = _label("", 22, SelectionUi.MUTED, false, details)
	for cls: String in ["warrior", "mage"]:
		class_buttons[cls] = _button(GameState.CLASSES[cls]["name"], func(): select_class(cls))
		class_buttons[cls].name = cls
		# Native CENTER icon alignment overlaps the text. Center their actual combined minimum instead.
		class_buttons[cls].icon = null
		var center := CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		class_buttons[cls].add_child(center)
		var group := HBoxContainer.new()
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(group)
		_class_tab_groups[cls] = group
		var icon := TextureRect.new()
		icon.name = "ClassIcon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.texture = SelectionUi.class_icon(cls)
		group.add_child(icon)
		class_tab_icons[cls] = icon
		var label := _label(class_buttons[cls].text, 28, SelectionUi.IVORY, true, group)
		label.name = "ClassName"
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		class_tab_labels[cls] = label
	slot_surface = Panel.new()
	slot_surface.name = "SaveSheet"
	slot_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_surface.add_theme_stylebox_override(
		"panel", UiKit.panel_style(Color("171e1c"), Color("756348"), 8)
	)
	add_child(slot_surface)
	move_child(slot_surface, 2)
	slot_scroll = ScrollContainer.new()
	ScrollArrows.prepare(slot_scroll)
	slot_scroll.name = "SaveListScroll"
	slot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	slot_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# 터치로 눌렀던 행이 스와이프 뒤 다시 따라오지 않게 한다.
	# 패드의 명시적 이동만 _reveal_focused_slot에서 현재 행을 드러낸다.
	slot_scroll.follow_focus = false
	slot_scroll.scroll_started.connect(func(): _slot_dragging = true)
	slot_scroll.scroll_ended.connect(func(): _slot_dragging = false)
	slot_scroll.clip_contents = true
	slot_scroll.scroll_deadzone = 10
	add_child(slot_scroll)
	slot_list = VBoxContainer.new()
	slot_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_scroll.add_child(slot_list)
	slot_scroll.item_rect_changed.connect(_queue_publish_buttons)
	slot_list.item_rect_changed.connect(_queue_publish_buttons)
	slot_scroll.get_v_scroll_bar().value_changed.connect(
		func(_value: float): _queue_publish_buttons()
	)
	slot_footer = Panel.new()
	slot_footer.name = "SaveFooter"
	slot_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var footer_skin := StyleBoxFlat.new()
	footer_skin.bg_color = Color(0.06, 0.08, 0.07, 0.98)
	footer_skin.border_color = Color("514a3b")
	footer_skin.border_width_top = 1
	slot_footer.add_theme_stylebox_override("panel", footer_skin)
	add_child(slot_footer)
	slot_context = _label("", 22, SelectionUi.MUTED)
	slot_context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot_context.minimum_size_changed.connect(_queue_slot_layout)
	for index in GameState.MAX_SAVE_SLOTS:
		var number := index + 1
		var band := HBoxContainer.new()
		band.name = "SaveBand%d" % number
		band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		band.draw.connect(
			func():
				band.draw_style_box(
					band.get_theme_stylebox("panel"), Rect2(Vector2.ZERO, band.size)
				)
		)
		band.resized.connect(band.queue_redraw)
		slot_list.add_child(band)
		band.item_rect_changed.connect(_queue_publish_buttons)
		slot_bands.append(band)
		var row := _button("", func(): select_slot(number))
		row.name = "SaveSlot%d" % number
		row.clip_text = true
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.reparent(band, false)
		slot_buttons.append(row)
		row.focus_entered.connect(_queue_slot_reveal)
		row.resized.connect(func(): _place_slot_labels(number - 1))
		slot_number_labels.append(_label("%02d" % number, 28, EntryUi.BRONZE, true, row))
		slot_title_labels.append(_label("", 26, EntryUi.TEXT, true, row))
		slot_title_labels.back().clip_text = true
		slot_title_labels.back().text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		slot_number_labels.back().horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var meta := _label("", 22, SelectionUi.MUTED, false, row)
		meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		meta.minimum_size_changed.connect(_queue_slot_layout)
		slot_meta_labels.append(meta)
		slot_status_labels.append(_label("", 20, EntryUi.BRONZE, false, row))
		var remove := _button("삭제", func(): confirm_delete(number))
		remove.name = "DeleteSlot%d" % number
		remove.reparent(band, false)
		remove.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		remove.tooltip_text = "저장 %d 삭제" % number
		var icon := Control.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		remove.add_child(icon)
		icon.draw.connect(func(): _draw_delete_icon(icon))
		icon.resized.connect(icon.queue_redraw)
		delete_buttons.append(remove)
		# 이 목록은 PanelFrame 밖에 있으므로 버튼·중간 band의 드래그 전달을 직접 준비한다.
		ScrollTouchSupport.prepare_button(row, self)
		ScrollTouchSupport.prepare_button(remove, self)

	start_button = _button("", _choose, true)
	continue_button = _button("이어 하기", _request_continue, true)
	refresh_slots()
	var occupied := false
	var first_empty := 0
	var first_valid := 0
	for summary: Dictionary in _summaries:
		occupied = occupied or bool(summary["occupied"])
		if first_empty == 0 and not bool(summary["occupied"]):
			first_empty = int(summary["slot"])
		if first_valid == 0 and bool(summary["valid"]):
			first_valid = int(summary["slot"])
	if entry_mode == "new" and first_empty > 0:
		_class_back_to_slots = false
		selected_slot = first_empty
		_stage = "class"
	elif entry_mode == "continue":
		_stage = "slots"
		selected_slot = (
			GameState.active_slot
			if bool(_summaries[GameState.active_slot - 1]["valid"])
			else maxi(1, first_valid)
		)
	elif not occupied:
		_stage = "class"
	else:
		_stage = "slots"
		if bool(_summaries[GameState.active_slot - 1]["occupied"]):
			selected_slot = GameState.active_slot
		else:
			for summary: Dictionary in _summaries:
				if bool(summary["occupied"]):
					selected_slot = int(summary["slot"])
					break
	resized.connect(_layout)
	_setup_presentation()
	_update()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sjrpgClassSelectReady = true")


func _button(text: String, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	button.focus_entered.connect(_queue_publish_buttons)
	button.focus_exited.connect(_queue_publish_buttons)
	button.item_rect_changed.connect(_queue_publish_buttons)
	SelectionUi.style(button, primary)
	add_child(button)
	return button


func _label(text: String, pixels: int, color: Color, bold := false, parent: Node = null) -> Label:
	var label := EntryUi.label(text, pixels, color, bold)
	label.add_theme_font_override("font", SelectionUi.TITLE_FONT if bold else SelectionUi.BODY_FONT)
	(parent if parent != null else self).add_child(label)
	return label


func refresh_slots() -> void:
	_summaries = GameState.slot_summaries()


func _selected() -> Dictionary:
	return _summaries[selected_slot - 1]


func show_slots() -> void:
	if _modal_open():
		return
	_stage = "slots"
	refresh_slots()
	_update()


func select_slot(number: int) -> void:
	if _modal_open() or number < 1 or number > GameState.MAX_SAVE_SLOTS:
		return
	if _stage == "slots":
		_class_back_to_slots = true
	selected_slot = number
	var summary := _selected()
	_stage = "slots" if bool(summary["occupied"]) else "class"
	if bool(summary["valid"]):
		selected_class = str(summary["class"])
	_update()


func select_class(cls: String) -> void:
	if _modal_open() or not EntryUi.HEROES.has(cls) or bool(_selected()["occupied"]):
		return
	selected_class = cls
	_stage = "class"
	_update()


func _update() -> void:
	var summary := _selected()
	var choosing := _stage == "class"
	if bool(summary["valid"]):
		selected_class = str(summary["class"])
	showcase.visible = true
	heading.text = "수호자 선택" if choosing else "모험 이어가기"
	subtitle.text = "자연을 지킬 당신의 힘을 선택하세요." if choosing else "계속할 모험을 선택하세요."
	slot_switch.text = "↔  저장 슬롯 변경"
	slot_switch.tooltip_text = "선택한 저장 슬롯: %d" % selected_slot
	var info: Dictionary = GameState.CLASSES.get(selected_class, GameState.CLASSES["mage"])
	hero_art.texture = SelectionUi.hero_image(selected_class)
	hero_name.text = str(info["name"])
	role.text = ROLES[selected_class]
	description.text = DESCRIPTIONS[selected_class]
	health.text = "체력  " + HudArt.stat(info["hp"])
	resource.text = str(info["resource"]) + "  " + HudArt.res(info["resource_max"])
	start_button.text = "%s로 모험 시작" % info["name"]
	start_button.disabled = bool(summary["occupied"])
	continue_button.disabled = bool(summary["occupied"]) and not bool(summary["valid"])
	continue_button.text = (
		"선택한 모험 이어가기"
		if bool(summary["valid"])
		else ("저장을 읽을 수 없습니다" if bool(summary["occupied"]) else "새 수호자 선택")
	)
	for key: String in class_buttons:
		SelectionUi.style(class_buttons[key], false, key == selected_class)
		_quiet_row_text(class_buttons[key])
		class_tab_labels[key].add_theme_color_override(
			"font_color", Color("f7e7c7") if key == selected_class else SelectionUi.IVORY
		)
	for index in GameState.MAX_SAVE_SLOTS:
		var entry: Dictionary = _summaries[index]
		var title := "새로운 모험"
		var meta := "새 수호자를 선택하세요"
		var status := "선택됨" if selected_slot == index + 1 else ""
		if bool(entry["valid"]):
			var name: String = GameState.CLASSES[str(entry["class"])]["name"]
			title = "%s · Lv.%d" % [name, int(entry["level"])]
			var location := "바람 동굴" if str(entry["location"]) == "cave" else "숲 마을"
			meta = (
				location
				+ " · "
				+ (
					"백업 복원"
					if bool(entry["backup"])
					else SaveTimeLabel.for_device(float(entry["timestamp"]))
				)
			)
			if bool(entry["backup"]) and status.is_empty():
				status = "백업"
		elif bool(entry["occupied"]):
			title = "읽을 수 없는 모험"
			meta = "삭제 후 새로운 모험을\n만들 수 있습니다"
			if status.is_empty():
				status = "확인 필요"
		slot_title_labels[index].text = title
		slot_meta_labels[index].text = meta
		slot_status_labels[index].text = status
		slot_buttons[index].text = "%02d    %s\n        %s" % [index + 1, title, meta]
		SelectionUi.slot_style(slot_bands[index], slot_buttons[index], selected_slot == index + 1)
		_quiet_row_text(slot_buttons[index])
		SelectionUi.style(delete_buttons[index])
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			delete_buttons[index].add_theme_stylebox_override(state, StyleBoxEmpty.new())
		_quiet_row_text(delete_buttons[index])
		slot_portraits[index].visible = bool(entry["valid"])
		slot_portrait_frames[index].visible = true
		slot_empty_marks[index].visible = not bool(entry["valid"])
		slot_portraits[index].texture = (
			SelectionUi.portrait(SelectionUi.hero_image(str(entry["class"])))
			if bool(entry["valid"])
			else null
		)
	_refresh_disabled()

	_layout()


func show_error(message: String) -> void:
	subtitle.text = message
	_layout.call_deferred()


func _choose() -> void:
	if not _modal_open() and _stage == "class" and not bool(_selected()["occupied"]):
		chosen.emit(selected_class)


func confirm_delete(number: int) -> void:
	if _modal_open() or _stage != "slots" or number < 1 or number > GameState.MAX_SAVE_SLOTS:
		return
	var summary: Dictionary = _summaries[number - 1]
	if not bool(summary["occupied"]) or is_instance_valid(_delete_dialog):
		return
	_delete_target = number
	_delete_dialog = PanelFrame.new()
	add_child(_delete_dialog)
	_delete_dialog.set_compact()
	_delete_dialog.set_header("저장 %d의 모험을 삭제할까요?" % number)
	var identity := "읽을 수 없는 모험"
	if bool(summary["valid"]):
		identity = (
			"%s · Lv.%d" % [GameState.CLASSES[str(summary["class"])]["name"], int(summary["level"])]
		)
	_delete_dialog.body.add_child(
		PanelFrame.wrap_label(identity + "\n삭제한 모험은 복구할 수 없습니다. 다른 슬롯의 모험은 유지됩니다.", 22)
	)
	_delete_dialog.add_footer("취소", _close_delete)
	_delete_dialog.add_footer(
		"이 모험 삭제",
		func():
			var deleted: bool = GameState.delete_slot(number)
			_close_delete(true)
			refresh_slots()
			_stage = "slots"
			_update()
			if not deleted:
				show_error("삭제하지 못했습니다. 다시 시도해 주세요."),
		true
	)
	_delete_dialog.closed.connect(_close_delete)
	_delete_dialog._panel.item_rect_changed.connect(_queue_publish_buttons)
	_delete_dialog.footer.item_rect_changed.connect(_queue_publish_buttons)
	_delete_dialog.item_rect_changed.connect(_queue_publish_buttons)
	_delete_dialog._column.item_rect_changed.connect(_queue_publish_buttons)
	_delete_dialog.body_holder.item_rect_changed.connect(_queue_publish_buttons)
	for target: Node in _delete_dialog.find_children("*", "Button", true, false):
		(target as Button).focus_entered.connect(_queue_publish_buttons)
		(target as Button).focus_exited.connect(_queue_publish_buttons)
	_refresh_disabled()
	_fit_delete_dialog()
	(_delete_dialog.footer.get_child(0) as Button).grab_focus.call_deferred()
	_queue_publish_buttons()


func _close_delete(use_row := false) -> void:
	if is_instance_valid(_delete_dialog):
		_delete_dialog.queue_free()
	_delete_dialog = null
	_refresh_disabled()
	_restore_delete_focus.call_deferred(_delete_target, use_row)
	_queue_publish_buttons()


func _setup_presentation() -> void:
	brand_label = _label("자연의 수호자", 22, SelectionUi.BRONZE, true)
	brand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("d4cbb5"))
	for label: Label in [brand_label, heading, subtitle]:
		label.add_theme_color_override("font_shadow_color", Color(0.02, 0.03, 0.025, 0.8))
		label.add_theme_constant_override("shadow_offset_x", 0)
	class_surface = Panel.new()
	class_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	class_surface.add_theme_stylebox_override(
		"panel", SelectionUi.skin(Color(0.04, 0.075, 0.066, 0.60), SelectionUi.BRONZE, 10)
	)
	add_child(class_surface)
	move_child(class_surface, 2)
	_hero_backdrop = SelectionUi.backdrop(showcase)
	showcase.move_child(_hero_backdrop, 0)
	showcase.clip_contents = true
	_hero_backdrop.hide()
	info_surface = Panel.new()
	info_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_surface.add_theme_stylebox_override("panel", SelectionUi.concept_skin("info"))
	details.add_child(info_surface)
	details.move_child(info_surface, 0)
	identity_icon = TextureRect.new()
	identity_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	identity_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	details.add_child(identity_icon)
	for index in 2:
		var chip := Panel.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_stylebox_override("panel", SelectionUi.concept_skin("stat"))
		details.add_child(chip)
		details.move_child(chip, 1)
		stat_boxes.append(chip)
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = SelectionUi.icon_texture("heart" if index == 0 else "resource")
		details.add_child(icon)
		stat_icons.append(icon)
	for index in GameState.MAX_SAVE_SLOTS:
		var frame := Panel.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_theme_stylebox_override(
			"panel", SelectionUi.skin(Color("1b2923"), Color("847755"), 6)
		)
		slot_buttons[index].add_child(frame)
		slot_buttons[index].move_child(frame, 0)
		slot_portrait_frames.append(frame)
		var art := TextureRect.new()
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.offset_left = 3
		art.offset_top = 3
		art.offset_right = -3
		art.offset_bottom = -3
		frame.clip_contents = true
		frame.add_child(art)
		slot_portraits.append(art)
		var empty_mark := _label("+", 42, SelectionUi.BRONZE, false, frame)
		empty_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot_empty_marks.append(empty_mark)
		var badge := Panel.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_stylebox_override(
			"panel", SelectionUi.skin(Color("101b18"), SelectionUi.BRONZE, 4)
		)
		slot_buttons[index].add_child(badge)
		slot_number_badges.append(badge)
		# Order locally inside the row; elevated canvas z would pierce modal dimmers.
		slot_number_labels[index].z_index = 0
		slot_buttons[index].move_child(
			slot_number_labels[index], slot_buttons[index].get_child_count() - 1
		)
		slot_number_labels[index].add_theme_color_override("font_color", SelectionUi.IVORY)
		slot_number_labels[index].add_theme_constant_override("outline_size", 0)
	slot_surface.add_theme_stylebox_override(
		"panel", SelectionUi.skin(Color(0.035, 0.065, 0.058, 0.54), Color("766b50"), 10)
	)
	var footer_skin := SelectionUi.skin(
		Color(0.025, 0.06, 0.05, 0.15), Color(0.55, 0.53, 0.37, 0.35), 0
	)
	footer_skin.set_border_width_all(0)
	footer_skin.border_width_top = 1
	slot_footer.add_theme_stylebox_override("panel", footer_skin)


func _measure(label: Label, width: float, minimum := 0.0, text_override := "") -> float:
	var paragraph := TextParagraph.new()
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	paragraph.width = maxf(width, 1.0)
	paragraph.add_string(label.text if text_override.is_empty() else text_override,
		label.get_theme_font("font"), label.get_theme_font_size("font_size"), label.language)
	# Label의 줄간격은 Font/TextParagraph 크기에 포함되지 않는다. 세 줄 이상에서
	# 실제 최소 높이가 예측을 넘으면 중앙 정렬도 어긋나므로 함께 계산한다.
	var gaps := maxi(0, paragraph.get_line_count() - 1)
	return maxf(minimum, paragraph.get_size().y + gaps * label.get_theme_constant("line_spacing") + 2.0)


func _layout_header(area: Rect2, left: float, width: float, portrait: bool, compact: bool) -> float:
	var u := _unit
	var css := _slot_css
	var outer := maxf(24.0 * u, 12.0 * css)
	var touch := maxf(68.0 * u, 44.0 * css)
	var gap := maxf(12.0 * u, 6.0 * css)
	var top := area.position.y + (maxf(outer, area.size.y * 0.03) if portrait else outer)
	brand_label.visible = not compact
	var narrow := portrait and area.size.x / css < 360.0
	_font(brand_label, 32 if portrait else 29, 15 if narrow else 16)
	_font(heading, 58 if portrait else 52, (27 if narrow else 30) if portrait else 23)
	_font(subtitle, 26 if portrait and not narrow else 23, 14)
	for label: Label in [brand_label, heading, subtitle]:
		var shadow_y := maxi(1, roundi(css))
		if label.get_theme_constant("shadow_offset_y") != shadow_y:
			label.add_theme_constant_override("shadow_offset_y", shadow_y)
	_font(back_button, 40, 28)
	back_button.text = "‹"
	back_button.tooltip_text = (
		"저장 슬롯 목록으로 돌아가기" if _stage == "class" and _class_back_to_slots else "처음 화면으로 돌아가기"
	)
	var back_minimum := back_button.get_combined_minimum_size()
	var back_side := maxf(touch, maxf(back_minimum.x, back_minimum.y))
	EntryUi.place(back_button, Rect2(area.position + Vector2.ONE * outer, Vector2.ONE * back_side))
	var gutter := back_side + gap if portrait else 0.0
	var header_w := maxf(1.0, width - gutter * 2.0)
	var brand_h := _measure(brand_label, header_w) if brand_label.visible else 0.0
	var title_y := top + brand_h + (maxf(gap, area.size.y * 0.016) if brand_label.visible else 0.0)
	var title_h := _measure(heading, header_w)
	var subtitle_y := title_y + title_h + maxf(gap * 0.6, area.size.y * 0.007)
	var subtitle_h := _measure(subtitle, width)
	for label: Label in [brand_label, heading, subtitle]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EntryUi.place(brand_label, Rect2(Vector2(left + gutter, top), Vector2(header_w, brand_h)))
	EntryUi.place(heading, Rect2(Vector2(left + gutter, title_y), Vector2(header_w, title_h)))
	EntryUi.place(subtitle, Rect2(Vector2(left, subtitle_y), Vector2(width, subtitle_h)))
	return subtitle_y + subtitle_h


func _layout_class() -> void:
	var margins := PanelFrame.safe_margins(get_viewport())
	var area := Rect2(
		Vector2(margins.x, margins.y), size - Vector2(margins.x + margins.z, margins.y + margins.w)
	)
	_class_safe = area
	var portrait := area.size.y > area.size.x
	_unit = (
		minf(area.size.x / 720.0, area.size.y / 1280.0)
		if portrait
		else minf(area.size.x / 1280.0, area.size.y / 720.0)
	)
	_slot_css = _css_scale()
	var u := _unit
	var css := _slot_css
	var outer := maxf(24.0 * u, 12.0 * css)
	var gap := maxf(14.0 * u, 6.0 * css)
	var touch := maxf(68.0 * u, 44.0 * css)
	var narrow := portrait and area.size.x / css < 360.0
	var roomy := portrait and not narrow
	var action_h := maxf((100.0 if roomy else 88.0) * u, (56.0 if roomy else 48.0) * css)
	_class_compact = not portrait and area.size.y / css < 460.0
	var right := area.position.x + outer if portrait else area.position.x + area.size.x * 0.53
	var width := area.size.x - outer * 2.0 if portrait else area.end.x - outer - right
	for entry in [
		[slot_switch, 23, 14],
		[start_button, 42 if roomy else 34, 22 if roomy else 18],
		[hero_name, 52 if roomy else 44, 27 if roomy else 24],
		[role, 28 if roomy else 24, 15 if roomy else 14],
		[description, 26 if roomy else 23, 14],
		[health, 26 if roomy else 24, 14],
		[resource, 26 if roomy else 24, 14]
	]:
		_font(entry[0], float(entry[1]), float(entry[2]))
	action_h = EntryUi.fit_action(start_button, action_h, css)
	for cls: String in class_buttons:
		var button: Button = class_buttons[cls]
		_font(button, 30, 17)
		_font(class_tab_labels[cls], 30, 17)
		var icon: TextureRect = class_tab_icons[cls]
		icon.custom_minimum_size = Vector2.ONE * maxf(32.0 * u, 18.0 * css)
		var group: HBoxContainer = _class_tab_groups[cls]
		group.add_theme_constant_override("separation", roundi(maxf(12.0 * u, 6.0 * css)))
		# 탭 원화 하단의 V를 제외한 몸체 중심에 아이콘·문구를 맞춘다.
		var center := group.get_parent() as CenterContainer
		center.offset_bottom = -6.0 * css
	continue_button.hide()
	start_button.show()
	slot_switch.show()
	details.show()
	class_surface.hide()
	showcase.show()
	_hero_backdrop.hide()
	hero_name.visible = not _class_compact or area.size.y / css >= 360.0
	role.show()
	description.show()
	var header_end := _layout_header(area, right, width, portrait, _class_compact)
	var tabs_y := header_end + maxf(gap, area.size.y * (0.018 if portrait else 0.012))
	for index in 2:
		var button: Button = class_buttons[["warrior", "mage"][index]]
		button.show()
		EntryUi.place(
			button,
			Rect2(
				Vector2(right + index * (width + gap) * 0.5, tabs_y),
				Vector2((width - gap) * 0.5, touch)
			)
		)
	var slots_y := area.end.y - outer - touch
	var start_y := slots_y - gap - action_h
	EntryUi.place(slot_switch, Rect2(Vector2(right, slots_y), Vector2(width, touch)))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		slot_switch.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	EntryUi.place(start_button, Rect2(Vector2(right, start_y), Vector2(width, action_h)))
	var pad := maxf((12.0 if _class_compact else 22.0) * u, (6.0 if _class_compact else 9.0) * css)
	var detail_gap := maxf(
		(8.0 if _class_compact else 10.0) * u, (3.0 if _class_compact else 4.0) * css
	)
	description.text = (
		("검과 함성으로 전열을 지킵니다." if selected_class == "warrior" else "세 원소로 전장을 지배합니다.")
		if _class_compact
		else DESCRIPTIONS[selected_class]
	)
	var inside := width - pad * 2.0
	var name_h := _measure(hero_name, inside) if hero_name.visible else 0.0
	var header_icon_size := maxf(74.0 * u, 40.0 * css) if hero_name.visible else 0.0
	var name_indent := header_icon_size + gap if hero_name.visible else 0.0
	var role_h := _measure(role, inside - name_indent)
	var desc_h := _measure(description, inside)
	var chip_h := maxf(
		(44.0 if _class_compact else 52.0) * u,
		(24.0 if _class_compact else (30.0 if roomy else 28.0)) * css
	)
	var info_h := pad * 2.0 + role_h + desc_h + chip_h + detail_gap * 2.0
	if hero_name.visible:
		info_h += name_h + detail_gap * 0.4
	var extra_info_space := maxf(0.0, area.size.y * 0.20 - info_h) if portrait else 0.0
	info_h += extra_info_space
	var info_y := start_y - gap * 1.8 - info_h
	var art_top := tabs_y + touch + gap * 0.4 if portrait else area.position.y + outer
	var art_left := right if portrait else area.position.x + outer
	var art_width := width if portrait else right - gap * 2.0 - art_left
	var art_bottom := info_y + info_h if portrait else area.end.y - outer
	EntryUi.place(
		showcase,
		Rect2(Vector2(art_left, art_top), Vector2(art_width, maxf(32.0, art_bottom - art_top)))
	)
	hero_art.texture = SelectionUi.hero_image(selected_class)
	# 원본 숲 여백을 위로 보내 시안처럼 머리는 탭 아래, 상체는 정보 패널 뒤에 둔다.
	var image_h := (
		showcase.size.x * hero_art.texture.get_height() / float(hero_art.texture.get_width())
	)
	EntryUi.place(hero_art, Rect2(Vector2(0, -image_h * 0.15), Vector2(showcase.size.x, image_h)))
	SelectionUi.blend_portrait(hero_art)
	EntryUi.place(details, Rect2(Vector2(right, info_y), Vector2(width, info_h)))
	EntryUi.place(info_surface, Rect2(Vector2.ZERO, details.size))
	var cursor := pad
	identity_icon.visible = hero_name.visible
	identity_icon.texture = SelectionUi.class_icon(selected_class)
	if hero_name.visible:
		var header_h := name_h + detail_gap * 0.4 + role_h
		EntryUi.place(
			identity_icon,
			Rect2(
				Vector2(pad, cursor + (header_h - header_icon_size) * 0.5),
				Vector2.ONE * header_icon_size
			)
		)
		EntryUi.place(
			hero_name,
			Rect2(Vector2(pad + name_indent, cursor), Vector2(inside - name_indent, name_h))
		)
		cursor += name_h + detail_gap * 0.4
	EntryUi.place(
		role, Rect2(Vector2(pad + name_indent, cursor), Vector2(inside - name_indent, role_h))
	)
	cursor += role_h + detail_gap + extra_info_space * 0.4
	EntryUi.place(description, Rect2(Vector2(pad, cursor), Vector2(inside, desc_h)))
	cursor += desc_h + detail_gap + extra_info_space * 0.6
	var chip_w := (inside - gap) * 0.5
	for index in 2:
		var chip_rect := Rect2(
			Vector2(pad + index * (chip_w + gap), cursor), Vector2(chip_w, chip_h)
		)
		EntryUi.place(stat_boxes[index], chip_rect)
		var label := health if index == 0 else resource
		var inset := maxf(8.0 * u, 5.0 * css)
		var icon_size := maxf(26.0 * u, (16.0 if roomy else 12.0) * css)
		EntryUi.place(
			stat_icons[index],
			Rect2(
				chip_rect.position + Vector2(inset, (chip_h - icon_size) * 0.5),
				Vector2.ONE * icon_size
			)
		)
		var text_left := inset + icon_size + inset
		EntryUi.place(
			label,
			Rect2(
				chip_rect.position + Vector2(text_left, inset * 0.5),
				Vector2(chip_w - text_left - inset, chip_h - inset)
			)
		)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EntryUi.place(class_surface, showcase.get_rect())
	_queue_publish_buttons()


func _publish_buttons() -> void:
	if start_button == null or not OS.has_feature("web"):
		return
	var targets := {
		"warrior": class_buttons["warrior"],
		"mage": class_buttons["mage"],
		"start": start_button,
		"continue": continue_button,
		"back": back_button,
		"slots": slot_switch
	}
	for index in GameState.MAX_SAVE_SLOTS:
		targets["slot%d" % (index + 1)] = slot_buttons[index]
		targets["delete%d" % (index + 1)] = delete_buttons[index]
	if is_instance_valid(_delete_dialog) and _delete_dialog.footer.get_child_count() == 2:
		targets["delete_cancel"] = _delete_dialog.footer.get_child(0)
		targets["delete_confirm"] = _delete_dialog.footer.get_child(1)
	var points := {
		"viewport": [size.x, size.y],
		"save_layout": _save_layout_probe(),
		"stage": _stage,
		"selected_slot": selected_slot,
		"selected_class": selected_class,
		"slots_state": _summaries,
		"slot_labels": slot_buttons.map(func(button: Button): return button.text)
	}
	var focus := get_viewport().gui_get_focus_owner()
	points["class_layout"] = _class_layout_probe()
	points["focus"] = ""
	points["rects"] = {}
	points["visible"] = {}
	points["fonts"] = {}
	points["save_layout"]["modal_focus"] = (
		_modal_open() and is_instance_valid(focus) and _delete_dialog.is_ancestor_of(focus)
	)
	for key: String in targets:
		var button: Button = targets[key]
		points["rects"][key] = _rect(button)
		points["visible"][key] = button.is_visible_in_tree()
		points["fonts"][key] = button.get_theme_font_size("font_size")
		if focus == button:
			points["focus"] = key
		var center := button.get_global_rect().get_center() / get_viewport_rect().size
		points[key] = [center.x, center.y]
	if bool(points["save_layout"]["modal_focus"]) and str(points["focus"]).is_empty():
		points["focus"] = "modal_close"
	var encoded := JSON.stringify(points)
	if encoded == _last_probe_json:
		return
	_last_probe_json = encoded
	_probe_writes += 1
	JavaScriptBridge.eval("window.__sjrpgClassButtons = " + encoded)


## Layout/focus/scroll signals publish only when the actual controls change.
func _queue_publish_buttons() -> void:
	if _probe_queued or not is_inside_tree():
		return
	_probe_queued = true
	_flush_buttons.call_deferred()


func _flush_buttons() -> void:
	# ScrollContainer moves its child after scrollbar.value_changed. Publish the
	# completed rendered geometry, never the preceding scrollbar-only state.
	if OS.has_feature("web") and DisplayServer.get_name() != "headless":
		RenderingServer.frame_post_draw.connect(_finish_buttons, CONNECT_ONE_SHOT)
	else:
		get_tree().process_frame.connect(_finish_buttons_after_frame, CONNECT_ONE_SHOT)


func _finish_buttons_after_frame() -> void:
	_finish_buttons.call_deferred()


func _finish_buttons() -> void:
	if not is_inside_tree():
		return
	_probe_queued = false
	_probe_flushes += 1
	_publish_buttons()


func probe_activity() -> Dictionary:
	return {
		"flushes": _probe_flushes,
		"writes": _probe_writes,
		"pending": _probe_queued,
		"idle_process": is_processing()
	}


func _modal_open() -> bool:
	return is_instance_valid(_delete_dialog) and not _delete_dialog.is_queued_for_deletion()


func _request_back() -> void:
	if _modal_open():
		return
	elif _stage == "class" and _class_back_to_slots:
		show_slots()
	else:
		back_requested.emit()


func _request_continue() -> void:
	if _modal_open() or _stage != "slots":
		return
	if bool(_selected()["valid"]):
		continue_requested.emit()
	elif not bool(_selected()["occupied"]):
		_class_back_to_slots = true
		_stage = "class"
		_update()


func _refresh_disabled() -> void:
	var blocked := _modal_open()
	for button: Button in (
		[start_button, continue_button, back_button, slot_switch]
		+ slot_buttons
		+ delete_buttons
		+ class_buttons.values()
	):
		button.disabled = blocked
	start_button.disabled = blocked or bool(_selected()["occupied"])
	continue_button.disabled = (
		blocked or (bool(_selected()["occupied"]) and not bool(_selected()["valid"]))
	)
	for index in GameState.MAX_SAVE_SLOTS:
		delete_buttons[index].disabled = blocked or not bool(_summaries[index]["occupied"])


func _css_scale() -> float:
	return UiMetrics.units_per_display_pixel(get_viewport())


func _font(control: Control, base: float, css_minimum: float) -> void:
	var pixels := maxi(1, ceili(maxf(base * _unit, css_minimum * _slot_css)))
	if control.get_theme_font_size("font_size") != pixels:
		control.add_theme_font_size_override("font_size", pixels)


func _quiet_row_text(button: Button) -> void:
	# Keep the canonical text for accessibility and existing save/time probes.
	# Visible title/metadata are separate labels with their own measured boxes.
	for key in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_focus_color",
		"font_disabled_color"
	]:
		button.add_theme_color_override(key, Color(1, 1, 1, 0))


func _queue_slot_layout() -> void:
	if _slot_relayout_pending or _stage != "slots" or slot_context == null:
		return
	_slot_relayout_pending = true
	_settle_slot_layout.call_deferred()


func _settle_slot_layout() -> void:
	_slot_relayout_pending = false
	if _stage == "slots":
		_layout()


func _layout() -> void:
	if start_button == null:
		return
	if _stage == "slots":
		_layout_slots()
	else:
		slot_surface.hide()
		slot_scroll.hide()
		slot_footer.hide()
		slot_context.hide()
		back_button.text = "‹"
		_layout_class()
	for chrome: Control in [brand_label, heading, subtitle, back_button]:
		move_child(chrome, get_child_count() - 1)
	if _modal_open():
		move_child(_delete_dialog, get_child_count() - 1)
		_fit_delete_dialog()


func _layout_slots() -> void:
	var margins := PanelFrame.safe_margins(get_viewport())
	var area := Rect2(
		Vector2(margins.x, margins.y), size - Vector2(margins.x + margins.z, margins.y + margins.w)
	)
	_slot_safe = area
	var portrait := area.size.y > area.size.x
	_unit = (
		minf(area.size.x / 720.0, area.size.y / 1280.0)
		if portrait
		else minf(area.size.x / 1280.0, area.size.y / 720.0)
	)
	_slot_css = _css_scale()
	var u := _unit
	var css := _slot_css
	var compact := not portrait and area.size.y / css < 460.0
	var outer := maxf(24.0 * u, 12.0 * css)
	var gap := maxf(maxf(14.0 * u, 6.0 * css), area.size.y * 0.018 if portrait else 0.0)
	_slot_pad = maxf(16.0 * u, 8.0 * css)
	_slot_gap = gap
	_slot_badge = maxf(84.0 * u, 44.0 * css)
	_slot_touch = maxf(72.0 * u, 44.0 * css)
	var left := area.position.x + outer if portrait else area.position.x + area.size.x * 0.48
	var width := area.end.x - outer - left
	var summary := _selected()
	slot_surface.hide()
	slot_scroll.show()
	slot_footer.show()
	slot_context.show()
	class_surface.hide()
	details.hide()
	slot_switch.hide()
	start_button.hide()
	continue_button.show()
	showcase.show()
	_hero_backdrop.hide()
	hero_art.texture = SelectionUi.hero_image(selected_class)
	_font(continue_button, EntryUi.ACTION_FONT_SIZE, EntryUi.ACTION_FONT_DP)
	_font(slot_context, 23, 14)
	slot_context.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var identity := (
		"%s Lv.%d" % [GameState.CLASSES[str(summary["class"])]["name"], int(summary["level"])]
		if bool(summary["valid"])
		else ("확인이 필요한 저장" if bool(summary["occupied"]) else "새로운 모험")
	)
	var plain_context := "선택한 모험  |  %02d. %s" % [selected_slot, identity]
	slot_context.text = plain_context + ("\n↕ 밀어서 더 보기" if _slot_overflow else "")
	var plain_context_h := _measure(slot_context, width, 0.0, plain_context)
	var header_end := _layout_header(area, left, width, portrait, compact)
	var context_h := _measure(slot_context, width)
	var action_h := EntryUi.fit_action(continue_button, EntryUi.action_height(u, css), css)
	var footer_h := context_h + gap * 2.0 + action_h
	var bottom_gap := maxf(outer, area.size.y * 0.055) if portrait else outer
	var footer_y := area.end.y - bottom_gap - footer_h
	var list_y := (
		maxf(header_end + gap, area.position.y + area.size.y * 0.402)
		if portrait
		else header_end + gap
	)
	# 짧은 폰은 그림을 줄여도 목록 한 행과 고정 주 버튼의 터치 영역을 먼저 확보한다.
	var row_minimum := maxf(_slot_badge + _slot_pad * 2.0, area.size.y * 0.086 if portrait else 0.0)
	list_y = minf(list_y, footer_y - gap * 2.0 - row_minimum)
	list_y = maxf(list_y, header_end + gap)
	var preview_gap := maxf(4.0 * u, 2.0 * css)
	if portrait:
		EntryUi.place(
			showcase,
			Rect2(
				Vector2(left, header_end + preview_gap),
				Vector2(width, maxf(1.0, list_y - header_end - preview_gap))
			)
		)
		var image_h := (
			showcase.size.x * hero_art.texture.get_height() / float(hero_art.texture.get_width())
		)
		EntryUi.place(
			hero_art, Rect2(Vector2(0, -image_h * 0.15), Vector2(showcase.size.x, image_h))
		)
		SelectionUi.blend_portrait(hero_art, 0.15 + showcase.size.y / image_h)
	else:
		var art_left := area.position.x + outer
		EntryUi.place(
			showcase,
			Rect2(
				Vector2(art_left, area.position.y + outer),
				Vector2(left - gap * 2.0 - art_left, area.size.y - outer * 2.0)
			)
		)
		var image_h := (
			showcase.size.x * hero_art.texture.get_height() / float(hero_art.texture.get_width())
		)
		EntryUi.place(
			hero_art, Rect2(Vector2(0, -image_h * 0.15), Vector2(showcase.size.x, image_h))
		)
	if not portrait:
		SelectionUi.blend_portrait(hero_art)
	EntryUi.place(
		slot_surface,
		Rect2(area.position + Vector2.ONE * outer, area.size - Vector2.ONE * outer * 2.0)
	)
	EntryUi.place(
		slot_scroll,
		Rect2(Vector2(left, list_y), Vector2(width, maxf(row_minimum, footer_y - gap - list_y)))
	)
	EntryUi.place(slot_footer, Rect2(Vector2(left, footer_y), Vector2(width, footer_h)))
	EntryUi.place(
		slot_context, Rect2(Vector2(left, footer_y + gap * 0.5), Vector2(width, context_h))
	)
	EntryUi.place(
		continue_button,
		Rect2(Vector2(left, footer_y + context_h + gap * 2.0), Vector2(width, action_h))
	)
	slot_list.add_theme_constant_override("separation", roundi(gap))
	var natural_content_h := float(roundi(gap) * (slot_bands.size() - 1))
	var natural_heights: Array[float] = []
	for button: Button in class_buttons.values():
		button.hide()
	for index in GameState.MAX_SAVE_SLOTS:
		var row := slot_buttons[index]
		var remove := delete_buttons[index]
		row.show()
		remove.visible = bool(_summaries[index]["occupied"])
		for entry in [
			[row, 28, 14],
			[remove, 20, 12],
			[slot_number_labels[index], 34, 18],
			[slot_title_labels[index], 28, 14],
			[slot_meta_labels[index], 22, 14],
			[slot_status_labels[index], 18, 10],
			[slot_empty_marks[index], 44, 26]
		]:
			_font(entry[0], float(entry[1]), float(entry[2]))
		remove.custom_minimum_size = Vector2(_slot_touch, _slot_touch)
		slot_bands[index].add_theme_constant_override("separation", 0)
		var scrollbar := slot_scroll.get_v_scroll_bar()
		var viewport_skin := slot_scroll.get_theme_stylebox("panel")
		var gutter := viewport_skin.get_content_margin(SIDE_LEFT) + viewport_skin.get_content_margin(SIDE_RIGHT)
		if scrollbar.visible:
			gutter += maxf(scrollbar.get_combined_minimum_size().x, scrollbar.size.x)
		# Scroll/BoxContainer는 실제 자식 폭을 정수 픽셀로 배치한다. 소수 폭으로
		# 미리 줄바꿈하면 정렬 뒤 폭과 번갈아 바뀌며 행 높이·포커스가 흔들린다.
		var content_width := ceilf(maxf(1.0, width - gutter))
		row.size.x = maxf(1.0, content_width - (ceilf(_slot_touch) if remove.visible else 0.0))
		var text_metrics := _slot_text_metrics(index)
		var row_h := ceilf(maxf(row_minimum, _slot_pad * 2.0 + text_metrics["height"]))
		natural_heights.append(row_h)
		natural_content_h += row_h
	# 모든 행이 모두 들어가는 화면은 카드 높이를 나누어 고정 행동까지 자연스럽게 연결한다.
	# 자연 최소 높이는 텍스트 측정값뿐이며, 중앙 배치한 자식 위치를 다시 읽지 않는다.
	var plain_footer_h := plain_context_h + gap * 2.0 + action_h
	var plain_list_h := area.end.y - bottom_gap - plain_footer_h - gap - list_y
	var overflowing := natural_content_h > plain_list_h + 1.0
	var expansion := 0.0 if overflowing else floorf(maxf(0.0, plain_list_h - natural_content_h) / float(GameState.MAX_SAVE_SLOTS))
	var content_h := float(roundi(gap) * (slot_bands.size() - 1))
	for index in GameState.MAX_SAVE_SLOTS:
		var row := slot_buttons[index]
		var row_h := natural_heights[index] + expansion
		row.custom_minimum_size = Vector2(0, row_h)
		slot_bands[index].custom_minimum_size.y = row_h
		row.update_minimum_size()
		slot_bands[index].update_minimum_size()
		content_h += slot_bands[index].get_combined_minimum_size().y
		_place_slot_labels(index)
		slot_bands[index].queue_sort()
		slot_bands[index].queue_redraw()
	# 회전 직후에는 위·아래 컨테이너의 최소 크기 신호가 서로 다른 프레임에 온다.
	# 실제 행 최소 높이를 같은 레이아웃에서 확정해 이전 화면의 스크롤 범위를 버린다.
	slot_list.custom_minimum_size.y = content_h
	slot_list.update_minimum_size()
	slot_list.size.y = content_h
	slot_list.queue_sort()
	slot_scroll.queue_sort()
	# 힌트가 차지한 높이를 제외하고 판정해야 회전 뒤에도 불필요한 안내가 남지 않는다.
	if _slot_overflow != overflowing:
		_slot_overflow = overflowing
		_queue_slot_layout()
	# 줄바꿈으로 위쪽 행 높이가 달라지면 focus_entered 때의 위치가 오래될 수 있다.
	# 컨테이너 정렬 뒤에 현재 포커스를 다시 드러낸다. 스크롤 값 변경은 재배치를 요청하지 않는다.
	_queue_slot_reveal()
	_queue_publish_buttons()


func _queue_slot_reveal() -> void:
	if _slot_reveal_pending or not is_inside_tree() or not Gamepad.using_gamepad:
		return
	_slot_reveal_pending = true
	get_tree().process_frame.connect(_after_slot_focus_frame, CONNECT_ONE_SHOT)


func _after_slot_focus_frame() -> void:
	_reveal_focused_slot.call_deferred()


func _reveal_focused_slot() -> void:
	_slot_reveal_pending = false
	if not is_inside_tree() or is_queued_for_deletion() or _stage != "slots" or _slot_dragging or not Gamepad.using_gamepad:
		return
	var focused := get_viewport().gui_get_focus_owner() as Button
	if focused != null and (slot_buttons.has(focused) or delete_buttons.has(focused)):
		slot_scroll.ensure_control_visible(focused)


func _place_slot_labels(index: int) -> void:
	if (
		index < 0
		or index >= slot_buttons.size()
		or index >= slot_status_labels.size()
		or index >= slot_portrait_frames.size()
	):
		return
	var row := slot_buttons[index]
	var pad := _slot_pad
	var gap := _slot_gap
	var number := slot_number_labels[index]
	var title := slot_title_labels[index]
	var meta := slot_meta_labels[index]
	var status := slot_status_labels[index]
	var number_w := maxf(42.0 * _unit, 25.0 * _slot_css)
	var text_metrics := _slot_text_metrics(index)
	var left: float = text_metrics["left"]
	var text_w: float = text_metrics["width"]
	var title_h: float = text_metrics["title_height"]
	var has_save := bool(_summaries[index]["valid"])
	var occupied := bool(_summaries[index]["occupied"])
	slot_portrait_frames[index].show()
	slot_portraits[index].visible = has_save
	slot_empty_marks[index].visible = not has_save
	slot_number_badges[index].hide()
	status.hide()
	var portrait_y := maxf(pad, (row.size.y - _slot_badge) * 0.5)
	EntryUi.place(
		slot_portrait_frames[index], Rect2(Vector2(pad, portrait_y), Vector2.ONE * _slot_badge)
	)
	EntryUi.place(
		number, Rect2(Vector2(pad + _slot_badge + gap, portrait_y), Vector2(number_w, _slot_badge))
	)
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var title_y := maxf(pad, (row.size.y - text_metrics["height"]) * 0.5)
	EntryUi.place(title, Rect2(Vector2(left, title_y), Vector2(text_w, title_h)))
	var meta_h: float = text_metrics["meta_height"]
	EntryUi.place(
		meta,
		Rect2(
			Vector2(left, title_y + title_h + maxf(6.0 * _unit, 3.0 * _slot_css)),
			Vector2(text_w, meta_h)
		)
	)
	meta.visible = occupied


func _slot_text_metrics(index: int) -> Dictionary:
	var title := slot_title_labels[index]
	var number_w := maxf(42.0 * _unit, 25.0 * _slot_css)
	var left := _slot_pad + _slot_badge + _slot_gap + number_w + _slot_gap
	var width := maxf(1.0, slot_buttons[index].size.x - left - _slot_pad)
	var title_h := title.get_theme_font("font").get_height(title.get_theme_font_size("font_size")) + 2.0
	var meta_h := _measure(slot_meta_labels[index], width, 20.0 * _unit)
	var text_h := title_h
	if bool(_summaries[index]["occupied"]):
		text_h += maxf(6.0 * _unit, 3.0 * _slot_css) + meta_h
	return {
		"left": left, "width": width, "title_height": title_h,
		"meta_height": meta_h, "height": text_h
	}


func _draw_delete_icon(icon: Control) -> void:
	var scale := minf(icon.size.x, icon.size.y) * 0.40
	var center := icon.size * 0.5
	var stroke := maxf(1.1, scale * 0.055)
	var color := SelectionUi.MUTED
	icon.draw_line(
		center + Vector2(-0.32, -0.26) * scale,
		center + Vector2(-0.25, 0.40) * scale,
		color,
		stroke,
		true
	)
	icon.draw_line(
		center + Vector2(-0.25, 0.40) * scale,
		center + Vector2(0.25, 0.40) * scale,
		color,
		stroke,
		true
	)
	icon.draw_line(
		center + Vector2(0.25, 0.40) * scale,
		center + Vector2(0.32, -0.26) * scale,
		color,
		stroke,
		true
	)
	icon.draw_line(
		center + Vector2(-0.40, -0.35) * scale,
		center + Vector2(0.40, -0.35) * scale,
		color,
		stroke,
		true
	)
	icon.draw_line(
		center + Vector2(-0.12, -0.48) * scale,
		center + Vector2(0.12, -0.48) * scale,
		color,
		stroke,
		true
	)
	for x in [-0.11, 0.11]:
		icon.draw_line(
			center + Vector2(x, -0.12) * scale,
			center + Vector2(x, 0.25) * scale,
			color,
			stroke,
			true
		)


func _fit_delete_dialog() -> void:
	if not _modal_open():
		return
	var pad := maxf(12.0 * _unit, 8.0 * _slot_css)
	var surface := UiKit.panel_style(Color("1c1b18"), Color("8c7653"), 8)
	surface.content_margin_left = pad
	surface.content_margin_right = pad
	surface.content_margin_top = pad
	surface.content_margin_bottom = pad
	_delete_dialog._panel.add_theme_stylebox_override("panel", surface)
	_delete_dialog._column.add_theme_constant_override(
		"separation", maxi(8, roundi(6.0 * _slot_css))
	)
	_font(_delete_dialog.title_label, 30, 20)
	for label: Node in _delete_dialog.body.find_children("*", "Label", true, false):
		_font(label as Label, 22, 14)
	var buttons := _delete_dialog.find_children("*", "Button", true, false)
	for index in buttons.size():
		var button := buttons[index] as Button
		_font(button, 24, 14)
		button.custom_minimum_size.y = _slot_touch
		if button.text == "×":
			button.custom_minimum_size.x = _slot_touch
		button.focus_next = button.get_path_to(buttons[(index + 1) % buttons.size()])
		button.focus_previous = button.get_path_to(
			buttons[(index - 1 + buttons.size()) % buttons.size()]
		)
	_delete_dialog._layout.call_deferred()


func _restore_delete_focus(number: int, use_row: bool) -> void:
	if number < 1 or number > slot_buttons.size() or _stage != "slots":
		return
	var button: Button = slot_buttons[number - 1]
	if (
		not use_row
		and delete_buttons[number - 1].is_visible_in_tree()
		and not delete_buttons[number - 1].disabled
	):
		button = delete_buttons[number - 1]
	button.grab_focus()
	slot_scroll.ensure_control_visible(slot_buttons[number - 1])


static func _rect(control: Control) -> Array:
	var r := control.get_global_rect()
	return [r.position.x, r.position.y, r.size.x, r.size.y]


func _save_layout_probe() -> Dictionary:
	if slot_scroll == null:
		return {}
	var cards := []
	for index in GameState.MAX_SAVE_SLOTS:
		cards.append(
			{
				"slot": index + 1,
				"row": _rect(slot_bands[index]),
				"select": _rect(slot_buttons[index]),
				"delete": _rect(delete_buttons[index]),
				"delete_visible": delete_buttons[index].is_visible_in_tree(),
				"title": _rect(slot_title_labels[index]),
				"meta": _rect(slot_meta_labels[index]),
				"number": _rect(slot_number_labels[index]),
				"status": _rect(slot_status_labels[index]),
				"title_text": slot_title_labels[index].text,
				"meta_text": slot_meta_labels[index].text,
				"meta_visible": slot_meta_labels[index].is_visible_in_tree(),
				"status_visible": slot_status_labels[index].is_visible_in_tree(),
				"status_text": slot_status_labels[index].text,
				"title_font": slot_title_labels[index].get_theme_font_size("font_size"),
				"meta_font": slot_meta_labels[index].get_theme_font_size("font_size")
			}
		)
	var bar := slot_scroll.get_v_scroll_bar()
	var result := {
		"safe":
		[_slot_safe.position.x, _slot_safe.position.y, _slot_safe.size.x, _slot_safe.size.y],
		"sheet": _rect(slot_surface),
		"list": _rect(slot_scroll),
		"footer": _rect(slot_footer),
		"context": _rect(slot_context),
		"context_text": slot_context.text,
		"overflow": _slot_overflow,
		"scroll_value": slot_scroll.scroll_vertical,
		"scroll_max": maxi(0, ceili(bar.max_value - bar.page)),
		"css_scale": _slot_css,
		"modal_open": _modal_open(),
		"cards": cards,
		"art": _rect(showcase),
		"art_visible": showcase.is_visible_in_tree(),
		"heading": _rect(heading),
		"subtitle": _rect(subtitle)
	}
	if _modal_open():
		result["dialog"] = {
			"panel": _rect(_delete_dialog._panel),
			"body": _rect(_delete_dialog.body_holder),
			"footer": _rect(_delete_dialog.footer)
		}
	return result


func gamepad_back() -> bool:
	if _modal_open():
		_close_delete()
	else:
		_request_back()
	return true


func gamepad_initial_focus() -> BaseButton:
	return class_buttons[selected_class] if _stage == "class" else slot_buttons[selected_slot - 1]


func _class_layout_probe() -> Dictionary:
	if brand_label == null:
		return {}
	var stats := []
	for index in 2:
		var label := health if index == 0 else resource
		stats.append(
			{
				"rect": _rect(stat_boxes[index]),
				"text_rect": _rect(label),
				"font_size": label.get_theme_font_size("font_size"),
				"text": label.text
			}
		)
	var fonts := {}
	var visible := {}
	var labels := {}
	var texts := {}
	for entry in [
		["brand", brand_label],
		["heading", heading],
		["subtitle", subtitle],
		["name", hero_name],
		["role", role],
		["description", description]
	]:
		var label: Label = entry[1]
		fonts[entry[0]] = label.get_theme_font_size("font_size")
		visible[entry[0]] = label.is_visible_in_tree()
		labels[entry[0]] = _rect(label)
		texts[entry[0]] = label.text
	var tab_contents := {}
	for cls: String in class_buttons:
		tab_contents[cls] = {
			"icon": _rect(class_tab_icons[cls]),
			"label": _rect(class_tab_labels[cls]),
			"text": class_tab_labels[cls].text
		}
	return {
		"safe":
		[_class_safe.position.x, _class_safe.position.y, _class_safe.size.x, _class_safe.size.y],
		"sheet": _rect(class_surface),
		"brand": _rect(brand_label),
		"heading": _rect(heading),
		"subtitle": _rect(subtitle),
		"back": _rect(back_button),
		"tabs": {"warrior": _rect(class_buttons["warrior"]), "mage": _rect(class_buttons["mage"])},
		"tab_contents": tab_contents,
		"art": _rect(showcase),
		"details": _rect(details),
		"stats": stats,
		"weapon": [],
		"start": _rect(start_button),
		"slotchange": _rect(slot_switch),
		"fonts": fonts,
		"visible": visible,
		"labels": labels,
		"texts": texts,
		"class": selected_class,
		"compact": _class_compact,
		"portrait": size.y > size.x,
		"css_scale": _slot_css
	}

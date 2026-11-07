extends Control
## Four independent adventures; previews never load, replace or save a hero.
signal chosen(cls: String)
signal continue_requested
signal back_requested
const ROLES := {"warrior": "검과 함성 · 근접 전투", "mage": "화염과 냉기 · 원거리 주문"}
const DESCRIPTIONS := {"warrior": "적진을 가르는 검과 흔들리지 않는 생존력.", "mage": "세 가지 원소로 전장을 지배하는 주문술사."}
var selected_class := "mage"
var selected_slot := 1
var class_buttons: Dictionary = {}
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

func _ready() -> void:
	add_to_group("gamepad_entry")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SelectionUi.backdrop(self)
	EntryUi.shade(self, 0.82)
	back_button = _button("‹  돌아가기", _request_back)
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
	role = _label("", 23, EntryUi.BRONZE, false, details)
	description = _label("", 24, EntryUi.TEXT, false, details)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	health = _label("", 22, EntryUi.MUTED, false, details)
	resource = _label("", 22, EntryUi.MUTED, false, details)
	for cls: String in ["warrior", "mage"]:
		class_buttons[cls] = _button(GameState.CLASSES[cls]["name"], func(): select_class(cls))
	slot_surface = Panel.new()
	slot_surface.name = "SaveSheet"
	slot_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_surface.add_theme_stylebox_override("panel", UiKit.panel_style(Color("171e1c"), Color("756348"), 8))
	add_child(slot_surface)
	move_child(slot_surface, 2)
	slot_scroll = ScrollContainer.new()
	slot_scroll.name = "SaveListScroll"
	slot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	slot_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	slot_scroll.follow_focus = true
	slot_scroll.clip_contents = true
	slot_scroll.scroll_deadzone = 10
	add_child(slot_scroll)
	slot_list = VBoxContainer.new()
	slot_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_scroll.add_child(slot_list)
	slot_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float): _queue_publish_buttons())
	slot_footer = Panel.new()
	slot_footer.name = "SaveFooter"
	slot_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var footer_skin := StyleBoxFlat.new()
	footer_skin.bg_color = Color(0.06, 0.08, 0.07, 0.98)
	footer_skin.border_color = Color("514a3b")
	footer_skin.border_width_top = 1
	slot_footer.add_theme_stylebox_override("panel", footer_skin)
	add_child(slot_footer)
	slot_context = _label("", 22, EntryUi.MUTED)
	slot_context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot_context.minimum_size_changed.connect(_queue_slot_layout)
	for index in 4:
		var number := index + 1
		var band := HBoxContainer.new()
		band.name = "SaveBand%d" % number
		band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_list.add_child(band)
		slot_bands.append(band)
		var row := _button("", func(): select_slot(number))
		row.name = "SaveSlot%d" % number
		row.clip_text = true
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.reparent(band, false)
		slot_buttons.append(row)
		row.focus_entered.connect(func(): slot_scroll.ensure_control_visible(row))
		row.resized.connect(func(): _place_slot_labels(number - 1))
		slot_number_labels.append(_label("%02d" % number, 28, EntryUi.BRONZE, true, row))
		slot_title_labels.append(_label("", 26, EntryUi.TEXT, true, row))
		slot_title_labels.back().clip_text = true
		slot_title_labels.back().text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		slot_number_labels.back().horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var meta := _label("", 22, EntryUi.MUTED, false, row)
		meta.clip_text = true
		meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		meta.minimum_size_changed.connect(_queue_slot_layout)
		slot_meta_labels.append(meta)
		slot_status_labels.append(_label("", 20, EntryUi.BRONZE, false, row))
		var remove := _button("삭제", func(): confirm_delete(number))
		remove.name = "DeleteSlot%d" % number
		remove.reparent(band, false)
		remove.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		delete_buttons.append(remove)

	start_button = _button("", _choose, true)
	continue_button = _button("이어 하기", _request_continue, true)
	refresh_slots()
	var occupied := false
	for summary: Dictionary in _summaries:
		occupied = occupied or bool(summary["occupied"])
	if not occupied:
		_stage = "class"
	else:
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
	button.item_rect_changed.connect(_queue_publish_buttons)
	SelectionUi.style(button, primary)
	add_child(button)
	return button

func _label(text: String, pixels: int, color: Color, bold := false, parent: Node = null) -> Label:
	var label := EntryUi.label(text, pixels, color, bold)
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
	if _modal_open() or number < 1 or number > 4:
		return
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
	showcase.visible = choosing or bool(summary["valid"])
	heading.text = "수호자 선택" if choosing else "모험 이어가기"
	subtitle.text = "당신의 전투 방식을 선택하세요" if choosing else "이어 갈 모험을 선택하세요"
	slot_switch.text = "저장 %d · 다른 슬롯 선택" % selected_slot
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
	continue_button.text = "이 모험 이어 하기" if bool(summary["valid"]) else ("저장을 읽을 수 없습니다" if bool(summary["occupied"]) else "새 수호자 선택")
	for key: String in class_buttons:
		SelectionUi.style(class_buttons[key], false, key == selected_class)
	for index in 4:
		var entry: Dictionary = _summaries[index]
		var title := "새로운 모험"
		var meta := "전사 또는 마법사로\n새로운 여정을 시작하세요"
		var status := "선택됨" if selected_slot == index + 1 else ""
		if bool(entry["valid"]):
			var name: String = GameState.CLASSES[str(entry["class"])]["name"]
			title = "%s · Lv.%d" % [name, int(entry["level"])]
			var location := "바람 동굴" if str(entry["location"]) == "cave" else "숲 마을"
			meta = location + "\n" + ("백업 복원" if bool(entry["backup"]) else SaveTimeLabel.for_device(float(entry["timestamp"])))
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
		SelectionUi.style(slot_buttons[index], false, selected_slot == index + 1)
		_quiet_row_text(slot_buttons[index])
		SelectionUi.style(delete_buttons[index])
		slot_portraits[index].visible = bool(entry["valid"])
		slot_portraits[index].texture = SelectionUi.portrait(SelectionUi.hero_image(str(entry["class"]))) if bool(entry["valid"]) else null
	_refresh_disabled()

	_layout()

func show_error(message: String) -> void:
	subtitle.text = message
	_layout.call_deferred()

func _choose() -> void:
	if not _modal_open() and _stage == "class" and not bool(_selected()["occupied"]):
		chosen.emit(selected_class)

func confirm_delete(number: int) -> void:
	if _modal_open() or _stage != "slots" or number < 1 or number > 4:
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
		identity = "%s · Lv.%d" % [GameState.CLASSES[str(summary["class"])]["name"], int(summary["level"])]
	_delete_dialog.body.add_child(PanelFrame.wrap_label(identity + "\n삭제한 모험은 복구할 수 없습니다. 다른 슬롯의 모험은 유지됩니다.", 22))
	_delete_dialog.add_footer("취소", _close_delete)
	_delete_dialog.add_footer("이 모험 삭제", func():
		var deleted: bool = GameState.delete_slot(number)
		_close_delete(true)
		refresh_slots()
		_stage = "slots"
		_update()
		if not deleted:
			show_error("삭제하지 못했습니다. 다시 시도해 주세요."), true)
	_delete_dialog.closed.connect(_close_delete)
	_delete_dialog._panel.item_rect_changed.connect(_queue_publish_buttons)
	_delete_dialog.footer.item_rect_changed.connect(_queue_publish_buttons)
	_delete_dialog.item_rect_changed.connect(_queue_publish_buttons)
	_delete_dialog._column.item_rect_changed.connect(_queue_publish_buttons)
	_delete_dialog.body_holder.item_rect_changed.connect(_queue_publish_buttons)
	for target: Node in _delete_dialog.find_children("*", "Button", true, false):
		(target as Button).focus_entered.connect(_queue_publish_buttons)
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
	class_surface = Panel.new()
	class_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	class_surface.add_theme_stylebox_override("panel", SelectionUi.skin(Color(0.04, 0.075, 0.066, 0.60), SelectionUi.BRONZE, 10))
	add_child(class_surface)
	move_child(class_surface, 2)
	_hero_backdrop = SelectionUi.backdrop(showcase)
	showcase.move_child(_hero_backdrop, 0)
	showcase.clip_contents = true
	info_surface = Panel.new()
	info_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_surface.add_theme_stylebox_override("panel", SelectionUi.skin(Color(0.035, 0.065, 0.058, 0.95), Color("6c745c"), 8))
	details.add_child(info_surface)
	details.move_child(info_surface, 0)
	for index in 2:
		var chip := Panel.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_stylebox_override("panel", SelectionUi.skin(Color(0.04, 0.06, 0.05, 0.9), Color("706b4e"), 6))
		details.add_child(chip)
		details.move_child(chip, 1)
		stat_boxes.append(chip)
	for index in 4:
		var frame := Panel.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_theme_stylebox_override("panel", SelectionUi.skin(Color("1b2923"), Color("847755"), 6))
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
		var badge := Panel.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_stylebox_override("panel", SelectionUi.skin(Color("101b18"), SelectionUi.BRONZE, 4))
		slot_buttons[index].add_child(badge)
		slot_number_badges.append(badge)
		# Order locally inside the row; elevated canvas z would pierce modal dimmers.
		slot_number_labels[index].z_index = 0
		slot_buttons[index].move_child(slot_number_labels[index], slot_buttons[index].get_child_count() - 1)
		slot_number_labels[index].add_theme_color_override("font_color", SelectionUi.IVORY)
		slot_number_labels[index].add_theme_constant_override("outline_size", 0)
	slot_surface.add_theme_stylebox_override("panel", SelectionUi.skin(Color(0.035, 0.065, 0.058, 0.54), Color("766b50"), 10))
	slot_footer.add_theme_stylebox_override("panel", SelectionUi.skin(Color(0.035, 0.06, 0.052, 0.86), Color(0.4, 0.43, 0.34, 0.6), 7))


func _measure(label: Label, width: float, minimum := 0.0) -> float:
	var font := label.get_theme_font("font")
	var flags := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	return maxf(minimum, font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT,
		maxf(width, 1.0), label.get_theme_font_size("font_size"), -1, flags).y + 2.0)


func _layout_class() -> void:
	# Set the compact glyph before Control.size can be clamped by its text minimum.
	back_button.text = "‹"
	var margins := PanelFrame.safe_margins(get_viewport())
	var area := Rect2(Vector2(margins.x, margins.y), size - Vector2(margins.x + margins.z, margins.y + margins.w))
	_class_safe = area
	var portrait := area.size.y > area.size.x
	_unit = minf(area.size.x / 720.0, area.size.y / 1280.0) if portrait else minf(area.size.x / 1280.0, area.size.y / 720.0)
	_slot_css = _css_scale()
	var u := _unit
	var outer := maxf(24.0 * u, 12.0 * _slot_css)
	var gap := maxf(12.0 * u, 6.0 * _slot_css)
	var touch := maxf(68.0 * u, 44.0 * _slot_css)
	var action_h := maxf(88.0 * u, 48.0 * _slot_css)
	_class_compact = not portrait and area.size.y / _slot_css < 460.0
	var right := area.position.x + outer if portrait else area.position.x + area.size.x * 0.53
	var width := area.size.x - outer * 2.0 if portrait else area.end.x - outer - right
	for entry in [[back_button, 24, 16], [slot_switch, 20, 12], [start_button, 28, 17], [brand_label, 22, 12], [heading, 40, 24], [subtitle, 22, 12], [hero_name, 36, 18], [role, 21, 12], [description, 19, 12], [health, 20, 12], [resource, 20, 12]]:
		_font(entry[0], float(entry[1]), float(entry[2]))
	if _class_compact:
		_font(heading, 36, 20)
	brand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for button: Button in class_buttons.values():
		_font(button, 26, 16)
	continue_button.hide()
	start_button.show()
	slot_switch.show()
	details.show()
	class_surface.show()
	showcase.show()
	_hero_backdrop.modulate.a = 0.44
	hero_name.visible = not _class_compact
	brand_label.visible = not _class_compact
	role.show()
	description.show()
	var top := area.position.y + outer
	var header_gutter := touch + gap if portrait else 0.0
	var header_width := maxf(1.0, width - header_gutter * 2.0)
	var brand_h := _measure(brand_label, header_width)
	var heading_h := _measure(heading, header_width)
	var subtitle_h := _measure(subtitle, width)
	var title_y := top + (brand_h + gap if brand_label.visible else 0.0)
	EntryUi.place(brand_label, Rect2(Vector2(right + header_gutter, top), Vector2(header_width, brand_h)))
	EntryUi.place(heading, Rect2(Vector2(right + header_gutter, title_y), Vector2(header_width, heading_h)))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle_y := title_y + heading_h + gap * 0.5
	EntryUi.place(subtitle, Rect2(Vector2(right, subtitle_y), Vector2(width, subtitle_h)))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EntryUi.place(back_button, Rect2(area.position + Vector2(outer, outer), Vector2(touch, touch)))
	back_button.text = "‹"
	var tabs_y := subtitle_y + subtitle_h + gap
	for index in 2:
		var button: Button = class_buttons[["warrior", "mage"][index]]
		button.show()
		EntryUi.place(button, Rect2(Vector2(right + index * (width + gap) * 0.5, tabs_y), Vector2((width - gap) * 0.5, touch)))
	var slots_y := area.end.y - outer - touch
	var start_y := slots_y - gap - action_h
	EntryUi.place(slot_switch, Rect2(Vector2(right, slots_y), Vector2(width, touch)))
	EntryUi.place(start_button, Rect2(Vector2(right, start_y), Vector2(width, action_h)))
	var pad := maxf((12.0 if _class_compact else 16.0) * u, (6.0 if _class_compact else 8.0) * _slot_css)
	var detail_gap := gap * 0.66 if _class_compact else gap
	var inside := width - pad * 2.0
	var name_h := _measure(hero_name, inside) if hero_name.visible else 0.0
	var role_h := _measure(role, inside)
	var desc_h := _measure(description, inside)
	var chip_h := maxf((36.0 if _class_compact else 46.0) * u, (24.0 if _class_compact else 27.0) * _slot_css)
	var info_h := pad * 2.0 + role_h + desc_h + chip_h + detail_gap * 2.0
	if hero_name.visible:
		info_h += name_h + gap * 0.5
	var info_y := start_y - gap - info_h
	var art_top := tabs_y + touch + gap if portrait else area.position.y + outer
	var art_left := right if portrait else area.position.x + outer
	var art_width := width if portrait else right - gap * 2.0 - art_left
	var art_bottom := info_y if portrait else area.end.y - outer
	EntryUi.place(showcase, Rect2(Vector2(art_left, art_top), Vector2(art_width, maxf(32.0, art_bottom - art_top))))
	EntryUi.place(hero_art, Rect2(Vector2.ZERO, showcase.size))
	EntryUi.place(details, Rect2(Vector2(right, info_y), Vector2(width, info_h)))
	EntryUi.place(info_surface, Rect2(Vector2.ZERO, details.size))
	var cursor := pad
	if hero_name.visible:
		EntryUi.place(hero_name, Rect2(Vector2(pad, cursor), Vector2(inside, name_h)))
		cursor += name_h + gap * 0.5
	EntryUi.place(role, Rect2(Vector2(pad, cursor), Vector2(inside, role_h)))
	cursor += role_h + detail_gap
	EntryUi.place(description, Rect2(Vector2(pad, cursor), Vector2(inside, desc_h)))
	cursor += desc_h + detail_gap
	var chip_w := (inside - gap) * 0.5
	for index in 2:
		var chip_rect := Rect2(Vector2(pad + index * (chip_w + gap), cursor), Vector2(chip_w, chip_h))
		EntryUi.place(stat_boxes[index], chip_rect)
		var label := health if index == 0 else resource
		EntryUi.place(label, chip_rect.grow(-maxf(5.0 * u, 3.0 * _slot_css)))
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sheet := Rect2(showcase.position, Vector2(showcase.size.x, details.position.y + details.size.y - showcase.position.y)) if portrait else showcase.get_rect()
	EntryUi.place(class_surface, sheet)
	_queue_publish_buttons()


func _publish_buttons() -> void:
	if start_button == null or not OS.has_feature("web"):
		return
	var targets := {"warrior": class_buttons["warrior"], "mage": class_buttons["mage"], "start": start_button, "continue": continue_button, "back": back_button, "slots": slot_switch}
	for index in 4:
		targets["slot%d" % (index + 1)] = slot_buttons[index]
		targets["delete%d" % (index + 1)] = delete_buttons[index]
	if is_instance_valid(_delete_dialog) and _delete_dialog.footer.get_child_count() == 2:
		targets["delete_cancel"] = _delete_dialog.footer.get_child(0)
		targets["delete_confirm"] = _delete_dialog.footer.get_child(1)
	var points := {"viewport": [size.x, size.y], "save_layout": _save_layout_probe(), "stage": _stage, "selected_slot": selected_slot, "selected_class": selected_class, "slots_state": _summaries, "slot_labels": slot_buttons.map(func(button: Button): return button.text)}
	var focus := get_viewport().gui_get_focus_owner()
	points["class_layout"] = _class_layout_probe()
	points["focus"] = ""
	points["rects"] = {}
	points["visible"] = {}
	points["fonts"] = {}
	points["save_layout"]["modal_focus"] = _modal_open() and is_instance_valid(focus) and _delete_dialog.is_ancestor_of(focus)
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
	_probe_queued = false
	_probe_flushes += 1
	_publish_buttons()


func probe_activity() -> Dictionary:
	return {"flushes": _probe_flushes, "writes": _probe_writes,
		"pending": _probe_queued, "idle_process": is_processing()}


func _modal_open() -> bool:
	return is_instance_valid(_delete_dialog) and not _delete_dialog.is_queued_for_deletion()

func _request_back() -> void:
	if not _modal_open():
		back_requested.emit()

func _request_continue() -> void:
	if _modal_open() or _stage != "slots":
		return
	if bool(_selected()["valid"]):
		continue_requested.emit()
	elif not bool(_selected()["occupied"]):
		_stage = "class"
		_update()

func _refresh_disabled() -> void:
	var blocked := _modal_open()
	for button: Button in [start_button, continue_button, back_button, slot_switch] + slot_buttons + delete_buttons + class_buttons.values():
		button.disabled = blocked
	start_button.disabled = blocked or bool(_selected()["occupied"])
	continue_button.disabled = blocked or (bool(_selected()["occupied"]) and not bool(_selected()["valid"]))
	for index in 4:
		delete_buttons[index].disabled = blocked or not bool(_summaries[index]["occupied"])

func _css_scale() -> float:
	if OS.has_feature("web"):
		var width: Variant = JavaScriptBridge.eval("window.innerWidth", true)
		if (width is float or width is int) and float(width) > 0.0:
			return size.x / float(width)
	if DisplayServer.get_name() == "headless":
		return 1.0
	return size.x / maxf(1.0, float(DisplayServer.window_get_size().x))

func _font(control: Control, base: float, css_minimum: float) -> void:
	var pixels := maxi(1, ceili(maxf(base * _unit, css_minimum * _slot_css)))
	if control.get_theme_font_size("font_size") != pixels:
		control.add_theme_font_size_override("font_size", pixels)

func _quiet_row_text(button: Button) -> void:
	# Keep the canonical text for accessibility and existing save/time probes.
	# Visible title/metadata are separate labels with their own measured boxes.
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
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
	if _modal_open():
		_fit_delete_dialog()

func _layout_slots() -> void:
	var margins := PanelFrame.safe_margins(get_viewport())
	var area := Rect2(Vector2(margins.x, margins.y), size - Vector2(margins.x + margins.z, margins.y + margins.w))
	_slot_safe = area
	var portrait := area.size.y > area.size.x
	_unit = minf(area.size.x / 720.0, area.size.y / 1280.0) if portrait else minf(area.size.x / 1280.0, area.size.y / 720.0)
	_slot_css = _css_scale()
	var u := _unit
	var compact := area.size.y / _slot_css < 460.0
	var pad := maxf(22.0 * u, 10.0 * _slot_css)
	var gap := maxf(12.0 * u, 6.0 * _slot_css)
	var outer := maxf(22.0 * u, 12.0 * _slot_css)
	_slot_pad = maxf(12.0 * u, 7.0 * _slot_css)
	_slot_gap = gap
	_slot_badge = maxf(76.0 * u, 42.0 * _slot_css)
	_slot_touch = maxf(72.0 * u, 44.0 * _slot_css)
	var summary := _selected()
	var preview := bool(summary["valid"])
	var side_preview := preview and not portrait
	var side_left := area.position.x + area.size.x * 0.52
	var width := area.end.x - outer - side_left if side_preview else minf(area.size.x - outer * 2.0, maxf(1000.0 * u, 292.0 * _slot_css))
	var inner := maxf(1.0, width - pad * 2.0)
	var preview_h := maxf(150.0 * _slot_css, 180.0 * u) if preview and portrait else 0.0
	slot_surface.show()
	slot_scroll.show()
	slot_footer.show()
	slot_context.show()
	class_surface.hide()
	details.hide()
	slot_switch.hide()
	start_button.hide()
	continue_button.show()
	showcase.visible = preview
	_hero_backdrop.modulate.a = 0.44 if side_preview else 0.0
	hero_art.texture = SelectionUi.vignette(SelectionUi.hero_image(selected_class)) if portrait else SelectionUi.hero_image(selected_class)
	brand_label.visible = not compact
	back_button.text = "‹"
	back_button.tooltip_text = "처음 화면으로 돌아가기"
	for entry in [[back_button, 32, 20], [brand_label, 20, 12], [heading, 36, 22], [subtitle, 22, 12], [continue_button, 28, 16], [slot_context, 21, 12]]:
		_font(entry[0], float(entry[1]), float(entry[2]))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if portrait else HORIZONTAL_ALIGNMENT_LEFT
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if portrait else HORIZONTAL_ALIGNMENT_LEFT
	brand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if portrait else HORIZONTAL_ALIGNMENT_LEFT
	slot_context.text = "저장 %d · %s" % [selected_slot, "이 여정을 계속합니다" if bool(summary["valid"]) else "복구할 수 없는 저장" if bool(summary["occupied"]) else "새로운 여정을 준비하세요"]
	var header_left := _slot_touch + gap
	var header_width := maxf(1.0, inner - header_left * (2.0 if portrait else 1.0))
	var brand_h := _measure(brand_label, header_width) if brand_label.visible else 0.0
	var title_h := _measure(heading, header_width)
	var title_y := brand_h + gap * 0.4 if brand_label.visible else maxf(0.0, (_slot_touch - title_h) * 0.5)
	var subtitle_y := maxf(_slot_touch, title_y + title_h) + gap
	var subtitle_width := inner
	var subtitle_h := _measure(subtitle, subtitle_width)
	var vignette_y := subtitle_y + subtitle_h + gap
	var header_h := vignette_y + preview_h if preview and portrait else subtitle_y + subtitle_h
	slot_context.size.x = inner
	var context_h := _measure(slot_context, inner)
	var action_h := maxf(88.0 * u, 48.0 * _slot_css)
	var footer_h := context_h + gap * 2.0 + action_h
	slot_list.add_theme_constant_override("separation", roundi(gap))
	var total_rows := 0.0
	for button: Button in class_buttons.values():
		button.hide()
	for index in 4:
		var row := slot_buttons[index]
		var remove := delete_buttons[index]
		row.show()
		remove.visible = bool(_summaries[index]["occupied"])
		for entry in [[row, 26, 14], [remove, 20, 12], [slot_number_labels[index], 24, 14], [slot_title_labels[index], 26, 14], [slot_meta_labels[index], 21, 12], [slot_status_labels[index], 18, 10]]:
			_font(entry[0], float(entry[1]), float(entry[2]))
		var remove_w := maxf(76.0 * u, _slot_touch)
		remove.custom_minimum_size = Vector2(remove_w, _slot_touch)
		slot_bands[index].add_theme_constant_override("separation", roundi(gap))
		var scrollbar := slot_scroll.get_v_scroll_bar()
		var gutter := maxf(scrollbar.get_combined_minimum_size().x, scrollbar.size.x)
		row.size.x = maxf(1.0, inner - gutter - (remove_w + gap if remove.visible else 0.0))
		_place_slot_labels(index)
		var labels_h := slot_meta_labels[index].position.y + slot_meta_labels[index].size.y + _slot_pad
		var row_h := maxf(_slot_badge + _slot_pad * 2.0, maxf(labels_h, _slot_touch))
		row.custom_minimum_size = Vector2(0, row_h)
		slot_bands[index].custom_minimum_size.y = row_h
		total_rows += row_h
	total_rows += gap * 3.0
	for band in slot_bands:
		band.queue_sort()
	slot_list.queue_sort()
	var maximum_h := maxf(1.0, area.size.y - outer * 2.0)
	var height := minf(maximum_h, pad * 2.0 + header_h + gap * 2.0 + total_rows + footer_h)
	var origin := area.position + (area.size - Vector2(width, height)) * 0.5
	if side_preview:
		origin.x = side_left
	var content := origin + Vector2.ONE * pad
	EntryUi.place(slot_surface, Rect2(origin, Vector2(width, height)))
	EntryUi.place(back_button, Rect2(content, Vector2.ONE * _slot_touch))
	EntryUi.place(brand_label, Rect2(content + Vector2(header_left, 0), Vector2(header_width, brand_h)))
	EntryUi.place(heading, Rect2(content + Vector2(header_left, title_y), Vector2(header_width, title_h)))
	EntryUi.place(subtitle, Rect2(content + Vector2(0, subtitle_y), Vector2(subtitle_width, subtitle_h)))
	if preview:
		if portrait:
			EntryUi.place(showcase, Rect2(content + Vector2(0, vignette_y), Vector2(inner, preview_h)))
		else:
			var art_left := area.position.x + outer
			EntryUi.place(showcase, Rect2(Vector2(art_left, area.position.y + outer),
				Vector2(side_left - gap * 2.0 - art_left, area.size.y - outer * 2.0)))
		EntryUi.place(hero_art, Rect2(Vector2.ZERO, showcase.size))
	var list_y := content.y + header_h + gap
	var available := maxf(1.0, height - pad * 2.0 - header_h - gap * 2.0 - footer_h)
	EntryUi.place(slot_scroll, Rect2(Vector2(content.x, list_y), Vector2(inner, minf(total_rows, available))))
	var footer_y := slot_scroll.position.y + slot_scroll.size.y + gap
	EntryUi.place(slot_footer, Rect2(Vector2(content.x, footer_y), Vector2(inner, footer_h)))
	EntryUi.place(slot_context, Rect2(Vector2(content.x, footer_y + gap * 0.5), Vector2(inner, context_h)))
	EntryUi.place(continue_button, Rect2(Vector2(content.x, footer_y + context_h + gap), Vector2(inner, action_h)))
	_queue_publish_buttons()


func _place_slot_labels(index: int) -> void:
	if index < 0 or index >= slot_buttons.size() or index >= slot_status_labels.size() or index >= slot_portrait_frames.size():
		return
	var row := slot_buttons[index]
	var pad := _slot_pad
	var gap := _slot_gap
	var number := slot_number_labels[index]
	var title := slot_title_labels[index]
	var meta := slot_meta_labels[index]
	var status := slot_status_labels[index]
	var left := pad + _slot_badge + gap
	var text_w := maxf(1.0, row.size.x - left - pad)
	var status_w := status.get_combined_minimum_size().x if not status.text.is_empty() else 0.0
	status.visible = not status.text.is_empty() and text_w >= 190.0 * _slot_css
	if not status.visible:
		status_w = 0.0
	var title_h := title.get_combined_minimum_size().y
	EntryUi.place(slot_portrait_frames[index], Rect2(Vector2(pad, pad), Vector2.ONE * _slot_badge))
	var number_h := number.get_combined_minimum_size().y
	var badge_w := maxf(30.0 * _unit, 24.0 * _slot_css)
	var badge_h := number_h + 6.0 * _slot_css
	var badge_rect := Rect2(Vector2(pad - 3.0 * _slot_css, pad + _slot_badge - badge_h + 3.0 * _slot_css), Vector2(badge_w, badge_h))
	EntryUi.place(slot_number_badges[index], badge_rect)
	EntryUi.place(number, badge_rect.grow(-2.0 * _slot_css))
	EntryUi.place(title, Rect2(Vector2(left, pad), Vector2(maxf(1.0, text_w - status_w - (gap if status.visible else 0.0)), title_h)))
	EntryUi.place(status, Rect2(Vector2(row.size.x - pad - status_w, pad), Vector2(status_w, title_h)))
	var meta_h := _measure(meta, text_w, 22.0 * _unit)
	EntryUi.place(meta, Rect2(Vector2(left, pad + title_h + maxf(4.0 * _unit, 3.0 * _slot_css)), Vector2(text_w, meta_h)))


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
	_delete_dialog._column.add_theme_constant_override("separation", maxi(8, roundi(6.0 * _slot_css)))
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
		button.focus_previous = button.get_path_to(buttons[(index - 1 + buttons.size()) % buttons.size()])
	_delete_dialog._layout.call_deferred()

func _restore_delete_focus(number: int, use_row: bool) -> void:
	if number < 1 or number > slot_buttons.size() or _stage != "slots":
		return
	var button: Button = slot_buttons[number - 1]
	if not use_row and delete_buttons[number - 1].is_visible_in_tree() and not delete_buttons[number - 1].disabled:
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
	for index in 4:
		cards.append({"slot": index + 1, "row": _rect(slot_bands[index]), "select": _rect(slot_buttons[index]), "delete": _rect(delete_buttons[index]), "delete_visible": delete_buttons[index].is_visible_in_tree(), "title": _rect(slot_title_labels[index]), "meta": _rect(slot_meta_labels[index]), "number": _rect(slot_number_labels[index]), "status": _rect(slot_status_labels[index]), "title_text": slot_title_labels[index].text, "meta_text": slot_meta_labels[index].text, "status_text": slot_status_labels[index].text, "title_font": slot_title_labels[index].get_theme_font_size("font_size"), "meta_font": slot_meta_labels[index].get_theme_font_size("font_size")})
	var bar := slot_scroll.get_v_scroll_bar()
	var result := {"safe": [_slot_safe.position.x, _slot_safe.position.y, _slot_safe.size.x, _slot_safe.size.y], "sheet": _rect(slot_surface), "list": _rect(slot_scroll), "footer": _rect(slot_footer), "context": _rect(slot_context), "scroll_value": slot_scroll.scroll_vertical, "scroll_max": maxi(0, ceili(bar.max_value - bar.page)), "css_scale": _slot_css, "modal_open": _modal_open(), "cards": cards, "heading": _rect(heading), "subtitle": _rect(subtitle)}
	if _modal_open():
		result["dialog"] = {"panel": _rect(_delete_dialog._panel), "body": _rect(_delete_dialog.body_holder), "footer": _rect(_delete_dialog.footer)}
	return result


func gamepad_back() -> bool:
	if _modal_open():
		_close_delete()
	elif _stage == "class":
		show_slots()
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
		stats.append({"rect": _rect(stat_boxes[index]), "text_rect": _rect(label),
			"font_size": label.get_theme_font_size("font_size"), "text": label.text})
	var fonts := {}
	var visible := {}
	var labels := {}
	var texts := {}
	for entry in [["brand", brand_label], ["heading", heading], ["subtitle", subtitle], ["name", hero_name], ["role", role], ["description", description]]:
		var label: Label = entry[1]
		fonts[entry[0]] = label.get_theme_font_size("font_size")
		visible[entry[0]] = label.is_visible_in_tree()
		labels[entry[0]] = _rect(label)
		texts[entry[0]] = label.text
	return {"safe": [_class_safe.position.x, _class_safe.position.y, _class_safe.size.x, _class_safe.size.y],
		"sheet": _rect(class_surface), "brand": _rect(brand_label), "heading": _rect(heading), "subtitle": _rect(subtitle),
		"back": _rect(back_button), "tabs": {"warrior": _rect(class_buttons["warrior"]), "mage": _rect(class_buttons["mage"])},
		"art": _rect(showcase), "details": _rect(details), "stats": stats, "weapon": [],
		"start": _rect(start_button), "slotchange": _rect(slot_switch), "fonts": fonts, "visible": visible,
		"labels": labels, "texts": texts, "class": selected_class, "compact": _class_compact,
		"portrait": size.y > size.x, "css_scale": _slot_css}

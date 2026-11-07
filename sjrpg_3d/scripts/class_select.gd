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

func _ready() -> void:
	add_to_group("gamepad_entry")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	EntryUi.backdrop(self)
	EntryUi.shade(self, 0.97)
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
	slot_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float): _publish_buttons.call_deferred())
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
	_update()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sjrpgClassSelectReady = true")

func _button(text: String, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	button.focus_entered.connect(func(): _publish_buttons.call_deferred())
	EntryUi.style(button, primary)
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
	heading.text = "수호자 선택" if choosing else "모험 선택"
	subtitle.text = "당신의 전투 방식을 선택하세요" if choosing else "이어 갈 모험을 선택하세요"
	slot_switch.text = "저장 %d · 새 수호자     변경" % selected_slot
	var info: Dictionary = GameState.CLASSES.get(selected_class, GameState.CLASSES["mage"])
	hero_art.texture = EntryUi.image(EntryUi.HEROES[selected_class])
	hero_name.text = str(info["name"])
	role.text = ROLES[selected_class]
	description.text = DESCRIPTIONS[selected_class]
	health.text = "체력  " + HudArt.stat(info["hp"])
	resource.text = str(info["resource"]) + "  " + HudArt.res(info["resource_max"])
	start_button.text = "%s로 시작" % info["name"]
	start_button.disabled = bool(summary["occupied"])
	continue_button.disabled = bool(summary["occupied"]) and not bool(summary["valid"])
	continue_button.text = "이 모험 이어 하기" if bool(summary["valid"]) else ("저장을 읽을 수 없습니다" if bool(summary["occupied"]) else "새 수호자 선택")
	for key: String in class_buttons:
		EntryUi.style(class_buttons[key], false, key == selected_class)
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
		EntryUi.style(slot_buttons[index], false, selected_slot == index + 1)
		_quiet_row_text(slot_buttons[index])
		EntryUi.style(delete_buttons[index])
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
	_refresh_disabled()
	_fit_delete_dialog()
	(_delete_dialog.footer.get_child(0) as Button).grab_focus.call_deferred()
	_publish_buttons.call_deferred()

func _close_delete(use_row := false) -> void:
	if is_instance_valid(_delete_dialog):
		_delete_dialog.queue_free()
	_delete_dialog = null
	_refresh_disabled()
	_restore_delete_focus.call_deferred(_delete_target, use_row)
	_publish_buttons.call_deferred()

func _layout_class() -> void:
	if start_button == null:
		return
	var margins := PanelFrame.safe_margins(get_viewport())
	var area := Rect2(Vector2(margins.x, margins.y), size - Vector2(margins.x + margins.z, margins.y + margins.w))
	var portrait := area.size.y > area.size.x
	_unit = minf(area.size.x / 720.0, area.size.y / 1280.0) if portrait else minf(area.size.x / 1280.0, area.size.y / 720.0)
	var u := _unit
	for button in [start_button, continue_button, back_button, slot_switch]:
		button.add_theme_font_size_override("font_size", maxi(14, roundi((27.0 if button in [start_button, continue_button] else 22.0) * u)))
	for button in slot_buttons + delete_buttons + class_buttons.values():
		button.add_theme_font_size_override("font_size", maxi(14, roundi(24.0 * u)))
	heading.add_theme_font_size_override("font_size", maxi(18, roundi(36.0 * u)))
	subtitle.add_theme_font_size_override("font_size", maxi(14, roundi(23.0 * u)))
	var inset := 28.0 * u
	var left := area.position.x + inset
	var width := area.size.x - inset * 2.0
	var choosing := _stage == "class"
	EntryUi.place(back_button, Rect2(Vector2(left, area.position.y + 16.0 * u), Vector2(164, 100) * u))
	EntryUi.place(heading, Rect2(Vector2(left + 188.0 * u, area.position.y + 25.0 * u), Vector2(width - 188.0 * u, 50.0 * u)))
	EntryUi.place(subtitle, Rect2(Vector2(left, area.position.y + (132.0 if portrait else 120.0) * u), Vector2(width if portrait else area.size.x * 0.49 - inset, (44.0 if portrait else 32.0) * u)))
	var action_y := area.end.y - 136.0 * u
	var right := left if portrait else area.position.x + area.size.x * 0.53
	var controls_width := width if portrait else area.end.x - inset - right
	var action := Rect2(Vector2(right, action_y), Vector2(controls_width, 104.0 * u))
	EntryUi.place(start_button, action)
	EntryUi.place(continue_button, action)
	start_button.visible = choosing
	continue_button.visible = not choosing
	slot_switch.visible = choosing
	EntryUi.place(slot_switch, Rect2(Vector2(right, area.position.y + (190.0 if portrait else 105.0) * u), Vector2(controls_width, 100.0 * u)))
	for index in 4:
		slot_buttons[index].hide()
		delete_buttons[index].hide()
	for index in 2:
		var button: Button = class_buttons[["warrior", "mage"][index]]
		button.visible = choosing
		EntryUi.place(button, Rect2(Vector2(right + index * (controls_width + 14.0 * u) * 0.5, action_y - 116.0 * u), Vector2((controls_width - 14.0 * u) * 0.5, 100.0 * u)))
	details.visible = choosing
	var detail_y := action_y - 322.0 * u if portrait else area.position.y + 212.0 * u
	EntryUi.place(details, Rect2(Vector2(right, detail_y), Vector2(controls_width, 184.0 * u)))
	for entry in [[hero_name, 0, 48, 40], [role, 51, 31, 23], [description, 88, 54, 24], [health, 151, 32, 22], [resource, 151, 32, 22]]:
		var label: Label = entry[0]
		var x := controls_width * 0.5 if label == resource else 0.0
		var w := controls_width * 0.5 if label in [health, resource] else controls_width
		EntryUi.place(label, Rect2(Vector2(x, float(entry[1]) * u), Vector2(w, float(entry[2]) * u)))
		label.add_theme_font_size_override("font_size", maxi(14, roundi(float(entry[3]) * u)))
	# Minimum readable type can exceed proportional line boxes in a short window.
	# Measure the actual labels before placing the following information row.
	role.position.y = maxf(role.position.y, hero_name.position.y + hero_name.get_combined_minimum_size().y + 3.0 * u)
	description.position.y = maxf(description.position.y, role.position.y + role.get_combined_minimum_size().y + 4.0 * u)
	description.size.y = maxf(description.size.y, description.get_combined_minimum_size().y)
	var stats_y := maxf(health.position.y, description.position.y + description.size.y + 6.0 * u)
	for label: Label in [health, resource]:
		label.position.y = stats_y
		label.size.y = maxf(label.size.y, label.get_combined_minimum_size().y)
	details.size.y = maxf(details.size.y, stats_y + maxf(health.size.y, resource.size.y))
	if portrait:
		var art_top := area.position.y + (306.0 if choosing else 190.0) * u
		var art_bottom := detail_y - 16.0 * u if choosing else area.position.y + 420.0 * u
		EntryUi.place(showcase, Rect2(Vector2(left, art_top), Vector2(width, art_bottom - art_top)))
	else:
		EntryUi.place(showcase, Rect2(Vector2(left, area.position.y + 164.0 * u), Vector2(area.size.x * 0.49 - inset, area.size.y - 192.0 * u)))
	EntryUi.place(hero_art, Rect2(Vector2.ZERO, showcase.size))
	_publish_buttons()

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
	JavaScriptBridge.eval("window.__sjrpgClassButtons = " + JSON.stringify(points))


func _process(_delta: float) -> void:
	# Modal layout settles after its theme/safe-area update; publish real targets.
	if OS.has_feature("web") and (_stage == "slots" or is_instance_valid(_delete_dialog)):
		_publish_buttons()


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
		back_button.text = "‹  돌아가기"
		_layout_class()
	if _modal_open():
		_fit_delete_dialog()

func _layout_slots() -> void:
	var margins := PanelFrame.safe_margins(get_viewport())
	var area := Rect2(Vector2(margins.x, margins.y), size - Vector2(margins.x + margins.z, margins.y + margins.w))
	_slot_safe = area
	_unit = minf(area.size.x / 720.0, area.size.y / 1280.0) if area.size.y > area.size.x else minf(area.size.x / 1280.0, area.size.y / 720.0)
	_slot_css = _css_scale()
	var u := _unit
	var pad := maxf(24.0 * u, 12.0 * _slot_css)
	var gap := maxf(12.0 * u, 6.0 * _slot_css)
	_slot_pad = maxf(14.0 * u, 8.0 * _slot_css)
	_slot_gap = gap
	_slot_badge = maxf(56.0 * u, 28.0 * _slot_css)
	_slot_touch = maxf(80.0 * u, 44.0 * _slot_css)
	var outer := maxf(20.0 * u, 12.0 * _slot_css)
	var width := minf(area.size.x - outer * 2.0, maxf(920.0 * u, 280.0 * _slot_css))
	var inner := maxf(1.0, width - pad * 2.0)
	slot_surface.show()
	slot_scroll.show()
	slot_footer.show()
	slot_context.show()
	showcase.hide()
	details.hide()
	slot_switch.hide()
	start_button.hide()
	continue_button.show()
	back_button.text = "‹"
	back_button.tooltip_text = "처음 화면으로 돌아가기"
	_font(back_button, 36, 24)
	_font(heading, 38, 22)
	_font(subtitle, 23, 12)
	_font(continue_button, 28, 16)
	_font(slot_context, 22, 12)
	var summary := _selected()
	slot_context.text = "저장 %d · %s" % [selected_slot, "이어 갈 모험" if bool(summary["valid"]) else "읽을 수 없는 모험" if bool(summary["occupied"]) else "빈 슬롯을 선택해 새 모험을 시작하세요"]
	subtitle.size.x = inner
	var subtitle_h := maxf(28.0 * u, subtitle.get_combined_minimum_size().y)
	var header_h := _slot_touch + gap + subtitle_h
	slot_context.size.x = inner
	var context_h := maxf(26.0 * u, slot_context.get_combined_minimum_size().y)
	var action_h := maxf(100.0 * u, 48.0 * _slot_css)
	var footer_h := context_h + gap + action_h + gap
	slot_list.add_theme_constant_override("separation", roundi(gap))
	var total_rows := 0.0
	for index in 2:
		class_buttons[["warrior", "mage"][index]].hide()
	for index in 4:
		var row := slot_buttons[index]
		var remove := delete_buttons[index]
		row.show()
		remove.visible = bool(_summaries[index]["occupied"])
		_font(row, 26, 14)
		_font(remove, 22, 12)
		_font(slot_number_labels[index], 28, 16)
		_font(slot_title_labels[index], 26, 14)
		_font(slot_meta_labels[index], 22, 12)
		_font(slot_status_labels[index], 20, 11)
		var remove_w := maxf(84.0 * u, _slot_touch)
		remove.custom_minimum_size = Vector2(remove_w, _slot_touch)
		slot_bands[index].add_theme_constant_override("separation", roundi(gap))
		# Measure at the narrowest possible content width; AUTO scrolling can
		# reserve this gutter after the first container pass. A wider row stays safe.
		var scrollbar := slot_scroll.get_v_scroll_bar()
		var gutter := maxf(scrollbar.get_combined_minimum_size().x, scrollbar.size.x)
		var row_w := inner - gutter - (remove_w + gap if remove.visible else 0.0)
		row.size.x = maxf(1.0, row_w)
		_place_slot_labels(index)
		var labels_h := slot_meta_labels[index].position.y + slot_meta_labels[index].size.y + _slot_pad
		var row_h := maxf(maxf(116.0 * u, _slot_touch), maxf(labels_h, row.get_minimum_size().y))
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
	var content := origin + Vector2.ONE * pad
	EntryUi.place(slot_surface, Rect2(origin, Vector2(width, height)))
	EntryUi.place(back_button, Rect2(content, Vector2.ONE * _slot_touch))
	var title_h := heading.get_combined_minimum_size().y
	EntryUi.place(heading, Rect2(content + Vector2(_slot_touch + gap, (_slot_touch - title_h) * 0.5), Vector2(inner - _slot_touch - gap, title_h)))
	EntryUi.place(subtitle, Rect2(content + Vector2(0, _slot_touch + gap), Vector2(inner, subtitle_h)))
	var list_y := content.y + header_h + gap
	var available := maxf(1.0, height - pad * 2.0 - header_h - gap * 2.0 - footer_h)
	EntryUi.place(slot_scroll, Rect2(Vector2(content.x, list_y), Vector2(inner, minf(total_rows, available))))
	var footer_y := slot_scroll.position.y + slot_scroll.size.y + gap
	EntryUi.place(slot_footer, Rect2(Vector2(content.x, footer_y), Vector2(inner, footer_h)))
	EntryUi.place(slot_context, Rect2(Vector2(content.x, footer_y + gap * 0.5), Vector2(inner, context_h)))
	EntryUi.place(continue_button, Rect2(Vector2(content.x, footer_y + context_h + gap), Vector2(inner, action_h)))
	_publish_buttons.call_deferred()

func _place_slot_labels(index: int) -> void:
	if index < 0 or index >= slot_buttons.size() or index >= slot_status_labels.size():
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
	status.visible = not status.text.is_empty()
	var title_h := title.get_combined_minimum_size().y
	EntryUi.place(number, Rect2(Vector2(pad, pad), Vector2(_slot_badge, title_h)))
	EntryUi.place(title, Rect2(Vector2(left, pad), Vector2(maxf(1.0, text_w - status_w - (gap if status.visible else 0.0)), title_h)))
	EntryUi.place(status, Rect2(Vector2(row.size.x - pad - status_w, pad), Vector2(status_w, title_h)))
	meta.size.x = text_w
	var font := meta.get_theme_font("font")
	var flags := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var measured := font.get_multiline_string_size(meta.text, HORIZONTAL_ALIGNMENT_LEFT, text_w, meta.get_theme_font_size("font_size"), -1, flags)
	var meta_h := maxf(measured.y, 22.0 * _unit)
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

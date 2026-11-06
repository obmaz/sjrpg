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

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	EntryUi.backdrop(self)
	EntryUi.shade(self, 0.97)
	back_button = _button("‹  돌아가기", func(): back_requested.emit())
	heading = _label("모험 선택", 36, EntryUi.TEXT, true)
	subtitle = _label("네 개의 여정, 당신만의 수호자", 23, EntryUi.MUTED)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	for index in 4:
		var number := index + 1
		var row := _button("", func(): select_slot(number))
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot_buttons.append(row)
		delete_buttons.append(_button("삭제", func(): confirm_delete(number)))
	start_button = _button("", _choose, true)
	continue_button = _button("이어 하기", func(): continue_requested.emit(), true)
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
	_stage = "slots"
	refresh_slots()
	_update()

func select_slot(number: int) -> void:
	if number < 1 or number > 4:
		return
	selected_slot = number
	var summary := _selected()
	_stage = "slots" if bool(summary["occupied"]) else "class"
	if bool(summary["valid"]):
		selected_class = str(summary["class"])
	_update()

func select_class(cls: String) -> void:
	if not EntryUi.HEROES.has(cls) or bool(_selected()["occupied"]):
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
	continue_button.disabled = not bool(summary["valid"])
	continue_button.text = "이 모험 이어 하기" if bool(summary["valid"]) else ("저장을 읽을 수 없습니다" if bool(summary["occupied"]) else "빈 저장 슬롯")
	for key: String in class_buttons:
		EntryUi.style(class_buttons[key], false, key == selected_class)
	for index in 4:
		var entry: Dictionary = _summaries[index]
		var text := "%02d    새로운 모험" % (index + 1)
		if bool(entry["valid"]):
			var name: String = GameState.CLASSES[str(entry["class"])]["name"]
			var location := "바람 동굴" if str(entry["location"]) == "cave" else "숲 마을"
			var stamp := SaveTimeLabel.for_device(float(entry["timestamp"]))
			text = "%02d    %s · Lv.%d\n        %s · %s%s" % [index + 1, name, int(entry["level"]), location, "백업 복원" if bool(entry["backup"]) else stamp, ""]
		elif bool(entry["occupied"]):
			text = "%02d    읽을 수 없는 모험\n        삭제 후 새로 시작" % (index + 1)
		slot_buttons[index].text = text
		EntryUi.style(slot_buttons[index], false, selected_slot == index + 1)
		delete_buttons[index].disabled = not bool(entry["occupied"])
	_layout()

func show_error(message: String) -> void:
	subtitle.text = message

func _choose() -> void:
	if not bool(_selected()["occupied"]):
		chosen.emit(selected_class)

func confirm_delete(number: int) -> void:
	var summary: Dictionary = _summaries[number - 1]
	if not bool(summary["occupied"]) or is_instance_valid(_delete_dialog):
		return
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
		_close_delete()
		refresh_slots()
		_stage = "slots"
		_update()
		if not deleted:
			show_error("삭제하지 못했습니다. 다시 시도해 주세요."), true)
	_delete_dialog.closed.connect(_close_delete)
	_publish_buttons.call_deferred()

func _close_delete() -> void:
	if is_instance_valid(_delete_dialog):
		_delete_dialog.queue_free()
	_delete_dialog = null
	_publish_buttons.call_deferred()

func _layout() -> void:
	if start_button == null:
		return
	var margins := PanelFrame.safe_margins(get_viewport())
	var area := Rect2(Vector2(margins.x, margins.y), size - Vector2(margins.x + margins.z, margins.y + margins.w))
	var portrait := area.size.y > area.size.x
	_unit = minf(area.size.x / 720.0, area.size.y / 1280.0) if portrait else minf(area.size.x / 1280.0, area.size.y / 720.0)
	var u := _unit
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
		slot_buttons[index].visible = not choosing
		delete_buttons[index].visible = not choosing
		var rows_top := area.position.y + (436.0 if portrait else 154.0) * u
		var row_h := 108.0 if portrait else 100.0
		var y := rows_top + index * (row_h + (12.0 if portrait else 6.0)) * u
		EntryUi.place(slot_buttons[index], Rect2(Vector2(right, y), Vector2(controls_width - 116.0 * u, row_h * u)))
		EntryUi.place(delete_buttons[index], Rect2(Vector2(right + controls_width - 104.0 * u, y), Vector2(104.0 * u, row_h * u)))
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
	for button in [start_button, continue_button, back_button, slot_switch]:
		button.add_theme_font_size_override("font_size", maxi(14, roundi((27.0 if button in [start_button, continue_button] else 22.0) * u)))
	for button in slot_buttons + delete_buttons + class_buttons.values():
		button.add_theme_font_size_override("font_size", maxi(14, roundi(24.0 * u)))
	heading.add_theme_font_size_override("font_size", maxi(18, roundi(36.0 * u)))
	subtitle.add_theme_font_size_override("font_size", maxi(14, roundi(23.0 * u)))
	_publish_buttons()

func _publish_buttons() -> void:
	if not OS.has_feature("web"):
		return
	var targets := {"warrior": class_buttons["warrior"], "mage": class_buttons["mage"], "start": start_button, "continue": continue_button, "back": back_button, "slots": slot_switch}
	for index in 4:
		targets["slot%d" % (index + 1)] = slot_buttons[index]
		targets["delete%d" % (index + 1)] = delete_buttons[index]
	if is_instance_valid(_delete_dialog) and _delete_dialog.footer.get_child_count() == 2:
		targets["delete_cancel"] = _delete_dialog.footer.get_child(0)
		targets["delete_confirm"] = _delete_dialog.footer.get_child(1)
	var points := {"stage": _stage, "selected_slot": selected_slot, "selected_class": selected_class, "slots_state": _summaries, "slot_labels": slot_buttons.map(func(button: Button): return button.text)}
	for key: String in targets:
		var button: Button = targets[key]
		var center := button.get_global_rect().get_center() / get_viewport_rect().size
		points[key] = [center.x, center.y]
	JavaScriptBridge.eval("window.__sjrpgClassButtons = " + JSON.stringify(points))


func _process(_delta: float) -> void:
	# Modal layout settles after its theme/safe-area update; publish real targets.
	if OS.has_feature("web") and is_instance_valid(_delete_dialog):
		_publish_buttons()

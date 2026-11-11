class_name MapPlaceRow
extends PanelContainer
## 터치 드래그를 부모 ScrollContainer에 전달하고 짧은 탭/키보드 확인만 선택으로 처리한다.
signal pressed
var place_id := ""
var _number: Label
var _name: Label
var _detail: Label
var _category: Label
var _margin: MarginContainer
var _ink := Color.WHITE
var _selected := false
var _pointer := -2
var _drag := Vector2.ZERO
var _dragged := false


func setup(index: int, marker: Dictionary) -> MapPlaceRow:
	place_id = marker["id"]
	_ink = marker["color"]
	custom_minimum_size = Vector2(0, 82)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_ALL
	set_meta("gamepad_target", true)
	set_meta("gamepad_key", "map:" + place_id)
	_margin = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, 10)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	_margin.add_child(row)
	_number = UiKit.label(str(index), 21, _ink, true)
	_number.custom_minimum_size.x = 34
	_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_number)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	_category = UiKit.label(MapGeometry.category(marker), 14, _ink)
	words.add_child(_category)
	_name = UiKit.label(marker["label"], 19, UiKit.TEXT, true)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(_name)
	_detail = UiKit.label("", 15, UiKit.MUTED)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(_detail)
	for label: Label in [_category, _name, _detail]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.minimum_size_changed.connect(_fit_height)
	focus_entered.connect(_restyle)
	focus_exited.connect(_restyle)
	_restyle()
	return self


func _restyle() -> void:
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(_ink, .13 if _selected else .025)
	skin.border_color = Color(_ink, .85 if _selected or has_focus() else .23)
	skin.border_width_bottom = 1
	skin.border_width_left = 3 if _selected or has_focus() else 0
	add_theme_stylebox_override("panel", skin)


func _fit_height() -> void:
	custom_minimum_size.y = maxf(82, _margin.get_combined_minimum_size().y)


func update_state(marker: Dictionary, distance_m: float, selected: bool) -> void:
	var summary := "%d m · %s" % [roundi(distance_m), marker["detail"]]
	_detail.text = summary
	_name.text = marker["label"]
	if selected != _selected:
		_selected = selected
		_restyle()


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not event.is_echo():
		pressed.emit()
		accept_event()
	elif event is InputEventScreenTouch:
		if event.canceled and event.index == _pointer:
			_pointer = -2
		else:
			_pointer_event(event.position, event.pressed, event.index)
	elif event is InputEventScreenDrag and event.index == _pointer:
		_track_drag(event.relative)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_pointer_event(event.position, event.pressed, -1)
	elif event is InputEventMouseMotion and _pointer == -1:
		_track_drag(event.relative)


func _track_drag(relative: Vector2) -> void:
	_drag += relative
	# 손가락이 출발점으로 되돌아와도 이미 시작한 스크롤을 탭으로 바꾸지 않는다.
	_dragged = _dragged or _drag.length() >= 12


func _pointer_event(at: Vector2, down: bool, index: int) -> void:
	if down:
		if _pointer != -2:
			return
		_pointer = index
		_drag = Vector2.ZERO
		_dragged = false
	elif index == _pointer:
		_pointer = -2
		if not _dragged and Rect2(Vector2.ZERO, size).has_point(at):
			grab_focus()
			pressed.emit()

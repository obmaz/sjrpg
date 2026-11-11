class_name MapPlaceRow
extends Button
## 긴 장소명/설명은 줄바꿈하고 행 높이를 늘린다. 지도 번호와 동일한 번호를 표시한다.
var place_id := ""
var _number: Label
var _name: Label
var _detail: Label
var _margin: MarginContainer


func setup(index: int, marker: Dictionary) -> MapPlaceRow:
	place_id = marker["id"]
	custom_minimum_size = Vector2(0, 78)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.style_button(self)
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, 10)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	_margin.add_child(row)
	_number = UiKit.label(str(index), 21, marker["color"], true)
	_number.custom_minimum_size.x = 34
	_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_number)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	_name = UiKit.label(marker["label"], 19, UiKit.TEXT, true)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(_name)
	_detail = UiKit.label("", 15, UiKit.MUTED)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(_detail)
	_margin.minimum_size_changed.connect(_fit_height)
	return self


func _fit_height() -> void:
	custom_minimum_size.y = maxf(78, _margin.get_combined_minimum_size().y)


func update_state(marker: Dictionary, distance_m: float, selected: bool) -> void:
	var summary := "%d m · %s" % [roundi(distance_m), marker["detail"]]
	if _detail.text != summary:
		_detail.text = summary
	if _name.text != marker["label"]:
		_name.text = marker["label"]
	if bool(get_meta("selected", false)) != selected:
		UiKit.style_button(self, false, selected)
		set_meta("selected", selected)

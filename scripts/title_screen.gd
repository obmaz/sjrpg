extends Control
## Main title (원본: lib/src/app/title_screen.dart).

signal start_requested

var _prompt: Label
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.cover(preload("res://assets/art/ui/guardian-title.png")))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_bottom = -60
	box.alignment = BoxContainer.ALIGNMENT_END
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var title := UiKit.label("자연의 수호자", 54, UiKit.GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_prompt = UiKit.label("화면을 눌러 시작하세요", 26)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_prompt)


func _process(delta: float) -> void:
	_time += delta
	_prompt.modulate.a = 0.55 + 0.45 * sin(_time * 3.0)


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		start_requested.emit()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		start_requested.emit()

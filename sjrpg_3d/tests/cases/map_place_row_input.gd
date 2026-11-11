extends TestCase


func run() -> void:
	var row := MapPlaceRow.new().setup(
		1, {"id": "sanctuary:cave", "label": "동굴", "color": Color.WHITE}
	)
	add_child(row)
	row.size = Vector2(300, 100)
	var selections: Array[int] = []
	row.pressed.connect(func(): selections.append(1))
	_touch(row, true)
	_drag(row, Vector2(0, -40))
	_drag(row, Vector2(0, 40))
	_touch(row, false)
	check("reversing a scroll never becomes a tap", selections.is_empty())
	_touch(row, true)
	_drag(row, Vector2(2, 3))
	_touch(row, false)
	check("small finger jitter still permits a deliberate tap", selections.size() == 1)
	_touch(row, true)
	var cancel := InputEventScreenTouch.new()
	cancel.index = 0
	cancel.canceled = true
	cancel.position = Vector2(30, 30)
	row._gui_input(cancel)
	_touch(row, false)
	check("a canceled gesture never selects", selections.size() == 1)
	_touch(row, true)
	var second := InputEventScreenTouch.new()
	second.index = 1
	second.pressed = true
	second.position = Vector2(30, 30)
	row._gui_input(second)
	_drag(row, Vector2(0, 40))
	_touch(row, false)
	check("a second finger cannot reset a scrolling finger", selections.size() == 1)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(30, 30)
	row._gui_input(down)
	for offset in [Vector2(40, 0), Vector2(-40, 0)]:
		var motion := InputEventMouseMotion.new()
		motion.relative = offset
		row._gui_input(motion)
	down.pressed = false
	row._gui_input(down)
	check("reversing a mouse drag also never becomes a click", selections.size() == 1)
	row.queue_free()
	await _frames(2)


func _touch(row: MapPlaceRow, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.pressed = down
	event.position = Vector2(30, 30)
	row._gui_input(event)


func _drag(row: MapPlaceRow, offset: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.relative = offset
	row._gui_input(event)

extends TestCase


func run() -> void:
	var panel := PanelFrame.new()
	add_child(panel)
	await _frames(2)
	var wrapper := Control.new()
	panel.body.add_child(wrapper)
	var button := Button.new()
	wrapper.add_child(button)
	check("dynamically added body buttons pass gestures to scroll", button.mouse_filter == Control.MOUSE_FILTER_PASS and wrapper.mouse_filter == Control.MOUSE_FILTER_PASS)
	var footer_button := Button.new()
	panel.footer.add_child(footer_button)
	check("footer buttons keep their own input boundary", footer_button.mouse_filter == Control.MOUSE_FILTER_STOP)
	var slider := HSlider.new()
	panel.body.add_child(slider)
	var slider_child := Button.new()
	slider.add_child(slider_child)
	check("range controls keep their drag ownership", slider_child.mouse_filter == Control.MOUSE_FILTER_STOP)
	var cell := BagPanel.GearCell.new()
	cell.setup(null, "armor")
	cell.size = Vector2(90, 90)
	panel.body.add_child(cell)
	var selections := [0]
	cell.pressed.connect(func(): selections[0] += 1)
	_touch(cell, true)
	check("inventory cells wait for release", selections[0] == 0)
	_touch(cell, false)
	check("short inventory tap selects once", selections[0] == 1)
	_touch(cell, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.relative = Vector2(0, -30)
	cell._gui_input(drag)
	_touch(cell, false)
	check("inventory swipe does not activate item", selections[0] == 1)
	_touch(cell, true)
	cell.notification(Control.NOTIFICATION_SCROLL_BEGIN)
	_touch(cell, false)
	check("ancestor scroll cancels pending cell activation", selections[0] == 1)
	panel.queue_free()
	await _frames(2)


func _touch(cell: Control, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = Vector2(20, 20)
	event.pressed = down
	cell._gui_input(event)

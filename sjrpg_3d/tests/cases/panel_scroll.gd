extends TestCase


class CountedFrame:
	extends PanelFrame
	var layout_calls := 0

	func _layout() -> void:
		layout_calls += 1
		super._layout()


func run() -> void:
	check("Android physical pixels convert to dp before UI units", is_equal_approx(
		UiMetrics.units_for_display(Vector2(720, 1280), Vector2(1080, 1920), 3.0), 2.0))
	check("web CSS pixels do not receive an extra DPR factor", is_equal_approx(
		UiMetrics.units_for_display(Vector2(720, 1280), Vector2(360, 640)), 2.0))
	for unavailable: Vector2 in [Vector2.ZERO, Vector2(0, 1280), Vector2(720, 0),
			Vector2(-720, 1280), Vector2(720, -1280)]:
		check("unready viewport keeps a neutral scale %s" % unavailable,
			UiMetrics.units_for_display(unavailable, Vector2(1080, 1920), 3.0) == 1.0)
		check("unready Android surface keeps a neutral scale %s" % unavailable,
			UiMetrics.units_for_display(Vector2(720, 1280), unavailable, 3.0) == 1.0)
	check("ready surface restores its dp scale after fold transition", is_equal_approx(
		UiMetrics.units_for_display(Vector2(1280, 720), Vector2(1920, 1080), 3.0), 2.0))
	check("detached UI can request scale safely", UiMetrics.units_per_display_pixel(null) == 1.0)
	check("panel/card style uses its real content boundary", UiKit.panel_style() is StyleBoxFlat)
	var panel := CountedFrame.new()
	add_child(panel)
	await _frames(2)
	# 실제 목록을 한 번에 만들 때 노드마다 전체 서브트리를 다시 측정하지 않는다.
	await _frames(3)
	var before_layouts := panel.layout_calls
	var batch := VBoxContainer.new()
	panel.body.add_child(batch)
	for index: int in 40:
		batch.add_child(UiKit.label("일괄 목록 %d" % index, 18))
	await _frames(5)
	var layout_passes := panel.layout_calls - before_layouts
	check("bulk body construction uses a bounded number of layout passes",
		layout_passes >= 1 and layout_passes <= 4)
	check("coalesced layout still measures the completed body", batch.size.y > 100.0)
	panel.body.remove_child(batch)
	batch.queue_free()
	await _frames(2)
	var wrapper := Control.new()
	panel.body.add_child(wrapper)
	var button := Button.new()
	wrapper.add_child(button)
	check("dynamically added body buttons pass gestures to scroll", button.mouse_filter == Control.MOUSE_FILTER_PASS and wrapper.mouse_filter == Control.MOUSE_FILTER_PASS)
	var decoration := Control.new()
	button.add_child(decoration)
	check("late button decoration passes gestures through to the real scroll",
		decoration.mouse_filter == Control.MOUSE_FILTER_PASS)
	var decoration_slider := HSlider.new()
	button.add_child(decoration_slider)
	check("interactive button children retain their own drag boundary",
		decoration_slider.mouse_filter == Control.MOUSE_FILTER_STOP)
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

extends TestCase


class CountedFrame:
	extends PanelFrame
	var layout_calls := 0

	func _layout() -> void:
		layout_calls += 1
		super._layout()


class PhoneFrame:
	extends PanelFrame

	func display_pixel_scale() -> float:
		return 720.0 / 390.0


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
	var frame_skin := UiKit.frame_style()
	check("main panel keeps the actual generated ornate source", frame_skin.source_path.ends_with("/panel_ornate_frame.png"))
	check("ornate corners reserve an inner content inset", frame_skin.get_content_margin(SIDE_LEFT) >= 34.0 and frame_skin.get_content_margin(SIDE_TOP) >= 34.0)
	var primary_button := UiKit.button("두 줄로 이어지는 긴 행동 문구", 22)
	UiKit.style_button(primary_button, true)
	var primary_skin := primary_button.get_theme_stylebox("normal") as UiKit.GeneratedSkin
	check("primary action keeps the actual generated gold source", primary_skin != null and primary_skin.source_path.ends_with("/button_gold_primary.png"))
	var card_skin := UiKit.card_style(true, true)
	check("selected cards keep the generated source and dim without editing pixels", card_skin.source_path.ends_with("/slot_card_selected.png") and card_skin.tint.is_equal_approx(Color(0.8, 0.8, 0.8)))
	var selected_tab := UiKit.GeneratedSkin.new()
	selected_tab.configure("button", false, true)
	selected_tab.set_button_geometry(82.0, true)
	var idle_tab := UiKit.GeneratedSkin.new()
	idle_tab.configure("button")
	idle_tab.set_button_geometry(82.0, true)
	check("selected compact tab uses its actual gold selected-card source",
		selected_tab.drawn_source_path().ends_with("/slot_card_selected.png")
		and idle_tab.drawn_source_path().ends_with("/frame_bronze_9patch.png")
		and selected_tab.drawn_source_path() != idle_tab.drawn_source_path())
	selected_tab.set_button_geometry(82.0, false)
	check("wide selected action keeps the selected-card source",
		selected_tab.drawn_source_path().ends_with("/slot_card_selected.png"))
	check("primary action keeps its gold arrow source",
		primary_skin.drawn_source_path().ends_with("/button_gold_primary.png"))
	primary_button.free()
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
	await _generated_button_insets()
	await _arrow_scroll_state()



func _touch(cell: Control, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = Vector2(20, 20)
	event.pressed = down
	cell._gui_input(event)


func _generated_button_insets() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(720, 1558)
	add_child(view)
	var panel := PhoneFrame.new()
	view.add_child(panel)
	panel.set_header("스킬", "서로 다른 너비의 실제 행동 버튼")
	panel.body.add_child(PanelFrame.wrap_label("장식 안쪽의 글자 여백을 확인합니다.", 18))
	var reset := panel.add_footer("스킬 초기화", func(): pass, false, 1.0)
	var resume := panel.add_footer("모험 계속하기", func(): pass, true, 2.0)
	await _frames(8)
	for button: Button in [reset, resume]:
		var font := button.get_theme_font("font")
		var text_width := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			button.get_theme_font_size("font_size")).x
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			var skin := button.get_theme_stylebox(state) as UiKit.GeneratedSkin
			if state == "focus" and button.has_meta("gamepad_focus_style"):
				var outline := button.get_theme_stylebox(state) as StyleBoxFlat
				check("controller focus remains a separate transparent outline",
					outline != null and is_zero_approx(outline.bg_color.a))
				continue
			if not check("painted button state keeps its generated source " + state, skin != null):
				continue
			var left := skin.get_content_margin(SIDE_LEFT)
			var right := skin.get_content_margin(SIDE_RIGHT)
			var top := skin.get_content_margin(SIDE_TOP)
			var bottom := skin.get_content_margin(SIDE_BOTTOM)
			check("generated action reserves symmetric painted-border insets " + state,
				is_equal_approx(left, right) and is_equal_approx(top, bottom))
			if not skin.button_compact:
				check("both pointed caps keep the text inside the painted face " + state,
					left >= button.size.y * 0.55 - 0.1 and right >= button.size.y * 0.55 - 0.1)
			check("actual button minimum includes both text-side insets " + state,
				button.get_combined_minimum_size().x + 0.1 >= text_width + left + right)
		check("generated footer preserves 14dp text and 44dp touch size",
			float(button.get_theme_font_size("font_size")) / panel.display_pixel_scale() >= 14.0
			and button.size.y / panel.display_pixel_scale() >= 44.0)
	view.queue_free()
	await _frames(2)


func _arrow_scroll_state() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(720, 1558)
	add_child(view)
	var panel := PhoneFrame.new()
	view.add_child(panel)
	for index: int in 40:
		panel.body.add_child(PanelFrame.wrap_label("스크롤 항목 %d" % index, 20))
	panel.add_footer("닫기", func(): pass, true)
	await _frames(8)
	var arrows: ScrollArrows
	for child: Node in panel.scroll.get_children(true):
		if child is ScrollArrows:
			arrows = child as ScrollArrows
	check("scrolling keeps its actual range while native bars stay hidden", panel.scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER and not panel.scroll.get_v_scroll_bar().visible and panel.scroll.get_v_scroll_bar().max_value > panel.scroll.get_v_scroll_bar().page)
	if check("overflow has the generated direction cues", arrows != null):
		check("top of list shows only the remaining downward direction", arrows._remaining.x == 0.0 and arrows._remaining.y == 1.0)
		panel.scroll.scroll_vertical = 100000
		await _frames(6)
		check("end of list reverses cues from actual scroll position", arrows._remaining.x == 1.0 and arrows._remaining.y == 0.0)
	view.queue_free()
	await _frames(2)

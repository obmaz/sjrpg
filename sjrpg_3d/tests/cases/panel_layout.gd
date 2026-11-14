extends TestCase

func run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	add_child(view)
	var panel := PanelFrame.new()
	view.add_child(panel)
	panel.set_compact()
	panel.set_header("보급원 미라", "제1장 · 숲 마을")
	panel.body.add_child(PanelFrame.wrap_label("북쪽 숲 고목의 쉼터에 있는 약초사에게 꾸러미를 전해 주세요.", 21))
	panel.add_footer("수락", func(): pass, true)
	for size in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(540, 960), Vector2i(720, 1280)]:
		view.size = size
		await _frames(5)
		_check_frame(panel, size, "short")
		if size.y > size.x:
			check("short dialogs leave room around their content", panel._panel.size.y < size.y * 0.8)
	# Wrapped subtitles and a long scrollable body keep their own space after rotation.
	panel.set_header("파수꾼의 공터에서 모험을 준비하세요", "제1장 · 숲의 마지막 도전 · 의뢰와 준비 상태를 확인한 뒤 모험을 계속하세요")
	panel.clear_body()
	for i in 24:
		panel.body.add_child(PanelFrame.wrap_label("준비 안내 %d · 화면을 돌리거나 본문을 스크롤해도 제목과 행동 버튼은 고정됩니다." % i, 21))
	panel.add_footer("준비를 마치고 모험 계속하기", func(): pass, true)
	for size in [Vector2i(540, 960), Vector2i(1280, 720), Vector2i(720, 1280)]:
		view.size = size
		await _frames(6)
		_check_frame(panel, size, "wrapped")
		var footer_at := panel.footer.get_global_rect()
		panel.scroll.scroll_vertical = 100000
		await _frames(3)
		check("long body scrolls without moving footer %s" % size, panel.scroll.scroll_vertical > 0 and panel.footer.get_global_rect().is_equal_approx(footer_at))
		check("last paragraph is reachable above footer %s" % size, panel.body.get_global_rect().end.y <= panel.body_holder.get_global_rect().end.y + 1.0)
		panel.scroll.scroll_vertical = 0
		if size.x == 540:
			check("long actions stack inside narrow dialog", panel.footer.vertical)
	# Full panels share the same header rhythm and leave scrollable room beneath tabs.
	panel.compact = false
	panel.set_tabs(["전체", "안식처·워프 이동", "모험 기록"], 0, func(_index): pass)
	for size in [Vector2i(720, 1280), Vector2i(1280, 720)]:
		view.size = size
		await _frames(6)
		_check_frame(panel, size, "full")
		check("tabs remain between header and body %s" % size, panel._header.get_global_rect().end.y < panel.tab_scroll.get_global_rect().position.y and panel.tab_scroll.get_global_rect().end.y < panel.body_holder.get_global_rect().position.y)
	view.queue_free()
	await _frames(2)


func _check_frame(panel: PanelFrame, size: Vector2i, scenario: String) -> void:
	var context := "%s %s" % [scenario, size]
	var bounds := Rect2(Vector2.ZERO, Vector2(size))
	var frame := panel._panel.get_global_rect()
	var close: Button = panel._close
	check("popup title remains centered across the full frame " + context,
		panel.title_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
		and absf(panel.title_label.get_global_rect().get_center().x - frame.get_center().x) < 1.0)
	check("dialog stays in viewport " + context, bounds.encloses(frame))
	check("title and subtitle have breathing room " + context, panel.subtitle_label.get_global_rect().position.y - panel.title_label.get_global_rect().end.y >= 9.9)
	check("subtitle stays above body " + context, panel.subtitle_label.get_global_rect().end.y + 18.0 <= panel.body_holder.get_global_rect().position.y)
	check("header and actions stay inside panel " + context, frame.encloses(panel._header.get_global_rect()) and frame.encloses(panel.footer.get_global_rect()))
	check("close stays circular and touchable " + context, close.size.is_equal_approx(Vector2(64, 64)))
	check("body and actions have breathing room " + context, panel.body_holder.get_global_rect().end.y + 17.9 <= panel.footer.get_global_rect().position.y)
	check("body keeps usable scroll height " + context, panel.body_holder.size.y >= 96.0)

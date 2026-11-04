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
	for size in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(720, 1280)]:
		view.size = size
		await _frames(5)
		var bounds := Rect2(Vector2.ZERO, Vector2(size))
		check("dialog stays in viewport after orientation change %s" % size, bounds.encloses(panel._panel.get_global_rect()))
		check("dialog content and actions do not overlap %s" % size, panel.body_holder.get_global_rect().end.y <= panel.footer.get_global_rect().position.y)
		check("header and footer stay inside panel %s" % size, panel._panel.get_global_rect().encloses(panel.title_label.get_global_rect()) and panel._panel.get_global_rect().encloses(panel.footer.get_global_rect()))
		if size.y > size.x:
			check("short dialogs leave room around their content", panel._panel.size.y < size.y * 0.8)
	view.queue_free()
	await _frames(2)

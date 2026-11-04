extends TestCase
## Skill trees must remain readable/touchable on a short landscape viewport, including the last tier.

func run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	add_child(view)
	GameState.new_game("mage")
	var panel := SkillTreePanel.new()
	view.add_child(panel)
	for dimensions in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(720, 1560)]:
		view.size = dimensions
		await _frames(5)
		var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
		check("skill panel fits rotated viewport %s" % dimensions, bounds.encloses(panel._panel.get_global_rect()))
		var bottom := Rect2()
		for id in panel._nodes:
			var node: Rect2 = panel._nodes[id]
			check("skill target remains at least 64 units %s/%s" % [dimensions, id], node.size.x >= 64 and node.size.y >= 64)
			check("slot badge has upper breathing room %s/%s" % [dimensions, id], node.position.y >= 12)
			if node.end.y > bottom.end.y:
				bottom = node
		var tree_scroll: ScrollContainer = panel._tree.get_parent()
		tree_scroll.scroll_vertical = 10000
		await _frames(2)
		check("last tier can be reached by scrolling %s" % dimensions, tree_scroll.get_global_rect().intersects(Rect2(panel._tree.global_position + bottom.position, bottom.size)))
		tree_scroll.scroll_vertical = 0
		await _frames(2)
	var original: String = panel._selected
	var target := ""
	for id in panel._nodes:
		if id != original:
			target = id
			break
	var at: Vector2 = panel._nodes[target].get_center()
	var touch := InputEventScreenTouch.new()
	touch.index = 5
	touch.position = at
	touch.pressed = true
	panel._tree_input(touch)
	touch.pressed = false
	panel._tree_input(touch)
	check("a phone tap selects the intended skill", panel._selected == target)
	panel._selected = original
	touch.pressed = true
	panel._tree_input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 5
	drag.position = at + Vector2(0, 35)
	drag.relative = Vector2(0, 35)
	panel._tree_input(drag)
	touch.pressed = false
	touch.position = drag.position
	panel._tree_input(touch)
	check("scrolling does not accidentally select a skill", panel._selected == original)
	# Dispatch a platform-independent pan through the real GUI path.
	# Headless cannot emulate DisplayServer touchscreen capability; browser touch drags are checked separately.
	view.size = Vector2i(1280, 720)
	await _frames(4)
	panel._tree_scroll.scroll_vertical = 0
	await _frames(2)
	var target_center: Vector2 = panel._tree.global_position + panel._nodes[target].get_center()
	var start_selection: String = panel._selected
	var down := InputEventScreenTouch.new()
	down.index = 8
	down.position = target_center
	down.pressed = true
	view.push_input(down, true)
	await _frames(1)
	var pan := InputEventPanGesture.new()
	pan.position = target_center
	pan.delta = Vector2(0, 4)
	view.push_input(pan, true)
	await _frames(2)
	down.pressed = false
	view.push_input(down, true)
	await _frames(2)
	check("viewport pan scrolls tree without selecting", panel._tree_scroll.scroll_vertical > 0 and panel._selected == start_selection, "scroll=%d selected=%s" % [panel._tree_scroll.scroll_vertical, panel._selected])
	panel._tree_scroll.scroll_vertical = 0
	await _frames(3)
	down.index = 9
	down.position = panel._tree.global_position + panel._nodes[target].get_center()
	down.pressed = true
	view.push_input(down, true)
	down.pressed = false
	view.push_input(down, true)
	await _frames(2)
	check("a new tap still works after the scroll container claimed a gesture", panel._selected == target)
	view.queue_free()
	await _frames(2)

extends TestCase
## Focus ownership contracts; raw physical-pad edges are covered by gamepad_input.
func run() -> void:
	var old_mode: bool = Gamepad.using_gamepad
	var old_process := process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS
	var nav := Gamepad.get_node("Navigation") as GamepadNavigation
	var outer := PanelFrame.new()
	add_child(outer)
	outer.set_header("패드 검수")
	var disabled := UiKit.button("사용 불가")
	disabled.disabled = true
	outer.body.add_child(disabled)
	var first := UiKit.button("첫 동작")
	first.set_meta("gamepad_key", "first")
	outer.body.add_child(first)
	var queued := UiKit.button("삭제 중")
	outer.body.add_child(queued)
	queued.queue_free()
	for index in 64:
		outer.body.add_child(PanelFrame.wrap_label("긴 설명 %d" % index, 22))
	var last := UiKit.button("마지막 동작")
	last.set_meta("gamepad_key", "last")
	outer.body.add_child(last)
	var hidden := UiKit.button("숨김")
	hidden.hide()
	outer.body.add_child(hidden)
	await _frames(2)
	Gamepad.using_gamepad = false
	nav._process(0.11)
	nav._refresh()
	var touch_focus := first.get_theme_stylebox("focus") as StyleBoxFlat
	check("touch selection has no controller outline", touch_focus != null and touch_focus.border_width_left == 0)
	Gamepad.using_gamepad = true
	nav._process(0.11)
	nav._refresh()
	var pad_focus := first.get_theme_stylebox("focus") as StyleBoxFlat
	check("real controller keeps a visible focus outline", pad_focus != null and pad_focus.border_width_left == 2)
	var snapshot := nav.review_snapshot()
	check("ordered scope excludes disabled hidden and queued actions",
		snapshot["target_keys"].has("first") and snapshot["target_keys"].has("last")
		and not snapshot["target_keys"].has("text:사용 불가")
		and not snapshot["target_keys"].has("text:숨김")
		and not snapshot["target_keys"].has("text:삭제 중"))
	first.grab_focus()
	nav._action("nav_down")
	check("pad down follows logical action order", get_viewport().gui_get_focus_owner() == last)
	check("focused long-body action scrolls into view", outer.scroll.scroll_vertical > 0)
	var previous := last
	outer.body.remove_child(previous)
	previous.queue_free()
	var replacement := UiKit.button("마지막 동작")
	replacement.set_meta("gamepad_key", "last")
	outer.body.add_child(replacement)
	nav._refresh()
	check("rebuilt semantic action restores focus", get_viewport().gui_get_focus_owner() == replacement)
	var confirm := PanelFrame.new()
	outer.add_child(confirm)
	confirm.set_header("삭제 확인")
	var cancelled := [false]
	var destroyed := [false]
	var cancel := confirm.add_footer("취소", func():
		cancelled[0] = true
		confirm.queue_free())
	confirm.add_footer("영구 삭제", func(): destroyed[0] = true)
	get_tree().paused = true
	nav._process(0.11)
	nav._refresh()
	check("nested confirmation traps focus at safe cancel during pause",
		get_viewport().gui_get_focus_owner() == cancel and nav.review_snapshot()["focus_inside"])
	nav._action("roll")
	check("B cancels only the top confirmation", cancelled[0] and not destroyed[0]
		and not outer.is_queued_for_deletion())
	get_tree().paused = false
	await _frames(1)
	var loading := Control.new()
	loading.add_to_group("entry_loading")
	add_child(loading)
	var activated := [0]
	first.pressed.connect(func(): activated[0] += 1)
	first.grab_focus()
	nav._action("primary")
	nav._action("roll")
	check("real loading scope blocks A and B activation", nav.loading_blocked()
		and not nav.has_scope() and activated[0] == 0 and not outer.is_queued_for_deletion())
	loading.free()
	outer.free()
	await _frames(1)
	GameState.new_game("mage")
	var skills := SkillTreePanel.new()
	add_child(skills)
	await _frames(2)
	Gamepad.using_gamepad = true
	nav._process(0.11)
	nav._refresh()
	check("custom-drawn skill graph exposes actual focusable skill targets",
		not skills._pad_nodes.is_empty())
	if not skills._pad_nodes.is_empty():
		var id: String = skills._pad_nodes.keys()[0]
		var button := skills._pad_nodes[id] as Button
		button.grab_focus()
		check("focusing a graph node selects its actual detail", skills._selected == id)
		nav._action("primary")
		await _frames(1)
		var focus := get_viewport().gui_get_focus_owner()
		check("A reaches actual learn or assignment controls", focus != null
			and (skills._detail.is_ancestor_of(focus) or focus == button))
		if focus != null and skills._detail.is_ancestor_of(focus):
			nav._action("roll")
			check("B returns from detail to the selected graph node", get_viewport().gui_get_focus_owner() == button)
	skills.free()
	Gamepad.using_gamepad = old_mode
	Gamepad.require_neutral()
	process_mode = old_process

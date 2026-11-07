extends TestCase
## Idle entry UI must not rebuild/serialize its read-only browser probe each frame.
func run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	add_child(view)
	var select := preload("res://scripts/class_select.gd").new()
	view.add_child(select)
	select.show_slots()
	await _frames(10)
	var settled: int = select.probe_activity()["flushes"]
	await _frames(30)
	check("idle save selection has no script process or recurring probe flush",
		not select.is_processing() and int(select.probe_activity()["flushes"]) == settled)
	for index in 128:
		select._queue_publish_buttons()
	await _frames(2)
	check("many control changes coalesce into one deferred probe flush",
		int(select.probe_activity()["flushes"]) == settled + 1 and not bool(select.probe_activity()["pending"]))
	var before: int = select.probe_activity()["flushes"]
	var active := GameState.active_slot
	var hero := GameState.hero_class
	select.select_slot(2)
	await _frames(8)
	check("actual selection still schedules updated control probes without changing the live save",
		select.selected_slot == 2 and int(select.probe_activity()["flushes"]) > before
		and GameState.active_slot == active and GameState.hero_class == hero)
	var again: int = select.probe_activity()["flushes"]
	await _frames(20)
	check("selection settles back to zero idle probe work", int(select.probe_activity()["flushes"]) == again)
	var before_move: int = select.probe_activity()["flushes"]
	var old_position: Vector2 = select.back_button.position
	var old_size: Vector2 = select.back_button.size
	select.back_button.position += Vector2(1.0, 0.0)
	await _frames(3)
	check("position-only UI changes refresh probes without an idle poll or resize",
		int(select.probe_activity()["flushes"]) > before_move and select.back_button.size == old_size)
	select.back_button.position = old_position
	await _frames(3)
	select.back_button.grab_focus()
	await _frames(3)
	var before_blur: int = select.probe_activity()["flushes"]
	select.back_button.release_focus()
	await _frames(3)
	check("focus release schedules a real probe update without an idle poll",
		int(select.probe_activity()["flushes"]) > before_blur and view.gui_get_focus_owner() != select.back_button)
	var before_parent_move: int = select.probe_activity()["flushes"]
	var old_list_position: Vector2 = select.slot_list.position
	var old_scroll_value: int = select.slot_scroll.scroll_vertical
	select.slot_list.position += Vector2(0.0, -3.0)
	await _frames(4)
	check("scroll ancestor movement refreshes probes even without a scrollbar-value event",
		int(select.probe_activity()["flushes"]) > before_parent_move
		and select.slot_scroll.scroll_vertical == old_scroll_value)
	select.slot_list.position = old_list_position
	await _frames(4)
	view.queue_free()
	await _frames(3)

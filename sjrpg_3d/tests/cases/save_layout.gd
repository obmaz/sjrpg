extends TestCase
## Save-state geometry and guarded callbacks; browser harness supplies real input/visual proof.
const REVIEW := preload("res://scripts/inspection/save_layout_review.gd")
const SELECT := preload("res://scripts/ui/screens/class_select.gd")
const EPS := 1.5


func _inside(outer: Rect2, inner: Rect2) -> bool:
	return outer.grow(EPS).encloses(inner)


func _layout_check(select: Control, view: SubViewport, scenario: String) -> void:
	var area := Rect2(Vector2.ZERO, Vector2(view.size))
	var list: Rect2 = select.slot_scroll.get_global_rect()
	var footer: Rect2 = select.slot_footer.get_global_rect()
	var label := "%s/%s" % [scenario, view.size]
	check("save list and fixed action footer fit the real control viewport " + label, _inside(area, list) and _inside(area, footer) and list.size.y >= 44.0 and list.end.y <= footer.position.y + EPS)
	check("save title and subtitle stay separate " + label, select.heading.get_global_rect().end.y <= select.subtitle.get_global_rect().position.y + EPS)
	check("wrapped subtitle stays above the real scrolling list " + label, select.subtitle.get_global_rect().end.y <= list.position.y + EPS)
	check("footer context stays separate from its main action " + label, _inside(footer, select.slot_context.get_global_rect()) and select.slot_context.get_global_rect().end.y <= select.continue_button.get_global_rect().position.y + EPS)
	check("save sheet exposes exactly four real source rows " + label, select.slot_buttons.size() == 4 and select.slot_bands.size() == 4)
	if not select._slot_overflow:
		var last_row: Rect2 = select.slot_bands[3].get_global_rect()
		check("all-visible save cards fill the body up to the fixed action on unfolded screens " + label,
			footer.position.y - last_row.end.y <= 40.0
			and _inside(list, last_row))
	var summaries := GameState.slot_summaries()
	for index in 4:
		var row: Button = select.slot_buttons[index]
		var band: HBoxContainer = select.slot_bands[index]
		var remove: Button = select.delete_buttons[index]
		var title: Label = select.slot_title_labels[index]
		var meta: Label = select.slot_meta_labels[index]
		var number: Label = select.slot_number_labels[index]
		var box := band.get_global_rect()
		check("real row width remains inside its scroll clip " + label, box.position.x >= list.position.x - EPS and box.end.x <= list.end.x + EPS)
		check("real row hitbox remains usable " + label, row.size.y >= 44.0 and row.size.x >= 44.0)
		check("save rows and intermediate containers pass real finger drags to their list " + label,
			row.mouse_filter == Control.MOUSE_FILTER_PASS
			and band.mouse_filter == Control.MOUSE_FILTER_PASS
			and select.slot_list.mouse_filter == Control.MOUSE_FILTER_PASS)
		check("row has structured, readable identity and metadata " + label, title.get_theme_font_size("font_size") >= 14 and meta.get_theme_font_size("font_size") >= 14 and not title.text.is_empty() and not meta.text.is_empty() and not number.text.is_empty())
		check("row text has enough measured height " + label, title.size.y + EPS >= title.get_combined_minimum_size().y and meta.size.y + EPS >= meta.get_combined_minimum_size().y)
		if meta.is_visible_in_tree():
			check("saved time and recovery instructions show every wrapped line " + label,
				meta.get_visible_line_count() == meta.get_line_count())
		var metadata_fits := not meta.is_visible_in_tree() or (_inside(row.get_global_rect(), meta.get_global_rect()) and title.get_global_rect().end.y <= meta.get_global_rect().position.y + EPS)
		var contained := _inside(row.get_global_rect(), title.get_global_rect()) and metadata_fits and not number.get_global_rect().intersects(title.get_global_rect())
		if not contained:
			print("FAIL SAVE_TEXT_DIAG ", JSON.stringify({"label": label, "slot": index + 1, "row": str(row.get_global_rect()), "band": str(box), "title": str(title.get_global_rect()), "meta": str(meta.get_global_rect()), "number": str(number.get_global_rect()), "status": str(select.slot_status_labels[index].get_global_rect()), "minimum": str(meta.get_combined_minimum_size())}))
		check("visible row labels retain their own measured space " + label, contained)
		var text_bottom := meta.get_global_rect().end.y if meta.is_visible_in_tree() else title.get_global_rect().end.y
		var text_center := (title.get_global_rect().position.y + text_bottom) * 0.5
		check("identity and metadata stay centered together in their real save target " + label,
			absf(text_center - row.get_global_rect().get_center().y) <= EPS)
		check("only real occupied saves show a second metadata line " + label, meta.is_visible_in_tree() == bool(summaries[index]["occupied"]))
		check("delete exists only for occupied source files " + label, remove.is_visible_in_tree() == bool(summaries[index]["occupied"]))
		if remove.is_visible_in_tree():
			check("dragging over the separate delete target can scroll without consuming the gesture " + label,
				remove.mouse_filter == Control.MOUSE_FILTER_PASS)
			check("select and delete have distinct usable targets " + label, not row.get_global_rect().intersects(remove.get_global_rect()) and remove.size.x >= 44.0 and remove.size.y >= 44.0 and _inside(box, remove.get_global_rect()))
		if index > 0:
			check("measured save rows do not overlap " + label, select.slot_bands[index - 1].get_global_rect().end.y < box.position.y)
		row.grab_focus()
		await _frames(3)
		if not _inside(list, row.get_global_rect()):
			print("FAIL SAVE_FOCUS_DIAG ", JSON.stringify({"scenario": label, "slot": index + 1, "clip_before": str(list), "clip_now": str(select.slot_scroll.get_global_rect()), "row": str(row.get_global_rect()), "scroll": select.slot_scroll.scroll_vertical, "max": select.slot_scroll.get_v_scroll_bar().max_value, "page": select.slot_scroll.get_v_scroll_bar().page}))
		check("keyboard focus brings every actual row fully into the list " + label, _inside(list, row.get_global_rect()))
	check("scrolling never moves the fixed footer " + label, select.slot_footer.get_global_rect().is_equal_approx(footer))


func _modal_check(select: Control, view: SubViewport) -> void:
	select.select_slot(1)
	var before := REVIEW.file_hashes()
	var hero := GameState.hero_class
	var gold := GameState.gold
	var active := GameState.active_slot
	var emitted := {"continue": 0, "chosen": 0, "back": 0}
	select.continue_requested.connect(func(): emitted["continue"] += 1)
	select.chosen.connect(func(_cls: String): emitted["chosen"] += 1)
	select.back_requested.connect(func(): emitted["back"] += 1)
	select.confirm_delete(3)
	await _frames(4)
	var dialog: PanelFrame = select._delete_dialog
	if not check("a different slot opens its own deletion confirmation", is_instance_valid(dialog)):
		return
	var focus := view.gui_get_focus_owner()
	check("deletion initially focuses the safe cancel action", focus == dialog.footer.get_child(0))
	# Disabled native buttons alone are insufficient: stale deferred callbacks also need guards.
	select.continue_button.pressed.emit()
	select.back_button.pressed.emit()
	select._choose()
	select.select_slot(2)
	select.show_slots()
	check("modal blocks all background launch/navigation and preview changes", int(emitted["continue"]) == 0 and int(emitted["chosen"]) == 0 and int(emitted["back"]) == 0 and select.selected_slot == 1 and REVIEW.file_hashes() == before and GameState.hero_class == hero and GameState.gold == gold and GameState.active_slot == active)
	dialog.footer.get_child(0).pressed.emit()
	await _frames(4)
	check("cancel returns focus to the actual delete target, not the selected slot", view.gui_get_focus_owner() == select.delete_buttons[2] and select.selected_slot == 1 and REVIEW.file_hashes() == before)
	select.confirm_delete(3)
	await _frames(3)
	dialog = select._delete_dialog
	dialog.footer.get_child(1).pressed.emit()
	await _frames(4)
	var after := REVIEW.file_hashes()
	check("confirmed deletion changes exactly the explicitly named slot", after["1"] == before["1"] and after["2"] == before["2"] and after["4"] == before["4"] and not bool(GameState.slot_summaries()[2]["occupied"]) and select.selected_slot == 1)
	check("deleting another slot keeps the live hero untouched", GameState.hero_class == hero and GameState.gold == gold and GameState.active_slot == active)
	check("removed delete action restores focus to its remaining slot card", view.gui_get_focus_owner() == select.slot_buttons[2])
	check("a hidden empty-slot delete target cannot open another modal", not select.delete_buttons[2].is_visible_in_tree())
	select.confirm_delete(3)
	check("programmatic empty-slot delete is a safe no-op", not is_instance_valid(select._delete_dialog))


func _short_modal_check(select: Control, view: SubViewport) -> void:
	check("prepare short-window modal data using real storage", REVIEW.prepare_scenario("mixed"))
	select.selected_slot = 1
	select.refresh_slots()
	select.show_slots()
	view.size = Vector2i(568, 320)
	await _frames(4)
	select.confirm_delete(3)
	await _frames(5)
	var dialog: PanelFrame = select._delete_dialog
	if not check("short window keeps the real confirmation", is_instance_valid(dialog)):
		return
	var area := Rect2(Vector2.ZERO, Vector2(view.size))
	check("short confirmation remains inside the viewport", _inside(area, dialog._panel.get_global_rect()))
	check("warning body retains a readable or scrollable viewport", dialog.body_holder.size.y >= 24.0 and (dialog.body.size.y <= dialog.body_holder.size.y + EPS or dialog.scroll.get_v_scroll_bar().max_value > dialog.scroll.get_v_scroll_bar().page))
	for node in dialog.find_children("*", "Button", true, false):
		var button := node as Button
		if button.is_visible_in_tree():
			check("short confirmation actions stay accessible", _inside(area, button.get_global_rect()))
	dialog.closed.emit()
	await _frames(3)


func run() -> void:
	var old_path := GameState.slot_path(1)
	var old_slot := GameState.active_slot
	DirAccess.make_dir_recursive_absolute("user://tests")
	GameState.save_path = "user://tests/unrelated-save-layout.json"
	check("review helpers reject a non-review save namespace", not REVIEW.prepare_scenario("full") and REVIEW.file_hashes().is_empty())
	GameState.save_path = REVIEW.PREFIX + "-headless-%d.json" % Time.get_ticks_usec()
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	add_child(view)
	var select: Control
	for scenario: String in REVIEW.SCENARIOS:
		check("prepare actual independent file scenario " + scenario, REVIEW.prepare_scenario(scenario))
		select = SELECT.new()
		view.add_child(select)
		await _frames(3)
		select.show_slots()
		if scenario == "long":
			select.show_error("모험을 읽지 못했습니다. 다른 저장 슬롯을 선택하거나 잠시 후 다시 시도해 주세요. 기존 모험은 그대로 유지됩니다.")
		var before := REVIEW.file_hashes()
		var hero := GameState.hero_class
		var gold := GameState.gold
		var active := GameState.active_slot
		for dimensions in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(540, 960), Vector2i(568, 320), Vector2i(320, 568), Vector2i(360, 640), Vector2i(768, 896), Vector2i(896, 768), Vector2i(800, 800), Vector2i(344, 883), Vector2i(883, 344), Vector2i(720, 1280)]:
			view.size = dimensions
			await _frames(4)
			await _layout_check(select, view, scenario)
		check("layout, focus and rotation preserve exact save bytes " + scenario, REVIEW.file_hashes() == before and GameState.hero_class == hero and GameState.gold == gold and GameState.active_slot == active)
		if scenario == "mixed":
			await _modal_check(select, view)
			await _short_modal_check(select, view)
		select.queue_free()
		await _frames(3)
	for number in range(1, 5):
		GameState.delete_slot(number)
	view.queue_free()
	await _frames(2)
	GameState.save_path = old_path
	GameState.select_slot(old_slot)

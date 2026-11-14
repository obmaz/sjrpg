extends TestCase
## Runtime atlas, class identity and real mobile hit geometry; browser verifies the actual pictures/actions.

class PhoneTree:
	extends SkillTreePanel
	var test_css_scale := 2.25
	func display_pixel_scale() -> float:
		return test_css_scale


class PhoneSettings:
	extends SettingsPanel
	func display_pixel_scale() -> float:
		return 720.0 / 320.0


class SettingsGame:
	extends Node
	var dungeon := {"active": false}


func run() -> void:
	check("painted HUD atlas has its actual delivered dimensions", UiToneArt.icons().get_size() == Vector2(1536, 1024))
	check("painted avatars have their actual delivered dimensions", UiToneArt.portraits().get_size() == Vector2(1774, 887))
	var regions := {}
	for key in ["bag", "skills", "quests", "settings", "hp", "mp"]:
		var frame := UiToneArt.frame(key)
		check("each actual HUD region is a full distinct source cell", Rect2(Vector2.ZERO, UiToneArt.icons().get_size()).encloses(frame) and frame.size == Vector2(512, 512) and not regions.has(frame.position))
		regions[frame.position] = true
	var warrior := HudArt.portrait_uv("warrior")
	var mage := HudArt.portrait_uv("mage")
	check("class portraits remain separate and inside actual texture UVs", not warrior.intersects(mage) and Rect2(0, 0, 1, 1).encloses(warrior) and Rect2(0, 0, 1, 1).encloses(mage))
	check("real skill-node input supports a 44px phone target without neighboring overlap", (SkillTreePanel.NODE_SIDE + 16.0) / 2.25 >= 44.0 and (SkillTreePanel.TREE_MIN_WIDTH - SkillTreePanel.TIER_LABEL_WIDTH - 12.0) / 3.0 >= SkillTreePanel.NODE_SIDE + 16.0)
	for scale in [720.0 / 390.0, 720.0 / 320.0, 1280.0 / 568.0]:
		for preferred in [19, 18, 17]:
			var pixels := SkillTreePanel.graph_font_size(preferred, scale)
			check("canvas graph labels remain at least 14 display pixels", float(pixels) / scale >= 14.0)
		var rank_pixels := SkillTreePanel.graph_font_size(18, scale)
		check("measured rank ribbon fits its existing row gap", UiKit.BOLD_FONT.get_height(rank_pixels) + 10.0 <= SkillTreePanel.TIER_HEIGHT - SkillTreePanel.NODE_SIDE)
		for count in [0, 7, 99, 999, 5000]:
			var target: float = 22.0 * float(scale)
			var geometry := PotionArt.count_geometry(Vector2.ZERO, 20.0 * scale, count, scale, target)
			var rect: Rect2 = geometry["rect"]
			check("actual potion count remains at least 12 CSS pixels", float(geometry["font_size"]) / scale >= 12.0)
			if count < 10:
				check("common potion counts clear the vial centre in a lower-right badge", rect.position.x > 0.0 and rect.position.y > 0.0)
			for point in [rect.position, rect.end, Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y)]:
				check("measured potion count ribbon stays inside its actual touch circle", point.length() <= target + 0.01)
		var point_scale: float = float(scale)
		for points: int in [1, 99]:
			var point_geometry: Dictionary = TouchControls.skill_points_geometry(Vector2.ZERO, 20.0 * point_scale, points, point_scale, 22.0 * point_scale)
			var point_rect: Rect2 = point_geometry["rect"]
			check("live skill-point quantity stays at least 12 CSS pixels", float(point_geometry["font_size"]) / point_scale >= 12.0)
			for corner: Vector2 in [point_rect.position, point_rect.end, Vector2(point_rect.position.x, point_rect.end.y), Vector2(point_rect.end.x, point_rect.position.y)]:
				check("skill-point badge stays within its existing menu touch circle", corner.length() <= 22.0 * point_scale + 0.01)
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	add_child(view)
	var panel := PhoneTree.new()
	view.add_child(panel)
	await _frames(4)
	panel._selected = str(GameState.starter_ids()[0])
	panel._build_detail()
	for dimensions in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(1558, 720), Vector2i(1280, 1100), Vector2i(1100, 1280)]:
		view.size = dimensions
		if dimensions.x == 1558:
			panel.test_css_scale = 1558.0 / 844.0
		elif mini(dimensions.x, dimensions.y) > 1000:
			panel.test_css_scale = float(dimensions.x) / (700.0 if dimensions.x == 1100 else 768.0)
		else:
			panel.test_css_scale = 720.0 / 320.0 if dimensions.y > dimensions.x else 1280.0 / 568.0
		panel._fit()
		# Run the common pass after the graph pass as deferred layout can do.
		# Both must retain the same 44dp target through every rotation.
		panel._layout()
		await _frames(5)
		check("skill graph and common frame use the same display scale", is_equal_approx(panel.graph_css_scale(), panel.display_pixel_scale()))
		for node in panel._detail.find_children("*", "Control", true, false):
			var control := node as Control
			if control is Label or control is Button:
				check("actual skill description/info/effects/slot controls retain 14 display pixels", float(control.get_theme_font_size("font_size")) / panel.test_css_scale >= 14.0)
			if control is Button:
				check("custom skill actions preserve the shared 16dp type minimum", float(control.get_theme_font_size("font_size")) / panel.test_css_scale >= 16.0)
				check("real learn and equip buttons retain 56 CSS pixel targets", control.size.x / panel.test_css_scale >= 56.0 and control.size.y / panel.test_css_scale >= 56.0, "view=%s action=%s size=%s minimum=%s scale=%s" % [dimensions, (control as Button).text, control.size, control.custom_minimum_size, panel.test_css_scale])
				check("skill action labels wrap instead of being truncated", not (control as Button).clip_text and (control as Button).text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING)
		var clipping := panel._detail.get_parent() as ScrollContainer
		check("larger skill text wraps within the real detail scroll viewport", panel._detail.size.x <= clipping.size.x + 1.0)
		check("folded skill columns stay inside the actual body", panel.body_holder.get_global_rect().encloses(panel._tree_scroll.get_global_rect()) and panel.body_holder.get_global_rect().encloses(panel._detail_panel.get_global_rect()))
		check("folded skill tree and detail never overlap", not panel._tree_scroll.get_global_rect().intersects(panel._detail_panel.get_global_rect()))
		if dimensions.x > dimensions.y:
			check("phone landscape uses the available skill workspace", panel._panel.size.x >= float(dimensions.x) - 40.0 * panel.test_css_scale)
			check("readable phone landscape places skill work areas side by side", not panel._layout_box.vertical and panel._tree_scroll.size.y >= panel.body_holder.size.y - 1.0 and panel._detail_panel.size.x / panel.test_css_scale >= 280.0)
	panel.queue_free()
	await _frames(2)
	view.size = Vector2i(720, 1280)
	var settings_game := SettingsGame.new()
	view.add_child(settings_game)
	var settings := PhoneSettings.new()
	settings.setup(settings_game)
	view.add_child(settings)
	await _frames(5)
	check("all real supported zoom choices are present", settings._zoom_buttons.size() == Prefs.WORLD_ZOOMS.size())
	for button in settings._zoom_buttons:
		check("actual zoom controls retain 44 CSS pixel targets", button.size.x / settings.display_pixel_scale() >= 44.0 and button.size.y / settings.display_pixel_scale() >= 44.0)
	# Narrow the actual option containers to exercise folding while the panel stays open.
	for width: float in [260.0, 400.0, 640.0]:
		for grid: GridContainer in [settings._zoom_grid, settings._screen_orientation_grid]:
			grid.columns = 1
			grid.size.x = width
			settings._fit_display_option_targets()
			var minimum := 56.0 * settings.display_pixel_scale()
			for button: Button in grid.get_children():
				minimum = maxf(minimum, button.get_combined_minimum_size().x)
			var gap := float(grid.get_theme_constant("h_separation"))
			check("folded settings choices keep their measured width", grid.columns * minimum + (grid.columns - 1) * gap <= width + 1.0 or grid.columns == 1)
	for copy: Label in settings.body.find_children("*", "Label", true, false):
		check("settings omit passive explanations", not copy.text.contains("해상도를") and not copy.text.contains("자동 저장") and not copy.text.contains("배경·캐릭터") and not copy.text.contains("현재 프레임"))
	var toggle := settings.find_child("ShowFps", true, false)
	var toggle_actions := toggle.find_children("*", "Button", true, false)
	check("settings toggle keeps one focusable whole-card action", toggle_actions.size() == 1 and (toggle_actions[0] as Button).focus_mode == Control.FOCUS_ALL)
	var switch_layout := toggle.find_child("SwitchLayout", true, false) as BoxContainer
	var switch_state := toggle.find_child("SwitchState", true, false) as SettingsPanel.ToggleState
	check("settings preserve the bronze toggle state", switch_state != null and switch_state.on == Prefs.show_fps)
	for width: float in [260.0, 720.0]:
		switch_layout.vertical = true
		switch_layout.size.x = width
		settings._fit_toggle_rows()
		check("settings switch copy and state seal adapt to available width", switch_layout.vertical == (width == 260.0))
		check("settings state seal keeps readable text", float(switch_state.font_pixels) / settings.display_pixel_scale() >= 14.0)
		check("whole-card switch keeps a 56dp touch height", (toggle_actions[0] as Button).custom_minimum_size.y / settings.display_pixel_scale() >= 56.0)
	view.queue_free()
	await _frames(2)
	await _check_run_choices()


func _check_run_choices() -> void:
	var before_ranks := GameState.ranks.duplicate(true)
	var before_expedition := GameState.expedition.duplicate(true)
	var ids: Array[String] = []
	for skill: Dictionary in GameState.skills():
		if not skill.get("passive", true):
			ids.append(str(skill["id"]))
			GameState.ranks[str(skill["id"])] = 1
		if ids.size() == 4:
			break
	GameState.expedition = {"phase": "missions", "signature": ids[0], "runes": {}, "rune_inventory": ["reach", "thrift"]}
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	add_child(view)
	var panel := RunBuildPanel.new()
	view.add_child(panel)
	await _frames(4)
	for button: Button in panel._skill_grid.get_children():
		if button.get_meta("run_skill") == ids[1]:
			button.pressed.emit()
			break
	await _frames(4)
	check("real run skill selector keeps the chosen skill and rune inventory", panel._selected == ids[1] and GameState.expedition["rune_inventory"] == ["reach", "thrift"] and GameState.expedition["runes"].is_empty())
	for dimensions in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(1280, 1100), Vector2i(540, 960)]:
		view.size = dimensions
		await _frames(4)
		check("run skill choices wrap within the real scroll width %s" % dimensions, panel._skill_grid.size.x <= panel.scroll.size.x + 1.0)
		var occupied: Array[Rect2] = []
		for button: Button in panel._skill_grid.get_children():
			check("run skill names keep whole text and touch height", button.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART and not button.clip_text and button.size.y >= 44.0)
			for other: Rect2 in occupied:
				check("run skill choices do not overlap", not button.get_global_rect().intersects(other))
			occupied.append(button.get_global_rect())
		await _frames(12)
		var settled_sizes: Array[Vector2] = []
		for button: Button in panel._skill_grid.get_children():
			settled_sizes.append(button.size)
		await _frames(12)
		for index: int in panel._skill_grid.get_child_count():
			var button: Button = panel._skill_grid.get_child(index)
			check("wrapped generated skill buttons settle without layout oscillation %s" % dimensions,
				button.size.is_equal_approx(settled_sizes[index]))
	var rune_actions := 0
	for button: Button in panel.body.find_children("*", "Button", true, false):
		if button.has_meta("gamepad_key") and str(button.get_meta("gamepad_key")).begins_with("run_rune:"):
			rune_actions += 1
	check("each acquired rune keeps one actual equipment action", rune_actions == 2)
	view.queue_free()
	await _frames(2)
	GameState.ranks = before_ranks
	GameState.expedition = before_expedition

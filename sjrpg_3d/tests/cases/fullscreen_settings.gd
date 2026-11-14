extends TestCase
## Accessible fullscreen control, paused live state and clean unsupported fallback.
## Real browser fullscreen gestures are covered by web/check_fullscreen.mjs.


func run() -> void:
	var previous_path := Prefs.settings_path
	var previous_orientation := Prefs.screen_orientation
	var previous_zoom := Prefs.world_zoom
	Prefs.settings_path = "user://tests/fullscreen-orientation.cfg"
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	add_child(view)
	GameState.new_game("mage")
	var game := preload("res://scripts/gameplay/game.gd").new()
	view.add_child(game)
	while not game.native_ready:
		await get_tree().physics_frame
		await _frames(1)
	var renderer: WorldRenderer3D = game.world_renderer
	var position: Vector2 = game.player.position
	var hp: float = game.player.hp
	game.hud.open_settings()
	await _frames(3)
	var panel: SettingsPanel = game.hud._panel
	check("settings use the footer instead of a duplicate close X", not panel._close.visible)
	for label: Label in panel.body.find_children("*", "Label", true, false):
		check("settings omit redundant group headings", label.text not in ["화면", "화면 방향", "화면 확대", "화면과 타격감", "진행", "모험 선택", "기기에 설치"])
	for card: PanelContainer in panel.body.find_children("*", "PanelContainer", true, false):
		check("settings rows do not draw nested card frames", card.get_theme_stylebox("panel") is StyleBoxEmpty)
	check("touch settings hide the gamepad instruction action", panel._gamepad_help_button.visible == Gamepad.using_gamepad)
	for dimensions in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(720, 1280)]:
		view.size = dimensions
		await _frames(3)
		var button := panel.find_child("FullscreenToggle", true, false) as Button
		if not check("settings expose one actual fullscreen button without passive subtext %s" % dimensions, button != null and panel.find_child("FullscreenHint", true, false) == null):
			continue
		var bounds := button.get_global_rect()
		check("fullscreen is a visible 64px+ top settings action %s" % dimensions, button.is_visible_in_tree() and bounds.size.y >= 64.0 and Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(bounds) and button.get_index() == 0)
		var state := Prefs.fullscreen_state()
		check("fullscreen button reflects real supported state %s" % dimensions, button.text == str(state["title"]) and button.disabled == (not bool(state["supported"]) or bool(state["pending"])))
		check("settings expose all orientation choices while paused", panel._screen_orientation_buttons.size() == 3 and panel.find_child("ScreenOrientationHint", true, false) == null)
		for choice: Button in panel._screen_orientation_buttons:
			check("orientation choices remain touchable after layout rotation %s" % dimensions, choice.size.y >= 64.0 and panel._panel.get_global_rect().encloses(choice.get_global_rect()))
		check("settings rotation keeps the same paused adventure", get_tree().paused and game.world_renderer == renderer and game.player.position == position and is_equal_approx(game.player.hp, hp))
	var portrait := panel.find_child("Orientation_portrait", true, false) as Button
	var orientation_grid := panel._screen_orientation_grid
	portrait.pressed.emit()
	await _frames(3)
	check("actual settings choice saves orientation and preserves the paused adventure", Prefs.screen_orientation == "portrait" and get_tree().paused and game.world_renderer == renderer and game.player.position == position)
	var selected := panel.find_child("Orientation_portrait", true, false) as Button
	check("orientation changes update the same controls without rebuilding settings", selected == portrait and selected.button_pressed and panel._screen_orientation_grid == orientation_grid)
	check("orientation shows a supported Korean selection label without a selected button color", (selected.get_node("OptionSelected") as Label).text == "선택" and (selected.get_node("OptionSelected") as Label).visible and selected.get_theme_stylebox("normal") is StyleBoxEmpty)
	var zoom_grid := panel._zoom_grid
	panel.scroll.scroll_vertical = 200
	await _frames(2)
	var scroll_position := panel.scroll.scroll_vertical
	var grid_bounds := zoom_grid.get_global_rect()
	var grid_columns := zoom_grid.columns
	var skins: Array[StyleBox] = []
	for zoom: Button in panel._zoom_buttons:
		skins.append(zoom.get_theme_stylebox("normal"))
	for index: int in panel._zoom_buttons.size():
		var zoom: Button = panel._zoom_buttons[index]
		zoom.pressed.emit()
		await _frames(3)
		check("zoom choice preserves controls, layout and scroll %s" % zoom.text,
			panel._zoom_grid == zoom_grid and zoom_grid.columns == grid_columns
			and zoom_grid.get_global_rect().is_equal_approx(grid_bounds)
			and panel.scroll.scroll_vertical == scroll_position)
		check("zoom choice keeps the same frameless touch target %s" % zoom.text,
			zoom.get_theme_stylebox("normal") == skins[index]
			and zoom.get_theme_stylebox("normal") is StyleBoxEmpty)
		check("zoom selection is visible without changing the option text %s" % zoom.text,
			(zoom.get_node("OptionSelected") as Label).visible and zoom.button_pressed)
	for action: Button in [panel._haptics_test_button, panel._sound_test_button]:
		check("settings test actions are centered in the content column %s" % action.text,
			action.alignment == HORIZONTAL_ALIGNMENT_CENTER
			and is_equal_approx(action.get_global_rect().get_center().x, panel.body.get_global_rect().get_center().x))
	if DisplayServer.get_name() == "headless":
		check("headless fullscreen reports unsupported instead of pretending it changed", not Prefs.fullscreen_supported() and not Prefs.is_fullscreen())
		Prefs.toggle_fullscreen()
		check("unsupported fullscreen call is a safe no-op", not Prefs.is_fullscreen())
	panel._confirm_restart()
	await _frames(2)
	panel._refresh_fullscreen()
	check("restart confirmation does not retain a stale fullscreen control", panel.find_child("FullscreenToggle", true, false) == null)
	game.hud.close_panel()
	view.queue_free()
	await _frames(2)
	Prefs.set_screen_orientation(previous_orientation)
	Prefs.set_world_zoom(previous_zoom)
	Prefs.settings_path = previous_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://tests/fullscreen-orientation.cfg"))

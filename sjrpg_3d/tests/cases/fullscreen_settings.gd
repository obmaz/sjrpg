extends TestCase
## Accessible fullscreen control, paused live state and clean unsupported fallback.
## Real browser fullscreen gestures are covered by web/check_fullscreen.mjs.


func run() -> void:
	var previous_path := Prefs.settings_path
	var previous_orientation := Prefs.screen_orientation
	Prefs.settings_path = "user://tests/fullscreen-orientation.cfg"
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	add_child(view)
	GameState.new_game("mage")
	var game := preload("res://scripts/game.gd").new()
	view.add_child(game)
	while not game.native_ready:
		await get_tree().physics_frame
		await _frames(1)
	var preview: Ortho3DPreview = game.ortho_preview
	var position: Vector2 = game.player.position
	var hp: float = game.player.hp
	game.hud.open_settings()
	await _frames(3)
	var panel: SettingsPanel = game.hud._panel
	for dimensions in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(720, 1280)]:
		view.size = dimensions
		await _frames(3)
		var button := panel.find_child("FullscreenToggle", true, false) as Button
		var hint := panel.find_child("FullscreenHint", true, false) as Label
		if not check("settings expose one actual fullscreen button and status hint %s" % dimensions, button != null and hint != null):
			continue
		var bounds := button.get_global_rect()
		check("fullscreen is a visible 64px+ top settings action %s" % dimensions, button.is_visible_in_tree() and bounds.size.y >= 64.0 and Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(bounds) and button.get_index() == 1)
		var state := Prefs.fullscreen_state()
		check("fullscreen button and hint reflect real supported state %s" % dimensions, button.text == str(state["title"]) and button.disabled == (not bool(state["supported"]) or bool(state["pending"])) and not hint.text.is_empty())
		check("settings expose all orientation choices while paused", panel._screen_orientation_buttons.size() == 3 and panel.find_child("ScreenOrientationHint", true, false) != null)
		for choice: Button in panel._screen_orientation_buttons:
			check("orientation choices remain touchable after layout rotation %s" % dimensions, choice.size.y >= 64.0 and panel._panel.get_global_rect().encloses(choice.get_global_rect()))
		check("settings rotation keeps the same paused adventure", get_tree().paused and game.ortho_preview == preview and game.player.position == position and is_equal_approx(game.player.hp, hp))
	var portrait := panel.find_child("Orientation_portrait", true, false) as Button
	portrait.pressed.emit()
	await _frames(3)
	check("actual settings choice saves orientation and preserves the paused adventure", Prefs.screen_orientation == "portrait" and get_tree().paused and game.ortho_preview == preview and game.player.position == position)
	var selected := panel.find_child("Orientation_portrait", true, false) as Button
	check("the saved orientation is reflected after rebuilding settings", selected != null and selected.button_pressed)
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
	Prefs.settings_path = previous_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://tests/fullscreen-orientation.cfg"))

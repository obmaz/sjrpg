extends TestCase
## Device zoom changes the world camera, keeping HUD dimensions and real input coordinates.

const PrefsScript := preload("res://scripts/state/prefs.gd")
const TEST_PATH := "user://tests/world-zoom-settings.cfg"


func run() -> void:
	var previous_path := Prefs.settings_path
	var previous_zoom := Prefs.world_zoom
	var previous_low := Prefs.low_resolution
	Prefs.settings_path = TEST_PATH
	Prefs.set_world_zoom(1.0)
	Prefs.set_low_resolution(false)
	for invalid in [-1.0, 0.0, 0.9, 4.0, INF, NAN, "1.5", true, null]:
		check("unsupported device zoom defaults to 1x", is_equal_approx(Prefs.normalize_world_zoom(invalid), 1.0))
	var game := await make_game()
	var baseline: Vector2 = game.camera.zoom
	var view_size: Vector2 = game.get_viewport_rect().size
	var original_camera_scale: float = clampf(minf(view_size.x, view_size.y) / 720.0, 0.5, 1.6) * game.CAMERA_WORLD_SCALE
	check("displayed default 1x applies the configured composition scale once", is_equal_approx(Prefs.world_zoom, 1.0) and is_equal_approx(Prefs.actual_world_zoom(), Prefs.WORLD_ZOOM_BASE) and baseline.is_equal_approx(Vector2.ONE * original_camera_scale * Prefs.WORLD_ZOOM_BASE))
	game.inspection = AdventureInspection.create(game, "inspection=1")
	game.inspection.zoom_multiplier = 0.75
	game._update_zoom()
	check("URL debug scale remains an independent relative multiplier", game.camera.zoom.is_equal_approx(baseline * 0.75) and is_equal_approx(Prefs.world_zoom, 1.0))
	game.inspection.zoom_multiplier = 1.0
	game._update_zoom()
	var hud_size: Vector2 = game.hud.minimap.size
	var controls_before: Dictionary = game.hud.controls._buttons["bar_bag"].duplicate(true)
	var hero_position: Vector2 = game.player.position
	game.player._attack_time = 0.5
	game.hud.open_settings()
	for amount: float in Prefs.WORLD_ZOOMS:
		Prefs.set_world_zoom(amount)
		await _frames(2)
		check("relative zoom maps once to the rebased actual scale", is_equal_approx(Prefs.actual_world_zoom(), Prefs.WORLD_ZOOM_BASE * amount))
		check("world zoom changes immediately while menu is paused", get_tree().paused and game.camera.zoom.is_equal_approx(baseline * amount))
		check("zoom cannot advance or move a paused hero", is_equal_approx(game.player._attack_time, 0.5) and game.player.position == hero_position)
		check("world zoom leaves HUD and menu hit areas unchanged", game.hud.minimap.size == hud_size and game.hud.controls._buttons["bar_bag"] == controls_before)
		var full_view: Vector2 = game.scene_view.get_visible_rect().size / game.camera.zoom
		Prefs.set_low_resolution(true)
		await _frames(2)
		var low_view: Vector2 = game.scene_view.get_visible_rect().size / game.camera.zoom
		check("economy quality preserves each zoom's field of view", low_view.distance_to(full_view) < 4.0 and game.player.get_viewport() == game.scene_view)
		Prefs.set_low_resolution(false)
		await _frames(2)
	game.hud.close_panel()
	game.player._cancel_actions()
	for amount: float in Prefs.WORLD_ZOOMS:
		Prefs.set_world_zoom(amount)
		for low in [false, true]:
			Prefs.set_low_resolution(low)
			await _frames(2)
			var target: Vector2 = game.player.position + Vector2(40, -30)
			var native: Vector3 = WorldSpace3D.projected_to_world(target, game.spatial_world.height_at(target))
			var renderer: WorldRenderer3D = game.world_renderer
			var expected_native_size: float = game.scene_view.get_visible_rect().size.y / WorldSpace3D.pixels_per_meter(game.camera.zoom.y)
			check("native camera inherits the rebased scale exactly once in either quality", is_equal_approx(renderer.camera.size, expected_native_size))
			var screen := renderer.camera.unproject_position(native)
			screen *= game.get_viewport_rect().size / Vector2(renderer.viewport.size)
			check("native screen-to-floor targeting round-trips at zoom %s/economy=%s" % [amount, low], game.screen_to_world(screen).distance_to(target) < 0.01)
			check("native targeting changes neither minimap nor menu touch dimensions", game.hud.minimap.size == hud_size and game.hud.controls._buttons["bar_bag"] == controls_before)
	Prefs.set_low_resolution(false)
	await _frames(2)
	Prefs.set_world_zoom(0.5)
	var loaded := PrefsScript.new()
	loaded.settings_path = TEST_PATH
	add_child(loaded)
	check("device zoom survives a fresh settings load", is_equal_approx(loaded.world_zoom, 0.5))
	loaded.queue_free()
	await _frames(2)
	var cfg := ConfigFile.new()
	cfg.set_value("device", "sound", false)
	cfg.save(TEST_PATH)
	loaded = PrefsScript.new()
	loaded.settings_path = TEST_PATH
	add_child(loaded)
	check("legacy device settings keep displayed default and existing values with the new actual base", is_equal_approx(loaded.world_zoom, 1.0) and is_equal_approx(loaded.actual_world_zoom(), Prefs.WORLD_ZOOM_BASE) and not loaded.sound_enabled)
	loaded.queue_free()
	await _frames(2)
	for old_choice: float in Prefs.WORLD_ZOOMS:
		cfg.set_value("device", "world_zoom", old_choice)
		cfg.save(TEST_PATH)
		loaded = PrefsScript.new()
		loaded.settings_path = TEST_PATH
		add_child(loaded)
		check("existing stored preferences keep their relative selection without a schema migration", is_equal_approx(loaded.world_zoom, old_choice) and is_equal_approx(loaded.actual_world_zoom(), Prefs.WORLD_ZOOM_BASE * old_choice))
		loaded.queue_free()
		await _frames(2)
	cfg.set_value("device", "world_zoom", "corrupt")
	cfg.save(TEST_PATH)
	loaded = PrefsScript.new()
	loaded.settings_path = TEST_PATH
	add_child(loaded)
	check("invalid stored zoom cannot create an unusable camera", is_equal_approx(loaded.world_zoom, 1.0))
	loaded.queue_free()
	await _frames(2)
	game.player.position = game.dungeon.entry_point()
	check("zoomed world can enter the cave", game.dungeon.enter())
	Prefs.set_world_zoom(1.5)
	await _frames(2)
	check("cave uses the same selected world zoom", game.dungeon.active and game.camera.zoom.is_equal_approx(baseline * 1.5))
	game.dungeon.leave("")
	await _check_settings_layout(game)
	game.queue_free()
	await _frames(2)
	Prefs.set_world_zoom(previous_zoom)
	Prefs.set_low_resolution(previous_low)
	Prefs.settings_path = previous_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func _check_settings_layout(game: Node) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	add_child(view)
	var panel := SettingsPanel.new().setup(game)
	view.add_child(panel)
	for dimensions in [Vector2i(720, 1280), Vector2i(540, 960), Vector2i(1280, 720)]:
		view.size = dimensions
		await _frames(5)
		check("settings exposes all five zoom choices", panel._zoom_buttons.size() == 5)
		check("all platforms expose three orientation choices", panel._screen_orientation_buttons.size() == 3)
		panel.scroll.ensure_control_visible(panel._zoom_grid)
		await _frames(3)
		var frame := panel._panel.get_global_rect()
		var occupied: Array[Rect2] = []
		for button: Button in panel._zoom_buttons:
			var box := button.get_global_rect()
			check("zoom controls stay separated and touchable in %s" % dimensions, button.size.y >= PanelFrame.MIN_TOUCH and frame.encloses(box))
			for other: Rect2 in occupied:
				check("zoom rows never overlap", not box.intersects(other))
			occupied.append(box)
	var chosen: Button = panel._zoom_buttons[3]
	chosen.pressed.emit()
	await _frames(3)
	check("real settings action applies the chosen zoom", is_equal_approx(Prefs.world_zoom, 1.25))
	var selected := 0
	for button: Button in panel._zoom_buttons:
		if button.button_pressed:
			selected += 1
			check("selected zoom is visible in the button state", is_equal_approx(float(button.get_meta("world_zoom")), 1.25))
	check("exactly one zoom remains selected", selected == 1)
	view.queue_free()
	await _frames(2)

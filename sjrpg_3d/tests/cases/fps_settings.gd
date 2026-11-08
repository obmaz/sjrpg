extends TestCase
## Saved device option, live paused toggle, actual Engine FPS and mobile HUD/input clearance.

const PrefsScript := preload("res://scripts/prefs.gd")
const TEST_PATH := "user://tests/fps-settings.cfg"


func _toggle(panel: SettingsPanel) -> void:
	var row := panel.find_child("ShowFps", true, false)
	if not check("settings expose the real FPS switch", row != null):
		return
	var buttons := row.find_children("*", "Button", true, false)
	if check("FPS row has one real action", buttons.size() == 1):
		(buttons[0] as Button).pressed.emit()


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	var cfg := ConfigFile.new()
	cfg.set_value("device", "sound", false)
	check("legacy settings fixture can be written", cfg.save(TEST_PATH) == OK)
	var loaded := PrefsScript.new()
	loaded.settings_path = TEST_PATH
	add_child(loaded)
	check("FPS defaults off for existing settings without changing audio", not loaded.show_fps and not loaded.sound_enabled)
	loaded.free()
	var previous_path := Prefs.settings_path
	var previous_fps := Prefs.show_fps
	Prefs.settings_path = TEST_PATH
	Prefs.set_show_fps(false)
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	add_child(view)
	GameState.new_game("mage")
	var game := preload("res://scripts/game.gd").new()
	view.add_child(game)
	while not game.native_ready:
		await get_tree().physics_frame
		await _frames(1)
	var counter: FpsCounter = game.hud._fps
	check("disabled FPS is hidden, empty and does not process", not counter.visible and not counter.is_processing() and counter.text.is_empty())
	game.hud.open_settings()
	await _frames(2)
	var panel: SettingsPanel = game.hud._panel
	var hero_position: Vector2 = game.player.position
	_toggle(panel)
	await _frames(3)
	check("actual setting enables the existing counter while preserving the paused game",
		Prefs.show_fps and counter.visible and counter.is_processing()
		and get_tree().paused and game.player.position == hero_position)
	loaded = PrefsScript.new()
	loaded.settings_path = TEST_PATH
	add_child(loaded)
	check("FPS selection survives a fresh device settings load", loaded.show_fps)
	loaded.free()
	counter._sample_fps()
	check("display uses the current Engine FPS value", counter.text == "FPS %d" % roundi(Engine.get_frames_per_second()))
	var counters := 0
	for child in game.hud.get_children():
		if child is FpsCounter:
			counters += 1
	check("the HUD owns exactly one noninteractive FPS label", counters == 1 and counter.mouse_filter == Control.MOUSE_FILTER_IGNORE and counter.focus_mode == Control.FOCUS_NONE)
	for dimensions in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(540, 960), Vector2i(720, 1560), Vector2i(860, 720)]:
		view.size = dimensions
		await _frames(4)
		# The counter receives resize signals even while normal HUD processing is paused.
		var rect := counter.get_global_rect()
		var margins := PanelFrame.safe_margins(view)
		var safe := Rect2(Vector2(margins.x, margins.y), Vector2(dimensions) - Vector2(margins.x + margins.z, margins.y + margins.w))
		var geometry: Dictionary = game.hud.status_geometry()
		var map: Rect2 = geometry["map"]
		check("FPS stays inside safe bounds without covering status or minimap %s" % dimensions,
			safe.encloses(rect) and not rect.intersects(geometry["paint_bounds"]) and not rect.intersects(map))
		game.hud.controls._layout()
		var controls: TouchControls = game.hud.controls
		for key: String in controls._buttons:
			var button: Dictionary = controls._buttons[key]
			var half: Vector2 = button.get("half_size", Vector2.ONE * float(button["radius"]))
			var target := Rect2(button["center"] - half, half * 2.0)
			check("FPS clears the real touch target %s/%s" % [dimensions, key], not rect.intersects(target))
		var stick := Rect2(controls._stick_center - Vector2.ONE * controls.stick_radius(), Vector2.ONE * controls.stick_radius() * 2.0)
		check("FPS clears the joystick %s" % dimensions, not rect.intersects(stick))
		check("rotation keeps paused gameplay unchanged", get_tree().paused and game.player.position == hero_position)
	_toggle(panel)
	await _frames(3)
	check("turning FPS off stops polling immediately", not Prefs.show_fps and not counter.visible and not counter.is_processing() and counter.text.is_empty())
	game.hud.close_panel()
	view.queue_free()
	await _frames(2)
	Prefs.set_show_fps(previous_fps)
	Prefs.settings_path = previous_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

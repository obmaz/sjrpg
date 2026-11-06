extends TestCase
## Old comparison preferences/queries cannot change this independent2D project.


func _check_canvas(game: Node, label: String) -> void:
	var probe: Dictionary = game._edition_probe()
	check(label, probe["renderer"] == "2d" and int(probe["native_groups"]) == 0 and probe["world_is_canvas"] and probe["root_3d_disabled"] and probe["world_3d_disabled"] and game.camera is Camera2D)


func run() -> void:
	var old_path := Prefs.settings_path
	var old_quality := Prefs.low_resolution
	var path := "user://tests/edition-isolation.cfg"
	Prefs.settings_path = path
	var cfg := ConfigFile.new()
	cfg.set_value("device", "town_3d", true)
	cfg.set_value("device", "sound", false)
	cfg.set_value("device", "world_zoom", 1.5)
	cfg.save(path)
	var loaded := preload("res://scripts/prefs.gd").new()
	loaded.settings_path = path
	add_child(loaded)
	check("legacy3D preference is ignored while real2D device preferences survive", not loaded.sound_enabled and loaded.world_zoom == 1.5 and not loaded.has_signal("town_renderer_changed") and not loaded.has_method("set_town_3d"))
	loaded._save()
	cfg.clear()
	cfg.load(path)
	check("saving device preferences cannot retain an obsolete renderer switch", not cfg.has_section_key("device", "town_3d") and cfg.get_value("device", "sound", true) == false)
	loaded.queue_free()
	Prefs.set_low_resolution(false)
	var game := await make_game("warrior")
	var position: Vector2 = game.player.position
	_check_canvas(game, "ordinary2D launch has a real Canvas world and disables3D rendering")
	game._apply_debug_query("?preview3d=1&town_3d=true")
	await _frames(2)
	_check_canvas(game, "legacy preview query cannot create or activate a native renderer")
	check("obsolete queries preserve the selected hero and position", GameState.hero_class == "warrior" and game.player.position == position and not game.has_method("_enable_ortho_preview") and not game.has_method("set_town_3d"))
	game._apply_debug_query("?preview3d=1&quality=low")
	await _frames(2)
	_check_canvas(game, "economy quality remains2D even with an old comparison bookmark")
	game.hud.open_settings()
	var panel: SettingsPanel = game.hud._panel
	var edition: Label = panel.find_child("CurrentEdition", true, false)
	check("settings identify the current2D project without direct edition buttons", edition != null and edition.text == "현재 버전 · 2D" and panel.find_child("Version2D", true, false) == null and panel.find_child("Version3D", true, false) == null and panel.find_child("Town3D", true, false) == null)
	var select: Button = panel.find_child("VersionSelect", true, false)
	check("only web settings expose the single root chooser action", (select != null and panel._version_buttons.size() == 1 and not select.toggle_mode) if OS.has_feature("web") else (select == null and panel._version_buttons.is_empty()))
	check("navigation cannot directly switch this project to another renderer", not EditionNavigation.open("3d") and not EditionNavigation.open("2d"))
	panel._confirm_restart()
	await _frames(2)
	panel._publish_version_buttons()
	check("restart confirmation removes stale navigation button references", panel._version_buttons.is_empty())
	game.hud.close_panel()
	game.player.position = game.dungeon.entry_point()
	check("strict2D adventure still enters the existing cave", game.dungeon.enter())
	await _frames(2)
	_check_canvas(game, "the2D cave keeps the same Canvas renderer")
	game.dungeon.leave("")
	await _frames(2)
	_check_canvas(game, "returning from the cave restores the2D field")
	check("removed comparison resources cannot be loaded by a stale caller", not ResourceLoader.exists("res://scripts/ortho_3d_preview.gd") and not ResourceLoader.exists("res://scripts/launch_mode.gd"))
	game.queue_free()
	await _frames(2)
	Prefs.set_low_resolution(old_quality)
	Prefs.settings_path = old_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

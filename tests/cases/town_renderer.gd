extends TestCase
## Switching the presentation in a paused menu must preserve the actual adventure.


func run() -> void:
	var old_path := Prefs.settings_path
	var old_mode := Prefs.town_3d
	Prefs.settings_path = "user://tests/town-renderer.cfg"
	Prefs.set_town_3d(false)
	var game := await make_game("mage")
	var position: Vector2 = game.player.position
	var player_id: int = game.player.get_instance_id()
	var hp: float = game.player.hp
	game.player._attack_time = 0.5
	game.hud.open_settings()
	var panel: SettingsPanel = game.hud._panel
	panel._renderer_buttons[1].pressed.emit()
	await _frames(3)
	var preview: Ortho3DPreview = game.ortho_preview
	check("settings enable native town while the adventure remains paused", game.town_3d_enabled and Prefs.town_3d and get_tree().paused and preview.display.visible)
	check("first paused activation samples the current cast pose once", preview._hero_motion.active_clip.to_lower().contains("cast") and preview._hero_motion.pose_updates == 1)
	panel._renderer_buttons[0].pressed.emit()
	await _frames(2)
	check("settings restore the2D town immediately", not game.town_3d_enabled and not Prefs.town_3d and game.field_root.visibility_layer != 0 and not preview.display.visible)
	panel._renderer_buttons[1].pressed.emit()
	await _frames(2)
	check("repeated switching reuses its native assets", game.ortho_preview == preview and preview.display.visible)
	check("switching preserves hero identity position health and attack clock", game.player.get_instance_id() == player_id and game.player.position == position and game.player.hp == hp and is_equal_approx(game.player._attack_time, 0.5) and GameState.hero_class == "mage")
	panel._confirm_restart()
	await _frames(2)
	panel._publish_renderer_buttons()
	check("restart confirmation removes stale renderer button references", panel._renderer_buttons.is_empty())
	var loaded := preload("res://scripts/prefs.gd").new()
	loaded.settings_path = Prefs.settings_path
	add_child(loaded)
	check("town renderer choice survives a fresh device settings load", loaded.town_3d)
	loaded.queue_free()
	game.hud.close_panel()
	game.player._cancel_actions()
	game.player.position = game.dungeon.entry_point()
	check("3D town mode can enter the existing2D cave", game.dungeon.enter())
	await _frames(2)
	check("native town never replaces cave geometry", game.dungeon.active and not preview.display.visible and game.dungeon._root.visible)
	Prefs.set_town_3d(false)
	Prefs.set_town_3d(true)
	game.dungeon.leave("")
	game.player.position = position
	await _frames(2)
	check("returning from the cave resumes native town", preview.display.visible and game.field_root.visibility_layer == 0)
	game.queue_free()
	await _frames(2)
	Prefs.set_town_3d(false)
	game = await make_game("mage")
	position = game.player.position
	game.player.position = game.dungeon.entry_point()
	check("fresh comparison can be enabled from an already active cave", game.dungeon.enter())
	Prefs.set_town_3d(true)
	await _frames(2)
	preview = game.ortho_preview
	check("first activation inside cave keeps cave visible", not preview.display.visible and game.field_root.visibility_layer == 0 and game._forest_layer != 0)
	game.dungeon.leave("")
	game.player.position = game.village.safe_zone[0] + Vector2(-10000, 0)
	await _frames(2)
	check("leaving cave restores2D forest after first activation there", game.field_root.visibility_layer != 0 and not preview.display.visible)
	game.queue_free()
	await _frames(2)
	game = await make_game("warrior")
	check("saved3D preference loads without changing the warrior class", game.town_3d_enabled and is_instance_valid(game.ortho_preview) and not game.ortho_preview._native_mage and GameState.hero_class == "warrior")
	game.queue_free()
	await _frames(2)
	Prefs.set_town_3d(old_mode)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Prefs.settings_path))
	Prefs.settings_path = old_path

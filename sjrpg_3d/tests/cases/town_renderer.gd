extends TestCase
## The independent3D edition keeps one native world through menus and cave travel.


func _native_active(game: Node) -> bool:
	return is_instance_valid(game.ortho_preview) and game.ortho_preview.display.visible and game.field_root.visibility_layer == 0


func run() -> void:
	check("3D edition uses its own persistent user directory", bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)) and str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")) == "sjrpg_3d")
	if not OS.has_feature("web"):
		check("actual native save directory belongs to the3D edition", OS.get_user_data_dir().get_file() == "sjrpg_3d")
	check("hero save and device preferences resolve within the isolated edition directory", ProjectSettings.globalize_path(GameState.SAVE_PATH).begins_with(OS.get_user_data_dir() + "/") and ProjectSettings.globalize_path(Prefs.PATH).begins_with(OS.get_user_data_dir() + "/"))
	var old_path := Prefs.settings_path
	var old_quality := Prefs.low_resolution
	Prefs.settings_path = "user://tests/native-edition-settings.cfg"
	var game := await make_game("mage")
	await _frames(3)
	var preview: Ortho3DPreview = game.ortho_preview
	check("new3D adventure creates its native world without a preview parameter", _native_active(game) and is_instance_valid(game.spatial_world))
	if preview == null:
		game.queue_free()
		await _frames(2)
		Prefs.settings_path = old_path
		return
	check("hero has an authoritative native character body", game.spatial_world.actor_bodies.get(game.player.get_instance_id()) is CharacterBody3D)
	game.player._attack_time = 0.5
	await _frames(1)
	var position: Vector2 = game.player.position
	var player_id: int = game.player.get_instance_id()
	var hp: float = game.player.hp
	var attack_time: float = game.player._attack_time
	game.hud.open_settings()
	var panel: SettingsPanel = game.hud._panel
	await _frames(2)
	var pose_time: float = preview._hero_motion.sample_time
	var pose_updates: int = preview._hero_motion.pose_updates
	Prefs.set_low_resolution(not old_quality)
	panel._rebuild()
	await _frames(3)
	check("paused settings reuse the live native world", get_tree().paused and _native_active(game) and game.ortho_preview == preview)
	check("paused settings preserve identity position health and attack clock", game.player.get_instance_id() == player_id and game.player.position == position and game.player.hp == hp and is_equal_approx(game.player._attack_time, attack_time) and GameState.hero_class == "mage")
	check("paused menu changes do not advance the native cast pose", preview._hero_motion.sample_time == pose_time and preview._hero_motion.pose_updates == pose_updates)
	var link_2d: Button = panel.find_child("Version2D", true, false)
	var current_3d: Button = panel.find_child("Version3D", true, false)
	var select_link: Button = panel.find_child("VersionSelect", true, false)
	check("settings offer navigation to the independent2D edition", link_2d != null and not link_2d.toggle_mode and not link_2d.disabled and select_link != null and not select_link.toggle_mode)
	check("settings identify3D as the current edition instead of offering a renderer toggle", current_3d != null and current_3d.disabled and not current_3d.toggle_mode and panel._renderer_buttons.is_empty())
	panel._confirm_restart()
	await _frames(3)
	panel._publish_renderer_buttons()
	check("restart confirmation keeps the same paused native adventure and no stale renderer buttons", get_tree().paused and game.ortho_preview == preview and _native_active(game) and panel._renderer_buttons.is_empty())
	var loaded := preload("res://scripts/prefs.gd").new()
	loaded.settings_path = Prefs.settings_path
	add_child(loaded)
	check("edition settings survive a fresh load from the isolated directory", loaded.low_resolution == Prefs.low_resolution and ProjectSettings.globalize_path(Prefs.settings_path).begins_with(OS.get_user_data_dir() + "/"))
	loaded.queue_free()
	game.hud.close_panel()
	game.player._cancel_actions()
	game.player.position = game.village.gate_points[0] + (game.village.gate_points[0] - game.village.spawn_point).normalized() * 450.0
	await _frames(3)
	check("outside the town remains native3D with original field drawing culled", not Geometry2D.is_point_in_polygon(game.player.position, game.village.safe_zone) and _native_active(game) and preview._world_environment.forest.visible)
	game.player.position = game.dungeon.entry_point()
	check("native adventure enters the existing cave encounter", game.dungeon.enter())
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _frames(2)
	check("cave uses a visible native realm without revealing the2D field", game.dungeon.active and _native_active(game) and preview._world_environment.cave.visible and not preview._world_environment.forest.visible)
	game.dungeon.leave("")
	game.player.position = position
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _frames(2)
	check("cave return reuses native assets and restores the native forest", game.ortho_preview == preview and _native_active(game) and preview._world_environment.forest.visible and not preview._world_environment.cave.visible)
	game.queue_free()
	await _frames(2)
	game = await make_game("warrior")
	await _frames(2)
	check("a fresh warrior adventure remains native without changing its class", _native_active(game) and GameState.hero_class == "warrior" and is_instance_valid(game.spatial_world.actor_bodies.get(game.player.get_instance_id())))
	game.queue_free()
	await _frames(2)
	Prefs.set_low_resolution(old_quality)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Prefs.settings_path))
	Prefs.settings_path = old_path

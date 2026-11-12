extends TestCase
## The independent3D edition keeps one native world through menus and cave travel.


func _native_active(game: Node) -> bool:
	return is_instance_valid(game.world_renderer) and game.world_renderer.display.visible and game.field_root.visibility_layer == 0


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
	var renderer: WorldRenderer3D = game.world_renderer
	check("new3D adventure creates its native world without a preview parameter", _native_active(game) and is_instance_valid(game.spatial_world))
	if renderer == null:
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
	var pose_time: float = renderer._hero_motion.sample_time
	var pose_updates: int = renderer._hero_motion.pose_updates
	Prefs.set_low_resolution(not old_quality)
	panel._rebuild()
	await _frames(3)
	check("paused settings reuse the live native world", get_tree().paused and _native_active(game) and game.world_renderer == renderer)
	check("paused settings preserve identity position health and attack clock", game.player.get_instance_id() == player_id and game.player.position == position and game.player.hp == hp and is_equal_approx(game.player._attack_time, attack_time) and GameState.hero_class == "mage")
	check("paused menu changes do not advance the native cast pose", renderer._hero_motion.sample_time == pose_time and renderer._hero_motion.pose_updates == pose_updates)
	var current: Label = panel.find_child("CurrentEdition", true, false)
	var select_link: Button = panel.find_child("VersionSelect", true, false)
	check("settings omit technical edition text and direct renderer switches", current == null and panel.find_child("Version2D", true, false) == null and panel.find_child("Version3D", true, false) == null and panel.find_child("Town2D", true, false) == null)
	check("only web settings can return to the root chooser", (select_link != null) == OS.has_feature("web"))
	panel._confirm_restart()
	await _frames(3)
	panel._publish_version_buttons()
	check("restart confirmation keeps the same paused native adventure without stale navigation", get_tree().paused and game.world_renderer == renderer and _native_active(game) and panel._version_buttons.is_empty())
	var loaded := preload("res://scripts/state/prefs.gd").new()
	loaded.settings_path = Prefs.settings_path
	add_child(loaded)
	check("edition settings survive a fresh load from the isolated directory", loaded.low_resolution == Prefs.low_resolution and ProjectSettings.globalize_path(Prefs.settings_path).begins_with(OS.get_user_data_dir() + "/"))
	loaded.queue_free()
	game.hud.close_panel()
	game.player._cancel_actions()
	game.player.position = game.village.gate_points[0] + (game.village.gate_points[0] - game.village.spawn_point).normalized() * 450.0
	await _frames(3)
	check("outside the town remains native3D with original field drawing culled", not Geometry2D.is_point_in_polygon(game.player.position, game.village.safe_zone) and _native_active(game) and renderer._world_environment.forest.visible)
	game.player.position = game.dungeon.entry_point()
	check("native adventure enters the existing cave encounter", game.dungeon.enter())
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _frames(2)
	check("cave uses a visible native realm without revealing the2D field", game.dungeon.active and _native_active(game) and renderer._world_environment.cave.visible and not renderer._world_environment.forest.visible)
	game.dungeon.leave("")
	game.player.position = position
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _frames(2)
	check("cave return reuses native assets and restores the native forest", game.world_renderer == renderer and _native_active(game) and renderer._world_environment.forest.visible and not renderer._world_environment.cave.visible)
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

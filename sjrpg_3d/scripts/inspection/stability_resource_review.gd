extends Node
## Opt-in, read-only runtime telemetry. Never creates actors or changes gameplay state.
var root_screen: Node
var _elapsed := 0.0
var _deltas: Array[float] = []
var _peaks := {}
func setup(screen: Node) -> Node:
	root_screen = screen
	process_mode = Node.PROCESS_MODE_ALWAYS
	return self
func _process(delta: float) -> void:
	_deltas.append(delta * 1000.0)
	if _deltas.size() > 300:
		_deltas.pop_front()
	_elapsed += delta
	if _elapsed < 0.5:
		return
	_elapsed = 0.0
	var current: Node = root_screen.current
	var adventure: bool = current is Adventure3D
	var game: Node = current.simulation if adventure else null
	var report := {"drawn_frame": Engine.get_frames_drawn(), "label": str(JavaScriptBridge.eval("window.__sjrpgProfileLabel || 'boot'", true)), "frame": Engine.get_process_frames(), "adventure": adventure, "paused": get_tree().paused, "viewport": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y], "window": [get_window().size.x, get_window().size.y], "nodes": get_tree().get_node_count(), "orphan_nodes": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), "buttons": [], "monitors": {}, "frame_ms": {}}
	var monitors := {"process_seconds": Performance.TIME_PROCESS, "physics_seconds": Performance.TIME_PHYSICS_PROCESS, "static_bytes": Performance.MEMORY_STATIC, "static_peak_bytes": Performance.MEMORY_STATIC_MAX, "objects": Performance.OBJECT_COUNT, "resources": Performance.OBJECT_RESOURCE_COUNT, "render_objects": Performance.RENDER_TOTAL_OBJECTS_IN_FRAME, "triangles": Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME, "draw_calls": Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME, "video_bytes": Performance.RENDER_VIDEO_MEM_USED, "texture_bytes": Performance.RENDER_TEXTURE_MEM_USED, "buffer_bytes": Performance.RENDER_BUFFER_MEM_USED}
	for key in monitors:
		var value: float = Performance.get_monitor(int(monitors[key]))
		report.monitors[key] = value
		_peaks[key] = maxf(float(_peaks.get(key, 0.0)), value)
	report["peaks"] = _peaks
	var atlas_script: Script = load("res://scripts/rendering/sprites/actor_atlas.gd")
	var snapshot_available := false
	for method in atlas_script.get_script_method_list():
		if str(method.name) == "texture_snapshot":
			snapshot_available = true
	if snapshot_available:
		report["actor_atlases"] = atlas_script.call("texture_snapshot")
	else:
		# Immutable baseline has a plain eager texture field, not the candidate getter.
		var resident := {"metadata_atlases": ActorAtlas._cache.size(), "loaded_textures": 0, "rgba8_base_bytes_estimate": 0, "atlases": []}
		for key in ActorAtlas._cache:
			var entry: ActorAtlas = ActorAtlas._cache[key]
			var texture: Texture2D = entry.texture
			var dimensions: Vector2i = Vector2i.ZERO if texture == null else Vector2i(texture.get_size())
			resident.atlases.append({"name": key, "texture_loaded": texture != null, "dimensions": [dimensions.x, dimensions.y], "frames": entry.regions.size()})
			if texture != null:
				resident.loaded_textures += 1
				resident.rgba8_base_bytes_estimate += dimensions.x * dimensions.y * 4
		report["actor_atlases"] = resident
	var ordered: Array[float] = _deltas.duplicate()
	ordered.sort()
	if not ordered.is_empty():
		var total := 0.0
		for value in ordered:
			total += value
		report.frame_ms = {"count": ordered.size(), "mean": total / ordered.size(), "p95": ordered[mini(ordered.size()-1, floori(ordered.size()*0.95))], "max": ordered.back()}
	if is_instance_valid(current):
		report["screen_script"] = str(current.get_script().resource_path)
		if current.has_method("probe_activity"):
			report["selection_probe_activity"] = current.call("probe_activity")
		for control in current.find_children("*", "Button", true, false):
			var button: Button = control
			if not button.is_visible_in_tree():
				continue
			var rectangle := button.get_global_rect()
			var clipped := rectangle.intersection(get_viewport().get_visible_rect())
			var ancestor: Node = button.get_parent()
			while ancestor is Control:
				var parent: Control = ancestor
				if parent.clip_contents:
					clipped = clipped.intersection(parent.get_global_rect())
				ancestor = ancestor.get_parent()
			report.buttons.append({"text": button.text, "disabled": button.disabled, "rect": [rectangle.position.x, rectangle.position.y, rectangle.size.x, rectangle.size.y], "visible_rect": [clipped.position.x, clipped.position.y, clipped.size.x, clipped.size.y]})
	var enemy_script: Script = load("res://scripts/rendering/actors/enemy_renderer_3d.gd")
	for method in enemy_script.get_script_method_list():
		if str(method.name) == "cache_stats":
			report["enemy_mesh_cache"] = enemy_script.call("cache_stats")
	var scenery := {"loaded_textures": IsoSprite._textures.size(), "rgba8_base_bytes_estimate": 0, "textures": []}
	for path in IsoSprite._textures:
		var cached: Texture2D = IsoSprite._textures[path]
		if cached == null:
			continue
		var dimensions := cached.get_size()
		scenery.textures.append({"path": path, "width": dimensions.x, "height": dimensions.y})
		scenery.rgba8_base_bytes_estimate += int(dimensions.x) * int(dimensions.y) * 4
	report["iso_sprite_cache"] = scenery
	if adventure:
		report["native_ready"] = JavaScriptBridge.eval("window.__sjrpgAdventureReady === true", true)
		report["hero_class"] = GameState.hero_class
		report["dungeon"] = game.dungeon.active
		report["town"] = game.in_town(game.player.position)
		report["player"] = [game.player.position.x, game.player.position.y]
		report["player_facing"] = game.player.facing
		report["player_run_distance"] = game.player._run_distance
		report["has_move_target"] = game.player.has_move_target
		report["move_input"] = [game.player.move_input.x, game.player.move_input.y]
		report["camera_locked"] = is_instance_valid(game.inspection) and game.inspection.focus_point != Vector2.ZERO
		report["camera_2d"] = [game.camera.global_position.x, game.camera.global_position.y]
		var polygon: Array = []
		for point: Vector2 in game.village.safe_zone:
			polygon.append([point.x, point.y])
		report["town_polygon"] = polygon
		var controls: TouchControls = game.hud.controls
		report["touch_stick"] = {"center": [controls._stick_center.x, controls._stick_center.y], "radius": controls.stick_radius()}
		if is_instance_valid(game.spatial_world):
			report["physics_ticks"] = game.spatial_world.physics_ticks
		report["dead"] = game.player.dead
		report["enemies"] = game.enemies.size()
		report["quality_low"] = Prefs.low_resolution
		if is_instance_valid(game.world_renderer):
			report["native_render_size"] = [game.world_renderer.viewport.size.x, game.world_renderer.viewport.size.y]
			report["native_msaa_3d"] = game.world_renderer.viewport.msaa_3d
			report["os_features"] = {"web": OS.has_feature("web"), "web_android": OS.has_feature("web_android"), "mobile": OS.has_feature("mobile")}
			report["native_camera_size"] = game.world_renderer.camera.size
			report["camera_3d"] = [game.world_renderer.camera.global_position.x, game.world_renderer.camera.global_position.y, game.world_renderer.camera.global_position.z]
			if game.world_renderer.has_method("render_activity"):
				report["render_activity"] = game.world_renderer.call("render_activity")
	JavaScriptBridge.eval("window.__sjrpgResourceProfile = " + JSON.stringify(report), true)

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
	var adventure: bool = current is NativeAdventure
	var game: Node = current.simulation if adventure else null
	var report := {"label": str(JavaScriptBridge.eval("window.__sjrpgProfileLabel || 'boot'", true)), "frame": Engine.get_process_frames(), "adventure": adventure, "paused": get_tree().paused, "viewport": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y], "window": [get_window().size.x, get_window().size.y], "nodes": get_tree().get_node_count(), "orphan_nodes": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), "buttons": [], "monitors": {}, "frame_ms": {}}
	var monitors := {"process_seconds": Performance.TIME_PROCESS, "physics_seconds": Performance.TIME_PHYSICS_PROCESS, "static_bytes": Performance.MEMORY_STATIC, "static_peak_bytes": Performance.MEMORY_STATIC_MAX, "objects": Performance.OBJECT_COUNT, "resources": Performance.OBJECT_RESOURCE_COUNT, "render_objects": Performance.RENDER_TOTAL_OBJECTS_IN_FRAME, "triangles": Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME, "draw_calls": Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME, "video_bytes": Performance.RENDER_VIDEO_MEM_USED, "texture_bytes": Performance.RENDER_TEXTURE_MEM_USED, "buffer_bytes": Performance.RENDER_BUFFER_MEM_USED}
	for key in monitors:
		var value: float = Performance.get_monitor(int(monitors[key]))
		report.monitors[key] = value
		_peaks[key] = maxf(float(_peaks.get(key, 0.0)), value)
	report["peaks"] = _peaks
	var ordered: Array[float] = _deltas.duplicate()
	ordered.sort()
	if not ordered.is_empty():
		var total := 0.0
		for value in ordered:
			total += value
		report.frame_ms = {"count": ordered.size(), "mean": total / ordered.size(), "p95": ordered[mini(ordered.size()-1, floori(ordered.size()*0.95))], "max": ordered.back()}
	if is_instance_valid(current):
		report["screen_script"] = str(current.get_script().resource_path)
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
	if adventure:
		report["native_ready"] = JavaScriptBridge.eval("window.__sjrpgAdventureReady === true", true)
		report["dungeon"] = game.dungeon.active
		report["town"] = game.in_town(game.player.position)
		report["player"] = [game.player.position.x, game.player.position.y]
		report["dead"] = game.player.dead
		report["enemies"] = game.enemies.size()
		report["quality_low"] = Prefs.low_resolution
	JavaScriptBridge.eval("window.__sjrpgResourceProfile = " + JSON.stringify(report), true)

extends Node
## CI-only read-only observer. Install the identical file into both disposable
## exports. Never changes gameplay state, actors, camera, clocks or render size.
const MAX_SAMPLES := 4096
const COLUMNS := ["draw_seq", "process_frame", "frames_drawn", "wall_ms", "interval_ms", "process_ms", "physics_ms", "draw_calls", "triangles", "render_objects", "objects", "resources", "nodes", "static_bytes", "video_bytes", "texture_bytes", "buffer_bytes", "player_x", "player_y", "camera_x", "camera_y", "camera_z", "physics_ticks", "input_x", "input_y"]
var root_screen: Node
var _callback: Variant
var _recording := false
var _samples: Array[Array] = []
var _last_draw_us: int = 0
var _draw_seq: int = 0
var _overflow := false

func setup(screen: Node) -> Node:
	root_screen = screen
	process_mode = Node.PROCESS_MODE_ALWAYS
	return self

func _ready() -> void:
	if not OS.has_feature("web"):
		set_process(false)
		return
	_callback = JavaScriptBridge.create_callback(_command)
	var window: Variant = JavaScriptBridge.get_interface("window")
	window.__sjrpgPacingCommand = _callback
	RenderingServer.frame_post_draw.connect(_post_draw)
	_publish_progress()

func _command(args: Array) -> void:
	var command: String = str(args[0]) if not args.is_empty() else ""
	if command == "begin":
		_samples.clear()
		_last_draw_us = 0
		_overflow = false
		_recording = true
		_publish_progress()
	elif command == "stop":
		_recording = false
		var result := {"columns": COLUMNS, "samples": _samples, "overflow": _overflow, "state": _state(),
			"monitor_semantics": "RenderingServer.frame_post_draw submission intervals from OS microseconds; no GPU completion fence. Performance CPU/render monitors are the engine latest reported values, not measured GPU milliseconds."}
		JavaScriptBridge.eval("window.__sjrpgPacingResult = " + JSON.stringify(result), true)
	elif command == "snapshot":
		_publish_progress()

func _state() -> Dictionary:
	var current: Node = root_screen.current
	var adventure: bool = current is NativeAdventure
	var report := {"draw_seq": _draw_seq, "recorded": _samples.size(), "overflow": _overflow,
		"process_frame": Engine.get_process_frames(), "frames_drawn": Engine.get_frames_drawn(),
		"adventure": adventure, "paused": get_tree().paused,
		"viewport": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y]}
	if not adventure:
		return report
	var game: Node = current.simulation
	if not is_instance_valid(game) or not game.native_ready:
		report["native_ready"] = false
		return report
	report["native_ready"] = true
	report["hero"] = GameState.hero_class
	report["quality_low"] = Prefs.low_resolution
	report["player"] = [game.player.position.x, game.player.position.y]
	report["dead"] = game.player.dead
	report["town"] = game.in_town(game.player.position)
	report["dungeon"] = game.dungeon.active
	report["camera_locked"] = game._fx_review_focus != Vector2.ZERO
	report["physics_ticks"] = game.spatial_world.physics_ticks
	report["input"] = [game.player.move_input.x, game.player.move_input.y]
	var controls: TouchControls = game.hud.controls
	report["stick"] = {"center": [controls._stick_center.x, controls._stick_center.y], "radius": controls.stick_radius()}
	var presenter: Ortho3DPreview = game.ortho_preview
	report["camera"] = [presenter.camera.global_position.x, presenter.camera.global_position.y, presenter.camera.global_position.z]
	report["native_size"] = [presenter.viewport.size.x, presenter.viewport.size.y]
	report["native_msaa"] = presenter.viewport.msaa_3d
	report["camera_size"] = presenter.camera.size
	return report

func _publish_progress() -> void:
	JavaScriptBridge.eval("window.__sjrpgPacingProgress = " + JSON.stringify(_state()), true)

func _post_draw() -> void:
	_draw_seq += 1
	var now_us: int = Time.get_ticks_usec()
	if _recording:
		var state: Dictionary = _state()
		if bool(state.get("native_ready", false)):
			var player: Array = state["player"]
			var camera: Array = state["camera"]
			var movement: Array = state["input"]
			var interval: float = float(now_us - _last_draw_us) / 1000.0 if _last_draw_us != 0 else 0.0
			var row: Array = [_draw_seq, Engine.get_process_frames(), Engine.get_frames_drawn(), float(now_us) / 1000.0, interval,
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
				Performance.get_monitor(Performance.OBJECT_COUNT),
				Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), get_tree().get_node_count(),
				Performance.get_monitor(Performance.MEMORY_STATIC),
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
				Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
				Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED),
				player[0], player[1], camera[0], camera[1], camera[2], state["physics_ticks"], movement[0], movement[1]]
			if _samples.size() < MAX_SAMPLES:
				_samples.append(row)
			else:
				_overflow = true
				_recording = false
		_last_draw_us = now_us
	# Small state only per submission; the full sample array crosses JS once on
	# explicit stop. No GL wrappers, cache scans, shader tracing or per-frame logs.
	_publish_progress()

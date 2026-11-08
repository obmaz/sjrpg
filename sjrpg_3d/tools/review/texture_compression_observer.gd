extends Node
## CI-only read-only texture observation, injected only into the explicit review URL.
## Normal screenshots precede the separately labelled controlled resource loads.
const TARGETS := [
	"res://assets/art/preview3d/limestone.webp",
	"res://assets/art/preview3d/slate.webp",
	"res://assets/art/preview3d/timber.webp",
	"res://assets/art/preview3d/bark.webp",
	"res://assets/art/forest/grass.webp",
	"res://assets/art/forest/paving.webp",
	"res://assets/art/village/rock.webp",
	"res://assets/art/village/water.webp",
	"res://assets/art/cave/floor.webp",
	"res://assets/art/cave/dark.webp",
]
var _root: Node
var _callback: JavaScriptObject
var _elapsed := 0.0
var _held: Array[Texture2D] = []
var _probe := {}
var _pending_frame := -1

func setup(root: Node) -> Node:
	_root = root
	return self

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		_callback = JavaScriptBridge.create_callback(_action)
		var window := JavaScriptBridge.get_interface("window")
		window.__sjrpgTextureCompressionAction = _callback

func _game() -> Node:
	if not is_instance_valid(_root) or not (_root.current is NativeAdventure):
		return null
	var game: Node = _root.current.simulation
	return game if is_instance_valid(game) and game.native_ready else null

func _texture_memory() -> int:
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)

func _action(arguments: Array) -> void:
	if arguments.size() != 1 or str(arguments[0]) not in ["measure", "clear"]:
		return
	if str(arguments[0]) == "clear":
		_held.clear()
		_probe = {}
		_pending_frame = -1
		return
	if _game() == null or _pending_frame >= 0:
		return
	_held.clear()
	var rows: Array[Dictionary] = []
	var uncached: Array[String] = []
	var before := _texture_memory()
	for path: String in TARGETS:
		var cached := ResourceLoader.has_cached(path)
		if not cached:
			uncached.append(path)
		# This is the only controlled load. Never request pixel data or GPU readback.
		var resource := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
		var row := {"path": path, "was_cached": cached, "exists": resource != null}
		if resource != null:
			_held.append(resource)
			row["class"] = resource.get_class()
			row["width"] = resource.get_width()
			row["height"] = resource.get_height()
			row["load_path"] = (resource as CompressedTexture2D).get_load_path() if resource is CompressedTexture2D else ""
		rows.append(row)
	_pending_frame = Engine.get_process_frames()
	_probe = {
		"ready": false,
		"scope": "controlled resource measurement; not normal gameplay heap",
		"requested_frame": _pending_frame,
		"texture_memory_before_bytes": before,
		"uncached_explicit_loads": uncached,
		"textures": rows,
	}

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.2 or not OS.has_feature("web"):
		return
	_elapsed = 0.0
	var game := _game()
	if game == null:
		return
	var frame := Engine.get_process_frames()
	if _pending_frame >= 0 and frame >= _pending_frame + 4:
		_probe["ready"] = true
		_probe["completed_frame"] = frame
		_probe["texture_memory_after_bytes"] = _texture_memory()
		_pending_frame = -1
	var preview: Ortho3DPreview = game.ortho_preview
	var eye := preview.camera.global_basis.z.normalized()
	var position := preview.camera.global_position
	var feature_flags := {}
	for feature: String in ["s3tc", "bptc", "etc2", "astc"]:
		feature_flags[feature] = OS.has_feature(feature)
	var report := {
		"frame": frame,
		"ready": true,
		"paused": get_tree().paused,
		"quality": "low" if Prefs.low_resolution else "high",
		"texture_memory_bytes": _texture_memory(),
		"features": feature_flags,
		"dungeon_active": game.dungeon.active,
		"player": [game.player.position.x, game.player.position.y],
		"world_zoom": Prefs.world_zoom,
		"camera_position": [position.x, position.y, position.z],
		"camera_size": preview.camera.size,
		"camera_elevation": rad_to_deg(asin(eye.y)),
		"camera_azimuth": fposmod(rad_to_deg(atan2(eye.x, eye.z)), 360.0),
		"render_size": [preview.viewport.size.x, preview.viewport.size.y],
		"hud_visible": game.hud.visible,
		"hud_bars_visible": game.hud._bars.visible,
		"hud_controls_visible": game.hud.controls.visible,
		"hud_bars_visible_in_tree": game.hud._bars.is_visible_in_tree(),
		"probe": _probe,
	}
	JavaScriptBridge.eval("window.__sjrpgTextureCompression = " + JSON.stringify(report), true)

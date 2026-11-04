class_name RenderProbe
extends Node
## Enabled only by ?benchmark=1. Confirms the world is rendered before sampling browser cadence.
var game: Node
var _elapsed := 0.0

func setup(g: Node) -> RenderProbe:
	game = g
	return self

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 1.0 or not OS.has_feature("web"):
		return
	_elapsed = 0.0
	var viewport: Viewport = game.scene_view
	var size := viewport.get_texture().get_size()
	var report := {"engine_fps": Engine.get_frames_per_second(), "world_width": size.x, "world_height": size.y,
		"world_draw_calls": viewport.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME), "quality": "low" if Prefs.low_resolution else "high"}
	JavaScriptBridge.eval("window.__sjrpgRenderProbe = " + JSON.stringify(report))

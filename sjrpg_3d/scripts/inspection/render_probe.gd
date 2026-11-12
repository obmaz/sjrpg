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
	# Root ViewportTexture.get_size() multiplies Window size by its stretch scale again.
	# SubViewport textures use their actual size; the root framebuffer uses Window.size.
	var size := Vector2((viewport as SubViewport).size) if viewport is SubViewport else Vector2(get_window().size)
	var report := {"engine_fps": Engine.get_frames_per_second(), "world_width": size.x, "world_height": size.y,
		"world_draw_calls": viewport.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME), "quality": "low" if Prefs.low_resolution else "high",
		"offscreen_world": viewport != get_viewport(), "native_width": get_window().size.x, "native_height": get_window().size.y}
	JavaScriptBridge.eval("window.__sjrpgRenderProbe = " + JSON.stringify(report))

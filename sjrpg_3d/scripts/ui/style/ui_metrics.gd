class_name UiMetrics
extends RefCounted
## 뷰포트 논리 단위 / 표시 픽셀. 웹은 CSS 픽셀이며 DPR을 다시 곱하지 않는다.


static func units_per_display_pixel(viewport: Viewport) -> float:
	if OS.has_feature("web"):
		var css_width: Variant = JavaScriptBridge.eval("window.innerWidth", true)
		if (css_width is float or css_width is int) and float(css_width) > 0.0:
			return viewport.get_visible_rect().size.x / float(css_width)
	if DisplayServer.get_name() == "headless":
		return 1.0
	return viewport.get_visible_rect().size.x / maxf(1.0, float(viewport.get_window().size.x))

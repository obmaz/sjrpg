class_name UiMetrics
extends RefCounted
## 뷰포트 논리 단위 / 표시 단위. 웹은 CSS px, Android는 dp를 사용한다.


static func units_per_display_pixel(viewport: Viewport) -> float:
	if viewport == null:
		return 1.0
	var view := viewport.get_visible_rect().size
	if OS.has_feature("web"):
		var css_width: Variant = JavaScriptBridge.eval("window.innerWidth", true)
		if (css_width is float or css_width is int) and float(css_width) > 0.0:
			return units_for_display(view, Vector2(float(css_width), 1.0))
	if DisplayServer.get_name() == "headless":
		return 1.0
	var density := 1.0
	if OS.has_feature("android"):
		# Android window 크기는 물리 픽셀이다. 이를 dp로 바꾼 뒤 논리 좌표에 대응한다.
		var dpi := DisplayServer.screen_get_dpi(viewport.get_window().current_screen)
		density = maxf(1.0, float(dpi) / 160.0)
	return units_for_display(view, Vector2(viewport.get_window().size), density)


static func units_for_display(view: Vector2, window_pixels: Vector2, density := 1.0) -> float:
	# 접힘·회전 중 Android surface가 잠깐 0 크기가 될 수 있다.
	# 준비되지 않은 크기를 폰트 배율로 확대하지 않고 다음 resize에서 다시 계산한다.
	if (not view.is_finite() or not window_pixels.is_finite()
			or view.x <= 0.0 or view.y <= 0.0
			or window_pixels.x <= 0.0 or window_pixels.y <= 0.0):
		return 1.0
	return view.x * maxf(0.01, density) / window_pixels.x

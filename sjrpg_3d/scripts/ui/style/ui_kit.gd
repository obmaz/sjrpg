class_name UiKit
extends RefCounted
## 생성형 청동 장식·슬레이트 원화와 실제 콘텐츠 안전 여백을 공유하는 메뉴 스타일.

const BOLD_FONT := preload("res://assets/fonts/NanumGothic-ExtraBold.ttf")
## Panels raise this so text stays readable on phones (720-wide portrait ≈ 0.57 css px per unit).
static var boost := 1.0
## 화면 CSS px / Android dp 기준의 메뉴 조작 크기와 이웃 조작 간격.
const ACTION_TOUCH_DP := 56.0
const ACTION_GAP_DP := 12.0
const GOLD := Color("c9af7c")
const INK := Color("211c16")
const TEXT := Color("e9dfc9")
const MUTED := Color("b8ad97")
const SURFACE := Color("201e1a")
const SURFACE_RAISED := Color("2d2820")
const EDGE := Color("6c5940")


## 실제 콘텐츠 경계와 동일한 얇은 금속 테두리. 원화 모서리를 늘리지 않는다.
static func panel_style(bg := SURFACE, border := EDGE, radius := 6) -> StyleBoxFlat:
	var skin := StyleBoxFlat.new()
	skin.bg_color = bg
	skin.border_color = border
	skin.set_border_width_all(1)
	skin.set_corner_radius_all(mini(radius, 10))
	skin.content_margin_left = 18
	skin.content_margin_right = 18
	skin.content_margin_top = 14
	skin.content_margin_bottom = 14
	return skin


static func label(text: String, size := 22, color := TEXT, bold := false) -> Label:
	size = roundi(size * boost)
	var l := Label.new()
	l.text = text
	l.set_meta("ui_font_base", size)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	# Opaque panels provide contrast; paragraphs do not need the HUD's outline.
	l.add_theme_constant_override("outline_size", 0 if boost > 1.01 else maxi(2, size / 6))
	if bold:
		l.add_theme_font_override("font", BOLD_FONT)
	return l


static func button(text: String, size := 24) -> Button:
	size = roundi(size * boost)
	var b := Button.new()
	b.text = text
	b.set_meta("ui_font_base", size)
	b.set_meta("ui_touch", true)
	b.add_theme_font_override("font", BOLD_FONT)
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(220, 64)
	style_button(b)
	return b


static func texture_stylebox(path: String, left: int, top: int, right: int, bottom: int, modulate := Color.WHITE) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	var tex := load(path) as Texture2D
	if tex != null:
		box.texture = tex
	box.texture_margin_left = float(left)
	box.texture_margin_top = float(top)
	box.texture_margin_right = float(right)
	box.texture_margin_bottom = float(bottom)
	# 테두리 자르기는 원본 이미지 픽셀, 내용 여백은 논리 UI 단위다.
	# 큰 원화 테두리를 버튼의 최소 너비로 쓰면 뒤로가기·삭제가 본문을 밀어낸다.
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	box.modulate_color = modulate
	return box


## 원화의 픽셀 자르기와 표시 배율을 분리해 장식을 콘텐츠 위로 늘리지 않는다.
class GeneratedSkin:
	extends StyleBox
	const ROOT := "res://assets/ui/woodland_panels/"
	const FRAME := ROOT + "panel_ornate_frame.png"
	const SLATE := ROOT + "panel_slate_bg.png"
	const GOLD_BUTTON := ROOT + "button_gold_primary.png"
	const BRONZE_BUTTON := ROOT + "button_bronze_secondary.png"
	const COMPACT := ROOT + "frame_bronze_9patch.png"
	const CARD := ROOT + "slot_card_normal.png"
	const SELECTED_CARD := ROOT + "slot_card_selected.png"
	const DIVIDER := ROOT + "divider_ornate.png"
	static var _textures: Dictionary = {}
	var kind := "frame"
	var source_path := FRAME
	var unit := 1.0
	var tint := Color.WHITE
	var primary := false
	var selected := false
	var button_compact := false
	var button_height := 0.0
	var short_frame := false
	var _last_drawn_source := ""

	func configure(role: String, is_primary := false, is_selected := false) -> void:
		kind = role
		primary = is_primary
		selected = is_selected
		match kind:
			"frame": source_path = FRAME
			"card": source_path = SELECTED_CARD if selected else CARD
			"button": source_path = GOLD_BUTTON if primary else (SELECTED_CARD if selected else BRONZE_BUTTON)
			"divider": source_path = DIVIDER
			_: source_path = COMPACT
		_apply_margins()

	func set_unit(value: float) -> void:
		if is_equal_approx(unit, value):
			return
		unit = value
		_apply_margins()
		emit_changed()

	func _apply_margins() -> void:
		var horizontal := 34.0 if kind == "frame" else 16.0
		var vertical := (16.0 if short_frame else 34.0) if kind == "frame" else 12.0
		if kind == "button":
			horizontal = 8.0 if button_compact else (button_height * 0.55 / unit if button_height > 0.0 else 24.0)
			vertical = 8.0 if button_compact else (button_height * 0.24 / unit if button_height > 0.0 else 10.0)
		elif kind == "compact":
			horizontal = 10.0
			vertical = 8.0
		elif kind == "divider":
			horizontal = 0.0
			vertical = 0.0
		# setter가 minimum-size/resized 신호를 내기 전에 네 방향의 값을 확정한다.
		var margin_x := horizontal * unit
		var margin_y := vertical * unit
		content_margin_left = margin_x
		content_margin_right = margin_x
		content_margin_top = margin_y
		content_margin_bottom = margin_y

	func set_button_geometry(height: float, compact: bool) -> void:
		if is_equal_approx(button_height, height) and button_compact == compact:
			return
		button_height = height
		button_compact = compact
		_apply_margins()
		emit_changed()

	static func _texture(path: String) -> Texture2D:
		if not _textures.has(path):
			_textures[path] = load(path) as Texture2D
		return _textures[path]

	func _piece(item: RID, path: String, to: Rect2, from: Rect2) -> void:
		if to.size.x <= 0.0 or to.size.y <= 0.0:
			return
		var texture := _texture(path)
		RenderingServer.canvas_item_add_texture_rect_region(item, to, texture.get_rid(), from, tint)

	func _nine(item: RID, rect: Rect2, path: String, cut: float, corner: float,
			edge := -1.0) -> void:
		var texture := _texture(path)
		var source := texture.get_size()
		corner = minf(corner, minf(rect.size.x, rect.size.y) * 0.5)
		var border := corner if edge < 0.0 else minf(edge, corner)
		# 모서리는 정사각 비율을 유지하고 얇은 변만 늘린다.
		for x: int in 2:
			for y: int in 2:
				_piece(item, path,
					Rect2(rect.position + Vector2((rect.size.x - corner) * x,
						(rect.size.y - corner) * y), Vector2.ONE * corner),
					Rect2(Vector2((source.x - cut) * x, (source.y - cut) * y), Vector2.ONE * cut))
		for side: int in 2:
			_piece(item, path, Rect2(rect.position + Vector2(corner, (rect.size.y - border) * side),
				Vector2(rect.size.x - 2.0 * corner, border)),
				Rect2(Vector2(cut, (source.y - (44.0 if kind == "frame" else cut)) * side),
					Vector2(source.x - 2.0 * cut, 44.0 if kind == "frame" else cut)))
			_piece(item, path, Rect2(rect.position + Vector2((rect.size.x - border) * side, corner),
				Vector2(border, rect.size.y - 2.0 * corner)),
				Rect2(Vector2((source.x - (44.0 if kind == "frame" else cut)) * side, cut),
					Vector2(44.0 if kind == "frame" else cut, source.y - 2.0 * cut)))

	func _band(item: RID, rect: Rect2, path: String, cap: float, middle: float) -> void:
		var source := _texture(path).get_size()
		var scale := rect.size.y / source.y
		var end_width := cap * scale
		var middle_width := middle * scale
		var wing := maxf(0.0, (rect.size.x - 2.0 * end_width - middle_width) * 0.5)
		var center_left := (source.x - middle) * 0.5
		var source_x := [0.0, cap, center_left, center_left + middle, source.x - cap]
		var source_w := [cap, center_left - cap, middle, center_left - cap, cap]
		var target_w := [end_width, wing, middle_width, wing, end_width]
		var cursor := rect.position.x
		for index: int in 5:
			_piece(item, path, Rect2(Vector2(cursor, rect.position.y),
				Vector2(target_w[index], rect.size.y)),
				Rect2(Vector2(source_x[index], 0), Vector2(source_w[index], source.y)))
			cursor += target_w[index]

	func drawn_source_path() -> String:
		if _last_drawn_source != "":
			return _last_drawn_source
		if kind == "button" and button_compact and not (selected and not primary):
			return COMPACT
		return source_path

	func _draw(item: RID, rect: Rect2) -> void:
		_last_drawn_source = source_path
		if kind == "frame":
			# 메인 면도 같은 원화의 청회색 균열 슬레이트를 사용한다. 장식 없는 내부만 늘린다.
			_piece(item, FRAME, rect.grow(-10.0 * unit), Rect2(144, 64, 363, 278))
			var corner := (22.0 if short_frame else 32.0) * unit
			_nine(item, rect, source_path, 144.0, corner, corner * 44.0 / 144.0)
		elif kind == "card":
			var texture := _texture(source_path)
			_piece(item, source_path, rect,
				Rect2(Vector2.ONE * 36.0, texture.get_size() - Vector2.ONE * 72.0))
			if selected:
				_nine(item, rect, source_path, 36.0, 5.0 * unit)
			else:
				# 내부 정보는 질감과 얇은 구분선으로 묶고 중첩된 장식 테두리를 줄인다.
				var color := Color(0.46, 0.39, 0.28, 0.45) * tint
				RenderingServer.canvas_item_add_line(item, rect.position, Vector2(rect.end.x, rect.position.y), color, unit, true)
				RenderingServer.canvas_item_add_line(item, Vector2(rect.position.x, rect.end.y), rect.end, color, unit, true)
		elif kind == "button" and selected and not primary:
			# 선택 탭은 원래 금빛 선택 카드로 구분한다. 작은 옵션도 금속 띠를 보존한다.
			var texture := _texture(SELECTED_CARD)
			var corner := (6.0 if button_compact else 12.0) * unit
			_piece(item, SELECTED_CARD, rect.grow(-corner * 0.67),
				Rect2(Vector2.ONE * 36.0, texture.get_size() - Vector2.ONE * 72.0))
			_nine(item, rect, SELECTED_CARD, 36.0, corner)
		elif kind == "button" and not button_compact and rect.size.x >= rect.size.y * 1.9:
			_band(item, rect, source_path, 110.0, 80.0)
		elif kind == "divider":
			_band(item, rect, source_path, 16.0, 209.0)
		else:
			_last_drawn_source = COMPACT
			# 좁은 옵션과 닫기는 긴 버튼의 마름모 끝을 억지로 압축하지 않는다.
			var slate := _texture(SLATE)
			var shade := Color(0.78, 0.7, 0.52) if selected or primary else Color.WHITE
			RenderingServer.canvas_item_add_texture_rect(item, rect.grow(-2.0 * unit),
				slate.get_rid(), true, tint * shade)
			_nine(item, rect, COMPACT, 8.0, 5.0 * unit)


static func frame_style() -> GeneratedSkin:
	var skin := GeneratedSkin.new()
	skin.configure("frame")
	return skin


static func card_style(selected := false, dimmed := false) -> GeneratedSkin:
	var skin := GeneratedSkin.new()
	skin.configure("card", false, selected)
	if dimmed:
		skin.tint = Color(0.8, 0.8, 0.8)
	return skin


static func style_button(button: Button, primary := false, selected := false, compact := false) -> void:
	var already_fitting := bool(button.get_meta("ui_generated_fitting", false))
	button.set_meta("ui_generated_fitting", true)
	button.set_meta("ui_compact_button", compact)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var skin := GeneratedSkin.new()
		skin.configure("button", primary, selected)
		if state == "pressed":
			skin.tint = Color(0.75, 0.75, 0.75)
		elif state == "disabled":
			skin.tint = Color(0.5, 0.5, 0.5)
		button.add_theme_stylebox_override(state, skin)
	# Focus is an overlay; repeating the banner here doubles its painted border.
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	button.add_theme_stylebox_override("focus", focus)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color("fff2d1") if primary or selected else TEXT)
	button.add_theme_color_override("font_disabled_color", Color("a69e8c"))
	if not button.has_meta("ui_generated_fit_hook"):
		button.set_meta("ui_generated_fit_hook", true)
		button.resized.connect(func(): _refit_generated(button))
	button.set_meta("ui_generated_fitting", already_fitting)
	_request_generated_refit(button)


static func _request_generated_refit(control: Control) -> void:
	if bool(control.get_meta("ui_generated_refit_pending", false)):
		return
	control.set_meta("ui_generated_refit_pending", true)
	_flush_generated_refit.bind(weakref(control)).call_deferred()


static func _flush_generated_refit(reference: WeakRef) -> void:
	var control := reference.get_ref() as Control
	if control == null or control.is_queued_for_deletion():
		return
	control.set_meta("ui_generated_refit_pending", false)
	_refit_generated(control)


static func _refit_generated(control: Control) -> void:
	var scale := 1.0
	if control.has_meta("ui_generated_scale"):
		scale = float(control.get_meta("ui_generated_scale"))
	else:
		scale = UiMetrics.units_per_display_pixel(control.get_viewport())
	fit_generated(control, scale)


static func fit_generated(control: Control, scale: float) -> void:
	control.set_meta("ui_generated_scale", scale)
	if bool(control.get_meta("ui_generated_fitting", false)):
		_request_generated_refit(control)
		return
	control.set_meta("ui_generated_fitting", true)
	var names: Array = ["normal", "hover", "pressed", "disabled", "focus"] if control is Button else ["panel"]
	var button_height := 0.0
	var compact := false
	if control is Button:
		var normal := control.get_theme_stylebox("normal") as GeneratedSkin
		if normal != null:
			compact = bool(control.get_meta("ui_compact_button", false))
			if control.size.x > 0.0 and control.size.y > 0.0:
				compact = compact or control.size.x < control.size.y * 1.9
			var text_height := maxf(0.0, control.get_minimum_size().y - normal.get_content_margin(SIDE_TOP) - normal.get_content_margin(SIDE_BOTTOM))
			# 긴 라벨이 줄바꿈되어도 글자를 원화의 위아래 금속 띠 안쪽에 둔다.
			button_height = maxf(44.0 * scale, text_height / 0.52) if not compact else 44.0 * scale
			control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, ceilf(button_height))
	var face_height := maxf(button_height, control.size.y)
	for name: String in names:
		if control.has_theme_stylebox_override(name):
			var skin := control.get_theme_stylebox(name) as GeneratedSkin
			if skin != null:
				skin.set_unit(scale)
				if skin.kind == "button":
					skin.set_button_geometry(face_height, compact)
	if control.has_meta("ui_divider_skin"):
		var divider_skin: GeneratedSkin = control.get_meta("ui_divider_skin")
		divider_skin.set_unit(scale)
		control.custom_minimum_size.y = 14.0 * scale
		control.queue_redraw()
	control.set_meta("ui_generated_fitting", false)


static func divider() -> Control:
	var divider := Control.new()
	var skin := GeneratedSkin.new()
	skin.configure("divider")
	divider.set_meta("ui_divider_skin", skin)
	divider.custom_minimum_size.y = 14.0
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.draw.connect(func(): skin.draw(divider.get_canvas_item(), Rect2(Vector2.ZERO, divider.size)))
	divider.resized.connect(divider.queue_redraw)
	return divider


static func cover(texture: Texture2D) -> TextureRect:
	var t := TextureRect.new()
	t.texture = texture
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

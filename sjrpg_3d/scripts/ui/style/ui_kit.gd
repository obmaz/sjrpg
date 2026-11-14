class_name UiKit
extends RefCounted
## 숲빛·차콜 면과 얇은 청동 테두리를 공유하는 메뉴 스타일.

const BOLD_FONT := preload("res://assets/fonts/NanumGothic-ExtraBold.ttf")
## Panels raise this so text stays readable on phones (720-wide portrait ≈ 0.57 css px per unit).
static var boost := 1.0
const GOLD := Color("c9af7c")
const INK := Color("211c16")
const TEXT := Color("e9dfc9")
const MUTED := Color("b7b6a8")
const SURFACE := Color("17211e")
const SURFACE_RAISED := Color("24312a")
const EDGE := Color("77664b")


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


## 얇은 청동 테두리와 숲빛 면으로 선택·주 동작을 구분한다.
static func style_button(button: Button, primary := false, selected := false) -> void:
	var face := Color("344537") if primary else (Color("293a31") if selected else Color("202a25"))
	var edge := GOLD if primary or selected else EDGE
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := panel_style(face, edge, 6)
		box.content_margin_left = 18
		box.content_margin_right = 18
		box.content_margin_top = 12
		box.content_margin_bottom = 12
		if state == "pressed":
			box.bg_color = face.darkened(0.2)
		elif state == "disabled":
			box.bg_color = SURFACE
			box.border_color = EDGE.darkened(0.35)
		button.add_theme_stylebox_override(state, box)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, TEXT)
	button.add_theme_color_override("font_disabled_color", Color("90988c"))


static func divider() -> Control:
	var separator := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = Color("5c5946")
	style.thickness = 1
	separator.add_theme_stylebox_override("separator", style)
	separator.custom_minimum_size.y = 2
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return separator


static func cover(texture: Texture2D) -> TextureRect:
	var t := TextureRect.new()
	t.texture = texture
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

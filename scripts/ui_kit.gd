class_name UiKit
extends RefCounted
## Shared styling helpers for the code-built UI.

const BOLD_FONT := preload("res://assets/fonts/NanumGothic-ExtraBold.ttf")
const GOLD := Color(0.96, 0.84, 0.52)
const INK := Color(0.06, 0.14, 0.13)


static func panel_style(bg := Color(0.05, 0.12, 0.11, 0.88), border := GOLD, radius := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


static func label(text: String, size := 22, color := Color.WHITE, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(2, size / 6))
	if bold:
		l.add_theme_font_override("font", BOLD_FONT)
	return l


static func button(text: String, size := 24) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", BOLD_FONT)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_focus_color", INK)
	var normal := panel_style(GOLD, Color(0.55, 0.4, 0.15), 12)
	var hover := panel_style(GOLD.lightened(0.15), Color(0.55, 0.4, 0.15), 12)
	var pressed := panel_style(GOLD.darkened(0.15), Color(0.55, 0.4, 0.15), 12)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", hover)
	b.custom_minimum_size = Vector2(220, 56)
	return b


static func cover(texture: Texture2D) -> TextureRect:
	var t := TextureRect.new()
	t.texture = texture
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

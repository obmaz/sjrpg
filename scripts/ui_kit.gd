class_name UiKit
extends RefCounted
## Shared styling helpers for the code-built UI.

const BOLD_FONT := preload("res://assets/fonts/NanumGothic-ExtraBold.ttf")
## Panels raise this so text stays readable on phones (720-wide portrait ≈ 0.57 css px per unit).
static var boost := 1.0
const GOLD := Color(0.96, 0.84, 0.52)
const INK := Color(0.06, 0.14, 0.13)


static func panel_style(bg := Color(0.075, 0.105, 0.105, 0.98), border := Color(0.27, 0.33, 0.31), radius := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


static func label(text: String, size := 22, color := Color.WHITE, bold := false) -> Label:
	size = roundi(size * boost)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	# Opaque panels provide contrast; heavy HUD outlines make paragraph text muddy.
	l.add_theme_constant_override("outline_size", 0 if boost > 1.01 else maxi(2, size / 6))
	if bold:
		l.add_theme_font_override("font", BOLD_FONT)
	return l


static func button(text: String, size := 24) -> Button:
	size = roundi(size * boost)
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
	if boost > 1.01:
		style_button(b)
	return b


## Panel actions use a quiet surface; one primary action carries the warm accent.
static func style_button(button: Button, primary := false, selected := false) -> void:
	var surface := Color("c9b68b") if primary else Color("283633") if selected else Color("202b2a")
	var border := Color("d7c59d") if primary else Color("b5a17a") if selected else Color("45534e")
	var ink := Color("192421") if primary else Color("ece8de")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var fill := surface
		if state == "hover":
			fill = surface.lightened(0.08)
		elif state == "pressed":
			fill = surface.darkened(0.1)
		elif state == "disabled":
			fill = Color("18211f")
		var box := panel_style(fill, Color("8eaf9e") if state == "focus" else border, 8)
		if state == "focus":
			box.set_border_width_all(2)
		button.add_theme_stylebox_override(state, box)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, ink)
	button.add_theme_color_override("font_disabled_color", Color("748079"))


static func cover(texture: Texture2D) -> TextureRect:
	var t := TextureRect.new()
	t.texture = texture
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

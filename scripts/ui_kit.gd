class_name UiKit
extends RefCounted
## Shared bronze, charcoal and leather surfaces for the reference HUD's menus.

const BOLD_FONT := preload("res://assets/fonts/NanumGothic-ExtraBold.ttf")
## Panels raise this so text stays readable on phones (720-wide portrait ≈ 0.57 css px per unit).
static var boost := 1.0
const GOLD := Color("c9af7c")
const INK := Color("211c16")
const TEXT := Color("e9dfc9")
const MUTED := Color("a99d86")
const SURFACE := Color("201e1a")
const SURFACE_RAISED := Color("2d2820")
const EDGE := Color("6c5940")


## A layered metal edge and an inset leather face. StyleBox margins remain available to containers.
class MetalSkin:
	extends StyleBox
	var fill := SURFACE
	var metal := EDGE
	var radius := 6
	var raised := false
	var shadow_color := Color(0, 0, 0, 0.0)
	var shadow_size := 0
	var _outline: StyleBoxFlat
	var _rim: StyleBoxFlat
	var _face: StyleBoxFlat
	var _gradient: GradientTexture2D
	static var _leather: Texture2D
	# Canvas commands outlive temporary StyleBoxes used by custom-drawn cells.
	# Retain texture RIDs globally until rendering has consumed those commands.
	static var _gradients: Dictionary = {}

	func prepare() -> void:
		_outline = StyleBoxFlat.new()
		_outline.bg_color = Color("0d0d0c")
		_outline.border_color = Color("080908")
		_outline.set_border_width_all(1)
		_outline.set_corner_radius_all(radius)
		_rim = StyleBoxFlat.new()
		_rim.bg_color = metal.darkened(0.45)
		_rim.border_color = metal
		_rim.set_border_width_all(1)
		_rim.set_corner_radius_all(maxi(0, radius - 1))
		_face = StyleBoxFlat.new()
		_face.bg_color = fill
		_face.border_color = Color("100f0d")
		_face.set_border_width_all(1)
		_face.set_corner_radius_all(maxi(0, radius - 3))
		var gradient_key := 1 if raised else 0
		if not _gradients.has(gradient_key):
			var gradient := Gradient.new()
			gradient.set_color(0, Color(1, 0.85, 0.62, 0.07 if raised else 0.025))
			gradient.set_color(1, Color(0, 0, 0, 0.18))
			var texture := GradientTexture2D.new()
			texture.gradient = gradient
			texture.width = 4
			texture.height = 64
			texture.fill_from = Vector2(0.0, 0.0)
			texture.fill_to = Vector2(0.0, 1.0)
			_gradients[gradient_key] = texture
		_gradient = _gradients[gradient_key]
		if _leather == null and ResourceLoader.exists("res://assets/art/hud/panel-leather.webp"):
			_leather = load("res://assets/art/hud/panel-leather.webp")

	func _draw(item: RID, rect: Rect2) -> void:
		if _outline == null:
			prepare()
		_outline.shadow_color = shadow_color
		_outline.shadow_size = shadow_size
		_outline.draw(item, rect)
		_rim.draw(item, rect.grow(-1.0))
		_face.draw(item, rect.grow(-3.0))
		var face := rect.grow(-5.0)
		if radius <= 14 and face.has_area():
			if _leather != null:
				RenderingServer.canvas_item_add_texture_rect(item, face, _leather.get_rid(), true, Color(1, 0.9, 0.74, 0.19))
			RenderingServer.canvas_item_add_texture_rect(item, face, _gradient.get_rid())
		# Interrupted highlights leave the face quiet while making the rim read as metal.
		if rect.size.x > 80.0:
			RenderingServer.canvas_item_add_line(item, rect.position + Vector2(10, 2), Vector2(rect.end.x - 10, rect.position.y + 2), Color(metal.lightened(0.3), 0.52), 1.0, true)
			RenderingServer.canvas_item_add_line(item, Vector2(rect.position.x + 10, rect.end.y - 2), rect.end - Vector2(10, 2), Color(0, 0, 0, 0.55), 1.0, true)


static func panel_style(bg := SURFACE, border := EDGE, radius := 6) -> MetalSkin:
	var skin := MetalSkin.new()
	skin.fill = bg
	skin.metal = border
	skin.radius = radius
	skin.content_margin_left = 18
	skin.content_margin_right = 18
	skin.content_margin_top = 12
	skin.content_margin_bottom = 12
	return skin


static func label(text: String, size := 22, color := TEXT, bold := false) -> Label:
	size = roundi(size * boost)
	var l := Label.new()
	l.text = text
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
	b.add_theme_font_override("font", BOLD_FONT)
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(220, 64)
	style_button(b)
	return b


## The action hierarchy is carried by bronze rims and warmer faces, not pale full-width blocks.
static func style_button(button: Button, primary := false, selected := false) -> void:
	var surface := Color("3b3022") if primary else Color("302b22") if selected else Color("201f1b")
	var border := Color("b39865") if primary else Color("b8a071") if selected else Color("65563f")
	var ink := Color("f1e4c7") if primary or selected else TEXT
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var fill := surface
		var edge := border
		if state == "hover":
			fill = surface.lightened(0.08)
			edge = border.lightened(0.15)
		elif state == "pressed":
			fill = surface.darkened(0.15)
		elif state == "disabled":
			fill = Color("191915")
			edge = Color("443d31")
		elif state == "focus":
			edge = Color("d4c092")
		var box := panel_style(fill, edge, 6)
		box.raised = true
		button.add_theme_stylebox_override(state, box)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, ink)
	button.add_theme_color_override("font_disabled_color", Color("746e60"))


static func divider() -> HSeparator:
	var separator := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = Color("69563a")
	style.thickness = 1
	style.grow_begin = -4
	style.grow_end = -4
	separator.add_theme_stylebox_override("separator", style)
	separator.custom_minimum_size.y = 8
	return separator


static func cover(texture: Texture2D) -> TextureRect:
	var t := TextureRect.new()
	t.texture = texture
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

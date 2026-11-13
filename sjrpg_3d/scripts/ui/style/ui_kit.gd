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
		if _leather == null and ResourceLoader.exists("res://assets/ui/hud/panel-leather.webp"):
			_leather = load("res://assets/ui/hud/panel-leather.webp")

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


static func panel_style(bg := SURFACE, border := EDGE, radius := 6) -> StyleBox:
	if ResourceLoader.exists(TEX_PANEL_FRAME) or ResourceLoader.exists(TEX_SLOT_NORMAL):
		if radius >= 10:
			var p := texture_stylebox(TEX_PANEL_FRAME, 65, 65, 65, 65)
			p.content_margin_left = 22
			p.content_margin_right = 22
			p.content_margin_top = 18
			p.content_margin_bottom = 18
			return p
		else:
			var c := texture_stylebox(TEX_SLOT_NORMAL, 25, 25, 25, 25)
			c.content_margin_left = 18
			c.content_margin_right = 18
			c.content_margin_top = 12
			c.content_margin_bottom = 12
			return c
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


const TEX_GOLD_BTN := "res://assets/ui/woodland_panels/button_gold_primary.png"
const TEX_BRONZE_BTN := "res://assets/ui/woodland_panels/button_bronze_secondary.png"
const TEX_SLOT_NORMAL := "res://assets/ui/woodland_panels/slot_card_normal.png"
const TEX_SLOT_SELECTED := "res://assets/ui/woodland_panels/slot_card_selected.png"
const TEX_PANEL_FRAME := "res://assets/ui/woodland_panels/panel_ornate_frame.png"
const TEX_DIVIDER := "res://assets/ui/woodland_panels/divider_ornate.png"


static func texture_stylebox(path: String, left: int, top: int, right: int, bottom: int, modulate := Color.WHITE) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	var tex := load(path) as Texture2D
	if tex != null:
		box.texture = tex
	box.texture_margin_left = float(left)
	box.texture_margin_top = float(top)
	box.texture_margin_right = float(right)
	box.texture_margin_bottom = float(bottom)
	box.modulate_color = modulate
	return box


## The action hierarchy is carried by bronze rims and warmer faces, not pale full-width blocks.
static func style_button(button: Button, primary := false, selected := false) -> void:
	var path := TEX_GOLD_BTN if primary else (TEX_SLOT_SELECTED if selected else TEX_BRONZE_BTN)
	var ml := 50 if primary else 24
	var mt := 25 if primary else 20
	var mr := 50 if primary else 24
	var mb := 25 if primary else 20
	var normal_box := texture_stylebox(path, ml, mt, mr, mb)
	var pressed_box := texture_stylebox(path, ml, mt, mr, mb, Color(0.75, 0.75, 0.75))
	var disabled_box := texture_stylebox(path, ml, mt, mr, mb, Color(0.4, 0.4, 0.4))

	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box: StyleBoxTexture
		if state == "pressed":
			box = pressed_box
		elif state == "disabled":
			box = disabled_box
		else:
			# hover 및 focus 효과는 프로젝트 규칙상 제거 (기본 상태 유지)
			box = normal_box
		button.add_theme_stylebox_override(state, box)
	var ink := Color("fff2d1") if primary or selected else TEXT
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, ink)
	button.add_theme_color_override("font_disabled_color", Color("746e60"))


static func divider() -> Control:
	if ResourceLoader.exists(TEX_DIVIDER):
		var div := TextureRect.new()
		div.texture = load(TEX_DIVIDER)
		div.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		div.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		div.custom_minimum_size = Vector2(0, 18)
		div.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return div
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

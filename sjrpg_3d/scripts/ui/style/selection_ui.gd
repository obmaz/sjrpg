class_name SelectionUi
extends RefCounted
## Selection-specific interpretation of the generated two-screen design board.
const FOREST := "res://assets/ui/entry/selection-forest.webp"
const HEROES := {"warrior": "res://assets/ui/entry/selection-warrior.webp", "mage": "res://assets/ui/entry/selection-mage.webp"}
const INK := Color("101a19")
const IVORY := Color("e7e1d1")
const MUTED := Color("a5b0a8")
const BRONZE := Color("a68b5b")


static func hero_image(cls: String) -> Texture2D:
	var path: String = HEROES.get(cls, HEROES["mage"])
	return EntryUi.image(path if ResourceLoader.exists(path) else EntryUi.HEROES.get(cls, EntryUi.HEROES["mage"]))


static func backdrop(parent: Control) -> TextureRect:
	var art := TextureRect.new()
	art.texture = EntryUi.image(FOREST if ResourceLoader.exists(FOREST) else EntryUi.BACKGROUND)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(art)
	return art


static func skin(fill := INK, edge := Color("5f6655"), radius := 8) -> StyleBox:
	if radius >= 8:
		var frame := UiKit.texture_stylebox(UiKit.TEX_PANEL_FRAME, 65, 65, 65, 65)
		frame.content_margin_left = 24
		frame.content_margin_top = 24
		frame.content_margin_right = 24
		frame.content_margin_bottom = 24
		return frame
	else:
		var card := UiKit.texture_stylebox(UiKit.TEX_SLOT_NORMAL, 25, 25, 25, 25)
		card.content_margin_left = 12
		card.content_margin_top = 10
		card.content_margin_right = 12
		card.content_margin_bottom = 10
		return card


static func style(button: Button, primary := false, selected := false) -> void:
	button.add_theme_font_override("font", UiKit.BOLD_FONT)
	button.add_theme_constant_override("outline_size", 0)

	var path := UiKit.TEX_GOLD_BTN if primary else (UiKit.TEX_SLOT_SELECTED if selected else UiKit.TEX_SLOT_NORMAL)
	var ml := 50 if primary else 25
	var mt := 25 if primary else 25
	var mr := 50 if primary else 25
	var mb := 25 if primary else 25

	var normal_box := UiKit.texture_stylebox(path, ml, mt, mr, mb)
	var pressed_box := UiKit.texture_stylebox(path, ml, mt, mr, mb, Color(0.75, 0.75, 0.75))
	var disabled_box := UiKit.texture_stylebox(path, ml, mt, mr, mb, Color(0.4, 0.4, 0.4))

	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box: StyleBoxTexture
		if state == "pressed":
			box = pressed_box
		elif state == "disabled":
			box = disabled_box
		else:
			# 호버 및 포커스 효과는 프로젝트 규칙에 따라 배제 (normal 상태와 동일 유지)
			box = normal_box
		button.add_theme_stylebox_override(state, box)

	var text_color := Color("fff2d1") if primary or selected else IVORY
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, text_color)
	button.add_theme_color_override("font_disabled_color", Color("758077"))


static func portrait(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var crop := AtlasTexture.new()
	crop.atlas = texture
	crop.region = Rect2(Vector2(texture.get_width() * 0.14, texture.get_height() * 0.09), Vector2(texture.get_width() * 0.72, texture.get_height() * 0.48))
	return crop


static func vignette(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var crop := AtlasTexture.new()
	crop.atlas = texture
	# Both delivered portraits place the eyes near the upper third. This upper-body
	# region keeps the face and casting hand in the wide Continue presentation.
	crop.region = Rect2(Vector2(0, texture.get_height() * 0.12),
		Vector2(texture.get_width(), texture.get_height() * 0.43))
	return crop

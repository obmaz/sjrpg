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


static func skin(fill := INK, edge := Color("5f6655"), radius := 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	return box


static func style(button: Button, primary := false, selected := false) -> void:
	button.add_theme_font_override("font", UiKit.BOLD_FONT)
	button.add_theme_constant_override("outline_size", 0)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var fill := Color("655638") if primary else Color("14211f")
		fill.a = 0.96 if primary else 0.88
		var edge := BRONZE if primary or selected else Color("4e5b50")
		if state in ["hover", "focus"]:
			fill = fill.lightened(0.08)
			edge = Color("dbc28c")
		elif state == "pressed":
			fill = fill.darkened(0.18)
		elif state == "disabled":
			fill = Color("15201d")
			edge = Color("39453c")
		if primary:
			# The existing layered metal/leather renderer supplies a restrained
			# highlight and inner bevel; the generated board keeps the face quiet.
			var metal := UiKit.panel_style(fill, edge, 7)
			metal.raised = true
			button.add_theme_stylebox_override(state, metal)
		else:
			var box := skin(fill, edge, 7)
			box.set_border_width_all(2 if selected or state == "focus" else 1)
			button.add_theme_stylebox_override(state, box)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, IVORY)
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

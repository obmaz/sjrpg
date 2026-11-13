class_name EntryUi
extends RefCounted
## Live type and controls over generated illustrations; no text is baked into the art.
const BACKGROUND := "res://assets/ui/entry/start-background.webp"
const HEROES := {"warrior": "res://assets/ui/entry/warrior.webp", "mage": "res://assets/ui/entry/mage.webp"}
const TEXT := Color("e7dfd0")
const MUTED := Color("a69e93")
const BRONZE := Color("a38660")

static func image(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

static func backdrop(parent: Control) -> TextureRect:
	var art := TextureRect.new()
	art.texture = image(BACKGROUND)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(art)
	return art

static func shade(parent: Control, bottom := 0.96) -> void:
	var ink := TextureRect.new()
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.018, 0.022, 0.028, 0.12), Color(0.018, 0.022, 0.028, bottom)])
	ramp.offsets = PackedFloat32Array([0.18, 0.95])
	var texture := GradientTexture2D.new()
	texture.gradient = ramp
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	ink.texture = texture
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(ink)

static func label(text: String, font_size: int, color := TEXT, bold := false) -> Label:
	var result := UiKit.label(text, font_size, color, bold)
	result.add_theme_constant_override("outline_size", 0)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func style(button: Button, primary := false, selected := false) -> void:
	button.add_theme_font_override("font", UiKit.BOLD_FONT)
	button.add_theme_constant_override("outline_size", 0)

	var path := UiKit.TEX_GOLD_BTN if primary else UiKit.TEX_BRONZE_BTN
	var ml := 50 if primary else 24
	var mt := 25 if primary else 20
	var mr := 50 if primary else 24
	var mb := 25 if primary else 20

	var normal_box := UiKit.texture_stylebox(path, ml, mt, mr, mb)
	var pressed_box := UiKit.texture_stylebox(path, ml, mt, mr, mb, Color(0.75, 0.75, 0.75))
	var disabled_box := UiKit.texture_stylebox(path, ml, mt, mr, mb, Color(0.4, 0.4, 0.4))

	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box: StyleBoxTexture
		if state == "pressed":
			box = pressed_box
		elif state == "disabled":
			box = disabled_box
		else:
			# 호버 및 포커스 효과는 프로젝트 규칙에 따라 배제 (normal 상태와 동일 유지)
			box = normal_box
		button.add_theme_stylebox_override(state, box)

	var ink := Color("fff2d1") if primary or selected else TEXT
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, ink)
	button.add_theme_color_override("font_disabled_color", Color("716e69"))

static func place(control: Control, rectangle: Rect2) -> void:
	control.position = rectangle.position
	control.size = rectangle.size

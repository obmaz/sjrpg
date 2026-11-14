class_name EntryUi
extends RefCounted
## Live type and controls over generated illustrations; no text is baked into the art.
const BACKGROUND := "res://assets/ui/entry/start-background.webp"
const HEROES := {"warrior": "res://assets/ui/entry/warrior.webp", "mage": "res://assets/ui/entry/mage.webp"}
const TEXT := Color("e7dfd0")
const MUTED := Color("a69e93")
const BRONZE := Color("a38660")
const ACTION_FONT_SIZE := 24.0
const ACTION_FONT_DP := 18.0

static func action_height(unit: float, display_scale: float) -> float:
	return maxf(72.0 * unit, UiKit.ACTION_TOUCH_DP * display_scale)

## 회전 전 최소 높이·스킨 여백을 함께 복원한 뒤 고정 영역이 예약할 실제 높이를 돌려준다.
static func fit_action(button: Button, requested_height: float, display_scale: float) -> float:
	# 지연된 공용 refit도 지금 화면의 배율을 사용해야 한다.
	button.set_meta("ui_generated_scale", display_scale)
	var normal := button.get_theme_stylebox("normal") as UiKit.GeneratedSkin
	var height := requested_height
	if normal != null:
		var text_height := maxf(0.0, button.get_minimum_size().y
			- normal.get_content_margin(SIDE_TOP) - normal.get_content_margin(SIDE_BOTTOM))
		height = maxf(height, ceilf(maxf(44.0 * display_scale, text_height / 0.52)))
	# 공용 자동 맞춤은 최소 크기를 늘리기만 하므로 각 화면의 목표부터 다시 확정한다.
	button.custom_minimum_size = Vector2(0.0, height)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var skin := button.get_theme_stylebox(state) as UiKit.GeneratedSkin
		if skin != null:
			skin.set_unit(display_scale)
			skin.set_button_geometry(height, false)
	button.update_minimum_size()
	return maxf(height, button.get_combined_minimum_size().y)

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

	UiKit.style_button(button, primary, selected)

static func place(control: Control, rectangle: Rect2) -> void:
	control.position = rectangle.position
	control.size = rectangle.size

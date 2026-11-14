class_name SelectionUi
extends RefCounted
## 선택·이어하기 시안의 얇은 청동선과 반투명 청록 패널. 공용 팝업 스킨과 분리한다.
const FOREST := "res://assets/ui/entry/selection-forest.webp"
const HEROES := {
	"warrior": "res://assets/ui/entry/selection-warrior.webp",
	"mage": "res://assets/ui/entry/selection-mage.webp"
}
const TITLE_FONT := preload("res://assets/fonts/NanumMyeongjo-Bold.ttf")
# 작은 역할·설명·저장 정보는 폰에서도 획이 유지되는 공용 고딕을 사용한다.
const BODY_FONT := preload("res://assets/fonts/NanumGothic-Regular.ttf")
const INK := Color("101a19")
const IVORY := Color("e7e1d1")
const MUTED := Color("d0cbbd")
const ROLE := Color("d7bd8e")
const BRONZE := Color("a68b5b")
const PORTRAIT_BLEND := """
shader_type canvas_item;
uniform float visible_bottom = 1.0;
void fragment() {
 vec4 ink = texture(TEXTURE, UV);
 float sides = smoothstep(0.0,0.13,UV.x)*(1.0-smoothstep(0.87,1.0,UV.x));
 // Runtime moves the source up by 15%; fade the visible crop edge, not source y=0.
 float top = smoothstep(0.15,0.235,UV.y);
 float bottom = 1.0-smoothstep(max(0.24,visible_bottom-0.10),visible_bottom,UV.y);
 COLOR = vec4(ink.rgb,ink.a*sides*top*bottom);
}
"""
static var _portrait_shader: Shader


static func hero_image(cls: String) -> Texture2D:
	var path: String = HEROES.get(cls, HEROES["mage"])
	return EntryUi.image(
		path if ResourceLoader.exists(path) else EntryUi.HEROES.get(cls, EntryUi.HEROES["mage"])
	)


static func blend_portrait(art: TextureRect, visible_bottom := 1.0) -> void:
	if _portrait_shader == null:
		_portrait_shader = Shader.new()
		_portrait_shader.code = PORTRAIT_BLEND
	if art.material == null:
		var material := ShaderMaterial.new()
		material.shader = _portrait_shader
		art.material = material
	var material := art.material as ShaderMaterial
	material.set_shader_parameter("visible_bottom", clampf(visible_bottom, 0.30, 1.0))


static func icon_texture(kind: String) -> Texture2D:
	return EntryUi.image("res://assets/ui/entry/concept/" + kind + ".png")


static func class_icon(cls: String) -> Texture2D:
	return icon_texture("swords" if cls == "warrior" else "staff")


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
	box.set_corner_radius_all(mini(radius, 6))
	box.set_content_margin_all(12.0)
	box.anti_aliasing = true
	return box


static func concept_skin(kind: String) -> StyleBoxTexture:
	var margins: Array = {
		"info": [14, 14],
		"slot": [14, 14],
		"slot_selected": [14, 14],
		"stat": [10, 8]
	}[kind]
	return UiKit.texture_stylebox(
		"res://assets/ui/entry/concept/" + kind + ".png",
		margins[0],
		margins[1],
		margins[0],
		margins[1]
	)


## 전체 테두리를 함께 늘려 대각 끝·선택 V를 아홉 구간으로 분리하지 않는다.
static func control_skin(kind: String) -> StyleBoxTexture:
	return UiKit.texture_stylebox("res://assets/ui/entry/controls/" + kind + ".png", 0, 0, 0, 0)


static func style(button: Button, primary := false, selected := false) -> void:
	button.add_theme_font_override("font", TITLE_FONT)
	button.add_theme_constant_override("outline_size", 0)
	var normal: StyleBox
	if primary:
		normal = control_skin("primary")
	elif button.name in ["warrior", "mage"] or selected:
		normal = control_skin("tab_selected" if selected else "tab_idle")
	elif button.name == "SelectionBack":
		normal = control_skin("back")
	else:
		normal = skin(Color(0.025, 0.075, 0.065, 0.74), Color("747459"), 4)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := normal.duplicate() as StyleBox
		if box is StyleBoxFlat:
			if state == "pressed":
				box.bg_color = box.bg_color.lightened(0.08)
			elif state == "disabled":
				box.bg_color = box.bg_color.darkened(0.14)
		elif box is StyleBoxTexture:
			if state == "pressed":
				box.modulate_color *= Color(0.90, 0.90, 0.90)
			elif state == "disabled":
				box.modulate_color *= Color(0.48, 0.48, 0.48)
		button.add_theme_stylebox_override(state, box)
	for state: String in [
		"font_color", "font_hover_color", "font_pressed_color", "font_focus_color"
	]:
		button.add_theme_color_override(state, Color("f7e7c7") if primary or selected else IVORY)
	button.add_theme_color_override("font_disabled_color", MUTED)
	if button.name == "SelectionBack":
		# 실제 화살표는 원화에 있다. 원래 문자는 접근성과 입력 식별을 위해 남긴다.
		for state: String in [
			"font_color",
			"font_hover_color",
			"font_pressed_color",
			"font_focus_color",
			"font_disabled_color"
		]:
			button.add_theme_color_override(state, Color(1, 1, 1, 0))


static func slot_style(band: Control, button: Button, selected: bool) -> void:
	var box := concept_skin("slot_selected" if selected else "slot")
	band.add_theme_stylebox_override("panel", box)
	band.queue_redraw()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())


static func portrait(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var crop := AtlasTexture.new()
	crop.atlas = texture
	crop.region = Rect2(
		Vector2(texture.get_width() * 0.29, texture.get_height() * 0.15),
		Vector2(texture.get_width() * 0.42, texture.get_height() * 0.30)
	)
	return crop

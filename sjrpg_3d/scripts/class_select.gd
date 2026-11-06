extends Control
## The user's guardian-selection composition: gold tabs, one hero card and two explicit actions.

signal chosen(cls: String)
signal continue_requested
signal back_requested

const HERO_ART := {
	"warrior": preload("res://assets/art/ui/hero-warrior.webp"),
	"mage": preload("res://assets/art/ui/hero-mage.webp"),
}
const ROLES := {"warrior": "근접 전투 · 강인한 생존력", "mage": "원거리 주문 · 세 가지 원소"}
const DESCRIPTIONS := {
	"warrior": "검으로 적진을 가르고, 함성으로 전투의 흐름을 바꾸세요.",
	"mage": "화염·냉기·번개를 조합해 다가오는 적을 제압하세요.",
}
const CREAM := Color("e8e2cf")
const GOLD := Color("c7ae74")

var selected_class := "mage"
var class_buttons: Dictionary = {}
var start_button: Button
var continue_button: Button
var back_button: Button
var hero_art: TextureRect
var showcase: Panel
var details: Control
var heading: Label
var subtitle: Label
var hero_name: Label
var role: Label
var description: Label
var health: Label
var resource: Label
var health_caption: Label
var resource_caption: Label
var health_box: Panel
var resource_box: Panel
var weapon: Label
var brand_name: Label
var brand_crest: TextureRect
var class_emblem: TextureRect
var selection_marker: Control
var _card_trim: Control
var _detail_lines: Control
var _info_face: Panel
var _trim_data: Dictionary
var _trim: Texture2D
var _unit := 1.0
var _portrait := true


## A fifty-unit back plaque keeps a sixty-four-unit touch target.
class InsetSkin:
	extends StyleBox
	var inner: StyleBox
	var inset := 7.0
	func _draw(item: RID, rect: Rect2) -> void:
		inner.draw(item, Rect2(rect.position + Vector2(0, inset), rect.size - Vector2(0, inset * 2.0)))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_trim_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/selection_ui.json"))
	_trim = load(_trim_data["texture"])
	add_child(UiKit.cover(preload("res://assets/art/ui/selection-forest.webp")))
	var shade := TextureRect.new()
	shade.texture = _gradient([0.0, 0.55, 1.0], [Color(0.015, 0.025, 0.019, 0.37), Color(0.015, 0.025, 0.019, 0.52), Color(0.008, 0.018, 0.012, 0.83)])
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	brand_crest = TextureRect.new()
	brand_crest.texture = _emblem("crest")
	brand_crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	brand_crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	brand_crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(brand_crest)
	brand_name = _label("자연의 수호자", 29, GOLD, true)
	brand_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_button = _button("‹  뒤로", func(): back_requested.emit())
	_style_button(back_button, "back")
	heading = _label("수호자 선택", 50, CREAM, true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle = _label("당신의 전투 방식을 선택하세요", 24, Color("b7b9a9"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for cls in ["warrior", "mage"]:
		var button := _button(GameState.CLASSES[cls]["name"], func(): select_class(cls))
		button.toggle_mode = true
		class_buttons[cls] = button
	selection_marker = Control.new()
	selection_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_marker.draw.connect(_draw_selection_marker)
	add_child(selection_marker)
	showcase = Panel.new()
	showcase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	showcase.clip_contents = true
	var card := StyleBoxFlat.new()
	card.bg_color = Color("142019")
	card.border_color = Color("615b42")
	card.set_border_width_all(1)
	card.set_corner_radius_all(18)
	card.shadow_color = Color(0, 0, 0, 0.5)
	card.shadow_size = 16
	showcase.add_theme_stylebox_override("panel", card)
	add_child(showcase)
	hero_art = TextureRect.new()
	hero_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hero_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	showcase.add_child(hero_art)
	details = Control.new()
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	showcase.add_child(details)
	_info_face = Panel.new()
	_info_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_info_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info_skin := StyleBoxFlat.new()
	info_skin.bg_color = Color(0.058, 0.10, 0.073, 0.98)
	info_skin.border_color = Color(0.47, 0.48, 0.35, 0.78)
	info_skin.set_border_width_all(1)
	info_skin.set_corner_radius_all(14)
	info_skin.shadow_color = Color(0, 0, 0, 0.22)
	info_skin.shadow_size = 8
	_info_face.add_theme_stylebox_override("panel", info_skin)
	details.add_child(_info_face)
	_detail_lines = Control.new()
	_detail_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_lines.draw.connect(_draw_detail_lines)
	details.add_child(_detail_lines)
	class_emblem = TextureRect.new()
	class_emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	class_emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	class_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(class_emblem)
	hero_name = _label("", 44, CREAM, true, details)
	role = _label("", 24, GOLD, false, details)
	description = _label("", 25, Color("d4d8ca"), false, details)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.max_lines_visible = 2
	description.clip_text = true
	health_box = _stat_box(false)
	resource_box = _stat_box(true)
	health_caption = _label("체력", 18, Color("c9cbbb"), false, health_box)
	resource_caption = _label("", 18, Color("c9cbbb"), false, resource_box)
	health = _label("", 31, CREAM, true, health_box)
	resource = _label("", 31, CREAM, true, resource_box)
	weapon = _label("", 23, Color("c2bd9f"), false, details)
	_card_trim = Control.new()
	_card_trim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_trim.draw.connect(_draw_card_trim)
	showcase.add_child(_card_trim)
	start_button = _button("", _choose)
	_style_button(start_button, "primary")
	continue_button = _button("이어하기 · 저장 없음", func(): continue_requested.emit())
	_style_button(continue_button, "continue")
	continue_button.disabled = true
	if GameState.has_save() and GameState.load_game():
		selected_class = GameState.hero_class
		continue_button.text = "이어하기 · %s Lv.%d%s" % [GameState.class_info()["name"], GameState.level, " · 백업 복원" if GameState.loaded_backup else ""]
		continue_button.disabled = false
	elif GameState.has_save_files():
		continue_button.text = "저장을 읽을 수 없습니다"
	subtitle.text = "3D 모험 · 수호자를 선택하세요"
	resized.connect(_layout)
	select_class(selected_class)
	_layout()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sjrpgClassSelectReady = true")


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", UiKit.BOLD_FONT)
	button.add_theme_constant_override("outline_size", 0)
	button.pressed.connect(action)
	add_child(button)
	return button


func _stat_box(energy: bool) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("19261e")
	skin.border_color = Color("536049")
	skin.set_border_width_all(1)
	skin.set_corner_radius_all(9)
	panel.add_theme_stylebox_override("panel", skin)
	panel.draw.connect(_draw_stat_symbol.bind(panel, energy))
	details.add_child(panel)
	return panel


func _label(text: String, font_size: int, color: Color, bold := false, parent: Node = null) -> Label:
	var label := UiKit.label(text, font_size, color, bold)
	label.add_theme_constant_override("outline_size", 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(label)
	return label


func _gradient(offsets: Array, colors: Array) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(offsets)
	gradient.colors = PackedColorArray(colors)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 4
	texture.height = 128
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	return texture


func _emblem(key: String) -> AtlasTexture:
	var frame: Array = _trim_data["regions"][key]
	var texture := AtlasTexture.new()
	texture.atlas = _trim
	texture.region = Rect2(frame[0], frame[1], frame[2], frame[3])
	return texture


func _skin(key: String, tint: Color) -> StyleBox:
	var frame: Array = _trim_data["regions"][key]
	var skin := StyleBoxTexture.new()
	skin.texture = _trim
	skin.region_rect = Rect2(frame[0], frame[1], frame[2], frame[3])
	skin.set_texture_margin_all(float(_trim_data["nine_slice"]))
	skin.modulate_color = tint
	skin.content_margin_left = 14
	skin.content_margin_right = 14
	skin.content_margin_top = 4
	skin.content_margin_bottom = 4
	return skin


func _style_button(button: Button, key: String) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var tint := Color.WHITE
		if state == "hover" or state == "focus":
			tint = Color(1.12, 1.09, 1.02)
		elif state == "pressed":
			tint = Color(0.84, 0.83, 0.77)
		elif state == "disabled":
			tint = Color(0.62, 0.64, 0.59, 0.72)
		var skin := _skin(key, tint)
		if key == "back":
			var inset := InsetSkin.new()
			inset.inner = skin
			inset.inset = 7.0 * _unit
			skin = inset
		button.add_theme_stylebox_override(state, skin)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, CREAM)
	button.add_theme_color_override("font_disabled_color", Color("8d9489"))


func select_class(cls: String) -> void:
	if not HERO_ART.has(cls):
		return
	selected_class = cls
	var info: Dictionary = GameState.CLASSES[cls]
	_crop_art()
	hero_name.text = info["name"]
	role.text = ROLES[cls]
	description.text = DESCRIPTIONS[cls]
	health.text = HudArt.stat(info["hp"])
	resource.text = HudArt.res(info["resource_max"])
	resource_caption.text = info["resource"]
	health_box.queue_redraw()
	resource_box.queue_redraw()
	weapon.text = "시작 무기 · " + str(Gear.def("shortsword" if cls == "warrior" else "wand")["name"])
	class_emblem.texture = _emblem("warrior") if cls == "warrior" else _mage_emblem()
	start_button.text = "%s로 3D 모험 시작" % info["name"]
	for key in class_buttons:
		var button: Button = class_buttons[key]
		button.set_pressed_no_signal(key == cls)
		_style_button(button, "tab_active" if key == cls else "tab_inactive")
	selection_marker.queue_redraw()


func _mage_emblem() -> AtlasTexture:
	# Reuse a real elemental skill illustration; the generated warrior shield remains class-specific.
	var frame: Array = GameState.skill_data()["mage"]["icons"]["lightning"]
	var source: Texture2D = SkillIcons.SHEETS["mage"]
	var texture := AtlasTexture.new()
	texture.atlas = source
	texture.region = Rect2(frame[0] * source.get_width(), frame[1] * source.get_height(), (frame[2] - frame[0]) * source.get_width(), (frame[3] - frame[1]) * source.get_height())
	return texture


func _choose() -> void:
	chosen.emit(selected_class)


func _layout() -> void:
	if start_button == null:
		return
	var margins := PanelFrame.safe_margins(get_viewport())
	var available := Rect2(Vector2(margins.x, margins.y), size - Vector2(margins.x + margins.z, margins.y + margins.w))
	_portrait = available.size.y > available.size.x
	_unit = minf(available.size.x / 720.0, available.size.y / 1280.0) if _portrait else minf(available.size.x / 1080.0, available.size.y / 720.0)
	var u := _unit
	var width := minf(available.size.x - 64.0 * u, 1180.0 * u)
	var left := available.get_center().x - width * 0.5
	var origin := Vector2(left, available.position.y)
	for entry in [[heading, 50 if _portrait else 38], [subtitle, 24 if _portrait else 22], [brand_name, 29 if _portrait else 23], [hero_name, 44 if _portrait else 39], [role, 24 if _portrait else 22], [description, 25 if _portrait else 23], [health, 31 if _portrait else 29], [resource, 31 if _portrait else 29], [health_caption, 18], [resource_caption, 18], [weapon, 23 if _portrait else 22], [back_button, 21], [start_button, 31], [continue_button, 25], [class_buttons["warrior"], 30], [class_buttons["mage"], 30]]:
		entry[0].add_theme_font_size_override("font_size", maxi(12, roundi(float(entry[1]) * u)))
	_place(back_button, Rect2(available.position + Vector2(20, 27) * u, Vector2(114, 64) * u))
	var logo_y := 6.0 if _portrait else -2.0
	_place(brand_crest, Rect2(Vector2(available.get_center().x - 61.0 * u, available.position.y + logo_y * u), Vector2(122, 75) * u))
	_place(brand_name, Rect2(Vector2(available.get_center().x - 180.0 * u, available.position.y + (77.0 if _portrait else 56.0) * u), Vector2(360, 36) * u))
	_place(heading, Rect2(origin + Vector2(0, 125.0 if _portrait else 90.0) * u, Vector2(width, (70.0 if _portrait else 45.0) * u)))
	_place(subtitle, Rect2(origin + Vector2(0, 199.0 if _portrait else 137.0) * u, Vector2(width, 34.0 * u)))
	var tabs_y := available.position.y + (245.0 if _portrait else 182.0) * u
	var tab_width := (width - 12.0 * u) / 2.0
	for index in 2:
		_place(class_buttons[["warrior", "mage"][index]], Rect2(Vector2(left + index * (tab_width + 12.0 * u), tabs_y), Vector2(tab_width, 66.0 * u)))
	_place(selection_marker, available)
	if _portrait:
		var extra := maxf(0.0, available.size.y - 1280.0 * u)
		_place(showcase, Rect2(origin + Vector2(0, 335) * u, Vector2(width, 630.0 * u + extra * 0.62)))
		_place(start_button, Rect2(origin + Vector2(0, 1017) * u + Vector2(0, extra * 0.72), Vector2(width, 90.0 * u)))
		_place(continue_button, Rect2(origin + Vector2(0, 1128) * u + Vector2(0, extra * 0.72), Vector2(width, 74.0 * u)))
		var info_height := maxf(360.0 * u, showcase.size.y * 0.54)
		_place(details, Rect2(Vector2(12.0 * u, showcase.size.y - 12.0 * u - info_height), Vector2(showcase.size.x - 24.0 * u, info_height)))
		_place(hero_art, Rect2(Vector2.ONE * 2.0 * u, Vector2(showcase.size.x - 4.0 * u, details.position.y + 90.0 * u)))
	else:
		var footer_y := available.end.y - 102.0 * u
		var body_y := tabs_y + 82.0 * u
		_place(showcase, Rect2(Vector2(left, body_y), Vector2(width, footer_y - body_y - 20.0 * u)))
		var art_width := minf(showcase.size.x * 0.43, showcase.size.y * 1.25)
		_place(hero_art, Rect2(Vector2.ONE * 2.0 * u, Vector2(art_width, showcase.size.y - 4.0 * u)))
		_place(details, Rect2(Vector2(art_width + 10.0 * u, 10.0 * u), Vector2(showcase.size.x - art_width - 20.0 * u, showcase.size.y - 20.0 * u)))
		var primary_width := (width - 16.0 * u) * 0.58
		_place(start_button, Rect2(Vector2(left, footer_y), Vector2(primary_width, 80.0 * u)))
		_place(continue_button, Rect2(Vector2(left + primary_width + 16.0 * u, footer_y), Vector2(width - primary_width - 16.0 * u, 80.0 * u)))
	var inset := 24.0 * u
	var text_width := details.size.x - inset * 2.0
	var heading_top := 18.0 * u
	_place(class_emblem, Rect2(Vector2(inset, 23.0 * u), Vector2(56, 70) * u))
	_place(hero_name, Rect2(Vector2(inset + 92.0 * u, heading_top), Vector2(text_width - 92.0 * u, (52.0 if _portrait else 46.0) * u)))
	_place(role, Rect2(Vector2(inset + 92.0 * u, (74.0 if _portrait else 68.0) * u), Vector2(text_width - 92.0 * u, (32.0 if _portrait else 30.0) * u)))
	var description_y := 121.0 if _portrait else 106.0
	var description_height := 65.0 if _portrait else 56.0
	_place(description, Rect2(Vector2(inset, description_y * u), Vector2(text_width, description_height * u)))
	var weapon_y := details.size.y - 48.0 * u
	var stat_height := (80.0 if _portrait else 72.0) * u
	var stat_y := weapon_y - stat_height - (34.0 if _portrait else 26.0) * u
	var stat_width := (text_width - 16.0 * u) * 0.5
	_place(health_box, Rect2(Vector2(inset, stat_y), Vector2(stat_width, stat_height)))
	_place(resource_box, Rect2(Vector2(inset + stat_width + 16.0 * u, stat_y), Vector2(stat_width, stat_height)))
	for pair in [[health_box, health_caption, health], [resource_box, resource_caption, resource]]:
		var box: Panel = pair[0]
		var caption: Label = pair[1]
		var value: Label = pair[2]
		_place(caption, Rect2(Vector2(58, 8) * u, Vector2(box.size.x - 70.0 * u, 24.0 * u)))
		_place(value, Rect2(Vector2(58, 30) * u, Vector2(box.size.x - 70.0 * u, 39.0 * u)))
		box.queue_redraw()
	_place(weapon, Rect2(Vector2(inset, weapon_y), Vector2(text_width, 32.0 * u)))
	_place(_detail_lines, Rect2(Vector2.ZERO, details.size))
	_place(_card_trim, Rect2(Vector2.ZERO, showcase.size))
	_crop_art()
	_card_trim.queue_redraw()
	_detail_lines.queue_redraw()
	selection_marker.queue_redraw()
	_publish_buttons()


func _draw_selection_marker() -> void:
	if not class_buttons.has(selected_class):
		return
	var button: Button = class_buttons[selected_class]
	var center := button.position + Vector2(button.size.x * 0.5, button.size.y + 5.0 * _unit) - selection_marker.position
	selection_marker.draw_colored_polygon(PackedVector2Array([center + Vector2(-8, 0) * _unit, center + Vector2(8, 0) * _unit, center + Vector2(0, 7) * _unit]), GOLD)


func _draw_detail_lines() -> void:
	var u := _unit
	var y := weapon.position.y - 15.0 * u
	_detail_lines.draw_line(Vector2(24.0 * u, y), Vector2(details.size.x - 24.0 * u, y), Color(0.58, 0.52, 0.35, 0.43), 1.0, true)
	var divider_x := class_emblem.position.x + 72.0 * u
	_detail_lines.draw_line(Vector2(divider_x, 24.0 * u), Vector2(divider_x, 98.0 * u), Color(0.58, 0.52, 0.35, 0.6), 1.0, true)


func _draw_stat_symbol(panel: Panel, energy: bool) -> void:
	var u := _unit
	var center := Vector2(29.0 * u, panel.size.y * 0.5)
	var color := Color("c4a56c") if not energy or selected_class == "warrior" else Color("a9c7d2")
	var points := PackedVector2Array()
	if energy:
		# A small flame-shaped glyph, drawn as UI line work rather than a substitute skill icon.
		for point in [Vector2(0, -17), Vector2(-3, -7), Vector2(-9, -2), Vector2(-11, 5), Vector2(-8, 12), Vector2(-2, 15), Vector2(5, 13), Vector2(10, 8), Vector2(10, 1), Vector2(6, -7), Vector2(5, 1), Vector2(0, -17)]:
			points.append(center + point * u)
	else:
		for point in [Vector2(0, -7), Vector2(-5, -12), Vector2(-11, -11), Vector2(-15, -6), Vector2(-15, 0), Vector2(-11, 6), Vector2(0, 16), Vector2(11, 6), Vector2(15, 0), Vector2(15, -6), Vector2(11, -11), Vector2(5, -12), Vector2(0, -7)]:
			points.append(center + point * u)
	panel.draw_polyline(points, color, 1.8 * u, true)


func _draw_card_trim() -> void:
	var trim := StyleBoxFlat.new()
	trim.bg_color = Color.TRANSPARENT
	trim.border_color = Color(0.54, 0.49, 0.33, 0.6)
	trim.set_border_width_all(1)
	trim.set_corner_radius_all(18)
	_card_trim.draw_style_box(trim, Rect2(Vector2.ZERO, _card_trim.size))


## Crop from the upper edge so a wide preview retains the hero's head and shoulders.
func _crop_art() -> void:
	if hero_art.size.x <= 0.0 or hero_art.size.y <= 0.0:
		return
	var texture: Texture2D = HERO_ART[selected_class]
	var source := texture.get_size()
	var aspect := hero_art.size.x / maxf(1.0, hero_art.size.y)
	var crop := Vector2(minf(source.x, source.y * aspect), minf(source.y, source.x / maxf(0.01, aspect)))
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(Vector2((source.x - crop.x) * 0.5, 0.0), crop)
	hero_art.texture = atlas


func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size


## Browser automation uses real button centres rather than stale viewport-specific coordinates.
func _publish_buttons() -> void:
	if not OS.has_feature("web"):
		return
	var targets := {"warrior": class_buttons["warrior"], "mage": class_buttons["mage"], "start": start_button, "continue": continue_button, "back": back_button}
	var points := {}
	for key in targets:
		var button: Button = targets[key]
		var center := button.get_global_rect().get_center() / get_viewport_rect().size
		points[key] = [center.x, center.y]
	JavaScriptBridge.eval("window.__sjrpgClassButtons = " + JSON.stringify(points))

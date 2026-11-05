extends Control
## One large hero preview, explicit class tabs and thumb-accessible actions on phones.

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

var selected_class := "warrior"
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
var weapon: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.cover(preload("res://assets/art/ui/select-scene.png")))
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.035, 0.027, 0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	back_button = _button("‹  타이틀", func(): back_requested.emit())
	heading = _label("수호자 선택", 34, UiKit.TEXT, true)
	subtitle = _label("당신의 전투 방식을 선택하세요", 23, UiKit.MUTED)
	for cls in ["warrior", "mage"]:
		var button := _button(GameState.CLASSES[cls]["name"], func(): select_class(cls))
		button.toggle_mode = true
		class_buttons[cls] = button
	showcase = Panel.new()
	showcase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	showcase.add_theme_stylebox_override("panel", UiKit.panel_style(Color("171c18"), Color("766347"), 8))
	add_child(showcase)
	hero_art = TextureRect.new()
	hero_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hero_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	showcase.add_child(hero_art)
	details = Control.new()
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	showcase.add_child(details)
	var face := ColorRect.new()
	face.color = Color("171c18")
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(face)
	hero_name = _label("", 40, UiKit.TEXT, true, details)
	role = _label("", 23, UiKit.GOLD, false, details)
	description = _label("", 24, UiKit.TEXT, false, details)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.max_lines_visible = 2
	description.clip_text = true
	health = _label("", 24, UiKit.TEXT, false, details)
	resource = _label("", 24, UiKit.TEXT, false, details)
	weapon = _label("", 22, UiKit.MUTED, false, details)
	start_button = _button("", _choose)
	UiKit.style_button(start_button, true)
	continue_button = _button("이어하기 · 저장 없음", func(): continue_requested.emit())
	continue_button.disabled = true
	if GameState.has_save() and GameState.load_game():
		selected_class = GameState.hero_class
		continue_button.text = "이어하기 · %s Lv.%d%s" % [GameState.class_info()["name"], GameState.level, " · 백업 복원" if GameState.loaded_backup else ""]
		continue_button.disabled = false
	elif GameState.has_save_files():
		continue_button.text = "저장을 읽을 수 없습니다"
	resized.connect(_layout)
	select_class(selected_class)
	_layout()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sjrpgClassSelectReady = true")


func _button(text: String, action: Callable) -> Button:
	var button := UiKit.button(text, 25)
	button.custom_minimum_size = Vector2.ZERO
	button.pressed.connect(action)
	add_child(button)
	return button


func _label(text: String, font_size: int, color: Color, bold := false, parent: Node = null) -> Label:
	var label := UiKit.label(text, font_size, color, bold)
	label.add_theme_constant_override("outline_size", 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(label)
	return label


func select_class(cls: String) -> void:
	if not HERO_ART.has(cls):
		return
	selected_class = cls
	var info: Dictionary = GameState.CLASSES[cls]
	_crop_art()
	hero_name.text = info["name"]
	role.text = ROLES[cls]
	description.text = DESCRIPTIONS[cls]
	health.text = "체력  %s" % HudArt.stat(info["hp"])
	resource.text = "%s  %s" % [info["resource"], HudArt.res(info["resource_max"])]
	weapon.text = "시작 무기 · " + str(Gear.def("shortsword" if cls == "warrior" else "wand")["name"])
	start_button.text = "%s로 모험 시작" % info["name"]
	for key in class_buttons:
		var button: Button = class_buttons[key]
		button.set_pressed_no_signal(key == cls)
		UiKit.style_button(button, false, key == cls)


func _choose() -> void:
	chosen.emit(selected_class)


func _layout() -> void:
	if start_button == null:
		return
	var margins := PanelFrame.safe_margins(get_viewport())
	var available := Rect2(Vector2(margins.x, margins.y), size - Vector2(margins.x + margins.z, margins.y + margins.w))
	var portrait := available.size.y > available.size.x
	var unit := minf(available.size.x / 720.0, available.size.y / 1280.0) if portrait else minf(available.size.x / 1080.0, available.size.y / 720.0)
	for entry in [[heading, 34], [subtitle, 23], [hero_name, 40], [role, 23], [description, 24], [health, 24], [resource, 24], [weapon, 22], [back_button, 23], [start_button, 27], [continue_button, 24], [class_buttons["warrior"], 27], [class_buttons["mage"], 27]]:
		entry[0].add_theme_font_size_override("font_size", roundi(float(entry[1]) * unit))
	var area := available.grow(-24.0 * unit)
	if area.size.x > 1240.0 * unit:
		area.position.x += (area.size.x - 1240.0 * unit) * 0.5
		area.size.x = 1240.0 * unit
	_place(back_button, Rect2(area.position, Vector2(150, 72) * unit))
	_place(heading, Rect2(area.position + Vector2(174, 0) * unit, Vector2(area.size.x - 174.0 * unit, 42.0 * unit)))
	_place(subtitle, Rect2(area.position + Vector2(174, 48) * unit, Vector2(area.size.x - 174.0 * unit, 32.0 * unit)))
	var tabs_y := area.position.y + 96.0 * unit
	var tab_width := (area.size.x - 12.0 * unit) / 2.0
	for index in 2:
		_place(class_buttons[["warrior", "mage"][index]], Rect2(Vector2(area.position.x + index * (tab_width + 12.0 * unit), tabs_y), Vector2(tab_width, 72.0 * unit)))
	var footer_y := area.end.y - (172.0 if portrait else 80.0) * unit
	var body_y := tabs_y + 88.0 * unit
	_place(showcase, Rect2(Vector2(area.position.x, body_y), Vector2(area.size.x, footer_y - body_y - 20.0 * unit)))
	var inner := Rect2(Vector2.ONE * 3.0 * unit, showcase.size - Vector2.ONE * 6.0 * unit)
	if portrait:
		var art_height := inner.size.y - 300.0 * unit
		_place(hero_art, Rect2(inner.position, Vector2(inner.size.x, art_height)))
		_place(details, Rect2(inner.position + Vector2(0, art_height), Vector2(inner.size.x, 300.0 * unit)))
		_place(start_button, Rect2(Vector2(area.position.x, footer_y), Vector2(area.size.x, 80.0 * unit)))
		_place(continue_button, Rect2(Vector2(area.position.x, footer_y + 92.0 * unit), Vector2(area.size.x, 80.0 * unit)))
	else:
		var art_width := minf(inner.size.x * 0.44, inner.size.y * 1.05)
		_place(hero_art, Rect2(inner.position, Vector2(art_width, inner.size.y)))
		_place(details, Rect2(inner.position + Vector2(art_width, 0), Vector2(inner.size.x - art_width, inner.size.y)))
		var primary_width := (area.size.x - 16.0 * unit) * 0.55
		_place(start_button, Rect2(Vector2(area.position.x, footer_y), Vector2(primary_width, 80.0 * unit)))
		_place(continue_button, Rect2(Vector2(area.position.x + primary_width + 16.0 * unit, footer_y), Vector2(area.size.x - primary_width - 16.0 * unit, 80.0 * unit)))
	var inset := 26.0 * unit
	var width := details.size.x - inset * 2.0
	var top := maxf(18.0 * unit, (details.size.y - 270.0 * unit) * 0.5)
	_place(hero_name, Rect2(Vector2(inset, top), Vector2(width, 48.0 * unit)))
	_place(role, Rect2(Vector2(inset, top + 54.0 * unit), Vector2(width, 32.0 * unit)))
	_place(description, Rect2(Vector2(inset, top + 100.0 * unit), Vector2(width, 68.0 * unit)))
	_place(health, Rect2(Vector2(inset, top + 184.0 * unit), Vector2(width * 0.52, 34.0 * unit)))
	_place(resource, Rect2(Vector2(inset + width * 0.52, top + 184.0 * unit), Vector2(width * 0.48, 34.0 * unit)))
	_place(weapon, Rect2(Vector2(inset, top + 232.0 * unit), Vector2(width, 32.0 * unit)))

	_crop_art()
	_publish_buttons()


## Crop from the upper edge so a wide phone preview never cuts off the hero's head.
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

extends Control
## Hero selection (원본: lib/src/app/class_selection.dart).

signal chosen(cls: String)
signal continue_requested
signal back_requested

const CARDS := {
	"warrior": preload("res://assets/art/ui/select-warrior-card.png"),
	"mage": preload("res://assets/art/ui/select-mage-card.png"),
}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.cover(preload("res://assets/art/ui/select-scene.png")))
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)

	var heading := UiKit.label("모험을 함께할 수호자를 고르세요", 34, UiKit.GOLD, true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)

	var row := BoxContainer.new()
	var view := get_viewport_rect().size
	row.vertical = view.y > view.x
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	column.add_child(row)
	for cls in ["warrior", "mage"]:
		row.add_child(_card(cls))

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 20)
	column.add_child(actions)
	var back := UiKit.button("타이틀", 22)
	back.custom_minimum_size = Vector2(160, 52)
	back.pressed.connect(func(): back_requested.emit())
	actions.add_child(back)
	var cont := UiKit.button("이어하기 · 저장 없음", 22)
	cont.custom_minimum_size = Vector2(260, 64)
	cont.disabled = true
	if GameState.has_save() and GameState.load_game():
		cont.text = "이어하기 · %s Lv.%d" % [GameState.class_info()["name"], GameState.level]
		if GameState.loaded_backup:
			cont.text += " (백업 복원)"
		cont.disabled = false
	elif FileAccess.file_exists(GameState.save_path):
		cont.text = "이어하기 · 저장을 읽을 수 없음"
	cont.pressed.connect(func(): continue_requested.emit())
	actions.add_child(cont)


func _card(cls: String) -> Control:
	var info: Dictionary = GameState.CLASSES[cls]
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style())
	panel.custom_minimum_size = Vector2(380, 0)
	if get_viewport_rect().size.y > get_viewport_rect().size.x:
		panel.custom_minimum_size = Vector2(560, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var art := TextureRect.new()
	art.texture = CARDS[cls]
	art.custom_minimum_size = Vector2(0, 190)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(art)
	var name_label := UiKit.label(info["name"], 30, UiKit.GOLD, true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	var desc := UiKit.label(info["desc"], 18)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)
	var weapon: String = Gear.def("shortsword" if cls == "warrior" else "wand")["name"]
	var stats := UiKit.label("체력 %s · %s %s · 시작 무기 %s" % [HudArt.stat(info["hp"]), info["resource"], HudArt.res(info["resource_max"]), weapon], 17, Color(0.8, 0.95, 0.85))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stats)
	var pick := UiKit.button("%s로 시작" % info["name"], 22)
	pick.pressed.connect(func(): chosen.emit(cls))
	box.add_child(pick)
	return panel

extends TestCase
## Real selection callbacks, saved bytes and adaptive controls; no adventure is loaded by preview.

class EntryRoot:
	extends "res://scripts/main.gd"
	var launches := 0
	func _ready() -> void:
		pass
	func start_game() -> void:
		launches += 1
		_swap(Node.new())

func _clean_slots() -> void:
	for slot in range(1, 5):
		GameState.delete_slot(slot)

func _buttons_fit(select: Control, dimensions: Vector2i) -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
	var unit := minf(dimensions.x / 720.0, dimensions.y / 1280.0) if dimensions.y > dimensions.x else minf(dimensions.x / 1280.0, dimensions.y / 720.0)
	var controls: Array = [select.start_button, select.continue_button, select.back_button, select.slot_switch] + select.class_buttons.values() + select.slot_buttons + select.delete_buttons
	for button: Button in controls:
		if button.is_visible_in_tree() and (select._stage == "class" or not select.slot_buttons.has(button) and not select.delete_buttons.has(button)):
			check("visible entry action remains safe and thumb-sized %s/%s" % [dimensions, button.text], bounds.encloses(button.get_global_rect()) and button.size.y >= 64.0 * unit)
	check("entry Back target never overlaps the actual title rectangle", not select.back_button.get_global_rect().intersects(select.heading.get_global_rect()))
	if select.showcase.is_visible_in_tree():
		check("entry uses a full illustration without stretching or clipping its frame", bounds.encloses(select.showcase.get_global_rect()) and select.hero_art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED and select.hero_art.get_global_rect().size.is_equal_approx(select.showcase.get_global_rect().size))
	if select._stage == "class":
		check("class tabs and main action remain separate", not select.start_button.get_global_rect().intersects(select.class_buttons["warrior"].get_global_rect()) and not select.class_buttons["warrior"].get_global_rect().intersects(select.class_buttons["mage"].get_global_rect()))
		check("role, description and real stats retain their own space", select.role.get_global_rect().end.y <= select.description.get_global_rect().position.y and select.description.get_global_rect().end.y < select.health.get_global_rect().position.y and select.details.get_global_rect().encloses(select.resource.get_global_rect()))
		if dimensions.y > dimensions.x:
			check("portrait class tabs precede the dominant illustration and readable information card",
				select.class_buttons["mage"].get_global_rect().end.y <= select.showcase.get_global_rect().position.y
				and select.showcase.get_global_rect().end.y <= select.details.get_global_rect().position.y
				and select.showcase.size.y >= dimensions.y * 0.20
				and select.details.get_global_rect().end.y < select.start_button.get_global_rect().position.y)
		else:
			check("landscape keeps illustration alongside the complete controls", select.showcase.get_global_rect().end.x < select.details.get_global_rect().position.x)
		check("class information and tabs keep separate bounds", not select.details.get_global_rect().intersects(select.class_buttons["mage"].get_global_rect()) and not select.start_button.get_global_rect().intersects(select.slot_switch.get_global_rect()))
	else:
		var clipping: Rect2 = select.slot_scroll.get_global_rect()
		check("save scroll and fixed footer remain separate and safe", bounds.encloses(clipping) and bounds.encloses(select.slot_footer.get_global_rect()) and not clipping.intersects(select.slot_footer.get_global_rect()))
		for index in 4:
			if select.delete_buttons[index].is_visible_in_tree():
				check("slot row and its delete action have separate targets", not select.slot_buttons[index].get_global_rect().intersects(select.delete_buttons[index].get_global_rect()))
			check("save row stays thumb-sized inside its clipping viewport", select.slot_buttons[index].size.y >= 64.0 * unit and clipping.size.y >= select.slot_buttons[index].size.y)
			if index > 0:
				var previous: Rect2 = select.slot_buttons[index - 1].get_global_rect()
				var current: Rect2 = select.slot_buttons[index].get_global_rect()
				if previous.end.y >= current.position.y:
					print("FAIL SAVE_ROW_DIAG ", JSON.stringify({"view": [dimensions.x, dimensions.y], "previous": str(previous), "current": str(current), "band": str(select.slot_bands[index].get_global_rect())}))
				check("save rows never overlap", previous.end.y < current.position.y)

func _canvas_z(item: CanvasItem) -> int:
	var result := 0
	var current := item
	while current != null:
		result += current.z_index
		if not current.z_as_relative:
			break
		current = current.get_parent() as CanvasItem
	return result


func run() -> void:
	var background := EntryUi.image(EntryUi.BACKGROUND)
	check("generated entry background exists at its actual delivered dimensions", background != null and background.get_size() == Vector2(1536, 1024))
	check("pre-engine and native title share the same delivered background bytes", FileAccess.get_file_as_bytes("res://web/loading-bg.webp") == FileAccess.get_file_as_bytes(EntryUi.BACKGROUND))
	for path: String in EntryUi.HEROES.values():
		var illustration := EntryUi.image(path)
		var pixels := Image.load_from_file(path)
		check("generated class illustration exists with actual transparent pixels", illustration != null and illustration.get_size() == Vector2(1024, 1536) and pixels != null and pixels.detect_alpha() != Image.ALPHA_NONE)
	var old_path := GameState.slot_path(1)
	var old_slot := GameState.active_slot
	GameState.save_path = "user://tests/entry-four.json"
	_clean_slots()
	GameState.select_slot(1)
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	add_child(view)
	var select := preload("res://scripts/class_select.gd").new()
	view.add_child(select)
	await _frames(3)
	check("first launch opens an empty slot directly to hero choice", select.selected_slot == 1 and select._stage == "class" and not select.start_button.disabled)
	var emitted: Array[String] = []
	select.chosen.connect(func(cls: String): emitted.append(cls))
	var unchanged_class := GameState.hero_class
	for dimensions in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(540, 960), Vector2i(1600, 720), Vector2i(568, 320), Vector2i(720, 1280)]:
		view.size = dimensions
		await _frames(3)
		for cls: String in ["warrior", "mage"]:
			select.class_buttons[cls].pressed.emit()
			check("class preview only updates the chosen illustration/role", select.selected_class == cls and GameState.hero_class == unchanged_class and emitted.is_empty())
			check("class preview uses actual starting values", HudArt.stat(GameState.CLASSES[cls]["hp"]) in select.health.text and HudArt.res(GameState.CLASSES[cls]["resource_max"]) in select.resource.text)
			_buttons_fit(select, dimensions)
		select.slot_switch.pressed.emit()
		await _frames(3)
		check("slot change exposes exactly four independent choices", select._stage == "slots" and select.slot_buttons.size() == 4)
		_buttons_fit(select, dimensions)
		select.slot_buttons[2].pressed.emit()
		check("empty slot selection opens hero choice in that slot", select.selected_slot == 3 and select._stage == "class")
	select.start_button.pressed.emit()
	check("only the explicit start callback emits the selected class", emitted == ["mage"])
	select.queue_free()
	await _frames(2)
	check("fixture creates real independent warrior save", GameState.create_slot(2, "warrior"))
	GameState.gold = 321
	GameState.level = 7
	GameState.save_game()
	var path := GameState.slot_path(2)
	var saved := FileAccess.get_file_as_string(path)
	var loaded := preload("res://scripts/class_select.gd").new()
	view.add_child(loaded)
	await _frames(3)
	check("saved entry starts at slot choices and identifies the actual hero", loaded._stage == "slots" and loaded.selected_slot == 2 and not loaded.continue_button.disabled and "Lv.7" in loaded.slot_buttons[1].text and loaded.selected_class == "warrior")
	loaded.select_class("mage")
	loaded._choose()
	check("occupied class/start callbacks cannot replace existing bytes", FileAccess.get_file_as_string(path) == saved and GameState.hero_class == "warrior" and GameState.gold == 321)
	loaded.delete_buttons[1].pressed.emit()
	check("deletion names a real slot and waits for confirmation", is_instance_valid(loaded._delete_dialog) and FileAccess.get_file_as_string(path) == saved)
	var dimmer := loaded._delete_dialog.get_child(0) as CanvasItem
	var below_dimmer := true
	for index in 4:
		below_dimmer = below_dimmer and _canvas_z(loaded.slot_number_labels[index]) <= _canvas_z(dimmer)
		below_dimmer = below_dimmer and _canvas_z(loaded.slot_number_badges[index]) <= _canvas_z(dimmer)
	check("actual save badges stay beneath the delete dimmer and action controls",
		below_dimmer and loaded.slot_scroll.get_index() < loaded._delete_dialog.get_index())
	loaded._delete_dialog.closed.emit()
	await _frames(2)
	check("cancel leaves the exact save intact", FileAccess.get_file_as_string(path) == saved)
	loaded.delete_buttons[1].pressed.emit()
	var confirm: Button = loaded._delete_dialog.footer.get_child(1)
	confirm.pressed.emit()
	await _frames(2)
	check("confirmed deletion frees only the named slot", not FileAccess.file_exists(path) and not bool(GameState.slot_summaries()[1]["occupied"]))
	# An unreadable file is occupied, never an invitation to silently overwrite.
	var broken_path := GameState.slot_path(4)
	var broken := FileAccess.open(broken_path, FileAccess.WRITE)
	broken.store_string("{broken")
	broken.close()
	loaded.refresh_slots()
	loaded.select_slot(4)
	check("unreadable slot blocks both continue and new creation", loaded.continue_button.disabled and loaded.start_button.disabled and "읽을 수 없는" in loaded.slot_buttons[3].text)
	loaded._choose()
	check("unreadable slot preview preserves exact original bytes", FileAccess.get_file_as_string(broken_path) == "{broken")
	view.queue_free()
	await _frames(2)
	var root := EntryRoot.new()
	add_child(root)
	root.show_class_select()
	await _frames(2)
	root.current.select_slot(3)
	root.current.select_class("mage")
	root._choose_hero("mage")
	root._choose_hero("mage")
	for frame in 120:
		if not root._entry_starting:
			break
		await _frames(1)
	check("rapid repeated start callbacks create and launch exactly one real adventure", root.launches == 1 and bool(GameState.slot_summaries()[2]["valid"]) and str(GameState.slot_summaries()[2]["class"]) == "mage")
	root.queue_free()
	await _frames(2)
	_clean_slots()
	GameState.save_path = old_path
	GameState.select_slot(old_slot)

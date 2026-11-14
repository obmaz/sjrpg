extends TestCase
## 타이틀의 새 생성·이어가기 진입과 저장·패드·뒤로가기 경계를 확인한다.


class EntryRoot:
	extends "res://scripts/app/main.gd"
	var launches := 0

	func _ready() -> void:
		pass

	func start_game() -> void:
		launches += 1
		_swap(Node.new())


func run() -> void:
	for slot in range(1, GameState.MAX_SAVE_SLOTS + 1):
		GameState.delete_slot(slot)
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	add_child(view)
	var root := EntryRoot.new()
	view.add_child(root)
	root.show_title()
	await _frames(2)
	for dimensions: Vector2i in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(320, 568), Vector2i(768, 896), Vector2i(896, 768), Vector2i(800, 800), Vector2i(344, 883), Vector2i(883, 344), Vector2i(568, 320)]:
		view.size = dimensions
		await _frames(2)
		var buttons: Array[Button] = [
			root.current._btn_new_game, root.current._btn_load_game, root.current._btn_settings
		]
		var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
		var design_unit := (
			minf(dimensions.x / 720.0, dimensions.y / 1280.0)
			if dimensions.y > dimensions.x
			else minf(dimensions.x / 1080.0, dimensions.y / 720.0)
		)
		var touch_minimum := maxf(44.0, 64.0 * design_unit)
		for index in buttons.size():
			var button := buttons[index]
			if not bounds.encloses(button.get_global_rect()) or button.size.y + 0.1 < touch_minimum:
				print("FAIL TITLE_BUTTON_DIAG ", JSON.stringify({
					"view": str(dimensions), "text": button.text,
					"rect": str(button.get_global_rect()),
					"minimum": str(button.get_combined_minimum_size()),
					"custom_minimum": str(button.custom_minimum_size),
					"expected_touch": touch_minimum,
					"font": button.get_theme_font_size("font_size")
				}))
			check(
				"title menu stays inside the viewport %s/%s" % [dimensions, button.text],
				bounds.encloses(buttons[index].get_global_rect())
			)
			check("title menu keeps a usable touch height %s/%s" % [dimensions, button.text], buttons[index].size.y + 0.1 >= touch_minimum)
			check("title menu copy remains readable", buttons[index].get_theme_font_size("font_size") >= 16)
			if index > 0:
				check(
					"title menus do not overlap",
					not buttons[index - 1].get_global_rect().intersects(
						buttons[index].get_global_rect()
					)
				)
		var previous: Label
		for caption: Label in [root.current._chapter, root.current._title, root.current._subtitle]:
			if not bounds.encloses(caption.get_global_rect()) or (previous != null and previous.get_global_rect().end.y > caption.get_global_rect().position.y):
				print("FAIL TITLE_COPY_DIAG ", JSON.stringify({
					"view": str(dimensions), "text": caption.text,
					"rect": str(caption.get_global_rect()),
					"minimum": str(caption.get_combined_minimum_size()),
					"font": caption.get_theme_font_size("font_size"),
					"previous": str(previous.get_global_rect()) if previous != null else ""
				}))
			check("title copy remains fully inside the real viewport %s/%s" % [dimensions, caption.text], bounds.encloses(caption.get_global_rect()))
			check("title copy keeps every wrapped line visible", caption.get_visible_line_count() == caption.get_line_count())
			if previous != null:
				check("title copy does not overlap %s/%s" % [dimensions, caption.text], previous.get_global_rect().end.y <= caption.get_global_rect().position.y)
			previous = caption
		check("title subtitle and the first action remain separate", previous.get_global_rect().end.y <= buttons[0].get_global_rect().position.y)
	root.current._btn_load_game.pressed.emit()
	await _frames(2)
	var menus := _panels(root)
	if check(
		"load button opens the concept continue screen even with no saves",
		(
			_is_selection(root.current)
			and root.current.entry_mode == "continue"
			and root.current._stage == "slots"
			and root.current.slot_buttons.size() == GameState.MAX_SAVE_SLOTS
			and menus.is_empty()
		)
	):
		root.handle_system_back()
		await _frames(2)
		check("continue Back returns to title", _is_title(root.current))
	root.current._btn_settings.pressed.emit()
	await _frames(2)
	menus = _panels(root)
	if check(
		"settings button opens the real settings panel",
		menus.size() == 1 and menus[0] is SettingsPanel
	):
		var settings: SettingsPanel = menus[0]
		settings._open_save_load_dialog()
		await _frames(2)
		var nested := _panels(settings)
		if check("settings opens its nested load menu", nested.size() == 1):
			root.handle_system_back()
			await _frames(2)
			check(
				"nested cancel retains settings and removes only load",
				is_instance_valid(settings) and _panels(settings).is_empty()
			)
		settings.closed.emit()
		await _frames(2)
		check("cancelling title settings removes its modal", _panels(root).is_empty())
	await _new_entry_modes(root)
	await _failed_title_load_returns_to_selection(root)
	await _slot_status_messages(root)
	GameState.select_slot(1)
	GameState.delete_save()
	check("title load fixture creates a fresh saved adventure", GameState.new_game("mage"))
	GameState.gold = 137
	check("title load fixture saves its actual progress", GameState.save_game())
	GameState.gold = 1
	root.current._btn_load_game.pressed.emit()
	await _frames(2)
	var load_menu: Control = root.current
	load_menu.slot_buttons[0].pressed.emit()
	await _frames(2)
	check("selecting a real saved row enables continue", not load_menu.continue_button.disabled)
	check("continue preview does not apply saved progress", GameState.gold == 1)
	load_menu.continue_button.pressed.emit()
	for frame in 120:
		await _frames(1)
		if not root._entry_starting:
			break
	check(
		"title load reads the selected save before launching once",
		root.launches == 1 and GameState.hero_class == "mage" and GameState.gold == 137
	)
	check(
		"successful title load retires the selection and loading screen",
		not is_instance_valid(load_menu) and not root._entry_starting
	)
	view.queue_free()
	await _frames(2)
	await _gamepad_menus()
	await _failed_save_keeps_settings()


func _is_selection(node: Node) -> bool:
	return node.get_script() == preload("res://scripts/ui/screens/class_select.gd")


func _is_title(node: Node) -> bool:
	return node.get_script() == preload("res://scripts/ui/screens/title_screen.gd")


func _failed_title_load_returns_to_selection(root: EntryRoot) -> void:
	# 타이틀 설정의 불러오기는 기존 게임이 없어도 읽기 실패를 같은 슬롯 화면에서 안내한다.
	var path := GameState.slot_path(4)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{unreadable")
	file.close()
	root.current._btn_settings.pressed.emit()
	await _frames(2)
	var settings: SettingsPanel = _panels(root)[0]
	settings.load_requested.emit(4)
	settings.closed.emit()
	for frame in 120:
		await _frames(1)
		if not root._entry_starting:
			break
	check(
		"failed title settings load returns to the intended continue screen with its error",
		(
			_is_selection(root.current)
			and root.current.entry_mode == "continue"
			and root.current.selected_slot == 4
			and root.current.subtitle.text.contains("모험을 읽지 못했습니다")
			and not root._entry_starting
			and root.launches == 0
		)
	)
	check(
		"failed title load preserves the damaged file",
		FileAccess.get_file_as_string(path) == "{unreadable"
	)
	root.handle_system_back()
	await _frames(2)
	GameState.delete_slot(4)


func _new_entry_modes(root: EntryRoot) -> void:
	check("entry fixture creates an occupied active slot", GameState.create_slot(2, "warrior"))
	var saved := FileAccess.get_file_as_string(GameState.slot_path(2))
	GameState.gold = 73
	root.current._btn_new_game.pressed.emit()
	await _frames(2)
	check(
		"new adventure chooses an empty slot instead of reopening the active save",
		(
			_is_selection(root.current)
			and root.current.entry_mode == "new"
			and root.current._stage == "class"
			and root.current.selected_slot == 1
		)
	)
	check(
		"new hero preview preserves the live hero and existing save bytes",
		(
			GameState.gold == 73
			and GameState.hero_class == "warrior"
			and FileAccess.get_file_as_string(GameState.slot_path(2)) == saved
		)
	)
	root.current.slot_switch.pressed.emit()
	await _frames(2)
	root.current.continue_button.pressed.emit()
	await _frames(2)
	check(
		"empty-slot main action opens hero choice from slot management",
		root.current._stage == "class" and root.current.selected_slot == 1
	)
	root.handle_system_back()
	await _frames(2)
	check(
		"Back after the empty-slot main action returns to slot management",
		_is_selection(root.current) and root.current._stage == "slots"
	)
	root.current.back_button.pressed.emit()
	await _frames(2)
	root.current._btn_load_game.pressed.emit()
	await _frames(2)
	check(
		"continue explicitly opens the occupied active slot in the same screen family",
		(
			_is_selection(root.current)
			and root.current.entry_mode == "continue"
			and root.current._stage == "slots"
			and root.current.selected_slot == 2
		)
	)
	root.handle_system_back()
	await _frames(2)
	for slot in [1, 3, 4]:
		check("entry fixture fills save slot %d" % slot, GameState.create_slot(slot, "mage"))
	var bytes: Array[String] = []
	for slot in range(1, GameState.MAX_SAVE_SLOTS + 1):
		bytes.append(FileAccess.get_file_as_string(GameState.slot_path(slot)))
	root.current._btn_new_game.pressed.emit()
	await _frames(2)
	check(
		"full slots show safe slot management instead of authorizing overwrite",
		(
			_is_selection(root.current)
			and root.current._stage == "slots"
			and root.current.start_button.disabled
		)
	)
	root.current.back_button.pressed.emit()
	await _frames(2)
	for slot in range(1, GameState.MAX_SAVE_SLOTS + 1):
		check(
			"entry routing never replaces an occupied slot %d" % slot,
			FileAccess.get_file_as_string(GameState.slot_path(slot)) == bytes[slot - 1]
		)
		GameState.delete_slot(slot)


func _gamepad_menus() -> void:
	# 실제 패드 내비게이션은 자기 뷰포트의 포커스를 읽으므로 루트 뷰포트에 배치한다.
	var root := EntryRoot.new()
	add_child(root)
	root.show_title()
	await _frames(2)
	var nav := Gamepad.get_node("Navigation") as GamepadNavigation
	var old_mode: bool = Gamepad.using_gamepad
	var old_combat: bool = Gamepad._combat
	Gamepad.using_gamepad = true
	for menu in ["load_game", "settings"]:
		nav._process(0.11)
		nav._refresh()
		var button: Button = root.current.get("_btn_" + menu)
		button.grab_focus()
		nav._action("primary")
		await _frames(2)
		var panels := _panels(root)
		var expected := panels.size() == 1 and panels[0] is SettingsPanel
		if menu == "load_game":
			expected = _is_selection(root.current) and root.current.entry_mode == "continue"
		check("pad primary opens the focused title menu: " + menu, expected)
		if not expected:
			break
		root.handle_system_back()
		await _frames(2)
	if (
		_panels(root).is_empty()
		and root.current.get_script() == preload("res://scripts/ui/screens/title_screen.gd")
	):
		nav._process(0.11)
		nav._refresh()
		root.current._btn_new_game.grab_focus()
		nav._action("primary")
		await _frames(2)
		check(
			"pad primary on new adventure opens the real selection screen",
			root.current.get_script() == preload("res://scripts/ui/screens/class_select.gd")
		)
	root.queue_free()
	await _frames(2)
	Gamepad.using_gamepad = old_mode
	Gamepad.set_combat_enabled(old_combat)
	Gamepad.require_neutral()


func _slot_status_messages(root: EntryRoot) -> void:
	for slot in [2, 3]:
		GameState.select_slot(slot)
		GameState.delete_save()
		check("slot notice fixture creates hero %d" % slot, GameState.new_game("warrior"))
		if slot == 2:
			check("slot notice fixture creates a readable backup", GameState.save_game())
		var file := FileAccess.open(GameState.save_path, FileAccess.WRITE)
		if not check("slot notice fixture opens primary %d" % slot, file != null):
			continue
		file.store_string("{corrupt")
		file.close()
	root.current._btn_load_game.pressed.emit()
	await _frames(2)
	var panel: Control = root.current
	var backup_text := _label_text(panel.slot_buttons[1])
	var broken_text := _label_text(panel.slot_buttons[2])
	check(
		"continue card identifies the actual recoverable backup",
		backup_text.contains("백업") and bool(panel._summaries[1]["backup"])
	)
	check(
		"unreadable occupied slot reports damage instead of inventing a level zero hero",
		(
			broken_text.contains("읽을 수 없는 모험")
			and broken_text.contains("삭제")
			and not broken_text.contains("Lv.0")
		)
	)
	panel.slot_buttons[1].pressed.emit()
	await _frames(2)
	check(
		"the recovered slot enables the explicit continue action",
		not panel.continue_button.disabled
	)
	panel.slot_buttons[2].pressed.emit()
	await _frames(2)
	check(
		"damaged slot remains manageable but cannot continue or replace its bytes",
		(
			panel.continue_button.disabled
			and panel.start_button.disabled
			and panel.delete_buttons[2].is_visible_in_tree()
			and FileAccess.get_file_as_string(GameState.slot_path(3)) == "{corrupt"
		)
	)
	root.handle_system_back()
	await _frames(2)
	GameState.delete_slot(2)
	GameState.delete_slot(3)


func _label_text(node: Node) -> String:
	var text: String = node.text if node is Label else ""
	for child in node.get_children():
		text += "\n" + _label_text(child)
	return text


func _panels(parent: Node) -> Array[PanelFrame]:
	var result: Array[PanelFrame] = []
	for child in parent.get_children():
		if child is PanelFrame and not child.is_queued_for_deletion():
			result.append(child)
	return result


func _failed_save_keeps_settings() -> void:
	var game := await make_game("mage")
	game.hud.open_settings()
	var settings: SettingsPanel = game.hud._panel
	settings._open_save_load_dialog()
	await _frames(2)
	var dialog: SaveLoadPanel = _panels(settings)[0]
	dialog.selected_slot = GameState.active_slot
	var original := GameState.save_path
	var slot := GameState.active_slot
	GameState.save_path = original + "/unavailable.json"
	dialog._on_load_pressed()
	await _frames(2)
	check(
		"failed save keeps the original live world and slot",
		not game._menu_exit_committed and GameState.active_slot == slot
	)
	check(
		"failed save retains settings and its visible error",
		game.hud._panel == settings and is_instance_valid(settings) and settings._feedback_error
	)
	GameState.save_path = original
	game.hud.close_panel(false)
	game.queue_free()
	await _frames(3)

extends TestCase
## Class previews must survive rotation without hiding actions or changing the adventure.


func run() -> void:
	var old_path := GameState.save_path
	GameState.save_path = "user://tests/entry.json"
	GameState.delete_save()
	GameState.new_game("warrior")
	GameState.delete_save()
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	add_child(view)
	var select := preload("res://scripts/class_select.gd").new()
	view.add_child(select)
	await _frames(3)
	check("empty save has a clear unavailable continue action", select.continue_button.disabled)
	var emitted: Array[String] = []
	select.chosen.connect(func(cls: String): emitted.append(cls))
	for dimensions in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(540, 960), Vector2i(1600, 720), Vector2i(720, 1280)]:
		view.size = dimensions
		await _frames(4)
		for cls in ["warrior", "mage"]:
			select.class_buttons[cls].pressed.emit()
			await _frames(2)
			check("class tab only changes preview %s/%s" % [dimensions, cls], select.selected_class == cls and GameState.hero_class == "warrior" and emitted.is_empty())
			var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
			var unit := minf(dimensions.x / 720.0, dimensions.y / 1280.0) if dimensions.y > dimensions.x else minf(dimensions.x / 1080.0, dimensions.y / 720.0)
			for button in [select.start_button, select.continue_button, select.back_button, select.class_buttons["warrior"], select.class_buttons["mage"]]:
				check("entry actions fit the screen and keep touch height %s" % dimensions, bounds.encloses(button.get_global_rect()) and button.size.y >= 64.0 * unit)
			check("large art and details remain separate after rotation", not select.hero_art.get_global_rect().intersects(select.details.get_global_rect()) and select.showcase.get_global_rect().encloses(select.details.get_global_rect()))
			check("description and stats keep their own space %s/%s" % [dimensions, cls], select.description.get_global_rect().end.y < select.health.get_global_rect().position.y and select.weapon.get_global_rect().end.y <= select.details.get_global_rect().end.y, str([select.description.get_global_rect(), select.health.get_global_rect(), select.weapon.get_global_rect(), select.details.get_global_rect()]))
			check("name and description match selected class", select.hero_name.text == GameState.CLASSES[cls]["name"] and select.start_button.text.begins_with(select.hero_name.text))
	select.start_button.pressed.emit()
	check("only the explicit start action emits the selected hero", emitted == ["mage"])
	view.queue_free()
	await _frames(2)
	GameState.gold = 321
	GameState.level = 7
	GameState.save_game()
	var saved := FileAccess.get_file_as_string(GameState.save_path)
	var loaded := preload("res://scripts/class_select.gd").new()
	add_child(loaded)
	await _frames(3)
	check("continue identifies the real saved hero", not loaded.continue_button.disabled and "Lv.7" in loaded.continue_button.text)
	loaded.select_class("mage")
	check("preview never overwrites an existing save", FileAccess.get_file_as_string(GameState.save_path) == saved and GameState.hero_class == "warrior" and GameState.gold == 321)
	loaded.queue_free()
	await _frames(2)
	GameState.delete_save()
	GameState.save_path = old_path

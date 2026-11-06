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
			var card: Rect2 = select.showcase.get_global_rect()
			var art: Rect2 = select.hero_art.get_global_rect()
			var details: Rect2 = select.details.get_global_rect()
			check("hero card keeps both illustration and details inside its frame", card.encloses(art) and card.encloses(details))
			if dimensions.y > dimensions.x:
				check("portrait information face overlaps the lower illustration as designed", art.intersects(details) and select.hero_name.get_global_rect().position.y > card.position.y + card.size.y * 0.38 and select.hero_name.get_global_rect().position.y < card.position.y + card.size.y * 0.58)
			else:
				check("landscape keeps information alongside the illustration", art.end.x <= details.position.x + 3.0 * unit)
			check("guardian title, tabs and card maintain their hierarchy", select.subtitle.get_global_rect().end.y < select.class_buttons["warrior"].get_global_rect().position.y and select.class_buttons["warrior"].get_global_rect().end.y < card.position.y)
			check("primary action stays below the hero card", card.end.y < select.start_button.get_global_rect().position.y)
			check("class preview displays real starting health and resource", HudArt.stat(GameState.CLASSES[cls]["hp"]) in select.health.text and HudArt.res(GameState.CLASSES[cls]["resource_max"]) in select.resource.text)
			var crop: AtlasTexture = select.hero_art.texture
			check("preview crop keeps the hero's head", is_zero_approx(crop.region.position.y))
			var health_bounds: Rect2 = select.health_box.get_global_rect()
			var resource_bounds: Rect2 = select.resource_box.get_global_rect()
			check("description and framed stats keep their own space %s/%s" % [dimensions, cls], select.description.get_global_rect().end.y + 4.0 * unit <= health_bounds.position.y and health_bounds.end.y + 14.0 * unit < select.weapon.get_global_rect().position.y and select.weapon.get_global_rect().end.y <= details.end.y)
			check("both framed stat boxes stay separate and contain their values", not health_bounds.intersects(resource_bounds) and details.encloses(health_bounds) and details.encloses(resource_bounds) and health_bounds.encloses(select.health.get_global_rect()) and resource_bounds.encloses(select.resource.get_global_rect()))
			check("stat captions identify actual health and class resource", select.health_caption.text == "체력" and select.resource_caption.text == GameState.CLASSES[cls]["resource"])
			check("title and role stay grouped beside the shield", select.hero_name.position.x == select.role.position.x and select.hero_name.position.x > select.class_emblem.position.x + select.class_emblem.size.x and select.hero_name.get_global_rect().end.y <= select.role.get_global_rect().position.y)
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
	await _check_unreadable_save()
	GameState.delete_save()
	GameState.save_path = old_path


func _check_unreadable_save() -> void:
	var root := preload("res://scripts/main.gd").new()
	add_child(root)
	for sample in [["", "{broken"], [".bak", JSON.stringify({"class": "mage", "version": GameState.SAVE_VERSION + 1})], [".tmp", "{interrupted"], [".bak.tmp", "{}"]]:
		GameState.delete_save()
		var path := GameState.save_path + str(sample[0])
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(str(sample[1]))
		file.close()
		root.show_class_select()
		await _frames(3)
		check("unreadable save disables continue but explains its presence " + str(sample[0]), root.current.continue_button.disabled and root.current.continue_button.text == "저장을 읽을 수 없습니다")
		root._choose_hero("mage")
		var confirmation: PanelFrame = null
		for child in root.get_children():
			if child is PanelFrame:
				confirmation = child
		check("unreadable or interrupted files still require replacement confirmation " + str(sample[0]), confirmation != null)
		check("opening replacement confirmation leaves save bytes intact", FileAccess.get_file_as_string(path) == str(sample[1]))
		if confirmation != null:
			confirmation.closed.emit()
		await _frames(3)
		check("cancel preserves unreadable save files", FileAccess.get_file_as_string(path) == str(sample[1]))
	root.queue_free()
	await _frames(2)

extends TestCase
## A deliberately opt-in atmosphere candidate must not become another lighting pass.


func run() -> void:
	var definition := ForestAtmosphere.data()
	for item: Dictionary in [definition["source"], definition["generation"], definition["texture"]] + definition["references"]:
		check("atmosphere candidate matches recorded generated pixels", FileAccess.get_sha256("res://" + str(item["path"])) == str(item["sha256"]))
	check("atmosphere trial stays explicitly separate from default adoption", bool(definition["trial_only"]) and int(definition["extra_dust_draws"]) == 0)
	check("generated source envelope bounds fill without shading a whole rectangle", float(definition["envelope_fraction"]) < 0.4 and definition["source_envelope"].size() >= 3)
	var image := Image.load_from_file("res://" + str(definition["texture"]["path"]))
	var clear := true
	for y in image.get_height():
		for x in [0, 1, image.get_width() - 2, image.get_width() - 1]:
			var color := image.get_pixel(x, y)
			clear = clear and maxf(color.r, maxf(color.g, color.b)) < 0.02
	check("ADD atmosphere has no luminous rectangular matte", clear)
	var game := await make_game()
	var old_quality := Prefs.low_resolution
	var old_motion := Prefs.reduce_motion
	var trial := ForestAtmosphere.new().setup(game.forest_lighting.openings)
	game.field_root.add_child(trial)
	check("atmosphere cannot appear before an explicit trial request", not trial.enabled and not trial.visible)
	trial.set_enabled(true)
	var material := trial.material as CanvasItemMaterial
	check("the two authored light shapes share a single unshaded ADD material", trial.anchors.size() == 2 and trial.get_child_count() == 0 and material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD and material.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED)
	check("shafts sit below actors and the actual canopy shadow layer", trial.z_index == -9 and not trial.z_as_relative and trial.z_index < CanopyShade.GROUND_Z)
	var pivot: Array = definition["pivot"]
	var native := Vector2(pivot[0], pivot[1])
	check("each shaft is registered at its real clearing opening", trial.source_point(0, native).is_equal_approx(game.forest_lighting.openings[0]) and trial.source_point(1, native).is_equal_approx(game.forest_lighting.openings[1]))
	var held := trial.source_point(0, native + Vector2(200, 100))
	game.camera.position += Vector2(100, -50)
	Prefs.set_low_resolution(not old_quality)
	await _frames(2)
	check("camera and quality changes preserve world anchored light geometry", trial.source_point(0, native + Vector2(200, 100)).is_equal_approx(held) and trial.get_viewport() == game.player.get_viewport())
	game.hud.open_settings()
	Prefs.reduce_motion = true
	await _frames(3)
	check("pause and reduced motion cannot animate or move the static light candidate", not trial.is_processing() and trial.source_point(0, native + Vector2(200, 100)).is_equal_approx(held))
	game.hud.close_panel()
	game.field_root.hide()
	check("a hidden forest cannot leak shafts into cave or UI", not trial.is_visible_in_tree())
	game.field_root.show()
	trial.set_enabled(false)
	check("comparison switch removes the candidate without altering daylight", not trial.is_visible_in_tree() and game.forest_lighting.enabled)
	Prefs.reduce_motion = old_motion
	Prefs.set_low_resolution(old_quality)
	game.queue_free()
	await _frames(2)

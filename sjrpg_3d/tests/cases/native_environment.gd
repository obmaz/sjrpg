extends TestCase
## The independent3D project keeps a spatial scene outside town and during cave return.


func run() -> void:
	var game := await make_game("mage")
	if game.ortho_preview == null:
		game._enable_ortho_preview()
	await _frames(3)
	var preview: Ortho3DPreview = game.ortho_preview
	var environment: Ortho3DEnvironment = preview._world_environment
	check("source forest stays hidden before any resize redraw", not game.field_root.visible and not game.world.is_visible_in_tree())
	check("ancestor hiding preserves native actor source flags", game.player.visible)
	check("native forest includes all four authored landmarks", int(environment.report["landmarks"]) == 4)
	check("outer trees and props are individual spatial geometry sharing atlases", int(environment.report["forest_sprites"]) >= 260 and int(environment.report["forest_groups"]) < 20)
	var point: Vector2 = game.village.bridge.position
	game.player.position = point
	preview._sync_scope()
	environment.sync(0.0, true)
	check("leaving town never restores the archived canvas renderer", preview.display.visible and preview._native_visible and game.field_root.visibility_layer == 0 and preview.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
	check("forest uses its spatial group and mode badge", environment.forest.visible and environment.report["scope"] == "forest" and preview._mode_label.text == "3D 숲")
	var root_count := environment.forest.get_child_count()
	for index in 4:
		environment.sync(0.0, true)
	check("static scenery is reused while paused", environment.forest.get_child_count() == root_count)
	game.player.position = game.dungeon.entry_point()
	await _frames(2)
	var entered: bool = game.dungeon.enter()
	check("existing cave gameplay entry remains available", entered)
	if entered:
		check("source cave stays hidden before its first draw", not game.dungeon._root.visible and not game.world.is_visible_in_tree() and game.player.visible)
		preview._sync_scope()
		preview._affordances.sync()
		environment.sync(0.0, true)
		check("cave switches spatial groups without a2D fallback", not environment.forest.visible and environment.cave.visible and preview.display.visible and preview._native_visible and game.dungeon._root.visibility_layer == 0)
		check("cave uses actual textured spatial floors and wall volumes", int(environment.report["cave_walls"]) > 10 and int(environment.report["cave_sprites"]) > 10 and int(environment.report["cave_groups"]) < 12)
		check("native cave lamps follow the ten authored lantern pivots", environment._cave_lights.size() == 10)
		check("native cave labels and portals exclude the town", preview._mode_label.text == "3D 동굴" and preview._affordances._art.is_empty())
		var hidden_headers := true
		for header: Dictionary in preview._affordances._headers.values():
			hidden_headers = hidden_headers and not (header["root"] as Node3D).visible
		check("town resident headers remain hidden in cave", hidden_headers)
		var batch: Dictionary = environment.cave.get_meta("static_batch")
		check("cave walls share a bounded spatial batch", int(batch["groups"]) <= 2 and int(batch["boxes"]) > 10)
		game.dungeon.leave("")
		check("cave return never shows source canvas even transiently", not game.field_root.visible)
		preview._sync_scope()
		environment.sync(0.0, true)
		check("cave return restores the native forest only", environment.forest.visible and not environment.cave.visible and game.field_root.visibility_layer == 0 and preview._native_visible)
	game.queue_free()
	await _frames(2)

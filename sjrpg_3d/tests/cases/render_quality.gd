extends TestCase

func run() -> void:
	var previous := Prefs.low_resolution
	Prefs.set_low_resolution(false)
	var game := await make_game()
	await _frames(3)
	var size_before: Vector2 = game.scene_view.get_visible_rect().size
	var view_before: Vector2 = game.scene_view.get_visible_rect().size / game.camera.zoom
	var hud_before: Vector2 = game.hud.minimap.size
	var gold := GameState.gold
	var renderer: WorldRenderer3D = game.world_renderer
	var native_size := renderer.viewport.size
	var native_view := renderer.camera.size
	var source_viewport: Viewport = game.player.get_viewport()
	var source_parent: Node = game.field_root.get_parent()
	var requested: Vector2 = game.get_viewport().get_visible_rect().size
	check("full quality displays the bounded native target while source drawing stays culled",
		renderer.display.visible and renderer.viewport.size == WorldRenderer3D.render_size(requested, false)
		and renderer.viewport.msaa_3d == Viewport.MSAA_2X
		and game.field_root.visibility_layer == 0)
	check("actual full target respects pixel and edge budgets without stretching",
		native_size.x * native_size.y <= 1536000 and maxi(native_size.x, native_size.y) <= 1920
		and absf(float(native_size.x) / native_size.y - requested.x / requested.y) <= 2.0 / mini(native_size.x, native_size.y))
	game.player._attack_time = 0.4
	game.player._pending = Callable()
	game.hud.open_settings()
	Prefs.set_low_resolution(true)
	await _frames(3)
	var size_after: Vector2 = game.scene_view.get_visible_rect().size
	var view_after: Vector2 = game.scene_view.get_visible_rect().size / game.camera.zoom
	check("paused quality changes leave the hidden source adapter at its original size", get_tree().paused and size_after == size_before and game.scene_view == source_viewport, "%s -> %s" % [size_before, size_after])
	check("economy quality never reparents cached source polygons or renders their viewport", game.field_root.get_parent() == source_parent and game.player.get_viewport() == source_viewport and game.hud.minimap.get_viewport() == get_viewport())
	check("economy quality halves the native render target and disables multisampling", renderer.viewport.size == native_size / 2 and renderer.viewport.msaa_3d == Viewport.MSAA_DISABLED and renderer.display.visible)
	check("world actors stay paused during quality changes", game.player._attack_time == 0.4)
	check("hidden adapter keeps its input projection through native quality changes", view_after.distance_to(view_before) < 4.0)
	check("native orthographic field of view survives a paused quality switch", is_equal_approx(renderer.camera.size, native_view))
	check("HUD size and hero progress are preserved", game.hud.minimap.size == hud_before and GameState.gold == gold)
	game.hud.close_panel()
	game.player.resource = 0.0
	GameState.mana_potions = 3
	var press := InputEventKey.new()
	press.keycode = KEY_E
	press.physical_keycode = KEY_E
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(1)
	var release := InputEventKey.new()
	release.keycode = KEY_E
	release.physical_keycode = KEY_E
	Input.parse_input_event(release)
	await _frames(1)
	check("keyboard actions are not duplicated by the world viewport", GameState.mana_potions == 2)
	game.player.position = game.dungeon.entry_point()
	check("cave works in economy quality", game.dungeon.enter() and game.player.get_viewport() == game.scene_view)
	game.dungeon.leave("테스트")
	game.player._attack_time = 0.4
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(3)
	check("disabled old scenes also stop economy viewport actors", game.player._attack_time == 0.4)
	game.process_mode = Node.PROCESS_MODE_INHERIT
	Prefs.set_low_resolution(false)
	await _frames(3)
	check("full quality restores world resolution", game.scene_view.get_visible_rect().size == size_before)
	check("full quality restores the native target without changing editions", renderer.viewport.size == native_size and renderer.viewport.msaa_3d == Viewport.MSAA_2X and renderer.display.visible and game.field_root.visibility_layer == 0)
	game.queue_free()
	await _frames(2)
	Prefs.set_low_resolution(previous)

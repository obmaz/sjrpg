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
	check("full quality uses the original viewport without an extra render pass", game.player.get_viewport() == get_viewport() and not game._view_container.visible)
	game.player._attack_time = 0.4
	game.player._pending = Callable()
	game.hud.open_settings()
	Prefs.set_low_resolution(true)
	await _frames(3)
	var size_after: Vector2 = game.scene_view.get_visible_rect().size
	var view_after: Vector2 = game.scene_view.get_visible_rect().size / game.camera.zoom
	check("quality changes while a panel is paused", get_tree().paused and size_after.x < size_before.x and size_after.y < size_before.y, "%s -> %s, paused=%s container=%s root=%s" % [size_before, size_after, get_tree().paused, game._view_container.size, get_viewport().get_visible_rect().size])
	check("economy world renders separately from the HUD", game.player.get_viewport() == game.scene_view and game.hud.minimap.get_viewport() == get_viewport())
	check("world actors stay paused during quality changes", game.player._attack_time == 0.4)
	check("quality keeps the same field of view", view_after.distance_to(view_before) < 4.0)
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
	game.queue_free()
	await _frames(2)
	Prefs.set_low_resolution(previous)

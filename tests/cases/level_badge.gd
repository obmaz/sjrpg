extends TestCase
## The portrait badge follows real progression and loaded levels without entering a menu.


func run() -> void:
	var game := await make_game()
	var badge: Label = game.hud._level_badge
	check("new adventure shows level one on the portrait", badge.text == "1" and badge.is_visible_in_tree())
	game.grant_xp(GameState.xp_to_next())
	await _frames(2)
	check("actual level-up updates the visible badge", GameState.level == 2 and badge.text == "2")
	GameState.level = 100
	check("high level can be saved", GameState.save_game())
	GameState.level = 1
	check("saved high level is restored", GameState.load_game() and GameState.level == 100)
	await _frames(2)
	check("badge shows the restored three-digit level", badge.text == "100")
	var live: Dictionary = game.hud.status_geometry()
	var medal: Rect2 = live["level_badge"]
	check("restored level text stays inside the live medallion", medal.encloses(badge.get_rect()))
	var tex := HudArt.level_badge()
	check("original medallion art is available", tex != null and tex.get_width() > 0)
	for view in [Vector2(540, 960), Vector2(720, 1280), Vector2(1280, 720), Vector2(720, 1600)]:
		for safe in [Vector4.ZERO, Vector4(44, 30, 20, 16)]:
			var layout := Hud.header_geometry(view, safe)
			var available := Rect2(Vector2(safe.x, safe.y), view - Vector2(safe.x + safe.z, safe.y + safe.w))
			var art: Rect2 = layout["level_badge"]
			var label: Rect2 = layout["level_label"]
			var center: Vector2 = layout["portrait"]
			check("badge stays at the safe upper-left of the avatar", available.encloses(art) and art.get_center().x < center.x and art.get_center().y < center.y and not art.intersects(layout["hp_label"]))
			for text in ["1", "99", "100", "999"]:
				var size := HudArt.fit_text_size(text, label, roundi(12.0 * float(layout["unit"])))
				var shaped := HudArt.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
				check("level digits fit inside the medallion", shaped.x <= label.size.x and HudArt.FONT.get_height(size) <= label.size.y)
	game.queue_free()
	await _frames(2)
	game = await make_game("mage")
	badge = game.hud._level_badge
	check("starting again resets the visible badge", badge.text == "1")

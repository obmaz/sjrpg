extends TestCase
## 번호·행·실제 점의 일치, 선택 확대, 글자 줄바꿈과 독립 스크롤을 확인한다.


func run() -> void:
	var game := await make_game("mage")
	game.player.set_process(false)
	game.hud.open_map()
	await _frames(3)
	var panel := game.hud._panel as MapPanel
	var canvas := panel.canvas
	var origin: Vector2 = game.player.position
	check(
		"map pauses gameplay and keeps the map independent of the place-list scroll",
		get_tree().paused and not panel.scroll.visible and panel._list_scroll != panel.scroll
	)
	check(
		"every numbered marker has one real selectable row",
		panel._rows.size() == canvas.markers.size() and panel._rows.size() > 5
	)
	var cave: Dictionary
	for marker in canvas.markers:
		if marker["id"] == "cave:entrance":
			cave = marker
	var row := panel._rows["cave:entrance"] as MapPlaceRow
	row.pressed.emit()
	await _frames(2)
	check(
		"a place button focuses its real world point and zooms the map",
		(
			panel.selected_id == "cave:entrance"
			and canvas.view_center == game.dungeon.entry_point()
			and canvas.zoom >= 6
		)
	)
	check("selection never teleports or changes player position", game.player.position == origin)
	var round_trip := canvas.to_world(canvas.to_canvas(cave["pos"]))
	check(
		"number callouts do not move actual map coordinates",
		(
			round_trip.distance_to(cave["pos"]) < .001
			and canvas.projected_markers["cave:entrance"].distance_to(canvas.size * .5) < .01
		)
	)
	var used: Array[Rect2] = []
	var readable := true
	for rect: Rect2 in canvas.badges.values():
		readable = readable and Rect2(Vector2.ZERO, canvas.size).encloses(rect)
		for previous in used:
			readable = readable and not rect.intersects(previous)
		used.append(rect)
	check(
		"visible numbers fit the map without overlapping other number plates",
		readable and canvas.badges.has("cave:entrance")
	)
	canvas.place_selected.emit("npc:상인")
	await _frames(2)
	check(
		"a number callout selects the matching row and real resident",
		(
			panel.selected_id == "npc:상인"
			and canvas.view_center == game.village.npc_nodes["상인"].position
		)
	)
	for place: MapPlaceRow in panel._rows.values():
		check("place touch rows remain at least 64 pixels high", place.size.y >= 64)
		check(
			"place names and details wrap instead of clipping",
			(
				place._name.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART
				and place._detail.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART
			)
		)
	var before := canvas.view_center
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = canvas.size * .5
	canvas._gui_input(touch)
	var drag := InputEventScreenDrag.new()
	drag.relative = Vector2(40, 20)
	canvas._gui_input(drag)
	check(
		"dragging pans the view without moving the hero",
		canvas.view_center != before and game.player.position == origin
	)
	panel._map_action("all")
	check(
		"whole-map action resets zoom without clearing actual geometry",
		canvas.zoom == 1.0 and canvas.view_center == canvas.world_bounds().get_center()
	)
	panel._map_action("player")
	check(
		"my-position action centres the true player coordinate",
		canvas.view_center == game.player.position
	)
	panel._tab = 1
	panel._rebuild()
	await _frames(2)
	check(
		"travel stays a separate tab with the original restrictions",
		panel.canvas == null and panel.scroll.visible
	)
	game.hud.close_panel()
	check("closing the redesigned map resumes gameplay", not get_tree().paused)
	await _frames(2)
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	add_child(view)
	var responsive := MapPanel.new().setup(game)
	view.add_child(responsive)
	await _frames(5)
	responsive._select_place("cave:entrance")
	for viewport_size in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(540, 960)]:
		view.size = viewport_size
		await _frames(8)
		var region := responsive.body_holder.get_global_rect()
		var map_rect := responsive.canvas.get_global_rect()
		var list_rect := responsive._list_scroll.get_global_rect()
		check(
			"map and independent list fit after rotation %s" % viewport_size,
			(
				region.grow(1).encloses(map_rect)
				and region.grow(1).encloses(list_rect)
				and not map_rect.intersects(list_rect)
				and map_rect.size.y >= 100
				and list_rect.size.y >= 96
			)
		)
		var selected_row: Control = responsive._rows["cave:entrance"]
		check(
			"selected place stays fully visible after rotation %s" % viewport_size,
			list_rect.grow(1).encloses(selected_row.get_global_rect())
		)
		responsive._list_scroll.scroll_vertical = 100000
		await _frames(3)
		check(
			"last place remains reachable without scrolling the map %s" % viewport_size,
			(
				(
					responsive._places.get_global_rect().end.y
					<= responsive._list_scroll.get_global_rect().end.y + 1
				)
				and responsive.canvas.get_global_rect().is_equal_approx(map_rect)
			)
		)
	responsive.set_process(false)
	var long_row := responsive._rows.values()[0] as MapPlaceRow
	long_row.update_state(
		{"label": "오래된 숲의 예배당과 약초사의 쉼터 ".repeat(5), "detail": "흙길을 따라 골짜기 아래 입구로 향하세요 ".repeat(5)},
		123,
		true
	)
	await _frames(8)
	check(
		"long place names and guidance expand the row to show all text",
		(
			long_row.size.y > 150
			and long_row.size.y + .1 >= long_row._margin.get_combined_minimum_size().y
		)
	)
	view.queue_free()
	await _frames(2)
	game.queue_free()
	await _frames(2)

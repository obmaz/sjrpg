extends TestCase
## 행의 입력 전달·드래그 취소·유형·웨이포인트 계약. 실제 GUI 스와이프는 check_map_touch.mjs로 검증한다.


func run() -> void:
	var game := await make_game("mage")
	game.hud.open_map()
	await _frames(4)
	var panel := game.hud._panel as MapPanel
	var waypoints := 0
	var colors := {}
	for marker in panel.canvas.markers:
		var category := MapGeometry.category(marker)
		colors[category] = marker["color"]
		if category == "웨이포인트":
			waypoints += 1
			if marker["id"] != "sanctuary:town":
				check(
					"unknown waypoints are listed with their discovery requirement",
					marker["detail"].contains("미발견")
				)
	check("all three real waypoint locations are available in the place list", waypoints == 3)
	check(
		"quests, residents, caves and waypoints have distinct category colors",
		(
			colors["의뢰"] != colors["마을 시설"]
			and colors["동굴"] != colors["마을 시설"]
			and colors["웨이포인트"] != colors["동굴"]
			and colors["재소환 비석"] != colors["웨이포인트"]
		)
	)
	var first := panel._rows.values()[0] as MapPlaceRow
	check(
		"place rows are scrolling list controls rather than input-consuming buttons",
		not is_instance_of(first, BaseButton) and first.mouse_filter == Control.MOUSE_FILTER_PASS
	)
	var bar := panel._list_scroll.get_v_scroll_bar()
	check("the separate place list has scrollable overflow", bar.max_value > bar.page + 100)
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = first.size * .5
	first._gui_input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.relative = Vector2(0, -50)
	first._gui_input(drag)
	touch.pressed = false
	first._gui_input(touch)
	check("dragging a list row never activates a place", panel.selected_id == "")
	for down in [true, false]:
		touch = InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = down
		touch.position = first.size * .5
		first._gui_input(touch)
	check(
		"a short touch selects the matching marker after release",
		panel.selected_id == first.place_id
	)
	var navigation := GamepadNavigation.new()
	add_child(navigation)
	navigation._scope = panel
	navigation._refresh()
	check("list rows remain available to controller navigation", navigation._buttons.has(first))
	navigation._activate(first)
	check("controller confirm selects the same list location", panel.selected_id == first.place_id)
	navigation.queue_free()
	game.hud.close_panel()
	game.queue_free()
	await _frames(2)

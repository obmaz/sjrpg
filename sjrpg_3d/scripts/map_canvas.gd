class_name WorldMapCanvas
extends Control
## 실제 좌표에 점을 찍고 번호판만 빈 곳으로 옮긴다. 선택은 지도 시야만 바꾼다.
signal place_selected(id: String)
var game: Node
var markers: Array[Dictionary] = []
var selected_id := ""
var zoom := 1.0
var view_center := Vector2.ZERO
var badges := {}
var projected_markers := {}
var _tracking := ""
var _configured := false
var _dragging := false
var _dragged := false
var _drag_delta := Vector2.ZERO
var _pin_style: StyleBox
var _selected_style: StyleBox


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_pin_style = UiKit.panel_style(Color("23271f"), Color("8c7956"), 8)
	_selected_style = UiKit.panel_style(Color("453820"), UiKit.GOLD, 8)
	resized.connect(queue_redraw)


func world_bounds() -> Rect2:
	if game.dungeon.active and game.dungeon.layout != null:
		return game.dungeon.layout.bounds
	var polygon := PackedVector2Array()
	for point in NativeChapelPlan.polygon(game.FIELD):
		polygon.append(Iso.project(point))
	return Iso.poly_bounds(polygon)


func map_scale() -> float:
	var bounds := world_bounds()
	return minf(maxf(1, size.x - 36) / bounds.size.x, maxf(1, size.y - 36) / bounds.size.y) * zoom


func to_canvas(world: Vector2) -> Vector2:
	return size * 0.5 + (world - view_center) * map_scale()


func to_world(point: Vector2) -> Vector2:
	return view_center + (point - size * 0.5) / map_scale()


func show_all() -> void:
	zoom = 1.0
	view_center = world_bounds().get_center()
	_tracking = ""
	_configured = true
	queue_redraw()


func show_player() -> void:
	view_center = game.player.position
	zoom = maxf(zoom, 6.0 if not game.dungeon.active else 2.5)
	_tracking = "player"
	queue_redraw()


func select_place(id: String) -> void:
	selected_id = id
	_tracking = id
	zoom = maxf(zoom, 6.0 if not game.dungeon.active else 2.5)
	_track()
	queue_redraw()


func change_zoom(multiplier: float, anchor: Vector2 = Vector2.INF) -> void:
	if not anchor.is_finite():
		anchor = size * 0.5
	var world := to_world(anchor)
	zoom = clampf(zoom * multiplier, 1.0, 18.0)
	view_center = world - (anchor - size * 0.5) / map_scale()
	_tracking = ""
	queue_redraw()


func update_source(places: Array[Dictionary]) -> void:
	markers = places
	if not _configured:
		show_all()
	_track()
	queue_redraw()


func _track() -> void:
	if _tracking == "player":
		view_center = game.player.position
	else:
		for marker in markers:
			if marker["id"] == _tracking:
				view_center = marker["pos"]
				return


func _badge(at: Vector2, used: Array[Rect2]) -> Rect2:
	var extent := Vector2(34, 30)
	for radius: float in [24.0, 44.0, 66.0, 88.0]:
		for step in 12:
			var centre := at + Vector2.from_angle(-PI * 0.25 + TAU * step / 12.0) * radius
			var rect := Rect2(centre - extent * 0.5, extent)
			rect.position = rect.position.clamp(
				Vector2(6, 6), (size - extent - Vector2(6, 6)).max(Vector2(6, 6))
			)
			var clear := true
			for other in used:
				clear = clear and not other.grow(3).intersects(rect)
			if clear:
				return rect
	return Rect2()


func _draw() -> void:
	if game == null or game.map_state == null or size.x < 40 or size.y < 40:
		return
	draw_style_box(UiKit.panel_style(Color("222b23"), UiKit.EDGE, 10), Rect2(Vector2.ZERO, size))
	if not _configured:
		show_all()
	var factor := map_scale()
	draw_set_transform(size * 0.5 - view_center * factor, 0, Vector2.ONE * factor)
	if game.map_state.full_mesh != null and game.map_state.full_mesh.get_surface_count() > 0:
		draw_mesh(game.map_state.full_mesh, null)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var inside := Rect2(Vector2(5, 5), size - Vector2(10, 10))
	for enemy: Enemy in game.enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			var at := to_canvas(enemy.position)
			if inside.has_point(at):
				draw_circle(at, 2.5, Color("c96a58"))
	badges.clear()
	projected_markers.clear()
	var hero := to_canvas(game.player.position)
	var used: Array[Rect2] = []
	if inside.has_point(hero):
		used.append(Rect2(hero - Vector2(14, 14), Vector2(28, 28)))
	var order: Array[int] = []
	for index in markers.size():
		if markers[index]["id"] == selected_id:
			order.push_front(index)
		else:
			order.append(index)
	for index in order:
		var marker: Dictionary = markers[index]
		var at := to_canvas(marker["pos"])
		projected_markers[marker["id"]] = at
		if not inside.has_point(at):
			continue
		var ink: Color = marker["color"]
		draw_circle(at, 3.5, ink)
		var rect := _badge(at, used)
		if not rect.has_area():
			continue
		used.append(rect)
		badges[marker["id"]] = rect
		draw_line(at, rect.get_center(), Color(ink, .7), 1.0, true)
		draw_style_box(_selected_style if marker["id"] == selected_id else _pin_style, rect)
		var text := str(index + 1)
		var width := UiKit.BOLD_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(
			UiKit.BOLD_FONT,
			rect.get_center() + Vector2(-width * .5, 6),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			18,
			ink
		)
	if inside.has_point(hero):
		draw_circle(hero, 10, Color("14221a"))
		var direction := Vector2.from_angle(game.player.facing)
		draw_colored_polygon(
			PackedVector2Array(
				[
					hero + direction * 9,
					hero + direction.rotated(2.5) * 7,
					hero + direction.rotated(-2.5) * 7
				]
			),
			Color.WHITE
		)
	draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), UiKit.EDGE, false, 1.5)


func _gui_input(event: InputEvent) -> void:
	if (
		(event is InputEventMouseButton or event is InputEventMouseMotion)
		and event.device == InputEvent.DEVICE_ID_EMULATION
	):
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			change_zoom(
				1.3 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.3, event.position
			)
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_pointer_event(event.position, event.pressed)
	elif event is InputEventScreenTouch:
		_pointer_event(event.position, event.pressed)
	elif event is InputEventMouseMotion and _dragging:
		_pan(event.relative)
	elif event is InputEventScreenDrag and _dragging:
		_pan(event.relative)


func _pointer_event(at: Vector2, pressed: bool) -> void:
	if pressed:
		_dragging = true
		_dragged = false
		_drag_delta = Vector2.ZERO
	else:
		if _dragging and not _dragged:
			for id: String in badges:
				if (badges[id] as Rect2).grow(5).has_point(at):
					place_selected.emit(id)
					break
		_dragging = false
	accept_event()


func _pan(relative: Vector2) -> void:
	if relative.length() < 0.1:
		return
	_drag_delta += relative
	if not _dragged:
		if _drag_delta.length() < 6.0:
			return
		relative = _drag_delta
	_dragged = true
	_tracking = ""
	view_center -= relative / map_scale()
	queue_redraw()
	accept_event()

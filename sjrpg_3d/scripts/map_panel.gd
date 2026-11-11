class_name MapPanel
extends PanelFrame
## 지도는 고정 시야, 장소 목록은 독립 스크롤이다. 번호 선택이 실제 이동을 실행하지 않는다.
var game: Node
var _tab := 0
var canvas: WorldMapCanvas
var selected_id := ""
var _map_area: BoxContainer
var _map_column: VBoxContainer
var _places: VBoxContainer
var _list_scroll: ScrollContainer
var _selected: Label
var _rows := {}
var _places_key := 0
var _last_revision := -1
var _last_markers := 0
var _last_player := Vector2.INF
var _last_facing := INF
var _scope := false
var _places_label: Label
var _review_clock := 0.0
var _reveal_frames := 0


func setup(g: Node) -> MapPanel:
	game = g
	return self


func _ready() -> void:
	super._ready()
	_rebuild()
	add_footer("탐험 계속하기", _close_map, true)
	body_holder.resized.connect(_layout_map)


func _close_map() -> void:
	closed.emit()


func _tab_selected(index: int) -> void:
	_tab = index
	_rebuild()


func _rebuild() -> void:
	_scope = game.dungeon.active
	if _scope:
		_tab = 0
	set_header("바람 동굴 지도" if _scope else "숲의 지도", "번호 또는 장소를 누르면 확대 · 지도를 끌어 이동")
	set_tabs(["동굴 지도"] if _scope else ["장소 찾기", "안식처·워프"], _tab, _tab_selected)
	clear_body()
	if is_instance_valid(_map_area):
		body_holder.remove_child(_map_area)
		_map_area.queue_free()
		_map_area = null
	canvas = null
	_rows.clear()
	_places_key = 0
	_last_revision = -1
	_last_markers = 0
	selected_id = ""
	scroll.visible = _tab != 0
	if _tab != 0:
		_build_travel()
		return
	_map_area = BoxContainer.new()
	_map_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_area.add_theme_constant_override("separation", 14)
	body_holder.add_child(_map_area)
	_map_column = VBoxContainer.new()
	_map_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_column.size_flags_stretch_ratio = 1.35
	_map_area.add_child(_map_column)
	canvas = WorldMapCanvas.new()
	canvas.game = game
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.place_selected.connect(_select_place)
	_map_column.add_child(canvas)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	_map_column.add_child(controls)
	for choice: Array in [["전체", "all"], ["내 위치", "player"], ["-", "out"], ["+", "in"]]:
		var button := UiKit.button(choice[0], 17)
		button.custom_minimum_size = Vector2(64, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_map_action.bind(choice[1]))
		controls.add_child(button)
	_selected = PanelFrame.wrap_label("목록에서 장소를 선택하세요", 16, UiKit.GOLD)
	_selected.custom_minimum_size.y = 36
	_map_column.add_child(_selected)
	var places_column := VBoxContainer.new()
	places_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	places_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_area.add_child(places_column)
	_places_label = UiKit.label("장소", 17, UiKit.MUTED, true)
	places_column.add_child(_places_label)
	_list_scroll = ScrollContainer.new()
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.scroll_deadzone = 12
	places_column.add_child(_list_scroll)
	_places = VBoxContainer.new()
	_places.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_places.add_theme_constant_override("separation", 8)
	_list_scroll.add_child(_places)
	_sync_map()
	_layout_map.call_deferred()


func _layout_map() -> void:
	if not is_instance_valid(_map_area):
		return
	var vertical := body_holder.size.y > body_holder.size.x * .85
	_map_area.vertical = vertical
	_map_column.size_flags_stretch_ratio = 1.25 if vertical else 1.4
	# 회전 뒤 새 행 높이가 정해진 다음 선택한 행을 다시 드러낸다.
	_reveal_frames = 2


func _process(delta: float) -> void:
	if game == null:
		return
	if _scope != game.dungeon.active:
		_rebuild()
		return
	if is_instance_valid(_map_area):
		_sync_map()
		if _reveal_frames > 0:
			_reveal_frames -= 1
			if _reveal_frames == 0:
				_reveal_selected()
	if OS.has_feature("web") and game.ortho_preview != null and game.ortho_preview._probe_enabled:
		_review_clock += delta
		if _review_clock >= .15:
			_review_clock = 0.0
			JavaScriptBridge.eval(
				"window.__sjrpgMapPanel = " + JSON.stringify(review_snapshot()), true
			)


func _sync_map() -> void:
	game.refresh_map()
	var markers := MapGeometry.markers(game)
	var key := []
	for marker in markers:
		key.append([marker["id"], marker["label"], marker["color"]])
	if _places_key != key.hash():
		_places_key = key.hash()
		for row in _places.get_children():
			_places.remove_child(row)
			row.queue_free()
		_rows.clear()
		for index in markers.size():
			var row := MapPlaceRow.new().setup(index + 1, markers[index])
			row.pressed.connect(_select_place.bind(str(markers[index]["id"])))
			_places.add_child(row)
			_rows[row.place_id] = row
		_places_label.text = "장소 %d · 번호 선택" % markers.size()
	if not _rows.has(selected_id):
		selected_id = ""
		canvas.selected_id = ""
		_selected.text = "흰 화살표: 내 위치 · 빨강: 적"
	for marker in markers:
		var distance := (
			Iso.unproject(marker["pos"] - game.player.position).length() / SpatialWorld3D.UNITS
		)
		(_rows[marker["id"]] as MapPlaceRow).update_state(
			marker, distance, marker["id"] == selected_id
		)
		if marker["id"] == selected_id:
			_selected.text = "%s · %d m" % [marker["label"], roundi(distance)]
	var fingerprint := markers.hash()
	if (
		_last_revision != game.map_state.revision
		or _last_markers != fingerprint
		or _last_player != game.player.position
		or _last_facing != game.player.facing
	):
		_last_revision = game.map_state.revision
		_last_markers = fingerprint
		_last_player = game.player.position
		_last_facing = game.player.facing
		canvas.update_source(markers)


func _select_place(id: String) -> void:
	selected_id = id
	canvas.select_place(id)
	_sync_map()
	_reveal_selected()


func _reveal_selected() -> void:
	var row: Control = _rows.get(selected_id)
	if row != null:
		_list_scroll.ensure_control_visible(row)


func _map_action(action: String) -> void:
	match action:
		"all":
			canvas.show_all()
		"player":
			canvas.show_player()
		"in":
			canvas.change_zoom(1.35)
		"out":
			canvas.change_zoom(1.0 / 1.35)


func _build_travel() -> void:
	var reason: String = game.exploration.travel_block_reason()
	body.add_child(
		PanelFrame.wrap_label(reason if reason != "" else "발견한 목적지를 선택하면 이동하고 생명·자원을 회복합니다.", 20)
	)
	for id: String in Exploration.NAMES:
		var found := GameState.discovered_sanctuaries.has(id)
		var button := UiKit.button(Exploration.NAMES[id] + ("" if found else " · 미발견"), 20)
		button.custom_minimum_size = Vector2(0, 76)
		button.disabled = not found or reason != "" or id == game.exploration.current_origin()
		button.pressed.connect(_travel.bind(id))
		body.add_child(button)


func _travel(id: String) -> void:
	if game.exploration.travel(id):
		closed.emit()


## 자동 브라우저 검수 전용 읽기 값. 게임 입력이나 위치를 바꾸는 인터페이스는 제공하지 않는다.
func review_snapshot() -> Dictionary:
	var places := []
	if is_instance_valid(canvas):
		for marker in canvas.markers:
			var row: Control = _rows.get(marker["id"])
			var rect := row.get_global_rect() if row != null else Rect2()
			var point: Vector2 = canvas.global_position + canvas.to_canvas(marker["pos"])
			var badge: Rect2 = canvas.badges.get(marker["id"], Rect2())
			badge.position += canvas.global_position
			places.append(
				{
					"id": marker["id"],
					"name": marker["label"],
					"world": [marker["pos"].x, marker["pos"].y],
					"point": [point.x, point.y],
					"badge": [badge.position.x, badge.position.y, badge.size.x, badge.size.y],
					"row": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
				}
			)
	var view := get_viewport_rect().size
	var map_rect := canvas.get_global_rect() if is_instance_valid(canvas) else Rect2()
	var list_rect := _list_scroll.get_global_rect() if is_instance_valid(_list_scroll) else Rect2()
	return {
		"view": [view.x, view.y],
		"selected": selected_id,
		"tab": _tab,
		"scope": "cave" if game.dungeon.active else "forest",
		"places": places,
		"zoom": canvas.zoom if is_instance_valid(canvas) else 0,
		"center": [canvas.view_center.x, canvas.view_center.y] if is_instance_valid(canvas) else [],
		"map": [map_rect.position.x, map_rect.position.y, map_rect.size.x, map_rect.size.y],
		"list": [list_rect.position.x, list_rect.position.y, list_rect.size.x, list_rect.size.y]
	}


func _exit_tree() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sjrpgMapPanel = null", true)
	super._exit_tree()

extends Node
## Root scene: swaps between title, class selection and the adventure.

var current: Node
var _edition_exiting := false
var _entry_starting := false
var _entry_loading: EntryLoading
var _entry_token := 0
var _entry_sequence := 0
var _entry_source: Node
var _entry_source_mode := Node.PROCESS_MODE_INHERIT
var _web_back_callback: Variant
signal entry_loading_changed(phase: String)


func _ready() -> void:
	get_tree().quit_on_go_back = false
	if OS.has_feature("web"):
		_web_back_callback = JavaScriptBridge.create_callback(_on_web_back)
		var api: Variant = JavaScriptBridge.get_interface("SjrpgBack")
		if api != null:
			api.attach(_web_back_callback)
	get_tree().root.size_changed.connect(_fit_orientation)
	_fit_orientation()
	show_title()
	if AdventureInspection.web_requested() and str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('expedition_review')", true)) == "1":
		add_child(preload("res://scripts/inspection/expedition_review.gd").new().setup(self))
	if AdventureInspection.web_requested() and str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('gamepad_review')", true)) == "1":
		add_child(preload("res://scripts/inspection/gamepad_review.gd").new().setup(self))
	if AdventureInspection.web_requested() and str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('scale_review')", true)) == "1":
		add_child(preload("res://scripts/inspection/native_scale_review.gd").new().setup(self))
	if AdventureInspection.web_requested() and str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('save_layout_review')", true)) == "1":
		add_child(preload("res://scripts/inspection/save_layout_review.gd").new().setup(self))
	if AdventureInspection.web_requested() and str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('native_style_review')", true)) == "1":
		add_child(preload("res://scripts/inspection/native_style_review.gd").new().setup(self))


## Landscape uses a 1280x720 base, portrait 720x1280, so UI keeps a readable size on phones.
func _fit_orientation() -> void:
	var window := get_window()
	var size := window.size
	var portrait := size.y > size.x
	var target := Vector2i(720, 1280) if portrait else Vector2i(1280, 720)
	if window.content_scale_size != target:
		window.content_scale_size = target


func _swap(node: Node) -> void:
	if current:
		# Queued nodes can still tick during this frame; stop the old adventure before replacing shared state.
		current.process_mode = Node.PROCESS_MODE_DISABLED
		if current is CanvasItem:
			current.hide()
		current.queue_free()
	current = node
	add_child(node)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if(window.SjrpgBack)window.SjrpgBack.setActive(" + ("true" if node is Adventure3D else "false") + ");")
	if is_instance_valid(_entry_loading):
		move_child(_entry_loading, get_child_count() - 1)


func show_title() -> void:
	_cancel_entry_loading()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sjrpgAdventureReady = false; window.__sjrpgClassSelectReady = false; window.__sjrpgTitleReady = false")
	var title := preload("res://scripts/ui/screens/title_screen.gd").new()
	title.new_game_requested.connect(show_class_select)
	title.load_game_requested.connect(_on_title_load_game)
	title.settings_requested.connect(_on_title_settings)
	_swap(title)


func _on_title_load_game() -> void:
	var panel := preload("res://scripts/ui/panels/save_load_panel.gd").new().setup(true)
	panel.slot_loaded.connect(func(slot: int):
		load_slot_adventure(slot)
	)
	_open_title_panel(panel)


func _on_title_settings() -> void:
	var panel := preload("res://scripts/ui/panels/settings_panel.gd").new().setup(null)
	panel.load_requested.connect(func(slot: int):
		load_slot_adventure(slot)
	)
	_open_title_panel(panel)


func _open_title_panel(panel: PanelFrame) -> void:
	panel.closed.connect(panel.queue_free)
	add_child(panel)


func load_slot_adventure(slot: int) -> void:
	if _entry_starting:
		return
	var summaries := GameState.slot_summaries()
	var cls := "warrior"
	for s: Dictionary in summaries:
		if int(s.get("slot", 0)) == slot and bool(s.get("valid", false)):
			cls = str(s.get("class", "warrior"))
			break
	var token: int = _open_entry_loading("continue", slot, cls)
	await _paint_entry_phase("load")
	if not _entry_valid(token):
		return
	_entry_loading.note_work()
	var loaded: bool = GameState.select_slot(slot) and GameState.load_game()
	if not loaded:
		_entry_failed(token, slot, "모험을 읽지 못했습니다. 다른 슬롯을 선택하거나 다시 시도해 주세요.")
		return
	await _build_entry_world(token, slot)


func show_class_select() -> void:
	_cancel_entry_loading()
	var select := preload("res://scripts/ui/screens/class_select.gd").new()
	select.chosen.connect(_choose_hero)
	select.continue_requested.connect(_continue_hero)
	select.back_requested.connect(show_title)
	_swap(select)


func start_game() -> void:
	var game := Adventure3D.new()
	game.reload_requested.connect(_reload_adventure)
	game.quit_requested.connect(show_title)
	game.restart_requested.connect(func():
		show_class_select())
	_swap(game)


func _choose_hero(cls: String) -> void:
	_begin_new_game(cls)


func _continue_hero() -> void:
	if _entry_starting or not is_instance_valid(current) or not current.has_method("show_error"):
		return
	var slot: int = current.selected_slot
	var cls: String = current.selected_class
	var token: int = _open_entry_loading("continue", slot, cls)
	await _paint_entry_phase("load")
	if not _entry_valid(token):
		return
	_entry_loading.note_work()
	var loaded: bool = GameState.select_slot(slot) and GameState.load_game()
	if not loaded:
		_entry_failed(token, slot, "모험을 읽지 못했습니다. 다른 슬롯을 선택하거나 다시 시도해 주세요.")
		return
	await _build_entry_world(token, slot)


func _begin_new_game(cls: String) -> void:
	if _entry_starting or not is_instance_valid(current) or not current.has_method("show_error"):
		return
	var slot: int = current.selected_slot
	var token: int = _open_entry_loading("new", slot, cls)
	await _paint_entry_phase("create")
	if not _entry_valid(token):
		return
	_entry_loading.note_work()
	if not GameState.create_slot(slot, cls, true):
		_entry_failed(token, slot, "새 모험을 저장하지 못했습니다. 빈 슬롯인지 확인하고 다시 시도해 주세요.")
		return
	await _build_entry_world(token, slot)


func _open_entry_loading(operation: String, slot: int, cls: String) -> int:
	_entry_token += 1
	_entry_sequence += 1
	_entry_starting = true
	_entry_source = current
	_entry_source_mode = current.process_mode
	current.process_mode = Node.PROCESS_MODE_DISABLED
	get_viewport().gui_release_focus()
	_entry_loading = preload("res://scripts/ui/screens/entry_loading.gd").new().setup(operation, slot, cls, _entry_sequence)
	add_child(_entry_loading)
	return _entry_token


func _entry_valid(token: int) -> bool:
	return is_inside_tree() and not _edition_exiting and _entry_starting and token == _entry_token and is_instance_valid(_entry_loading)


## Main owns the await, so removing a cancelled overlay cannot resume its freed script.
func _paint_entry_phase(phase: String) -> void:
	var token: int = _entry_token
	if not _entry_valid(token):
		return
	_entry_loading.set_phase(phase)
	entry_loading_changed.emit(phase)
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		if not _entry_valid(token):
			return
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
	if not _entry_valid(token):
		return
	while not _entry_loading.browser_painted():
		await get_tree().process_frame
		if not _entry_valid(token):
			return
	_entry_loading.mark_painted()


func _build_entry_world(token: int, slot: int) -> void:
	await _paint_entry_phase("world")
	if not _entry_valid(token):
		return
	_entry_loading.note_work()
	UiKit.boost = 1.0
	start_game()
	if not _entry_valid(token):
		return
	var ready: bool = await _wait_entry_world_ready()
	if not _entry_valid(token):
		return
	if not ready:
		_entry_failed(token, slot, "모험을 준비하지 못했습니다. 저장된 모험은 유지됩니다. 다시 이어해 주세요.")
		return
	await _paint_entry_phase("ready")
	if _entry_valid(token):
		_close_entry_loading("ready")


## Adventure3D's ready flag follows physics/actor setup, not merely add_child().
func _wait_entry_world_ready() -> bool:
	var target: Node = current
	var token: int = _entry_token
	if target is Adventure3D:
		var adventure := target as Adventure3D
		while _entry_valid(token) and is_instance_valid(adventure) and current == adventure:
			var simulation: Node = adventure.simulation
			if is_instance_valid(simulation) and bool(simulation.get("native_ready")):
				break
			await get_tree().process_frame
		if not _entry_valid(token) or not is_instance_valid(target) or current != target:
			return false
	_entry_loading.note_native_ready()
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		if not _entry_valid(token):
			return false
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
	return _entry_valid(token) and is_instance_valid(target) and current == target


func _entry_failed(token: int, slot: int, message: String) -> void:
	if not _entry_valid(token):
		return
	var original: Node = _entry_source
	var mode: int = _entry_source_mode
	if is_instance_valid(original) and current == original:
		_close_entry_loading("error")
		original.process_mode = mode
		original.refresh_slots()
		original.select_slot(slot)
		original.show_error(message)
	else:
		# Persistence may already have succeeded. Return to that slot's Continue flow.
		show_class_select()
		current.select_slot(slot)
		current.show_error(message)


func _close_entry_loading(reason: String) -> void:
	var overlay: EntryLoading = _entry_loading
	_entry_loading = null
	_entry_starting = false
	_entry_source = null
	if is_instance_valid(overlay):
		overlay.dismiss(reason)
		overlay.queue_free()


func _cancel_entry_loading() -> void:
	_entry_token += 1
	var original: Node = _entry_source
	if is_instance_valid(original):
		original.process_mode = _entry_source_mode
	_close_entry_loading("cancelled")


func _exit_tree() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if(window.SjrpgBack)window.SjrpgBack.detach();")
	_web_back_callback = null
	_cancel_entry_loading()


func prepare_edition_exit() -> void:
	if _edition_exiting:
		return
	_edition_exiting = true
	_cancel_entry_loading()
	# Retire the spatial/canvas scene before engine shutdown so native physics
	# and render jobs finish while their worker pool is still available.
	if is_instance_valid(current):
		current.process_mode = Node.PROCESS_MODE_DISABLED
		current.queue_free()
		current = null
	get_tree().paused = false
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		handle_system_back()


func _on_web_back(_arguments: Array) -> void:
	handle_system_back()


## 게임 중 Back은 설정으로, 시작 화면에서는 가장 위의 모달을 닫는다.
func handle_system_back() -> void:
	if _entry_starting or _edition_exiting or not is_instance_valid(current):
		return
	if not current is Adventure3D:
		var panels := get_tree().get_nodes_in_group("panel_frames")
		panels.reverse()
		for panel: PanelFrame in panels:
			if not panel.is_queued_for_deletion() and panel.get_viewport() == get_viewport():
				panel.closed.emit()
				return
	if current is Adventure3D and is_instance_valid(current.simulation):
		var hud: Hud = current.simulation.hud
		if not hud._panel is SettingsPanel:
			if hud.panel_open():
				hud.close_panel()
			hud.open_settings()


func _reload_adventure() -> void:
	var token := _open_entry_loading("continue", GameState.active_slot, GameState.hero_class)
	await _paint_entry_phase("load")
	if not _entry_valid(token):
		return
	_entry_loading.note_work()
	if not GameState.load_game():
		_entry_failed(token, GameState.active_slot, "모험을 읽지 못했습니다. 다른 슬롯을 선택해 주세요.")
		return
	await _build_entry_world(token, GameState.active_slot)

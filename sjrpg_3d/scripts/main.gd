extends Node
## Root scene: swaps between title, class selection and the adventure.

var current: Node
var _edition_exiting := false
var _entry_starting := false


func _ready() -> void:
	get_tree().root.size_changed.connect(_fit_orientation)
	_fit_orientation()
	show_title()


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


func show_title() -> void:
	_entry_starting = false
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sjrpgAdventureReady = false; window.__sjrpgClassSelectReady = false; window.__sjrpgTitleReady = false")
	var title := preload("res://scripts/title_screen.gd").new()
	title.start_requested.connect(show_class_select)
	_swap(title)


func show_class_select() -> void:
	_entry_starting = false
	var select := preload("res://scripts/class_select.gd").new()
	select.chosen.connect(_choose_hero)
	select.continue_requested.connect(_continue_hero)
	select.back_requested.connect(show_title)
	_swap(select)


func start_game() -> void:
	var game := NativeAdventure.new()
	game.quit_requested.connect(show_title)
	game.restart_requested.connect(func():
		show_class_select())
	_swap(game)


func _choose_hero(cls: String) -> void:
	_begin_new_game(cls)


func _continue_hero() -> void:
	if _entry_starting or not current.has_method("show_error"):
		return
	_entry_starting = true
	var slot: int = current.selected_slot
	if GameState.select_slot(slot) and GameState.load_game():
		UiKit.boost = 1.0
		start_game()
	else:
		_entry_starting = false
		current.show_error("모험을 읽지 못했습니다. 다른 슬롯을 선택하거나 다시 시도해 주세요.")


func _begin_new_game(cls: String) -> void:
	if _entry_starting or not current.has_method("show_error"):
		return
	_entry_starting = true
	var slot: int = current.selected_slot
	if GameState.create_slot(slot, cls):
		UiKit.boost = 1.0
		start_game()
	else:
		_entry_starting = false
		current.show_error("새 모험을 저장하지 못했습니다. 빈 슬롯인지 확인하고 다시 시도해 주세요.")


func prepare_edition_exit() -> void:
	if _edition_exiting:
		return
	_edition_exiting = true
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

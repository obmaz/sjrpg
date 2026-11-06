extends Node
## Root scene: swaps between title, class selection and the adventure.

var current: Node
var _edition_exiting := false


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
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sjrpgAdventureReady = false; window.__sjrpgClassSelectReady = false; window.__sjrpgTitleReady = false")
	var title := preload("res://scripts/title_screen.gd").new()
	title.start_requested.connect(show_class_select)
	_swap(title)


func show_class_select() -> void:
	var select := preload("res://scripts/class_select.gd").new()
	select.chosen.connect(_choose_hero)
	select.continue_requested.connect(func():
		if GameState.load_game():
			start_game())
	select.back_requested.connect(show_title)
	_swap(select)


func start_game() -> void:
	var game := NativeAdventure.new()
	game.quit_requested.connect(show_title)
	game.restart_requested.connect(func():
		show_class_select())
	_swap(game)


func _choose_hero(cls: String) -> void:
	if not GameState.has_save_files():
		_begin_new_game(cls)
		return
	var confirm := PanelFrame.new()
	add_child(confirm)
	confirm.set_compact()
	confirm.set_header("새 모험을 시작할까요?")
	var message := "새 모험을 시작하면 이전 진행을 덮어씁니다. 취소하면 기존 모험을 유지합니다."
	if not GameState.has_save():
		message = "저장 파일이 있지만 현재 읽을 수 없습니다. 새 모험을 시작하면 기존 파일을 덮어씁니다. 취소하면 파일을 그대로 유지합니다."
	confirm.body.add_child(PanelFrame.wrap_label(message, 22))
	confirm.add_footer("취소", func(): confirm.queue_free())
	confirm.add_footer("새 모험 시작", func():
		confirm.queue_free()
		_begin_new_game(cls), true)
	confirm.closed.connect(func(): confirm.queue_free())


func _begin_new_game(cls: String) -> void:
	UiKit.boost = 1.0
	GameState.new_game(cls)
	start_game()


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

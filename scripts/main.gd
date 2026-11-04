extends Node
## Root scene: swaps between title, class selection and the adventure.

var current: Node


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
		current.queue_free()
	current = node
	add_child(node)


func show_title() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sjrpgAdventureReady = false")
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
	var game := preload("res://scripts/game.gd").new()
	game.quit_requested.connect(show_title)
	game.restart_requested.connect(func():
		show_class_select())
	_swap(game)


func _choose_hero(cls: String) -> void:
	if not GameState.has_save():
		_begin_new_game(cls)
		return
	var confirm := PanelFrame.new()
	add_child(confirm)
	confirm.set_header("새 모험을 시작할까요?")
	confirm.body.add_child(PanelFrame.wrap_label("새 모험을 시작하면 이전 진행을 덮어씁니다. 취소하면 기존 모험을 유지합니다.", 22))
	confirm.add_footer("취소", func(): confirm.queue_free())
	confirm.add_footer("새 모험 시작", func():
		confirm.queue_free()
		_begin_new_game(cls), true)
	confirm.closed.connect(func(): confirm.queue_free())


func _begin_new_game(cls: String) -> void:
	UiKit.boost = 1.0
	GameState.new_game(cls)
	start_game()

extends TestCase
## Use real slot persistence and selection callbacks; replace only expensive world creation.

class SlowSimulation:
	extends Node2D
	var native_ready := false


class SlowAdventure:
	extends Adventure3D
	func _ready() -> void:
		simulation = SlowSimulation.new()
		add_child(simulation)


class EntryRoot:
	extends "res://scripts/app/main.gd"
	var launches := 0
	var hold_world := false
	var launch_phases: Array[String] = []
	func _ready() -> void:
		pass
	func start_game() -> void:
		launches += 1
		launch_phases.append(str(_entry_loading.snapshot().get("phase", "")))
		_swap(SlowAdventure.new() if hold_world else Node.new())


func _settle(root: Node) -> void:
	for frame in 120:
		if not bool(root.get("_entry_starting")):
			return
		await _frames(1)
	check("entry loading completes within bounded frames", false)


func _clean_slots() -> void:
	for number in range(1, 5):
		GameState.delete_slot(number)


func run() -> void:
	await _native_layout()
	var old_path := GameState.slot_path(1)
	var old_slot := GameState.active_slot
	GameState.save_path = "user://tests/entry-loading.json"
	_clean_slots()
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	add_child(view)
	var root := EntryRoot.new()
	view.add_child(root)
	root.show_class_select()
	await _frames(2)
	root.current.select_slot(1)
	root.current.select_class("mage")
	var path := GameState.slot_path(1)
	var observed: Array[Dictionary] = []
	root.entry_loading_changed.connect(func(phase: String):
		observed.append({"phase": phase, "exists": FileAccess.file_exists(path), "starting": root._entry_starting}))
	root._choose_hero("mage")
	root._choose_hero("mage")
	check("new-game indicator and guard appear before slot persistence or world creation",
		root._entry_starting and is_instance_valid(root._entry_loading) and bool(root._entry_loading.snapshot().get("visible", false))
		and not FileAccess.file_exists(path) and root.launches == 0)
	await _settle(root)
	check("new-game stages precede one actual slot creation and launch",
		root.launches == 1 and root.launch_phases == ["world"]
		and not observed.is_empty() and observed[0]["phase"] == "create" and not observed[0]["exists"]
		and bool(GameState.slot_summaries()[0]["valid"]) and GameState.hero_class == "mage")
	check("completed new-game transition removes its input-blocking overlay", not is_instance_valid(root._entry_loading) and not root._entry_starting)

	GameState.gold = 456
	GameState.save_game()
	var saved := FileAccess.get_file_as_string(path)
	GameState.gold = 1
	root.show_class_select()
	await _frames(2)
	root.current.select_slot(1)
	var selected: Node = root.current
	root._continue_hero()
	root._continue_hero()
	check("continue shows loading before changing live hero data",
		root._entry_starting and is_instance_valid(root._entry_loading)
		and GameState.gold == 1 and root.launches == 1)
	await _settle(root)
	check("continue loads the selected data once without changing saved bytes",
		root.launches == 2 and GameState.gold == 456 and FileAccess.get_file_as_string(path) == saved
		and root.launch_phases == ["world", "world"])
	check("continue retires selection and clears overlay after launch",
		not is_instance_valid(selected) and not is_instance_valid(root._entry_loading) and not root._entry_starting)

	root.show_class_select()
	await _frames(2)
	root.current.select_slot(1)
	selected = root.current
	root._begin_new_game("warrior")
	await _settle(root)
	check("occupied-slot creation failure preserves selection and exact save",
		root.current == selected and root.launches == 2 and FileAccess.get_file_as_string(path) == saved
		and "저장하지 못했습니다" in root.current.subtitle.text and not is_instance_valid(root._entry_loading))

	var broken_path := GameState.slot_path(3)
	var broken := FileAccess.open(broken_path, FileAccess.WRITE)
	broken.store_string("{broken review save")
	broken.close()
	root.current.refresh_slots()
	root.current.select_slot(3)
	root._continue_hero()
	await _settle(root)
	check("unreadable-save failure restores controls without launching or overwriting",
		root.current == selected and root.launches == 2 and FileAccess.get_file_as_string(broken_path) == "{broken review save"
		and "읽지 못했습니다" in root.current.subtitle.text and not root._entry_starting and not is_instance_valid(root._entry_loading))

	root.current.select_slot(2)
	root.current.select_class("warrior")
	root._choose_hero("warrior")
	root.show_class_select()
	await _frames(6)
	check("leaving selection cancels pending persistence and clears the loading guard",
		not FileAccess.file_exists(GameState.slot_path(2)) and root.launches == 2
		and not root._entry_starting and not is_instance_valid(root._entry_loading))
	root.current.select_slot(2)
	root.current.select_class("warrior")
	root._choose_hero("warrior")
	await _settle(root)
	check("a cancelled or failed transition can start another empty slot normally",
		root.launches == 3 and bool(GameState.slot_summaries()[1]["valid"]) and GameState.hero_class == "warrior")

	root.show_class_select()
	await _frames(2)
	root.current.select_slot(2)
	root.hold_world = true
	root._continue_hero()
	for frame in 120:
		if root.launches == 4:
			break
		await _frames(1)
	await _frames(2)
	check("world loading remains until the actual simulation readiness flag",
		root.launches == 4 and root._entry_starting and is_instance_valid(root._entry_loading)
		and root._entry_loading.snapshot().get("phase", "") == "world"
		and not root.current.simulation.native_ready)
	root.current.simulation.native_ready = true
	await _settle(root)
	check("world readiness releases the loading shield",
		not root._entry_starting and not is_instance_valid(root._entry_loading))

	root.show_class_select()
	await _frames(2)
	root.current.select_slot(2)
	root._continue_hero()
	for frame in 120:
		if root.launches == 5:
			break
		await _frames(1)
	check("teardown fixture reaches the pending world-ready wait", root.launches == 5 and root._entry_starting)
	var root_ref: WeakRef = weakref(root)
	root.queue_free()
	await _frames(3)
	check("root teardown releases the pending transition and its owned overlay", root_ref.get_ref() == null)

	view.queue_free()
	await _frames(3)
	_clean_slots()
	GameState.save_path = old_path
	GameState.select_slot(old_slot)


func _native_layout() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(320, 568)
	add_child(view)
	var overlay := preload("res://scripts/ui/screens/entry_loading.gd").new().setup("continue", 1, "mage", 991)
	view.add_child(overlay)
	overlay.set_phase("world")
	for dimensions in [Vector2i(320, 568), Vector2i(568, 320), Vector2i(344, 883), Vector2i(883, 344), Vector2i(768, 896), Vector2i(896, 768), Vector2i(800, 800)]:
		view.size = dimensions
		await _frames(4)
		var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
		var panel: Rect2 = overlay._panel.get_global_rect()
		check("native loading remains fully within the display " + str(dimensions), bounds.encloses(panel))
		for label: Label in [overlay._title, overlay._status, overlay._note]:
			check("loading text remains readable and inside its card " + str(dimensions), panel.encloses(label.get_global_rect()) and label.get_theme_font_size("font_size") >= 14 and label.size.y + 1.0 >= label.get_minimum_size().y)
	view.queue_free()
	await _frames(2)

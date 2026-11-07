class_name GamepadNavigation
extends Node
## Ordered focus scopes; gameplay remains owned by Game/Gamepad.
var _scope: Control
var _buttons: Array[BaseButton] = []
var _focus_index := 0
var _refresh_time := 0.0
var _last_key := ""
var _history: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Gamepad.action_pressed.connect(_action)
	Gamepad.input_mode_changed.connect(_mode_changed)


func _scope_now() -> Control:
	if loading_blocked():
		return null
	var result: Control
	for node: Node in get_tree().get_nodes_in_group("panel_frames"):
		if node is Control and node.can_process() and node.is_visible_in_tree() and not node.is_queued_for_deletion():
			result = node as Control
	if result != null:
		return result
	for node: Node in get_tree().get_nodes_in_group("gamepad_entry"):
		if node is Control and node.can_process() and not node.is_queued_for_deletion():
			if node.is_visible_in_tree() or bool(node.get_meta("gamepad_hidden_scope", false)):
				result = node as Control
	return result


func has_scope() -> bool:
	return _scope_now() != null


func _process(delta: float) -> void:
	var current := _scope_now()
	if current != _scope:
		if is_instance_valid(_scope):
			_history[_scope.get_instance_id()] = _last_key
		_scope = current
		_buttons.clear()
		_focus_index = 0
		_last_key = str(_history.get(_scope.get_instance_id(), "")) if _scope != null else ""
		Gamepad.require_neutral()
		_refresh_time = 0.0
	_scroll(delta)
	_refresh_time -= delta
	if _refresh_time <= 0.0:
		_refresh_time = 0.10
		_refresh()


func _valid(button: BaseButton) -> bool:
	return is_instance_valid(button) and not button.is_queued_for_deletion() and button.is_visible_in_tree() and not button.disabled


func _collect(node: Node, result: Array[BaseButton]) -> void:
	for child: Node in node.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is BaseButton:
			var button := child as BaseButton
			if _valid(button) and (button.mouse_filter != Control.MOUSE_FILTER_IGNORE or bool(button.get_meta("gamepad_target", false))):
				result.append(button)
		_collect(child, result)


func _key(button: BaseButton) -> String:
	if button.has_meta("gamepad_key"):
		return str(button.get_meta("gamepad_key"))
	if button is Button and not (button as Button).text.is_empty():
		return "text:" + (button as Button).text
	return str(_scope.get_path_to(button))


func _refresh() -> void:
	if not is_instance_valid(_scope):
		_buttons.clear()
		return
	var found: Array[BaseButton] = []
	if _scope is PanelFrame:
		var frame := _scope as PanelFrame
		_collect(frame.tab_row, found)
		_collect(frame.body_holder, found)
		_collect(frame.footer, found)
		_collect(frame._header, found)
	else:
		_collect(_scope, found)
	_buttons = found
	for button: BaseButton in _buttons:
		button.focus_mode = Control.FOCUS_ALL
		if not button.has_meta("gamepad_focus_style"):
			var border := StyleBoxFlat.new()
			border.bg_color = Color(0, 0, 0, 0)
			border.border_color = Color("e2c28a")
			border.set_border_width_all(2)
			border.set_corner_radius_all(5)
			border.set_expand_margin_all(3)
			button.add_theme_stylebox_override("focus", border)
			button.set_meta("gamepad_focus_style", true)
	if not Gamepad.using_gamepad or _buttons.is_empty():
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused is BaseButton and _buttons.has(focused):
		_focus_index = _buttons.find(focused)
		_last_key = _key(focused)
		return
	var target := -1
	for index: int in _buttons.size():
		if _key(_buttons[index]) == _last_key:
			target = index
			break
	if target < 0:
		# Destructive confirmations always start at cancel, including rebuilt bodies.
		for index: int in _buttons.size():
			if _buttons[index] is Button and (_buttons[index] as Button).text == "취소":
				target = index
				break
	if target < 0 and _scope.has_method("gamepad_initial_focus"):
		var preferred := _scope.call("gamepad_initial_focus") as BaseButton
		target = _buttons.find(preferred)
	if target < 0:
		target = mini(_focus_index, _buttons.size() - 1)
	_focus(target)


func _focus(index: int) -> void:
	if _buttons.is_empty():
		return
	_focus_index = posmod(index, _buttons.size())
	var button := _buttons[_focus_index]
	_last_key = _key(button)
	button.grab_focus()
	var parent := button.get_parent()
	while parent != null and parent != _scope:
		if parent is ScrollContainer:
			(parent as ScrollContainer).ensure_control_visible(button)
		parent = parent.get_parent()


func _activate(button: BaseButton) -> void:
	if not _valid(button):
		return
	Gamepad.require_neutral()
	if button.toggle_mode:
		button.button_pressed = not button.button_pressed
	button.pressed.emit()
	_refresh_time = 0.0


func _mode_changed(active: bool) -> void:
	if active:
		_refresh()
	else:
		var focus := get_viewport().gui_get_focus_owner()
		if focus != null:
			focus.release_focus()


func _back() -> void:
	if _scope.has_method("gamepad_back") and bool(_scope.call("gamepad_back")):
		Gamepad.require_neutral()
		return
	for button: BaseButton in _buttons:
		if button is Button and (button as Button).text == "취소":
			_activate(button)
			return
	if _scope is PanelFrame:
		Gamepad.require_neutral()
		(_scope as PanelFrame).closed.emit()


func _action(action: String) -> void:
	if loading_blocked():
		return
	# Resolve synchronously: an earlier signal listener may just have opened a menu.
	var current := _scope_now()
	if current != _scope:
		_scope = current
		_last_key = ""
		_refresh()
	if _scope != null:
		Gamepad.set_combat_enabled(false)
		match action:
			"primary":
				if _scope.has_method("gamepad_accept"):
					Gamepad.require_neutral()
					_scope.call("gamepad_accept")
				else:
					_refresh()
					var focus := get_viewport().gui_get_focus_owner() as BaseButton
					if focus != null and _buttons.has(focus):
						_activate(focus)
			"roll":
				_back()
			"nav_up", "nav_left":
				_refresh()
				_focus(_focus_index - 1)
			"nav_down", "nav_right":
				_refresh()
				_focus(_focus_index + 1)
		return
	if not Gamepad.combat_enabled() or get_tree().paused:
		return
	var hud: Hud
	for node: Node in get_tree().get_nodes_in_group("gamepad_hud"):
		if node is Hud and not node.is_queued_for_deletion():
			var candidate := node as Hud
			if is_instance_valid(candidate.game) and candidate.game.can_process() and not candidate.game.is_queued_for_deletion() and candidate.game.native_ready:
				hud = candidate
	if hud == null or hud.game.player.dead:
		return
	match action:
		"bag":
			hud.open_bag()
		"quests":
			hud.open_journal()
		"skills":
			hud.open_skill_tree()
		"settings":
			hud.open_settings()
		"map":
			hud.open_map()


func review_snapshot() -> Dictionary:
	var focus := get_viewport().gui_get_focus_owner()
	var rect := Rect2()
	if focus != null:
		rect = focus.get_global_rect()
	var keys: Array[String] = []
	for button: BaseButton in _buttons:
		if _valid(button) and is_instance_valid(_scope):
			keys.append(_key(button))
	return {"target_keys": keys, "focus_text": (focus as Button).text if focus is Button else "", "scope": str(_scope.name) if is_instance_valid(_scope) else "",
		"scope_class": str(_scope.get_script().resource_path) if is_instance_valid(_scope) else "",
		"focus": str(focus.name) if focus != null else "", "focus_key": _last_key,
		"focus_inside": is_instance_valid(_scope) and focus != null and _scope.is_ancestor_of(focus),
		"focus_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"targets": _buttons.size(), "index": _focus_index}


func loading_blocked() -> bool:
	for node: Node in get_tree().get_nodes_in_group("entry_loading"):
		if not node.is_queued_for_deletion():
			return true
	for node: Node in get_tree().get_nodes_in_group("gamepad_entry"):
		if node is Control and not node.is_queued_for_deletion() and node.is_visible_in_tree() and not node.can_process():
			return true
	return false


func _scroll(delta: float) -> void:
	if _scope == null or not Gamepad.using_gamepad:
		return
	var direction: Vector2 = Gamepad.ui_scroll_vector()
	if direction.is_zero_approx():
		return
	var target: ScrollContainer
	var focus := get_viewport().gui_get_focus_owner()
	var parent: Node = focus.get_parent() if focus != null else null
	while parent != null and parent != _scope:
		if parent is ScrollContainer:
			target = parent as ScrollContainer
			break
		parent = parent.get_parent()
	if _scope is PanelFrame:
		var frame := _scope as PanelFrame
		if target == null or target == frame.tab_scroll:
			target = frame.scroll
	if target == null or not target.is_visible_in_tree():
		return
	target.scroll_vertical += roundi(direction.y * 680.0 * delta)
	target.scroll_horizontal += roundi(direction.x * 680.0 * delta)

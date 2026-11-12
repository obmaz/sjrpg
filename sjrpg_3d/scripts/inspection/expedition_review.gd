extends Node
## 명시적 expedition_review=1에서만 읽기 전용 UI/저장 검수 좌표를 공개한다.
var main: Node
var _poll := 0.0


func setup(value: Node) -> Node:
	main = value
	process_mode = Node.PROCESS_MODE_ALWAYS
	return self


func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0:
		return
	_poll = 0.2
	if not main.current is Adventure3D:
		return
	var game: Node = main.current.simulation
	if not is_instance_valid(game) or not game.native_ready:
		return
	var controls := []
	var panel: Control = game.hud._panel
	var scroll_value := 0
	var scroll_max := 0.0
	if panel is ExpeditionPanel or panel is RunBuildPanel:
		scroll_value = panel.scroll.scroll_vertical
		scroll_max = (
			panel.scroll.get_v_scroll_bar().max_value - panel.scroll.get_v_scroll_bar().page
		)
		for button: Button in panel.find_children("*", "Button", true, false):
			var rect := button.get_global_rect()
			var visible_rect: Rect2 = panel.scroll.get_global_rect().intersection(rect)
			var point := rect.get_center() / get_viewport().get_visible_rect().size
			controls.append(
				{
					"id": str(button.name),
					"text": button.text,
					"point": [point.x, point.y],
					"visible":
					button.is_visible_in_tree() and visible_rect.size.y >= rect.size.y * 0.6,
					"disabled": button.disabled
				}
			)
	var report := {
		"phase": ExpeditionState.phase(),
		"active": ExpeditionState.active(),
		"level": GameState.level,
		"ranks": GameState.ranks,
		"slots": GameState.slots,
		"drafts": GameState.expedition.get("drafts", []),
		"runes": GameState.expedition.get("runes", {}),
		"offered": GameState.expedition.get("offered", []),
		"buttons": controls,
		"scroll": scroll_value,
		"scroll_max": scroll_max,
		"paused": get_tree().paused,
		"loading": main._entry_starting,
		"panel": str(panel.get_script().resource_path) if panel != null else ""
	}
	JavaScriptBridge.eval("window.__sjrpgExpedition = " + JSON.stringify(report))

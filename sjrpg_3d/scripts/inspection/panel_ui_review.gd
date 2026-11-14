extends Node
## 명시적 검수 세션의 실제 UI를 관찰한다. 입력·위치·게임 상태는 변경하지 않는다.
var _game: Node
var _elapsed := 0.0


func setup(game: Node) -> void:
	_game = game
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.15 or not OS.has_feature("web"):
		return
	_elapsed = 0.0
	if not is_instance_valid(_game):
		return
	var hud: Hud = _game.get("hud")
	if not is_instance_valid(hud):
		return
	var viewport := hud.controls.get_viewport()
	var view := viewport.get_visible_rect().size
	var margins := PanelFrame.safe_margins(viewport)
	var targets := {}
	for key: String in hud.controls._buttons:
		var target: Dictionary = hud.controls._buttons[key]
		var center: Vector2 = target["center"]
		targets[key] = [center.x, center.y]
	var state := {
		"frame": Engine.get_process_frames(), "viewport": [view.x, view.y],
		"scale": UiMetrics.units_per_display_pixel(viewport),
		"safe": _rect(Rect2(Vector2(margins.x, margins.y),
			view - Vector2(margins.x + margins.z, margins.y + margins.w))),
		"paused": get_tree().paused, "native_ready": _game.get("native_ready"),
		"hud_targets": targets, "world_zoom": Prefs.world_zoom, "gold": GameState.gold,
		"screen_orientation": Prefs.screen_orientation,
		"panel": {}
	}
	var panel: PanelFrame = hud._panel
	if is_instance_valid(panel):
		state["panel"] = _panel_snapshot(panel)
	JavaScriptBridge.eval("window.__sjrpgPanelLayout = " + JSON.stringify(state), true)


func _exit_tree() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("delete window.__sjrpgPanelLayout", true)


func _panel_snapshot(panel: PanelFrame) -> Dictionary:
	var controls: Array = []
	var scrolls: Array = []
	var switches: Array = []
	for child: Node in panel.find_children("*", "Control", true, false):
		var control := child as Control
		if not control.is_visible_in_tree():
			continue
		if control.name == "SwitchPill":
			switches.append({"rect": _rect(control.get_global_rect()), "on": bool(control.get("on")),
				"font": int(control.get("font_pixels"))})
		if control is ScrollContainer:
			var container := control as ScrollContainer
			var bar := container.get_v_scroll_bar()
			var content: Control = null
			for candidate: Node in container.get_children():
				if candidate is Control and not candidate is ScrollBar:
					content = candidate as Control
					break
			scrolls.append({
				"path": str(panel.get_path_to(control)), "rect": _rect(control.get_global_rect()),
				"vertical": container.scroll_vertical,
				"v_bar_visible": bar.is_visible_in_tree(),
				"h_bar_visible": container.get_h_scroll_bar().is_visible_in_tree(),
				"arrow_cues": container.has_meta("scroll_arrows"),
				"maximum": maxf(0.0, bar.max_value - bar.page), "page": bar.page,
				"horizontal_disabled": container.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
				"content": _rect(content.get_global_rect()) if content != null else []
			})
		if not control is Label and not control is Button:
			continue
		var box := control.get_global_rect()
		var clip := panel.get_viewport_rect()
		var parent := control.get_parent()
		while parent != null and parent != panel:
			if parent is Control and parent.clip_contents:
				clip = clip.intersection(parent.get_global_rect())
			parent = parent.get_parent()
		var words := str(control.get("text"))
		var font_size := control.get_theme_font_size("font_size")
		var font := control.get_theme_font("font")
		var inner := _content_rect(control, "normal") if control is Button else box
		var skin: UiKit.GeneratedSkin = control.get_theme_stylebox("normal") as UiKit.GeneratedSkin if control is Button else null
		var normal: StyleBox = control.get_theme_stylebox("normal") if control is Button else null
		controls.append({
			"id": control.get_instance_id(),
			"path": str(panel.get_path_to(control)), "kind": "button" if control is Button else "label",
			"text": words, "rect": _rect(box), "clip": _rect(clip),
			"visible_rect": _rect(box.intersection(clip)), "font": font_size,
			"minimum": _vector(control.get_combined_minimum_size()),
			"text_width": font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x,
			"content_rect": _rect(inner),
			"text_height": font.get_multiline_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, maxf(1.0, inner.size.x), font_size).y,
			"art_source": skin.drawn_source_path() if skin != null else "",
			"style": normal.get_class() if normal != null else "",
			"world_zoom": control.get_meta("world_zoom") if control.has_meta("world_zoom") else null,
			"screen_orientation": control.get_meta("screen_orientation") if control.has_meta("screen_orientation") else null,
			"selected": control.button_pressed if control is Button else false,
			"text_centered": control.alignment == HORIZONTAL_ALIGNMENT_CENTER if control is Button else false,
			"input_ignored": control.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"wrap": int(control.get("autowrap_mode")),
			"in_body": panel.body_holder.is_ancestor_of(control),
			"in_footer": panel.footer.is_ancestor_of(control),
			"disabled": control.disabled if control is Button else false,
			"key": control.get_meta("gamepad_key", "")
		})
	return {
		"id": panel.get_instance_id(), "type": panel.get_script().resource_path,
		"title_text": panel.title_label.text, "rect": _rect(panel._panel.get_global_rect()),
		"content_rect": _rect(_content_rect(panel._panel, "panel")),
		"header": _rect(panel._header.get_global_rect()),
		"title": _rect(panel.title_label.get_global_rect()),
		"close": _rect(panel._close.get_global_rect()) if is_instance_valid(panel._close) and panel._close.is_visible_in_tree() else [],
		"body_holder": _rect(panel.body_holder.get_global_rect()),
		"body_scroll": _rect(panel.scroll.get_global_rect()), "body": _rect(panel.body.get_global_rect()),
		"footer": _rect(panel.footer.get_global_rect()), "controls": controls, "scrolls": scrolls,
		"switches": switches
	}


func _content_rect(control: Control, name: String) -> Rect2:
	var style := control.get_theme_stylebox(name)
	var box := control.get_global_rect()
	return box.grow_individual(-style.get_content_margin(SIDE_LEFT), -style.get_content_margin(SIDE_TOP),
		-style.get_content_margin(SIDE_RIGHT), -style.get_content_margin(SIDE_BOTTOM))


func _vector(value: Vector2) -> Array:
	return [value.x, value.y]


func _rect(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]

class_name SkillTreePanel
extends PanelFrame
## 스킬 트리 (원본: lib/src/ui/skills_panel.dart · skill_tree.dart · skill_tree_layout.dart).
## Three schools of six level tiers (1·6·12·18·24·30), prerequisite arrows,
## learning with skill points, and equipping to the main / auxiliary slots.
## 실제 본문 폭이 충분할 때 좌우로, 접힌 화면에서는 트리(위) + 상세(아래)로 나뉩니다.

const TIERS := [1, 6, 12, 18, 24, 30]
const NODE_SIDE := 84.0
const TIER_HEIGHT := 150.0
const TREE_PADDING := 18.0
const TIER_LABEL_WIDTH := 70.0
const TREE_MIN_WIDTH := 400.0
const TAP_SLOP := 12.0

var _tab := 0
var _selected := ""
var _tree: Control
var _tree_scroll: ScrollContainer
var _gesture_index := -2
var _gesture_start := Vector2.ZERO
var _gesture_scroll := Vector2i.ZERO
var _gesture_node := ""
var _gesture_dragged := false
var _detail: VBoxContainer
var _detail_panel: PanelContainer
var _layout_box: BoxContainer
var _pad_nodes: Dictionary = {}
var _nodes := {}  # id -> Rect2 in _tree coordinates


func _ready() -> void:
	super._ready()
	set_header("%s 스킬" % GameState.class_info()["name"])
	# The tree needs the whole body, so it replaces the generic scrolling body.
	scroll.visible = false
	_layout_box = BoxContainer.new()
	_layout_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout_box.add_theme_constant_override("separation", 12)
	body_holder.add_child(_layout_box)

	_tree_scroll = ScrollContainer.new()
	_tree_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree_scroll.size_flags_stretch_ratio = 1.15
	_tree_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_tree_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_tree_scroll.scroll_deadzone = int(TAP_SLOP)
	_tree_scroll.scroll_started.connect(_cancel_tree_gesture)
	_layout_box.add_child(_tree_scroll)
	_tree = Control.new()
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.mouse_filter = Control.MOUSE_FILTER_PASS
	_tree.custom_minimum_size = Vector2(TREE_MIN_WIDTH, TIER_HEIGHT * TIERS.size() + TREE_PADDING * 2)
	_tree.draw.connect(_draw_tree)
	_tree.gui_input.connect(_tree_input)
	_tree.resized.connect(func():
		_layout_nodes()
		_tree.queue_redraw())
	_tree_scroll.add_child(_tree)

	_detail_panel = PanelContainer.new()
	_detail_panel.add_theme_stylebox_override("panel", UiKit.card_style())
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_layout_box.add_child(_detail_panel)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.scroll_deadzone = 14
	_detail_panel.add_child(detail_scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	detail_scroll.add_child(_detail)

	add_footer("스킬 초기화", func():
		if GameState.invested_points() > 0:
			GameState.reset_skills()
			_refresh(), false, 1.0)
	add_footer("모험 계속하기", func(): closed.emit(), true, 2.0)

	get_viewport().size_changed.connect(_fit)
	body_holder.resized.connect(_fit)
	_fit()
	_selected = GameState.slots[0]
	_tab = _tab_of(_selected)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_T]:
		get_viewport().set_input_as_handled()
		closed.emit()


func frame_max_width() -> float:
	var view := get_viewport_rect().size
	# A short landscape needs both work areas beside each other. The general
	# 880-unit reading cap would waste several hundred display pixels on a phone.
	return maxf(MAX_WIDTH, 1000.0 * graph_css_scale()) if view.x > view.y else MAX_WIDTH


func _fit() -> void:
	var scale := graph_css_scale()
	var side := _node_side()
	var tree_width := maxf(TREE_MIN_WIDTH, TIER_LABEL_WIDTH + 12.0 + 3.0 * (side + 16.0 + UiKit.ACTION_GAP_DP * scale))
	var gap := maxi(12, roundi(UiKit.ACTION_GAP_DP * scale))
	_layout_box.add_theme_constant_override("separation", gap)
	_detail.add_theme_constant_override("separation", maxi(8, roundi(UiKit.ACTION_GAP_DP * scale)))
	_tree.custom_minimum_size = Vector2(tree_width, _tier_height() * TIERS.size() + TREE_PADDING * 2.0)
	# Decide from the actual content width in display units: near-square folds and
	# phone landscape cannot support two readable columns inside the capped frame.
	# 짧은 가로 화면에서는 상세의 가독 폭을 지키고 커진 트리를 가로 스크롤한다.
	_layout_box.vertical = body_holder.size.x < (168.0 + 280.0) * scale + gap
	_detail_panel.custom_minimum_size.x = 0.0 if _layout_box.vertical else 280.0 * scale
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _layout_box.vertical else Control.SIZE_FILL
	_tree_scroll.size_flags_stretch_ratio = 1.15 if _layout_box.vertical else tree_width
	_detail_panel.size_flags_stretch_ratio = 1.0 if _layout_box.vertical else 280.0 * scale
	_tree_scroll.custom_minimum_size.y = 0.0
	_layout_nodes()
	_tree.queue_redraw()
	_fit_detail_type()


func _node_side() -> float:
	var scale := graph_css_scale()
	var rank_font := graph_font_size(18, scale)
	var ribbon_width := UiKit.BOLD_FONT.get_string_size("20/20", HORIZONTAL_ALIGNMENT_LEFT, -1, rank_font).x + 10.0
	return maxf(ribbon_width, maxf(NODE_SIDE, ceilf(UiKit.ACTION_TOUCH_DP * scale) - 16.0))


func _tier_height() -> float:
	return maxf(TIER_HEIGHT, _node_side() + UiKit.BOLD_FONT.get_height(graph_font_size(18, graph_css_scale())) + 18.0)


func _tab_labels() -> Array:
	var labels: Array = GameState.skill_data()[GameState.hero_class]["schools"].duplicate()
	if GameState.hero_class == "warrior":
		labels.append("기본·특수")
	return labels


## Skills placed in the current tab as [id, row, column 0..2].
func _tab_slots(tab: int) -> Array:
	var out := []
	if tab == 3:
		var extra := ["cleave", "shadowAssault", "battleSprint"]
		for i in extra.size():
			out.append([extra[i], i * 2, 1])
		return out
	var rows: Array = GameState.skill_data()[GameState.hero_class]["rows"]
	for r in rows.size():
		for slot in rows[r]:
			var col := int(slot[1])
			if col / 3 == tab:
				out.append([slot[0], r, col % 3])
	return out


func _tab_of(id: String) -> int:
	for t in _tab_labels().size():
		for slot in _tab_slots(t):
			if slot[0] == id:
				return t
	return 0


func _refresh() -> void:
	set_header("%s 스킬" % GameState.class_info()["name"], "스킬 포인트 %d · Lv.%d" % [GameState.skill_points, GameState.level])
	set_tabs(_tab_labels(), _tab, func(i):
		_tab = i
		_tree_scroll.scroll_vertical = 0
		_refresh())
	_layout_nodes()
	_tree.queue_redraw()
	_build_detail()
	_rebuild_pad_nodes()


# ───────── tree drawing ─────────

## Node geometry is independent of viewport height; the scroll area reveals all six tiers.
func _layout_nodes() -> void:
	_nodes.clear()
	var width := maxf(_tree.size.x, TREE_MIN_WIDTH)
	var col_w := (width - TIER_LABEL_WIDTH - 12.0) / 3.0
	var side := _node_side()
	for slot in _tab_slots(_tab):
		var center := Vector2(TIER_LABEL_WIDTH + (slot[2] + 0.5) * col_w, TREE_PADDING + slot[1] * _tier_height() + side * 0.5 + 14.0)
		_nodes[slot[0]] = Rect2(center - Vector2.ONE * side / 2.0, Vector2.ONE * side)

	for id: String in _pad_nodes:
		if _nodes.has(id) and is_instance_valid(_pad_nodes[id]):
			var button: Button = _pad_nodes[id]
			button.position = (_nodes[id] as Rect2).position
			button.size = (_nodes[id] as Rect2).size


## Canvas labels do not inherit PanelFrame's control font boost.
func graph_css_scale() -> float:
	return display_pixel_scale()


static func graph_font_size(preferred: int, css_scale: float) -> int:
	return maxi(preferred, ceili(14.0 * css_scale))


func _graph_label(text: String, rect: Rect2, pixels: int, color: Color) -> void:
	var font := UiKit.BOLD_FONT
	var baseline := rect.position.y + (rect.size.y - font.get_height(pixels)) * 0.5 + font.get_ascent(pixels)
	_tree.draw_string(font, Vector2(rect.position.x, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, pixels, color)


func _draw_tree() -> void:
	_layout_nodes()
	var area := _tree.size
	var font := UiKit.BOLD_FONT
	var scale := graph_css_scale()
	var tier_font := graph_font_size(19, scale)
	var rank_font := graph_font_size(18, scale)
	var mark_font := graph_font_size(17, scale)
	var tier_height := _tier_height()
	for r in TIERS.size():
		var y := TREE_PADDING + r * tier_height
		_tree.draw_rect(Rect2(0, y, area.x, tier_height - 2.0), Color(1, 0.9, 0.7, 0.025 if r % 2 == 0 else 0.045))
		var tier := "Lv.%d" % TIERS[r] if _tab != 3 else ""
		if not tier.is_empty() and font.get_string_size(tier, HORIZONTAL_ALIGNMENT_LEFT, -1, tier_font).x > TIER_LABEL_WIDTH - 4.0:
			var line_height := maxf(32.0, font.get_height(tier_font) + 2.0)
			_graph_label("Lv.", Rect2(0, y + 14.0, TIER_LABEL_WIDTH - 4.0, line_height), tier_font, UiKit.MUTED)
			_graph_label(str(TIERS[r]), Rect2(0, y + 14.0 + line_height, TIER_LABEL_WIDTH - 4.0, line_height), tier_font, UiKit.MUTED)
		else:
			_graph_label(tier, Rect2(0, y + 32.0, TIER_LABEL_WIDTH - 4.0, 48.0), tier_font, UiKit.MUTED)
	# Prerequisite arrows inside this school.
	for id in _nodes:
		var s := GameState.skill(id)
		for req in s.get("requires", {}):
			if not _nodes.has(req):
				continue
			var from: Rect2 = _nodes[req]
			var to: Rect2 = _nodes[id]
			var met := GameState.rank(req) >= int(s["requires"][req])
			var col := Color(UiKit.GOLD, 0.9) if met else Color(UiKit.MUTED, 0.4)
			# Route outside the rank ribbon so its larger readable text cannot cover a dependency.
			var edge_x := from.end.x + 8.0
			var target_x := to.end.x + 8.0
			var lane_y := from.end.y + 39.0
			var b := Vector2(to.end.x + 3.0, to.get_center().y)
			var route := PackedVector2Array([Vector2(from.end.x + 3.0, from.end.y - 12.0), Vector2(edge_x, from.end.y - 12.0), Vector2(edge_x, lane_y), Vector2(target_x, lane_y), Vector2(target_x, b.y), b])
			_tree.draw_polyline(route, col, 2.5, true)
			_tree.draw_colored_polygon(PackedVector2Array([b, b + Vector2(8, -5), b + Vector2(8, 5)]), col)
	for id in _nodes:
		var rect: Rect2 = _nodes[id]
		var s := GameState.skill(id)
		var rank := GameState.rank(id)
		var learnable := GameState.learn_block_reason(s) == ""
		var tint := Color.WHITE if rank > 0 else (Color(0.75, 0.75, 0.75) if learnable else Color(0.35, 0.35, 0.38))
		_tree.draw_style_box(UiKit.panel_style(UiKit.SURFACE, UiKit.GOLD.darkened(0.4), 4), rect.grow(3))
		SkillIcons.draw(_tree, id, rect.grow(-3), tint)
		var border := UiKit.GOLD if rank > 0 else UiKit.EDGE
		if learnable:
			border = UiKit.TEXT
		_tree.draw_rect(rect, border, false, 4.0 if id == _selected else 2.0)
		if id == _selected:
			_tree.draw_rect(rect.grow(4), UiKit.GOLD, false, 2.0)
		var badge := "%d/%d" % [rank, int(s["limit"])]
		var badge_size := Vector2(minf(rect.size.x, font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, rank_font).x + 10.0), font.get_height(rank_font) + 6.0)
		var badge_rect := Rect2(Vector2(rect.get_center().x - badge_size.x * 0.5, rect.end.y + 4.0), badge_size)
		_tree.draw_style_box(UiKit.panel_style(UiKit.SURFACE, UiKit.GOLD.darkened(0.4), 3), badge_rect)
		_graph_label(badge, badge_rect, rank_font, UiKit.TEXT if rank > 0 else UiKit.MUTED)
		if s["passive"] and not s["basic"]:
			var passive_size := Vector2(font.get_string_size("P", HORIZONTAL_ALIGNMENT_LEFT, -1, mark_font).x + 8.0, font.get_height(mark_font) + 4.0)
			var passive_rect := Rect2(rect.position + Vector2(3, 3), passive_size)
			_tree.draw_style_box(UiKit.panel_style(UiKit.SURFACE, UiKit.GOLD.darkened(0.4), 3), passive_rect)
			_graph_label("P", passive_rect, mark_font, UiKit.MUTED)
		var slot_index: int = GameState.slots.find(id)
		if slot_index >= 0:
			var tag := "주" if slot_index == 0 else str(slot_index)
			var tag_side := maxf(24.0, font.get_height(mark_font) + 6.0)
			var tag_rect := Rect2(rect.position + Vector2(rect.size.x - 3, 5) - Vector2.ONE * tag_side * 0.5, Vector2.ONE * tag_side)
			_tree.draw_circle(tag_rect.get_center(), tag_side * 0.5, UiKit.GOLD)
			_graph_label(tag, tag_rect, mark_font, UiKit.INK)


func _node_at(at: Vector2) -> String:
	for id in _nodes:
		if (_nodes[id] as Rect2).grow(8).has_point(at):
			return id
	return ""


func _begin_tree_gesture(index: int, at: Vector2) -> void:
	if _gesture_index != -2:
		return
	_gesture_index = index
	_gesture_start = _tree.get_global_transform_with_canvas() * at
	_gesture_scroll = Vector2i(_tree_scroll.scroll_horizontal, _tree_scroll.scroll_vertical)
	_gesture_node = _node_at(at)
	_gesture_dragged = false


func _cancel_tree_gesture() -> void:
	_gesture_dragged = true


func _drag_tree_gesture(at: Vector2) -> void:
	var current := _tree.get_global_transform_with_canvas() * at
	if current.distance_to(_gesture_start) > TAP_SLOP:
		_gesture_dragged = true


func _end_tree_gesture(index: int, at: Vector2) -> void:
	if index != _gesture_index:
		return
	_drag_tree_gesture(at)
	var tap := not _gesture_dragged and _gesture_scroll == Vector2i(_tree_scroll.scroll_horizontal, _tree_scroll.scroll_vertical) and _node_at(at) == _gesture_node
	var selected := _gesture_node
	_gesture_index = -2
	_gesture_node = ""
	if tap and selected != "":
		_selected = selected
		_tree.queue_redraw()
		_build_detail()


func _tree_input(event: InputEvent) -> void:
	# A node activates on release, after the scroll container has had a chance to claim a drag.
	# Do not accept press/drag events here: ScrollContainer owns touch panning and its deadzone.
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_tree_gesture(event.index, event.position)
		else:
			_end_tree_gesture(event.index, event.position)
	elif event is InputEventScreenDrag and event.index == _gesture_index:
		_drag_tree_gesture(event.position)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_tree_gesture(-1, event.position)
		else:
			_end_tree_gesture(-1, event.position)
	elif event is InputEventMouseMotion and _gesture_index == -1:
		_drag_tree_gesture(event.position)


# ───────── detail panel ─────────

func _build_detail() -> void:
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	if _selected == "" or GameState.skill(_selected).is_empty():
		_detail.add_child(UiKit.label("기술을 눌러 정보를 확인하세요", 18))
		_fit_detail_type()
		return
	var s := GameState.skill(_selected)
	var rank := GameState.rank(_selected)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_detail.add_child(head)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(88, 88)
	var id := _selected
	icon.draw.connect(func(): SkillIcons.draw(icon, id, Rect2(Vector2.ZERO, Vector2(88, 88))))
	head.add_child(icon)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", PanelFrame.CARD_TEXT_GAP)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	var title := PanelFrame.wrap_label(s["name"], 26, UiKit.GOLD)
	title.add_theme_font_override("font", UiKit.BOLD_FONT)
	names.add_child(title)
	var kind := "패시브" if s["passive"] and not s["basic"] else ("기본 공격" if s["basic"] else ("이동" if s["mobility"] else "사용 기술"))
	var subtitle := [s["branch"]] if s["branch"] == kind else [s["branch"], kind]
	subtitle.append("%d/%d등급" % [rank, int(s["limit"])])
	names.add_child(PanelFrame.wrap_label(" · ".join(subtitle), 16, UiKit.MUTED))

	var desc := UiKit.label(s["desc"], 17)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(160, 0)
	_detail.add_child(desc)

	var info := []
	var shown_rank := maxi(rank, 1)
	if not s["passive"] or s["basic"]:
		var cost := SkillDefs.cost(s, shown_rank)
		info.append("소모 %s %s" % [GameState.class_info()["resource"], HudArt.res(cost)] if cost > 0.0 else "소모 없음")
		var reuse := SkillDefs.cooldown(s)
		if reuse > 0.0:
			info.append("재사용 %.1f초" % reuse)
	info.append("습득 레벨 %d" % GameState.required_level_for_rank(s, rank + 1) if rank < int(s["limit"]) else "최고 등급")
	_detail.add_child(PanelFrame.wrap_label(" · ".join(info), 15, UiKit.MUTED))
	if rank > 0:
		_add_effect_line("현재", SkillDefs.describe(_selected, rank), UiKit.TEXT)
	if rank < int(s["limit"]):
		_add_effect_line("다음 등급" if rank > 0 else "1등급", SkillDefs.describe(_selected, rank + 1), UiKit.GOLD)

	var reason := GameState.learn_block_reason(s)
	var learn := UiKit.button("배우기 (포인트 1)" if rank == 0 else "등급 올리기 (포인트 1)", 21)
	learn.set_meta("gamepad_key", "learn:" + _selected)
	learn.custom_minimum_size = Vector2(0, 72)
	learn.disabled = reason != ""
	learn.pressed.connect(func():
		if GameState.learn(_selected):
			_refresh())
	_detail.add_child(learn)
	if reason != "":
		_detail.add_child(PanelFrame.wrap_label(reason, 15, UiKit.MUTED))

	if rank > 0 and GameState.is_assignable(s):
		_detail.add_child(UiKit.label("장착 슬롯", 16, UiKit.MUTED, true))
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		row.add_theme_constant_override("v_separation", 8)
		_detail.add_child(row)
		for i in 5:
			var b := UiKit.button("주" if i == 0 else str(i), 20)
			b.set_meta("gamepad_key", "assign:%s:%d" % [_selected, i])
			b.custom_minimum_size = Vector2(64, 68)
			if GameState.slots[i] == _selected:
				UiKit.style_button(b, false, true)
			var index := i
			b.pressed.connect(func():
				if GameState.slots[index] == _selected:
					GameState.clear_slot(index)
				else:
					GameState.assign_slot(index, _selected)
				_refresh())
			row.add_child(b)
		_detail.add_child(PanelFrame.wrap_label("같은 버튼을 다시 누르면 해제합니다", 15, UiKit.MUTED))

	_fit_detail_type()


func _fit_detail_type() -> void:
	if _detail == null:
		return
	for node in _detail.find_children("*", "Control", true, false):
		var control := node as Control
		if not (control is Label or control is Button):
			continue
		if not control.has_meta("woodland_base_font"):
			control.set_meta("woodland_base_font", control.get_theme_font_size("font_size"))
		var minimum := ceili((16.0 if control is Button else 14.0) * graph_css_scale())
		var pixels := maxi(int(control.get_meta("woodland_base_font")), minimum)
		# The shared frame may fit its widgets after this custom tree has fitted.
		# Preserve this tree's measured minimum through that later pass as well.
		control.set_meta("ui_font_base", pixels)
		if control.get_theme_font_size("font_size") != pixels:
			control.add_theme_font_size_override("font_size", pixels)
		if control is Label:
			var label := control as Label
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		elif control is Button:
			var button := control as Button
			if not button.has_meta("woodland_base_minimum"):
				button.set_meta("woodland_base_minimum", button.custom_minimum_size)
			var original: Vector2 = button.get_meta("woodland_base_minimum")
			# Containers align child rectangles to whole logical pixels. Round up
			# before layout so a fractional 56dp target cannot become 55.9dp.
			var touch := ceilf(UiKit.ACTION_TOUCH_DP * graph_css_scale())
			button.custom_minimum_size = Vector2(maxf(original.x, touch), maxf(original.y, touch))
			button.clip_text = false
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
			button.tooltip_text = button.text


func _add_effect_line(title: String, text: String, color: Color) -> void:
	if text == "":
		return
	var l := UiKit.label("%s: %s" % [title, text], 16, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(160, 0)
	_detail.add_child(l)


func _rebuild_pad_nodes() -> void:
	for old: Node in _pad_nodes.values():
		old.queue_free()
	_pad_nodes.clear()
	for slot: Array in _tab_slots(_tab):
		var id: String = slot[0]
		var button := Button.new()
		button.name = "Skill_" + id
		button.set_meta("gamepad_key", "skill:" + id)
		button.tooltip_text = str(GameState.skill(id)["name"])
		button.flat = true
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_ALL
		button.set_meta("gamepad_target", true)
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.position = (_nodes[id] as Rect2).position
		button.size = (_nodes[id] as Rect2).size
		button.focus_entered.connect(func():
			_selected = id
			_tree.queue_redraw()
			_build_detail())
		button.pressed.connect(func():
			_selected = id
			_build_detail()
			_focus_detail.call_deferred())
		_tree.add_child(button)
		_pad_nodes[id] = button


func _focus_detail() -> void:
	for child: Node in _detail.find_children("*", "Button", true, false):
		var button := child as Button
		if not button.is_queued_for_deletion() and not button.disabled:
			button.grab_focus()
			var parent := button.get_parent()
			while parent != null and parent != self:
				if parent is ScrollContainer:
					(parent as ScrollContainer).ensure_control_visible(button)
				parent = parent.get_parent()
			return


func gamepad_back() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and _detail.is_ancestor_of(focus) and _pad_nodes.has(_selected):
		(_pad_nodes[_selected] as Button).grab_focus()
		return true
	return false

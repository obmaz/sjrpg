class_name SkillTreePanel
extends Control
## 스킬 트리 (원본: lib/src/ui/skills_panel.dart · skill_tree.dart · skill_tree_layout.dart).
## Three schools of six level tiers (1·6·12·18·24·30), prerequisite arrows,
## learning with skill points, and equipping to the main / auxiliary slots.

signal closed

const TIERS := [1, 6, 12, 18, 24, 30]

var _tab := 0
var _selected := ""
var _tabs: HBoxContainer
var _tree: Control
var _points: Label
var _detail: VBoxContainer
var _layout_box: BoxContainer
var _nodes := {}  # id -> Rect2 in _tree coordinates


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.06, 0.05, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var title := UiKit.label("%s 스킬" % GameState.class_info()["name"], 28, UiKit.GOLD, true)
	header.add_child(title)
	_points = UiKit.label("", 22, Color(0.8, 1, 0.85), true)
	_points.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_points)
	var reset := UiKit.button("초기화", 18)
	reset.custom_minimum_size = Vector2(100, 44)
	reset.pressed.connect(func():
		if GameState.invested_points() == 0:
			return
		GameState.reset_skills()
		_refresh())
	header.add_child(reset)
	var close := UiKit.button("닫기", 18)
	close.custom_minimum_size = Vector2(100, 44)
	close.pressed.connect(func(): closed.emit())
	header.add_child(close)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	root.add_child(_tabs)

	_layout_box = BoxContainer.new()
	_layout_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_layout_box.add_theme_constant_override("separation", 14)
	root.add_child(_layout_box)

	_tree = Control.new()
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.size_flags_stretch_ratio = 1.6
	_tree.draw.connect(_draw_tree)
	_tree.gui_input.connect(_tree_input)
	_tree.resized.connect(func(): _tree.queue_redraw())
	_layout_box.add_child(_tree)

	var detail_panel := PanelContainer.new()
	detail_panel.add_theme_stylebox_override("panel", UiKit.panel_style())
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_layout_box.add_child(detail_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_panel.add_child(scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	scroll.add_child(_detail)

	get_viewport().size_changed.connect(_fit)
	_fit()
	_selected = GameState.slots[0]
	_tab = _tab_of(_selected)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_T]:
		get_viewport().set_input_as_handled()
		closed.emit()


func _fit() -> void:
	var size := get_viewport_rect().size
	_layout_box.vertical = size.y > size.x


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
	_points.text = "스킬 포인트 %d · Lv.%d" % [GameState.skill_points, GameState.level]
	for child in _tabs.get_children():
		child.queue_free()
	var labels := _tab_labels()
	for i in labels.size():
		var b := UiKit.button(labels[i], 18)
		b.custom_minimum_size = Vector2(120, 42)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i != _tab:
			b.modulate = Color(0.65, 0.65, 0.65)
		var index := i
		b.pressed.connect(func():
			_tab = index
			_refresh())
		_tabs.add_child(b)
	_tree.queue_redraw()
	_build_detail()


# ───────── tree drawing ─────────

func _draw_tree() -> void:
	_nodes.clear()
	var area := _tree.size
	var label_w := 54.0
	var col_w := (area.x - label_w) / 3.0
	var row_h := area.y / 6.0
	var icon := minf(col_w * 0.62, row_h * 0.7)
	var font := UiKit.BOLD_FONT
	for r in 6:
		var y := r * row_h
		_tree.draw_rect(Rect2(0, y + 2, area.x, row_h - 4), Color(1, 1, 1, 0.03 if r % 2 == 0 else 0.06))
		var tier := "Lv.%d" % TIERS[r] if _tab != 3 else ""
		_tree.draw_string(font, Vector2(4, y + row_h / 2.0 + 6), tier, HORIZONTAL_ALIGNMENT_LEFT, label_w, 15, Color(0.8, 0.85, 0.75))
	var slots := _tab_slots(_tab)
	for slot in slots:
		var c := Vector2(label_w + (slot[2] + 0.5) * col_w, (slot[1] + 0.5) * row_h - 8.0)
		_nodes[slot[0]] = Rect2(c - Vector2(icon, icon) / 2.0, Vector2(icon, icon))
	# Prerequisite arrows inside this school.
	for id in _nodes:
		var s := GameState.skill(id)
		for req in s.get("requires", {}):
			if not _nodes.has(req):
				continue
			var from: Rect2 = _nodes[req]
			var to: Rect2 = _nodes[id]
			var met := GameState.rank(req) >= int(s["requires"][req])
			var col := Color(0.96, 0.84, 0.52, 0.9) if met else Color(0.6, 0.6, 0.6, 0.6)
			var a := Vector2(from.get_center().x, from.end.y + 20)
			var b := Vector2(to.get_center().x, to.position.y - 4)
			_tree.draw_line(a, b, col, 3.0, true)
			var dir := (b - a).normalized()
			_tree.draw_colored_polygon(PackedVector2Array([b, b - dir * 12 + dir.orthogonal() * 7, b - dir * 12 - dir.orthogonal() * 7]), col)
	for id in _nodes:
		var rect: Rect2 = _nodes[id]
		var s := GameState.skill(id)
		var rank := GameState.rank(id)
		var learnable := GameState.learn_block_reason(s) == ""
		var tint := Color.WHITE if rank > 0 else (Color(0.75, 0.75, 0.75) if learnable else Color(0.35, 0.35, 0.38))
		SkillIcons.draw(_tree, id, rect, tint)
		var border := Color(0.96, 0.84, 0.52) if rank > 0 else Color(0.4, 0.45, 0.42)
		if learnable:
			border = Color(0.5, 1.0, 0.55)
		_tree.draw_rect(rect, border, false, 4.0 if id == _selected else 2.0)
		if id == _selected:
			_tree.draw_rect(rect.grow(5), Color(1, 1, 1, 0.9), false, 2.0)
		var badge := "%d/%d" % [rank, int(s["limit"])]
		var bpos := rect.position + Vector2(0, rect.size.y + 15)
		_tree.draw_string_outline(font, bpos, badge, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 14, 4, Color(0, 0, 0, 0.9))
		_tree.draw_string(font, bpos, badge, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 14, Color.WHITE if rank > 0 else Color(0.7, 0.7, 0.7))
		if s["passive"] and not s["basic"]:
			_tree.draw_string(font, rect.position + Vector2(3, 14), "P", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 1, 0.8))
		var slot_index: int = GameState.slots.find(id)
		if slot_index >= 0:
			var tag := "주" if slot_index == 0 else str(slot_index)
			_tree.draw_circle(rect.end - Vector2(4, rect.size.y - 4), 11, Color(0.96, 0.84, 0.52))
			_tree.draw_string(font, rect.end - Vector2(15, rect.size.y - 9), tag, HORIZONTAL_ALIGNMENT_CENTER, 22, 13, UiKit.INK)


func _tree_input(event: InputEvent) -> void:
	var pressed: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if not pressed:
		return
	for id in _nodes:
		if (_nodes[id] as Rect2).grow(10).has_point(event.position):
			_selected = id
			_tree.queue_redraw()
			_build_detail()
			_tree.accept_event()
			return


# ───────── detail panel ─────────

func _build_detail() -> void:
	for child in _detail.get_children():
		child.queue_free()
	if _selected == "" or GameState.skill(_selected).is_empty():
		_detail.add_child(UiKit.label("기술을 눌러 정보를 확인하세요", 18))
		return
	var s := GameState.skill(_selected)
	var rank := GameState.rank(_selected)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_detail.add_child(head)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(72, 72)
	var id := _selected
	icon.draw.connect(func(): SkillIcons.draw(icon, id, Rect2(Vector2.ZERO, Vector2(72, 72))))
	head.add_child(icon)
	var names := VBoxContainer.new()
	head.add_child(names)
	names.add_child(UiKit.label(s["name"], 26, UiKit.GOLD, true))
	var kind := "패시브" if s["passive"] and not s["basic"] else ("기본 공격" if s["basic"] else ("이동" if s["mobility"] else "사용 기술"))
	var subtitle := [s["branch"]] if s["branch"] == kind else [s["branch"], kind]
	subtitle.append("%d/%d등급" % [rank, int(s["limit"])])
	names.add_child(UiKit.label(" · ".join(subtitle), 16, Color(0.8, 0.9, 0.85)))

	var desc := UiKit.label(s["desc"], 17)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(240, 0)
	_detail.add_child(desc)

	var info := []
	var shown_rank := maxi(rank, 1)
	if not s["passive"] or s["basic"]:
		var cost := SkillDefs.cost(s, shown_rank)
		info.append("소모 %s %s" % [GameState.class_info()["resource"], HudArt.res(cost)] if cost > 0.0 else "소모 없음")
		if float(s["cooldown"]) > 0.0:
			info.append("재사용 %.1f초" % s["cooldown"])
	info.append("습득 레벨 %d" % GameState.required_level_for_rank(s, rank + 1) if rank < int(s["limit"]) else "최고 등급")
	_detail.add_child(UiKit.label(" · ".join(info), 15, Color(0.85, 0.85, 0.75)))
	if rank > 0:
		_add_effect_line("현재", SkillDefs.describe(_selected, rank), Color(1, 0.95, 0.75))
	if rank < int(s["limit"]):
		_add_effect_line("다음 등급" if rank > 0 else "1등급", SkillDefs.describe(_selected, rank + 1), Color(0.7, 1, 0.75))

	var reason := GameState.learn_block_reason(s)
	var learn := UiKit.button("배우기 (포인트 1)" if rank == 0 else "등급 올리기 (포인트 1)", 20)
	learn.disabled = reason != ""
	if reason != "":
		learn.text = reason
		learn.modulate = Color(0.6, 0.6, 0.6)
	learn.pressed.connect(func():
		if GameState.learn(_selected):
			_refresh())
	_detail.add_child(learn)

	if rank > 0 and GameState.is_assignable(s):
		_detail.add_child(UiKit.label("장착 슬롯", 16, Color(0.8, 0.9, 0.85), true))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_detail.add_child(row)
		for i in 5:
			var b := UiKit.button("주" if i == 0 else str(i), 18)
			b.custom_minimum_size = Vector2(52, 44)
			if GameState.slots[i] == _selected:
				b.modulate = Color(0.6, 1, 0.65)
			var index := i
			b.pressed.connect(func():
				if GameState.slots[index] == _selected:
					GameState.clear_slot(index)
				else:
					GameState.assign_slot(index, _selected)
				_refresh())
			row.add_child(b)
		_detail.add_child(UiKit.label("같은 버튼을 다시 누르면 해제합니다", 13, Color(0.7, 0.75, 0.7)))


func _add_effect_line(title: String, text: String, color: Color) -> void:
	if text == "":
		return
	var l := UiKit.label("%s: %s" % [title, text], 16, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(240, 0)
	_detail.add_child(l)

class_name DungeonHazardHint
extends PanelContainer
## 가까운 장치만 단계/시간을 알려 준다. 터치와 조작 영역을 가로채지 않는다.
var game: Node
var _label: Label
var _last_phase := -1


func setup(source: Node) -> DungeonHazardHint:
	game = source
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_override("font", HudArt.FONT)
	_label.add_theme_font_size_override("font_size", 18)
	add_child(_label)
	visible = false
	return self


func _process(_delta: float) -> void:
	if (
		not game.dungeon.active
		or game.dungeon.hazards == null
		or game.player.dead
		or game.hud.panel_open()
	):
		visible = false
		return
	var trap: DungeonTrap = game.dungeon.hazards.nearest()
	visible = trap != null
	if trap == null:
		return
	var viewport := get_viewport_rect().size
	size = Vector2(minf(420, viewport.x - 32), 42)
	position = Vector2((viewport.x - size.x) * .5, viewport.y * .21)
	_label.text = trap.title() + " · " + trap.detail()
	if _last_phase == trap.phase:
		return
	_last_phase = trap.phase
	var ink := Color("b8c4b8")
	if trap.phase == DungeonTrap.Phase.WARNING:
		ink = Color("e9b867")
	elif trap.phase == DungeonTrap.Phase.ACTIVE:
		ink = Color("ef8673")
	_label.add_theme_color_override("font_color", ink)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(.10, .09, .065, .92)
	panel.border_color = Color(ink, .60)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(5)
	panel.content_margin_left = 10
	panel.content_margin_right = 10
	panel.content_margin_top = 7
	panel.content_margin_bottom = 7
	add_theme_stylebox_override("panel", panel)

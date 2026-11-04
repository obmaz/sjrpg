class_name PanelFrame
extends Control
## Mobile-first panel scaffold shared by 가방 · 스킬 · 설정: dim backdrop, a framed panel
## that fills the phone screen (respecting the safe area) and caps its width on
## wide screens, a header with a big close button, tabs, a scrolling body and a
## footer of 56px+ touch buttons.

signal closed

const MAX_WIDTH := 880.0
const MIN_TOUCH := 64.0
const BOOST := 1.3

var title_label: Label
var subtitle_label: Label
var trailing: HBoxContainer
var tab_row: HBoxContainer
var tab_scroll: ScrollContainer
var body_holder: Control
var scroll: ScrollContainer
var body: VBoxContainer
var footer: HBoxContainer
var _panel: PanelContainer
var _tab_buttons: Array[Button] = []
var _on_tab: Callable


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	UiKit.boost = 1.0
	for panel in get_tree().get_nodes_in_group("panel_frames"):
		if panel != self and not panel.is_queued_for_deletion():
			UiKit.boost = BOOST
			break


func _ready() -> void:
	add_to_group("panel_frames")
	UiKit.boost = BOOST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.04, 0.04, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.035, 0.09, 0.09, 0.97), UiKit.GOLD, 18))
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	header.add_child(titles)
	title_label = UiKit.label("", 30, UiKit.GOLD, true)
	titles.add_child(title_label)
	subtitle_label = UiKit.label("", 17, Color(0.72, 0.85, 0.8))
	titles.add_child(subtitle_label)
	trailing = HBoxContainer.new()
	trailing.add_theme_constant_override("separation", 8)
	header.add_child(trailing)
	var close := UiKit.button("닫기", 19)
	close.custom_minimum_size = Vector2(MIN_TOUCH + 36.0, MIN_TOUCH)
	close.pressed.connect(func(): closed.emit())
	header.add_child(close)

	tab_scroll = ScrollContainer.new()
	tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_scroll.scroll_deadzone = 10
	tab_scroll.visible = false
	column.add_child(tab_scroll)
	tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	tab_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_scroll.add_child(tab_row)

	body_holder = Control.new()
	body_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_holder.clip_contents = true
	column.add_child(body_holder)
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 14
	body_holder.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)

	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	column.add_child(footer)

	get_viewport().size_changed.connect(_layout)
	_layout()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		closed.emit()


## Safe-area margins in viewport units (notches, rounded corners, gesture bars).
static func safe_margins(viewport: Viewport) -> Vector4:
	var view := viewport.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	if window.x <= 0.0 or window.y <= 0.0:
		return Vector4(0, 0, 0, 0)
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if safe.size == Vector2.ZERO:
		return Vector4(0, 0, 0, 0)
	var k := view / window
	return Vector4(maxf(0.0, safe.position.x) * k.x, maxf(0.0, safe.position.y) * k.y,
		maxf(0.0, window.x - safe.end.x) * k.x, maxf(0.0, window.y - safe.end.y) * k.y)


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var m := safe_margins(get_viewport())
	var pad := 10.0
	var left := pad + m.x
	var top := pad + m.y
	var right := pad + m.z
	var bottom := pad + m.w
	var width := minf(view.x - left - right, MAX_WIDTH)
	var cx := left + (view.x - left - right) / 2.0
	_panel.position = Vector2(cx - width / 2.0, top)
	_panel.size = Vector2(width, view.y - top - bottom)
	_panel.custom_minimum_size = _panel.size


func is_portrait() -> bool:
	var view := get_viewport().get_visible_rect().size
	return view.y > view.x


func set_header(title: String, subtitle := "") -> void:
	title_label.text = title
	subtitle_label.text = subtitle
	subtitle_label.visible = subtitle != ""


func set_tabs(labels: Array, selected: int, on_select: Callable) -> void:
	_on_tab = on_select
	tab_scroll.visible = labels.size() > 0
	for b in _tab_buttons:
		b.queue_free()
	_tab_buttons.clear()
	for i in labels.size():
		var b := UiKit.button(labels[i], 20)
		b.custom_minimum_size = Vector2(maxf(104.0, labels[i].length() * 30.0 + 34.0), MIN_TOUCH)
		if i != selected:
			b.modulate = Color(0.62, 0.66, 0.64)
		var index := i
		b.pressed.connect(func(): _on_tab.call(index))
		tab_row.add_child(b)
		_tab_buttons.append(b)


func clear_body() -> void:
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()


func add_footer(text: String, on_press: Callable, primary := false, weight := 1.0) -> Button:
	var b := UiKit.button(text, 22)
	b.custom_minimum_size = Vector2(0, MIN_TOUCH + 10.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_stretch_ratio = weight
	if not primary:
		b.modulate = Color(0.82, 0.86, 0.84)
	b.pressed.connect(on_press)
	footer.add_child(b)
	return b


## A tappable full-width section label.
static func section(text: String) -> Label:
	var l := UiKit.label(text, 19, Color(0.76, 0.9, 0.82), true)
	return l


static func wrap_label(text: String, size := 18, color := Color(0.93, 0.93, 0.88)) -> Label:
	var l := UiKit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(120, 0)
	return l

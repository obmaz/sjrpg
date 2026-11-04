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
var _trim: FrameTrim
var _tab_buttons: Array[Button] = []
var _on_tab: Callable
var compact := false


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
	dim.color = Color(0.018, 0.017, 0.014, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_panel = PanelContainer.new()
	var surface := UiKit.panel_style(Color("1c1b18"), Color("8c7653"), 10)
	surface.raised = true
	surface.content_margin_left = 24
	surface.content_margin_right = 24
	surface.content_margin_top = 26
	surface.content_margin_bottom = 26
	surface.shadow_color = Color(0, 0, 0, 0.32)
	surface.shadow_size = 18
	_panel.add_theme_stylebox_override("panel", surface)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	_panel.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	header.add_child(titles)
	title_label = UiKit.label("", 28, UiKit.TEXT, true)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.custom_minimum_size.x = 120
	titles.add_child(title_label)
	subtitle_label = UiKit.label("", 16, UiKit.MUTED)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(subtitle_label)
	trailing = HBoxContainer.new()
	trailing.add_theme_constant_override("separation", 8)
	header.add_child(trailing)
	var close := UiKit.button("×", 30)
	close.tooltip_text = "모험으로 돌아가기"
	close.custom_minimum_size = Vector2(MIN_TOUCH, MIN_TOUCH)
	for state in ["normal", "hover", "pressed", "focus"]:
		var coin := UiKit.panel_style(Color("211e18"), Color("a18a60") if state != "pressed" else Color("6d5c40"), 32)
		coin.raised = true
		coin.content_margin_left = 0
		coin.content_margin_right = 0
		coin.content_margin_top = 0
		coin.content_margin_bottom = 0
		close.add_theme_stylebox_override(state, coin)
	close.pressed.connect(func(): closed.emit())
	header.add_child(close)
	column.add_child(UiKit.divider())

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
	body.add_theme_constant_override("separation", 16)
	scroll.add_child(body)
	body.minimum_size_changed.connect(func():
		if compact:
			_layout.call_deferred())

	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	column.add_child(footer)

	_trim = FrameTrim.new()
	_trim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_trim)
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
	var pad := 18.0 if view.y > view.x else 28.0
	var left := pad + m.x
	var top := pad + m.y
	var right := pad + m.z
	var bottom := pad + m.w
	var width := minf(view.x - left - right, MAX_WIDTH)
	var cx := left + (view.x - left - right) / 2.0
	var height := view.y - top - bottom
	if compact and body != null:
		height = minf(height, maxf(380.0, body.get_combined_minimum_size().y + 270.0))
	_panel.custom_minimum_size = Vector2.ZERO
	_panel.position = Vector2(cx - width / 2.0, top + (view.y - top - bottom - height) / 2.0)
	_panel.size = Vector2(width, height)
	if _trim != null:
		_trim.position = _panel.position
		_trim.size = _panel.size
		_trim.queue_redraw()


func set_compact() -> void:
	compact = true
	_layout.call_deferred()


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
		UiKit.style_button(b, false, i == selected)
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
	UiKit.style_button(b, primary)
	b.pressed.connect(on_press)
	footer.add_child(b)
	return b


## A tappable full-width section label.
static func section(text: String) -> Label:
	var l := UiKit.label(text, 19, UiKit.GOLD, true)
	return l


static func wrap_label(text: String, size := 18, color := UiKit.TEXT) -> Label:
	var l := UiKit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(120, 0)
	return l


## Small corner brackets and rivets connect menu frames to the HUD's bronze medallions.
class FrameTrim:
	extends Control

	func _draw() -> void:
		var dark := Color("28231a")
		var gold := Color("aa9061")
		for x in [false, true]:
			for y in [false, true]:
				var corner := Vector2(size.x - 8 if x else 8, size.y - 8 if y else 8)
				var inward := Vector2(-1 if x else 1, -1 if y else 1)
				var points := PackedVector2Array([
					corner + Vector2(26 * inward.x, 0), corner + Vector2(9 * inward.x, 0),
					corner + Vector2(0, 9 * inward.y), corner + Vector2(0, 26 * inward.y)])
				draw_polyline(points, dark, 4.0, true)
				draw_polyline(points, Color(gold, 0.72), 1.0, true)
				var rivet := corner + inward * 5
				draw_circle(rivet, 2.4, Color("0f0e0b"))
				draw_circle(rivet - Vector2(0.4, 0.6), 1.3, gold)
		var c := Vector2(size.x * 0.5, 2)
		for i in [-1, 0, 1]:
			var at := c + Vector2(i * 12, 0)
			var diamond := PackedVector2Array([at + Vector2(0, -3), at + Vector2(3, 0), at + Vector2(0, 3), at + Vector2(-3, 0)])
			draw_colored_polygon(diamond, Color(gold, 0.95 if i == 0 else 0.5))

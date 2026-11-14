class_name PanelFrame
extends Control
## Mobile-first panel scaffold shared by 가방 · 스킬 · 설정: dim backdrop, a framed panel
## that fills the phone screen (respecting the safe area) and caps its width on
## wide screens, a header with a big close button, tabs, a scrolling body and a
## footer of 64px+ touch buttons.

signal closed

const MAX_WIDTH := 880.0
const MIN_TOUCH := 64.0
const BOOST := 1.3
const TITLE_GAP := 10
const CARD_TEXT_GAP := 8

var title_label: Label
var subtitle_label: Label
var trailing: HBoxContainer
var tab_row: HBoxContainer
var tab_scroll: ScrollContainer
var body_holder: Control
var scroll: ScrollContainer
var body: VBoxContainer
var footer: BoxContainer
var _panel: PanelContainer
var _column: VBoxContainer
var _header: HBoxContainer
var _titles: VBoxContainer
var _close: Button
var _sizing := false
var _layout_pending := false
var _tab_buttons: Array[Button] = []
var _on_tab: Callable
var compact := false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	_layout_pending = false
	UiKit.boost = 1.0
	for panel in get_tree().get_nodes_in_group("panel_frames"):
		if panel != self and not panel.is_queued_for_deletion():
			UiKit.boost = BOOST
			break


func _ready() -> void:
	get_tree().node_added.connect(_prepare_scroll_button)
	add_to_group("panel_frames")
	UiKit.boost = BOOST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.018, 0.017, 0.014, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_panel = PanelContainer.new()
	var surface := UiKit.frame_style()
	surface.content_margin_left = 24
	surface.content_margin_right = 24
	surface.content_margin_top = 24
	surface.content_margin_bottom = 24
	_panel.add_theme_stylebox_override("panel", surface)
	add_child(_panel)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 18)
	_panel.add_child(_column)

	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 16)
	_column.add_child(_header)
	_titles = VBoxContainer.new()
	var titles := _titles
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.add_theme_constant_override("separation", TITLE_GAP)
	_header.add_child(titles)
	title_label = UiKit.label("", 28, UiKit.TEXT, true)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.custom_minimum_size.x = 120
	titles.add_child(title_label)
	subtitle_label = UiKit.label("", 16, UiKit.MUTED)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_constant_override("line_spacing", 4)
	titles.add_child(subtitle_label)
	trailing = HBoxContainer.new()
	trailing.add_theme_constant_override("separation", 8)
	trailing.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_header.add_child(trailing)
	var close := UiKit.button("×", 30)
	_close = close
	close.tooltip_text = "모험으로 돌아가기"
	UiKit.style_button(close, false, false, true)
	close.custom_minimum_size = Vector2(MIN_TOUCH, MIN_TOUCH)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func(): closed.emit())
	_header.add_child(close)
	_column.add_child(UiKit.divider())

	tab_scroll = ScrollContainer.new()
	tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_scroll.scroll_deadzone = 10
	tab_scroll.visible = false
	_column.add_child(tab_scroll)
	tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	tab_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_scroll.add_child(tab_row)

	body_holder = Control.new()
	body_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_holder.clip_contents = true
	_column.add_child(body_holder)
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 14
	scroll.follow_focus = true
	body_holder.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	scroll.add_child(body)
	body.minimum_size_changed.connect(func():
		if compact:
			_request_layout())

	footer = BoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	_column.add_child(footer)
	_column.minimum_size_changed.connect(_request_layout)

	get_viewport().size_changed.connect(_request_layout)
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


## 한 번의 목록 구성에서 생긴 node/minimum-size 신호는 한 배치로 측정한다.
func _request_layout() -> void:
	if _layout_pending or not is_inside_tree() or is_queued_for_deletion():
		return
	_layout_pending = true
	_flush_layout.call_deferred()


func _flush_layout() -> void:
	if not _layout_pending:
		return
	_layout_pending = false
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_layout()


## 두 작업 영역을 가진 패널만 필요한 폭을 명시한다. 일반 목록은 기존 폭을 유지한다.
func frame_max_width() -> float:
	return MAX_WIDTH


## 공통 프레임과 패널 고유의 그림·터치가 동일한 표시 배율을 사용한다.
func display_pixel_scale() -> float:
	return UiMetrics.units_per_display_pixel(get_viewport())


func _layout() -> void:
	if _sizing or not is_instance_valid(footer):
		return
	_sizing = true
	var scale := display_pixel_scale()
	_fit_widgets(self, scale)
	var view := get_viewport().get_visible_rect().size
	var m := safe_margins(get_viewport())
	var pad := maxf(12.0, 8.0 * scale)
	var inside := 34.0 * scale
	var surface := _panel.get_theme_stylebox("panel")
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		if not is_equal_approx(surface.get_content_margin(side), inside):
			surface.set_content_margin(side, inside)
	_set_separation(_column, roundi(maxf(18.0, 9.0 * scale)))
	_set_separation(_titles, roundi(maxf(TITLE_GAP, 5.0 * scale)))
	_close.custom_minimum_size = Vector2.ONE * maxf(MIN_TOUCH, ceilf(44.0 * scale))
	var left := pad + m.x
	var top := pad + m.y
	var right := pad + m.z
	var bottom := pad + m.w
	var width := minf(view.x - left - right, frame_max_width())
	var cx := left + (view.x - left - right) / 2.0
	var height := view.y - top - bottom
	trailing.visible = trailing.get_children().any(func(child: Node): return not child.is_queued_for_deletion())
	# Long action labels stack instead of forcing the frame beyond the safe area.
	var footer_width := 0.0
	var actions := 0
	for action in footer.get_children():
		if action is Control and action.visible and not action.is_queued_for_deletion():
			footer_width += action.get_combined_minimum_size().x
			actions += 1
	footer_width += maxf(0.0, actions - 1) * footer.get_theme_constant("separation")
	footer.vertical = footer_width > width - surface.get_content_margin(SIDE_LEFT) - surface.get_content_margin(SIDE_RIGHT)
	if compact and body != null:
		# Measure actual chrome so wrapped subtitles/tabs cannot steal the body space.
		var chrome := surface.get_content_margin(SIDE_TOP) + surface.get_content_margin(SIDE_BOTTOM)
		chrome += _column.get_combined_minimum_size().y - body_holder.get_combined_minimum_size().y
		height = minf(height, chrome + maxf(96.0, body.get_combined_minimum_size().y))
	_panel.custom_minimum_size = Vector2.ZERO
	_panel.position = Vector2(cx - width / 2.0, top + (view.y - top - bottom - height) / 2.0)
	_panel.size = Vector2(width, height)
	_sizing = false


func set_compact() -> void:
	compact = true
	_request_layout()


func set_header(title: String, subtitle := "") -> void:
	title_label.text = title
	subtitle_label.text = subtitle
	subtitle_label.visible = subtitle != ""
	_request_layout()


func set_tabs(labels: Array, selected: int, on_select: Callable) -> void:
	_on_tab = on_select
	tab_scroll.visible = labels.size() > 0
	for b in _tab_buttons:
		b.queue_free()
	_tab_buttons.clear()
	for i in labels.size():
		var b := UiKit.button(labels[i], 20)
		b.custom_minimum_size = Vector2(maxf(104.0, labels[i].length() * 30.0 + 34.0), MIN_TOUCH)
		UiKit.style_button(b, false, i == selected, true)
		var index := i
		b.pressed.connect(func(): _on_tab.call(index))
		tab_row.add_child(b)
		_tab_buttons.append(b)
	_request_layout()


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
	_request_layout()
	return b


## A tappable full-width section label.
static func section(text: String) -> Label:
	var l := UiKit.label(text, 19, UiKit.GOLD, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func wrap_label(text: String, size := 18, color := UiKit.TEXT) -> Label:
	var l := UiKit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(120, 0)
	return l


## UiKit 기본 서체를 dp 최소값으로 올리되 원래 크기를 보존해 회전 후에도 복원한다.
func _fit_widgets(node: Node, scale: float) -> void:
	if node is Control and node.has_meta("ui_font_base"):
		var control := node as Control
		var preferred: int = control.get_meta("ui_font_base")
		var font_size := maxi(preferred, ceili(14.0 * scale))
		if control.get_theme_font_size("font_size") != font_size:
			control.add_theme_font_size_override("font_size", font_size)
		if control is Button and control.has_meta("ui_touch"):
			if not control.has_meta("ui_min_height"):
				control.set_meta("ui_min_height", control.custom_minimum_size.y)
			var minimum: float = control.get_meta("ui_min_height")
			control.custom_minimum_size.y = maxf(minimum, ceilf(44.0 * scale))
	if node is Control:
		UiKit.fit_generated(node as Control, scale)
	for child: Node in node.get_children():
		_fit_widgets(child, scale)


func _set_separation(box: BoxContainer, value: int) -> void:
	if box.get_theme_constant("separation") != value:
		box.add_theme_constant_override("separation", value)

func _prepare_scroll_button(node: Node) -> void:
	ScrollTouchSupport.prepare_button(node, self)
	if is_ancestor_of(node):
		_request_layout()

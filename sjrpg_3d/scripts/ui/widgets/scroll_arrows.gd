class_name ScrollArrows
extends Control
## 실제 스크롤 값으로 남은 방향을 표시한다. 장식은 터치를 가로채지 않는다.

const ARROW := preload("res://assets/ui/woodland_panels/scroll_arrow.png")
const GUTTER_DP := 22.0
var _scroll: ScrollContainer
var _base: StyleBox
var _configuration := Vector3(-1, -1, -1)
var _remaining := Vector4.ZERO
var _frame: PanelFrame
var _backing: StyleBoxFlat


static func prepare(scroll: ScrollContainer) -> void:
	if scroll.has_meta("scroll_arrows_pending"):
		return
	scroll.set_meta("scroll_arrows_pending", true)
	_attach_valid.bind(weakref(scroll)).call_deferred()


static func _attach_valid(reference: WeakRef) -> void:
	var scroll := reference.get_ref() as ScrollContainer
	if scroll != null and not scroll.is_queued_for_deletion() and scroll.is_inside_tree():
		attach(scroll)


static func attach(scroll: ScrollContainer) -> void:
	if scroll.has_meta("scroll_arrows"):
		return
	scroll.set_meta("scroll_arrows", true)
	var arrows := ScrollArrows.new()
	arrows._scroll = scroll
	arrows.top_level = true
	arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrows.process_mode = Node.PROCESS_MODE_ALWAYS
	scroll.add_child(arrows, false, Node.INTERNAL_MODE_FRONT)


func _ready() -> void:
	var ancestor := _scroll.get_parent()
	while ancestor != null:
		if ancestor is PanelFrame:
			_frame = ancestor as PanelFrame
			break
		ancestor = ancestor.get_parent()
	_base = _scroll.get_theme_stylebox("panel").duplicate()
	_backing = UiKit.panel_style(Color(0.10, 0.105, 0.11, 0.98), Color.TRANSPARENT, 4)
	_backing.set_border_width_all(0)
	resized.connect(queue_redraw)
	_scroll.visibility_changed.connect(_visibility_changed)
	_visibility_changed()
	_process(0.0)


func _visibility_changed() -> void:
	visible = _scroll.is_visible_in_tree()
	set_process(visible)


func _process(_delta: float) -> void:
	var scale := _frame.display_pixel_scale() if is_instance_valid(_frame) else UiMetrics.units_per_display_pixel(get_viewport())
	var vertical := _scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
	var horizontal := _scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
	if vertical and _scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_SHOW_NEVER:
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	if horizontal and _scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_SHOW_NEVER:
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var configuration := Vector3(scale, float(vertical), float(horizontal))
	if configuration != _configuration:
		_configuration = configuration
		var skin := _base.duplicate()
		# 한 축의 작은 가장자리 공간을 예약해 화살표가 글자·버튼 위에 겹치지 않는다.
		if vertical:
			skin.content_margin_right = _base.get_content_margin(SIDE_RIGHT) + GUTTER_DP * scale
		if horizontal and vertical:
			skin.content_margin_bottom = _base.get_content_margin(SIDE_BOTTOM) + GUTTER_DP * scale
		elif horizontal:
			skin.content_margin_left = _base.get_content_margin(SIDE_LEFT) + GUTTER_DP * scale
			skin.content_margin_right = _base.get_content_margin(SIDE_RIGHT) + GUTTER_DP * scale
		_scroll.add_theme_stylebox_override("panel", skin)
	global_position = _scroll.global_position
	size = _scroll.size
	var v := _scroll.get_v_scroll_bar()
	var h := _scroll.get_h_scroll_bar()
	var remaining := Vector4(float(vertical and v.value > 1.0), float(vertical and v.value < v.max_value - v.page - 1.0),
		float(horizontal and h.value > 1.0), float(horizontal and h.value < h.max_value - h.page - 1.0))
	if remaining != _remaining:
		_remaining = remaining
		queue_redraw()


func _draw() -> void:
	var scale := _configuration.x
	if scale <= 0.0:
		return
	var edge := GUTTER_DP * scale * 0.5
	var half := Vector2(10.0, 6.0) * scale
	for direction: int in 4:
		if _remaining[direction] == 0.0:
			continue
		var center := Vector2(size.x - edge, edge if direction == 0 else size.y - edge)
		var angle := PI if direction == 0 else 0.0
		if direction >= 2:
			center = Vector2(edge if direction == 2 else size.x - edge, size.y - edge if _configuration.y > 0.0 else size.y * 0.5)
			angle = PI * 0.5 if direction == 2 else -PI * 0.5
		# 가로로 잘린 탭의 글자가 화살표 뒤로 비치지 않게 작은 바탕만 가린다.
		draw_style_box(_backing, Rect2(center - Vector2.ONE * edge, Vector2.ONE * edge * 2.0))
		draw_set_transform(center, angle)
		draw_texture_rect(ARROW, Rect2(-half, half * 2.0), false)
	draw_set_transform(Vector2.ZERO)

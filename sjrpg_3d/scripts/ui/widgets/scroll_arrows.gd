class_name ScrollArrows
extends Node2D
## 실제 스크롤 값으로 남은 방향을 표시한다. 장식은 터치를 가로채지 않는다.

const ARROW := preload("res://assets/ui/woodland_panels/scroll_arrow.png")
const EDGE_DP := 10.0
var _scroll: ScrollContainer
var _configuration := Vector3(-1, -1, -1)
var _remaining := Vector4.ZERO
var _frame: PanelFrame
var _size := Vector2.ZERO


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
	# 비-Control 자식은 스크롤 콘텐츠 크기에 참여하지 않고, 상위 클리핑·모달 순서는 유지한다.
	arrows.process_mode = Node.PROCESS_MODE_ALWAYS
	scroll.add_child(arrows, false, Node.INTERNAL_MODE_BACK)


func _ready() -> void:
	var ancestor := _scroll.get_parent()
	while ancestor != null:
		if ancestor is PanelFrame:
			_frame = ancestor as PanelFrame
			break
		ancestor = ancestor.get_parent()
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
		# 비-Control 오버레이만 갱신한다. 콘텐츠 폭·여백은 바꾸지 않는다.
		queue_redraw()
	global_position = _scroll.global_position
	if _size != _scroll.size:
		_size = _scroll.size
		queue_redraw()
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
	var edge := EDGE_DP * scale
	var half := Vector2(8.0, 4.8) * scale
	for direction: int in 4:
		if _remaining[direction] == 0.0:
			continue
		var center := Vector2(_size.x * 0.5, edge if direction == 0 else _size.y - edge)
		var angle := PI if direction == 0 else 0.0
		if direction >= 2:
			center = Vector2(edge if direction == 2 else _size.x - edge, _size.y * 0.5)
			angle = PI * 0.5 if direction == 2 else -PI * 0.5
		draw_set_transform(center, angle)
		draw_texture_rect(ARROW, Rect2(-half, half * 2.0), false)
	draw_set_transform(Vector2.ZERO)

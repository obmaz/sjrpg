class_name LevelUpBanner
extends Control
## A nonblocking celebration on the adventure clock; menus pause it with the world.

const TITLE := "LEVEL UP"
const DURATION := 1.8
var level := 1
var age := 0.0
var active := false
var _first_update := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not active:
		hide()


func show_level(value: int) -> void:
	level = value
	age = 0.0
	active = true
	_first_update = true
	show()
	queue_redraw()


func _process(delta: float) -> void:
	if not active:
		return
	# Present the announcement before consuming a stalled first frame.
	age += minf(delta, 0.06) if _first_update else delta
	_first_update = false
	if age >= DURATION:
		active = false
		hide()
	queue_redraw()


static func banner_rect(view: Vector2, margins := Vector4.ZERO) -> Rect2:
	var safe := Rect2(Vector2(margins.x, margins.y), view - Vector2(margins.x + margins.z, margins.y + margins.w))
	var unit := clampf(minf(safe.size.x / 720.0, safe.size.y / 720.0), 0.5, 1.35)
	var width := minf(safe.size.x - 24.0 * unit, 440.0 * unit)
	var height_fraction := 0.30 if safe.size.y > safe.size.x else 0.16
	return Rect2(Vector2(safe.get_center().x - width * 0.5, safe.position.y + safe.size.y * height_fraction), Vector2(width, 98.0 * unit))


func rise_offset() -> float:
	return 0.0 if Prefs.reduce_motion else -18.0 * clampf(age / DURATION, 0.0, 1.0)


func _draw() -> void:
	if not active:
		return
	var rect := banner_rect(get_viewport_rect().size, PanelFrame.safe_margins(get_viewport()))
	var unit := rect.size.y / 98.0
	rect.position.y += rise_offset() * unit
	var alpha := minf(clampf(age / 0.12, 0.0, 1.0), clampf((DURATION - age) / 0.55, 0.0, 1.0))
	var tint := Color(1.0, 0.90, 0.63, alpha)
	var title_size := roundi(44.0 * unit)
	var subtitle_size := roundi(21.0 * unit)
	var font: Font = UiKit.BOLD_FONT
	var title_width := font.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	var title_at := Vector2(rect.get_center().x - title_width * 0.5, rect.position.y + 46.0 * unit)
	draw_string_outline(font, title_at, TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, maxi(2, roundi(3.0 * unit)), Color(0.09, 0.08, 0.05, alpha * 0.85))
	draw_string(font, title_at, TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, tint)
	var subtitle := "Lv. %d" % level
	var sub_width := font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, subtitle_size).x
	var sub_at := Vector2(rect.get_center().x - sub_width * 0.5, rect.position.y + 78.0 * unit)
	draw_string_outline(font, sub_at, subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, subtitle_size, 2, Color(0.09, 0.08, 0.05, alpha * 0.8))
	draw_string(font, sub_at, subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, subtitle_size, tint)
	for side in [-1.0, 1.0]:
		var start := Vector2(rect.get_center().x + side * (sub_width * 0.5 + 16.0 * unit), sub_at.y - 7.0 * unit)
		draw_line(start, start + Vector2(side * 54.0 * unit, 0), Color(0.88, 0.72, 0.39, alpha * 0.6), unit, true)
		var glint := start + Vector2(side * 62.0 * unit, 0)
		draw_line(glint - Vector2(3, 0) * unit, glint + Vector2(3, 0) * unit, tint, unit, true)
		draw_line(glint - Vector2(0, 3) * unit, glint + Vector2(0, 3) * unit, tint, unit, true)

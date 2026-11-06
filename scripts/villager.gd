class_name Villager
extends Node2D
## Named residents have distinct generated bodies at the same human scale as the hero.

## Hero nominal84 paints roughly117–118worldpixels in the idle atlas.
## Residents use112visiblepixels rather than the miniature legacy74px bodies.
const BODY_HEIGHT := 112.0

var kind := 0
var display_name := ""
var facing := PI / 2.0
var marker: Callable
var hp_ratio: Callable  # 보호 중인 조사관의 체력 막대
var _time := 0.0


func setup(k: int, label: String) -> void:
	kind = k
	display_name = label
	queue_redraw()
	add_to_group("daylight_bodies")


func body_rect() -> Rect2:
	return NpcArt.visible_rect(display_name, BODY_HEIGHT)


func _process(delta: float) -> void:
	_time += delta
	if int(_time * 2.0) != int((_time - delta) * 2.0) or marker.is_valid():
		queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	NpcArt.draw(self, display_name, BODY_HEIGHT, WorldLighting.color_at(global_position))
	var font := UiKit.BOLD_FONT
	var y := -BODY_HEIGHT - 10.0
	if hp_ratio.is_valid():
		var ratio: float = hp_ratio.call()
		if ratio >= 0.0:
			draw_rect(Rect2(-33, y + 8, 66, 9), Color(0, 0, 0, 0.7))
			draw_rect(Rect2(-31, y + 10, 62.0 * clampf(ratio, 0, 1), 5), Color(0.3, 0.85, 0.45))
	if marker.is_valid() and marker.call():
		var bob := 0.0 if Prefs.reduce_motion else sin(_time * 4.0) * 3.0
		draw_circle(Vector2(0, y - 30.0 + bob), 13.0, Color(1.0, 0.82, 0.3))
		draw_string(font, Vector2(-13, y - 23.0 + bob), "!", HORIZONTAL_ALIGNMENT_CENTER, 26, 22, Color(0.2, 0.1, 0.0))
	draw_string_outline(font, Vector2(-70, y), display_name, HORIZONTAL_ALIGNMENT_CENTER, 140, 14, 4, Color(0, 0, 0, 0.85))
	draw_string(font, Vector2(-70, y), display_name, HORIZONTAL_ALIGNMENT_CENTER, 140, 14, Color(1, 0.95, 0.8))

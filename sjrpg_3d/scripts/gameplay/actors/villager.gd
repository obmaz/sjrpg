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
var _hurt_flash := 0.0
var _hurt_presented := false
var _hurt_overlay: BodyFlash


func setup(k: int, label: String) -> void:
	kind = k
	display_name = label
	queue_redraw()
	add_to_group("daylight_bodies")


func body_rect() -> Rect2:
	return NpcArt.visible_rect(display_name, BODY_HEIGHT)


## Only an active protection bar needs extra space; ordinary residents keep their header.
func header_layout() -> Dictionary:
	var ratio: float = hp_ratio.call() if hp_ratio.is_valid() else -1.0
	var name_y := -BODY_HEIGHT - 10.0
	var bar := Rect2()
	if ratio >= 0.0:
		bar = Rect2(-33, body_rect().position.y - 18.0, 66, 9)
		name_y = bar.position.y - UiKit.BOLD_FONT.get_descent(14) - 8.0
	var name_bounds := Rect2(-74, name_y - UiKit.BOLD_FONT.get_ascent(14) - 4.0,
		148, UiKit.BOLD_FONT.get_height(14) + 8.0)
	var marker_y := name_y - 30.0 if ratio < 0.0 else name_bounds.position.y - 22.0
	return {"ratio": ratio, "bar": bar, "name_y": name_y, "name_bounds": name_bounds,
		"marker_y": marker_y, "marker_bounds": Rect2(-13, marker_y - 16.0, 26, 32)}


## One original-silhouette overlay, never parent tint: headers and the ground shadow stay unchanged.
func show_hurt() -> void:
	queue_redraw()
	if _hurt_flash > 0.0:
		return  # Rapid hits cannot extend one flash indefinitely.
	_hurt_flash = 0.35 if Prefs.reduce_motion else 1.0
	_hurt_presented = false
	if _hurt_overlay == null:
		_hurt_overlay = BodyFlash.new()
		_hurt_overlay.label = display_name
		var ink := ShaderMaterial.new()
		ink.shader = ActorSprite.FLASH_SHADER
		ink.set_shader_parameter("flash_color", Color(1.0, 0.45, 0.4).lerp(Color.WHITE, 0.35))
		_hurt_overlay.material = ink
		add_child(_hurt_overlay)
	_sync_hurt()


func _sync_hurt() -> void:
	if _hurt_overlay == null:
		return
	_hurt_overlay.visible = _hurt_flash > 0.0
	var ink := _hurt_overlay.material as ShaderMaterial
	ink.set_shader_parameter("flash_strength", 0.65 * _hurt_flash)
	_hurt_overlay.queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _hurt_flash > 0.0:
		if Prefs.reduce_motion:
			_hurt_flash = minf(_hurt_flash, 0.35)
		var flash_delta := minf(delta, 0.012) if not _hurt_presented and not Prefs.reduce_motion else delta
		_hurt_flash = maxf(0.0, _hurt_flash - flash_delta * 4.0)
		_hurt_presented = true
		_sync_hurt()
	if int(_time * 2.0) != int((_time - delta) * 2.0) or marker.is_valid():
		queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	NpcArt.draw(self, display_name, BODY_HEIGHT, WorldLighting.color_at(global_position))
	var font := UiKit.BOLD_FONT
	var header := header_layout()
	var y: float = header["name_y"]
	var ratio: float = header["ratio"]
	if ratio >= 0.0:
		var bar: Rect2 = header["bar"]
		draw_rect(bar, Color(0, 0, 0, 0.7))
		draw_rect(Rect2(bar.position + Vector2(2, 2), Vector2(62.0 * clampf(ratio, 0, 1), 5)), Color(0.3, 0.85, 0.45))
	if marker.is_valid() and marker.call():
		var bob := 0.0 if Prefs.reduce_motion else sin(_time * 4.0) * 3.0
		var marker_y: float = header["marker_y"]
		draw_circle(Vector2(0, marker_y + bob), 13.0, Color(1.0, 0.82, 0.3))
		draw_string(font, Vector2(-13, marker_y + 7.0 + bob), "!", HORIZONTAL_ALIGNMENT_CENTER, 26, 22, Color(0.2, 0.1, 0.0))
	draw_string_outline(font, Vector2(-70, y), display_name, HORIZONTAL_ALIGNMENT_CENTER, 140, 14, 4, Color(0, 0, 0, 0.85))
	draw_string(font, Vector2(-70, y), display_name, HORIZONTAL_ALIGNMENT_CENTER, 140, 14, Color(1, 0.95, 0.8))


class BodyFlash:
	extends Node2D
	var label := ""

	func _draw() -> void:
		# The exact same NPC atlas frame and sole-registered body quad as the base draw.
		NpcArt.draw(self, label, Villager.BODY_HEIGHT)

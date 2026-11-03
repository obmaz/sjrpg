class_name Villager
extends Node2D
## Town NPC drawn from the original villagers atlas (four kinds, eight bearings).

static var _tex: Texture2D
static var _data: Dictionary

var kind := 0
var display_name := ""
var facing := PI / 2.0
var _time := 0.0


func setup(k: int, label: String) -> void:
	kind = k
	display_name = label
	if _tex == null:
		_tex = load("res://assets/art/actors/villagers.webp")
		_data = JSON.parse_string(FileAccess.open("res://assets/art/actors/villagers.json", FileAccess.READ).get_as_text())


func _process(delta: float) -> void:
	_time += delta
	if int(_time * 2.0) != int((_time - delta) * 2.0):
		queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var phase := int(_time * 2.0) % 2
	var index := kind * 8 + ActorAtlas.facing(facing, 8) + phase * 32
	var f: Array = _data["frames"][index]
	var src := Rect2(f[0], f[1], f[2], f[3])
	var scale := 74.0 / float(_data["sizes"][kind][1])
	var dest := Rect2(Vector2(-src.size.x * scale / 2.0, -src.size.y * scale), src.size * scale)
	draw_texture_rect_region(_tex, dest, src)
	var font := UiKit.BOLD_FONT
	var y := -src.size.y * scale - 10.0
	draw_string_outline(font, Vector2(-70, y), display_name, HORIZONTAL_ALIGNMENT_CENTER, 140, 14, 4, Color(0, 0, 0, 0.85))
	draw_string(font, Vector2(-70, y), display_name, HORIZONTAL_ALIGNMENT_CENTER, 140, 14, Color(1, 0.95, 0.8))

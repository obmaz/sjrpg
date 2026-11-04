class_name CorpseArt
extends Node2D
## One fallen body sorts on the surface where it died; the game owns its lifetime.

const CELLS := {"goblin": 0, "wolf": 1, "boar": 2, "skeleton": 3, "golem": 4}
const LENGTHS := {"goblin": 1.4, "wolf": 1.75, "boar": 1.7, "skeleton": 1.4, "golem": 1.5}
static var _sheet: Texture2D
var corpse: Dictionary


func _draw() -> void:
	draw(self, corpse)


static func opacity(remaining: float, lifetime := 30.0) -> float:
	# Crossfade from the falling actor, then fade out during the last three seconds.
	return clampf((lifetime - remaining) / 0.18, 0.0, 1.0) * clampf(remaining / 3.0, 0.0, 1.0)


static func draw(canvas: Node2D, corpse: Dictionary) -> void:
	var alpha := opacity(float(corpse.get("time", 0.0)), float(corpse.get("lifetime", 30.0)))
	if alpha <= 0.0 or corpse.get("used", false):
		return
	if _sheet == null:
		_sheet = load("res://assets/art/actors/corpses.webp")
	var kind: String = corpse.get("kind", "goblin")
	var cell := int(CELLS.get(kind, 0))
	var width := float(corpse.get("height", 62.0)) * float(LENGTHS.get(kind, 1.4))
	# Reflection selects the other diagonal without tilting a body out of the ground plane.
	var flip := -1.0 if cos(float(corpse.get("facing", 0.0))) > 0.0 else 1.0
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(flip, 1.0))
	canvas.draw_texture_rect_region(_sheet, Rect2(Vector2.ONE * -width * 0.5, Vector2.ONE * width), Rect2(cell * 256, 0, 256, 256), Color(1, 1, 1, alpha))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

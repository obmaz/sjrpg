class_name SkillIcons
extends RefCounted
## Draws skill plaques from the original icon sheets (barbarian/sorceress-skills.webp).

const SHEETS := {
	"warrior": preload("res://assets/art/skills/warrior-skills.webp"),
	"mage": preload("res://assets/art/skills/mage-skills.webp"),
}
## Skills outside the 30-plaque sheets get a lettered medallion.
const FALLBACK := {
	"cleave": ["베", Color(0.75, 0.6, 0.35)],
	"shadowAssault": ["분", Color(0.45, 0.5, 0.85)],
	"battleSprint": ["질", Color(0.4, 0.7, 0.45)],
	"sorceressAttack": ["지", Color(0.55, 0.45, 0.3)],
}


## Draws the icon for `id` into `rect` on any CanvasItem.
static func draw(canvas: CanvasItem, id: String, rect: Rect2, modulate := Color.WHITE) -> void:
	var cls := GameState.hero_class
	var icons: Dictionary = GameState.skill_data()[cls]["icons"]
	if icons.has(id):
		var tex: Texture2D = SHEETS[cls]
		var b: Array = icons[id]
		var size := tex.get_size()
		var src := Rect2(b[0] * size.x, b[1] * size.y, (b[2] - b[0]) * size.x, (b[3] - b[1]) * size.y)
		canvas.draw_texture_rect_region(tex, rect, src, modulate)
		return
	var f: Array = FALLBACK.get(id, ["?", Color(0.4, 0.4, 0.4)])
	var c := rect.get_center()
	var r := minf(rect.size.x, rect.size.y) / 2.0
	canvas.draw_circle(c, r, Color(f[1], modulate.a) * Color(modulate.r, modulate.g, modulate.b))
	canvas.draw_arc(c, r - 2, 0, TAU, 32, Color(0.96, 0.84, 0.52, modulate.a), 3.0, true)
	var fs := int(r * 0.9)
	canvas.draw_string(UiKit.BOLD_FONT, c + Vector2(-r, fs * 0.36), f[0], HORIZONTAL_ALIGNMENT_CENTER, r * 2, fs, Color(1, 1, 1, modulate.a))

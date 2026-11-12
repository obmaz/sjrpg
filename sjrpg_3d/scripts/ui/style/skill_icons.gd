class_name SkillIcons
extends RefCounted
## Original illustrated skill plaques, with real art for skills outside the 30-cell catalogs.

const SHEETS := {
	"warrior": preload("res://assets/ui/skills/warrior-skills.webp"),
	"mage": preload("res://assets/ui/skills/mage-skills.webp"),
}
const BASIC_SWORD := preload("res://assets/ui/hud/reference-buttons.webp")
const COMBAT := preload("res://assets/ui/hud/icons.webp")


## Return normalized texture bounds so square panels and round HUD buttons use the same illustration.
static func source(id: String) -> Dictionary:
	id = AbilityLibrary.icon_id(id)
	var cls := GameState.hero_class
	var icons: Dictionary = GameState.skill_data()[cls]["icons"]
	if icons.has(id):
		var b: Array = icons[id]
		return {"texture": SHEETS[cls], "uv": Rect2(b[0], b[1], b[2] - b[0], b[3] - b[1])}
	match id:
		"cleave":
			return {"texture": BASIC_SWORD, "uv": Rect2(0.0, 0.0, 0.25, 1.0)}
		"shadowAssault":
			return {"texture": COMBAT, "uv": Rect2(6.0 / 1024, 7.0 / 768, 244.0 / 1024, 241.0 / 768)}
		"battleSprint":
			return {"texture": COMBAT, "uv": Rect2(518.0 / 1024, 263.0 / 768, 244.0 / 1024, 242.0 / 768)}
		"sorceressAttack":
			var b: Array = GameState.skill_data()["mage"]["icons"]["lightning"]
			return {"texture": SHEETS["mage"], "uv": Rect2(b[0], b[1], b[2] - b[0], b[3] - b[1])}
	return {"texture": BASIC_SWORD, "uv": Rect2(0.0, 0.0, 0.25, 1.0)}


static func draw(canvas: CanvasItem, id: String, rect: Rect2, modulate := Color.WHITE) -> void:
	var art := source(id)
	var texture: Texture2D = art["texture"]
	var uv: Rect2 = art["uv"]
	canvas.draw_texture_rect_region(texture, rect, Rect2(uv.position * texture.get_size(), uv.size * texture.get_size()), modulate)


## Clip away square plaque corners for the reference's thin circular silver-blue combat bezels.
static func draw_round(canvas: CanvasItem, id: String, center: Vector2, radius: float, modulate := Color.WHITE) -> void:
	var art := source(id)
	var texture: Texture2D = art["texture"]
	var uv: Rect2 = art["uv"]
	var mid := uv.get_center()
	var half := uv.size * 0.42
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in 48:
		var direction := Vector2.from_angle(TAU * i / 48.0)
		points.append(center + direction * radius)
		uvs.append(mid + direction * half)
	canvas.draw_polygon(points, PackedColorArray([modulate]), uvs, texture)

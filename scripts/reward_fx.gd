class_name RewardFx
extends Effect
## Confirmed rewards only: generated gold/level/rare glints, without gameplay state or hitboxes.
## Uses Game._add_effect's cosmetic budget and the same pause clock as the adventure.

static var _atlas: Texture2D
static var _reward_material: CanvasItemMaterial
var _first_update := true
var _diameter := 100.0
var _cell := 0
var _large := false


static func spawn(world_game: Node, at: Vector2, cell := 0, large := false) -> RewardFx:
	var effect := RewardFx.new()
	effect.kind = "reward"
	effect.position = at
	effect.z_index = 6
	effect._cell = clampi(cell, 0, 2)
	effect._large = large
	effect.life = 1.15 if large else 0.7
	effect._diameter = 196.0 if large else (74.0 if cell == 1 else 110.0)
	effect.params["reward_cell"] = effect._cell
	effect.params["large"] = large
	if _reward_material == null:
		_reward_material = CanvasItemMaterial.new()
		_reward_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	effect.material = _reward_material
	world_game._add_effect(effect)
	return effect


func _process(delta: float) -> void:
	# Ensure one visible update even on a slow frame, then expire normally offscreen/headless too.
	var elapsed := minf(delta, life * 0.1) if _first_update else delta
	age += elapsed
	_first_update = false
	if age >= life:
		queue_free()
		return
	if not Prefs.reduce_motion:
		position.y -= (24.0 if _large else 14.0) * elapsed
	queue_redraw()


func _draw() -> void:
	if _atlas == null:
		_atlas = load("res://assets/art/effects/reward-atlas.webp")
	var t := clampf(age / life, 0.0, 1.0)
	var diameter := _diameter * (0.95 if Prefs.reduce_motion else lerpf(0.82, 1.12, t))
	var alpha := pow(1.0 - t, 0.9) * (0.55 if Prefs.reduce_motion else 0.86)
	var cell := Vector2(_atlas.get_width() / 3.0, _atlas.get_height())
	draw_texture_rect_region(_atlas, Rect2(Vector2.ONE * -diameter * 0.5, Vector2.ONE * diameter), Rect2(Vector2(_cell * cell.x, 0), cell), Color(1, 1, 1, alpha))

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
var _anchor := Vector2.ZERO


static func spawn(world_game: Node, at: Vector2, cell := 0, large := false) -> RewardFx:
	var effect := RewardFx.new()
	effect.kind = "reward"
	effect.position = at
	effect.z_index = 6
	effect._cell = clampi(cell, 0, 2)
	effect._large = large
	if large and is_instance_valid(world_game.player):
		effect.owner_node = world_game.player
		effect._anchor = at - effect.owner_node.position
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


static func discover_waypoint(world_game: Node, at: Vector2) -> RewardFx:
	var effect := spawn(world_game, at + Vector2(0, -32), 1, true)
	effect.owner_node = null
	effect.params["waypoint_position"] = at
	effect.life = 1.6
	return effect


func _process(delta: float) -> void:
	# Ensure one visible update even on a slow frame, then expire normally offscreen/headless too.
	var elapsed := minf(delta, life * 0.1) if _first_update else delta
	age += elapsed
	_first_update = false
	if age >= life:
		queue_free()
		return
	if params.has("waypoint_position"):
		pass  # 발견 빛은 이동하는 영웅을 따라가지 않고 표식의 중앙에 남는다.
	elif _large and is_instance_valid(owner_node):
		position = owner_node.position + _anchor
	elif not Prefs.reduce_motion:
		position.y -= 14.0 * elapsed
	queue_redraw()


func _draw() -> void:
	if _atlas == null:
		_atlas = load("res://assets/effects/textures/reward-atlas.webp")
	var t := clampf(age / life, 0.0, 1.0)
	var diameter := _diameter * (0.95 if Prefs.reduce_motion else lerpf(0.82, 1.12, t))
	var alpha := pow(1.0 - t, 0.9) * (0.55 if Prefs.reduce_motion else 0.86)
	var cell := Vector2(_atlas.get_width() / 3.0, _atlas.get_height())
	draw_texture_rect_region(
		_atlas,
		Rect2(Vector2.ONE * -diameter * 0.5, Vector2.ONE * diameter),
		Rect2(Vector2(_cell * cell.x, 0), cell),
		Color(1, 1, 1, alpha)
	)

	if _large:
		# Reuse the generated level glints as a shallow foot halo, following the hero.
		# The body remains readable; no extra effect nodes or gameplay collision.
		var foot := -_anchor if is_instance_valid(owner_node) else Vector2(0, 32)
		var halo_size := Vector2(diameter * 0.95, diameter * 0.32)
		draw_texture_rect_region(
			_atlas,
			Rect2(foot - halo_size * 0.5, halo_size),
			Rect2(Vector2(_cell * cell.x, 0), cell),
			Color(1, 0.93, 0.72, alpha * 0.45)
		)

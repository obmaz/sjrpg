class_name EnemyRenderer3D
extends RefCounted
## 게임 상태를 관찰해 종별 GLB 씬을 표시한다. 물리·AI·피해를 소유하지 않는다.
const KINDS := ["goblin", "wolf", "boar", "skeleton", "golem"]
const CRAWLER := "cave_crawler"
var renderer: Node
var entries := {}
var offscreen := 0


func setup(presenter: Node) -> EnemyRenderer3D:
	renderer = presenter
	return self


static func build(kind: String) -> Dictionary:
	assert(kind in KINDS or kind == CRAWLER)
	return NativeEnemyAssets.build(kind)


static func pose(
	model: Dictionary, facing: float, cycle: float, attack: float, dead := false
) -> void:
	(model["visual"] as NativeEnemyVisual).pose(facing, cycle, attack, dead)


static func cache_stats() -> Dictionary:
	return NativeEnemyAssets.cache_stats()


static func model_kind(enemy: Enemy) -> String:
	return CRAWLER if str(enemy.get_meta("visual_variant", "")) == CRAWLER else enemy.kind


static func corpse_kind(corpse: Dictionary) -> String:
	return (
		CRAWLER
		if str(corpse.get("visual_variant", "")) == CRAWLER
		else str(corpse.get("kind", "goblin"))
	)


static func tint(
	model: Dictionary, color: Color, flash: float, flash_color: Color, alpha: float
) -> void:
	var materials: Array = model["materials"]
	var colors: Array = model["colors"]
	for index in materials.size():
		var material := materials[index] as StandardMaterial3D
		var ink: Color = colors[index] * color
		ink = ink.lerp(flash_color, clampf(flash, 0.0, 0.65))
		ink.a = alpha
		# GLES3 queues a uniform update even when the assigned value is unchanged.
		if material.albedo_color != ink:
			material.albedo_color = ink
		material.transparency = (
			BaseMaterial3D.TRANSPARENCY_ALPHA
			if alpha < 0.999
			else BaseMaterial3D.TRANSPARENCY_DISABLED
		)


static func hit_reaction(model: Dictionary, enemy: Enemy) -> void:
	model["hit_lean"] = 0.0
	if enemy.dead or Prefs.reduce_motion or enemy.hit_reaction_age >= 0.30:
		return
	var root: Node3D = model["root"]
	var direction := WorldSpace3D.projected_to_world(enemy._recoil_direction).normalized()
	var local := root.basis.orthonormalized().inverse() * direction
	var envelope := (
		exp(-10.0 * enemy.hit_reaction_age) * (1.0 - smoothstep(0.16, 0.30, enemy.hit_reaction_age))
	)
	var mass := (
		0.35 if enemy.is_boss or enemy.kind == "golem" else (0.65 if enemy.kind == "boar" else 1.0)
	)
	var strength: float = [0.16, 0.23, 0.32, 0.38][enemy.last_hit_tier] * envelope * mass
	model["hit_lean"] = strength
	var torso: Node3D = model["torso"]
	var lean := Basis.from_euler(Vector3(local.z * strength, 0.0, -local.x * strength))
	var pivot := Vector3(0, float(model["base_height"]) * 0.42, 0)
	var impulse := Transform3D(
		lean, pivot - lean * pivot + Vector3(local.x, -0.025, local.z) * strength * 0.10
	)
	torso.transform = impulse * torso.transform


func sync(delta := 0.0) -> void:
	var live := {}
	var view: Rect2 = renderer.source_view_rect()
	offscreen = 0
	var candidates: Array = renderer.game.enemies.duplicate()
	for entry: Dictionary in entries.values():
		var fading: Node = entry["owner"].get_ref()
		if is_instance_valid(fading) and not candidates.has(fading):
			candidates.append(fading)
	for candidate in candidates:
		if not is_instance_valid(candidate):
			continue
		var enemy := candidate as Enemy
		if enemy == null or enemy.is_queued_for_deletion():
			continue
		var id := enemy.get_instance_id()
		live[id] = true
		if not entries.has(id):
			var model := build(model_kind(enemy))
			model["owner"] = weakref(enemy)
			renderer.stage.add_child(model["root"])
			entries[id] = model
		var model: Dictionary = entries[id]
		var root: Node3D = model["root"]
		# An enemy well outside the camera is neither posed, tinted nor drawn into
		# the shadow map; it is fully refreshed on the frame it comes back.
		if not view.has_point(enemy.position):
			root.visible = false
			offscreen += 1
			continue
		var size := (
			enemy.sprite.body_height
			/ (WorldSpace3D.GROUND_UNITS_PER_METER * Iso.S)
			/ float(model["base_height"])
		)
		# JUICE #4: the 3D body follows the sprite's contact squash (feet stay planted at the root origin).
		var squash := enemy.sprite.squash_scale()
		root.scale = Vector3(size * squash.x, size * squash.y, size * squash.x)
		root.position = (
			renderer.actor_foot(enemy) + WorldSpace3D.projected_to_world(enemy.sprite.position)
		)
		root.visible = enemy.get_parent() == renderer.game.world and enemy.sprite.visible
		var attack := 0.0
		if enemy._state == "windup":
			attack = 0.6 * clampf(1.0 - enemy._timer / enemy._windup_duration, 0.0, 1.0)
		elif enemy._state == "recover":
			attack = (
				0.6
				+ (
					0.4
					* clampf(
						(enemy._recover_duration - enemy._timer) / enemy._recover_visual_duration,
						0.0,
						1.0
					)
				)
			)
		var visual: NativeEnemyVisual = model["visual"]
		var cycle := (
			visual.travel_cycle(enemy._run_distance_m, size)
			if enemy._state == "chase" or (enemy._state == "idle" and enemy._wander != Vector2.ZERO)
			else 0.0
		)
		visual.moving = (
			enemy._state == "chase" or (enemy._state == "idle" and enemy._wander != Vector2.ZERO)
		)
		visual.advance_idle(
			delta,
			(
				enemy.get_tree().paused
				or enemy.sprite.contact_hold > 0.0
				or enemy._hitstop.remaining > 0.0
			)
		)
		pose(model, enemy.facing, cycle, attack)
		hit_reaction(model, enemy)
		tint(
			model,
			enemy.sprite.tint,
			enemy.sprite.flash,
			enemy.sprite.flash_tint,
			enemy.sprite.modulate.a * enemy.sprite.self_modulate.a
		)
	for id in entries.keys():
		if not live.has(id):
			(entries[id]["root"] as Node3D).queue_free()
			entries.erase(id)


func snapshot() -> Dictionary:
	var sources := []
	for model: Dictionary in entries.values():
		var enemy: Enemy = model["owner"].get_ref()
		if not is_instance_valid(enemy):
			continue
		var root: Node3D = model["root"]
		var visual: NativeEnemyVisual = model["visual"]
		var gait: Dictionary = visual.manifest["locomotion"]
		sources.append(
			{
				"kind": model["kind"],
				"model_type": "glb",
				"clip": visual.active_clip,
				"sample_time": visual.sample_time,
				"run_distance_m": enemy._run_distance_m,
				"run_stride_m": float(gait["distance_per_clip_m"]),
				"facing": enemy.facing,
				"visible": root.visible,
				"hit_lean": model.get("hit_lean", 0.0),
				"pivot_error":
				root.position.distance_to(
					(
						renderer.actor_foot(enemy)
						+ WorldSpace3D.projected_to_world(enemy.sprite.position)
					)
				)
			}
		)
	return {"count": entries.size(), "kinds": KINDS, "volume": true, "sources": sources}


static func place_corpse(presenter: Node, model: Dictionary, corpse: Dictionary) -> void:
	var root: Node3D = model["root"]
	var at: Vector2 = corpse.get("pos", Vector2.ZERO)
	var facing: float = float(corpse.get("facing", 0.0))
	var height: float = float(corpse.get("height", 62.0))
	# Query the current floor every time: moved corpses or changed terrain invalidate placement.
	var floor_height: float = presenter.surface_height(at)
	var key: Array = [at, facing, height, floor_height]
	if model.get("_corpse_placement_key", []) != key:
		var ratio: float = (
			height / (WorldSpace3D.GROUND_UNITS_PER_METER * Iso.S) / float(model["base_height"])
		)
		root.scale = Vector3.ONE * ratio
		pose(model, facing, 0.0, 0.0, true)
		root.position = WorldSpace3D.projected_to_world(at, floor_height + 0.012)
		model["_corpse_placement_key"] = key
		model["_corpse_placement_updates"] = int(model.get("_corpse_placement_updates", 0)) + 1
	var opacity := CorpseArt.opacity(
		float(corpse.get("time", 0.0)), float(corpse.get("lifetime", 15.0))
	)
	root.visible = not bool(corpse.get("used", false)) and opacity > 0.0
	tint(model, Color.WHITE, 0.0, Color.WHITE, opacity)

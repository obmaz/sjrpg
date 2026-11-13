extends TestCase
## Actual walking must change skeletal poses, not just report a playing clip.


func _pose_difference(first: Dictionary, second: Dictionary) -> float:
	var maximum := 0.0
	for bone: String in first:
		if not second.has(bone):
			continue
		var a: Array = first[bone]
		var b: Array = second[bone]
		var qa := Quaternion(a[0], a[1], a[2], a[3])
		var qb := Quaternion(b[0], b[1], b[2], b[3])
		maximum = maxf(maximum, qa.angle_to(qb))
	return maximum


func run() -> void:
	var game := await make_game("mage")
	game.inspection = AdventureInspection.create(game, "inspection=1")
	game.inspection.scenes.place_at_chapel()
	game._create_world_renderer()
	await _frames(3)
	var renderer: WorldRenderer3D = game.world_renderer
	var motion: HeroAnimation3D = renderer._hero_animation
	game.player.move_input = Vector2.LEFT
	await _frames(4)
	var position: Vector2 = game.player.position
	var first := motion.bone_pose_sample()
	var phase := motion.sample_time
	await _frames(7)
	var second := motion.bone_pose_sample()
	check("real movement selects the run clip and advances its stride", motion.active_clip.to_lower().contains("run") and motion.sample_time != phase and game.player.position.distance_to(position) > 2.0)
	check("walking really changes thigh/calf skeleton rotations", first.has("thigh_l") and _pose_difference(first, second) > 0.03)
	game.player.move_input = Vector2.ZERO
	await _frames(3)
	game.player.set_process(false)
	motion.sync(game.player, 0.21)
	var idle_phase := motion.sample_time
	var clip: Animation = renderer.animation.get_animation(motion.active_clip)
	motion.sync(game.player, clip.length + 0.32)
	check("idle breathing keeps looping beyond its original clip duration", motion.active_clip.to_lower().contains("idle") and is_equal_approx(motion.sample_time, fposmod(idle_phase + 0.32, clip.length)))
	var held_time := motion.sample_time
	var held_updates := motion.pose_updates
	var held_pose := motion.bone_pose_sample()
	get_tree().paused = true
	motion.sync(game.player, 1.0, true)
	await _frames(2)
	check("paused native animation preserves its actual pose and clock", motion.sample_time == held_time and motion.pose_updates == held_updates and _pose_difference(held_pose, motion.bone_pose_sample()) < 0.001)
	get_tree().paused = false
	game.player.sprite.contact_hold = 0.05
	motion.sync(game.player, 0.3)
	check("contact hold cannot advance native bones", motion.sample_time == held_time and motion.pose_updates == held_updates)
	game.player.sprite.clear_contact_hold()
	game.player._hitstop.remaining = 0.05
	motion.sync(game.player, 0.3)
	check("simulation hit stop also freezes native bones", motion.sample_time == held_time and motion.pose_updates == held_updates)
	game.player._hitstop.remaining = 0.0
	game.queue_free()
	await _frames(2)

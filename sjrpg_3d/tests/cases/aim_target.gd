extends TestCase


func run() -> void:
	var game := await make_game("warrior")
	game.set_process(false)
	game.player.set_process(false)
	var renderer: WorldRenderer3D = game.world_renderer
	renderer.set_process(false)
	var foe := Enemy.new()
	foe.setup(game, "wolf", 1)
	foe.position = game.player.position + Vector2(40, 0)
	game.world.add_child(foe)
	game.enemies.append(foe)
	foe.set_process(false)
	var player: Player = game.player
	player.facing = 0.0
	var facing := player.facing
	var resource := player.resource
	var id: String = GameState.slots[0]
	var predicted := player.aim_target(player.aim_range(id, SkillDefs.get_def(id)))
	renderer._aim_target.sync()
	check(
		"target preview and attack use the same target query",
		predicted == foe and renderer._aim_target.target_id == foe.get_instance_id()
	)
	check(
		"showing the target changes no facing resource or attack",
		player.facing == facing and player.resource == resource and player._attack_time == 0.0
	)
	check(
		"the target ring is grounded and uses no light or collision",
		(
			(
				renderer._aim_target.ring.position.distance_to(
					renderer.actor_foot(foe) + Vector3.UP * 0.055
				)
				< 0.0001
			)
			and (
				renderer
				. _aim_target
				. ring
				. find_children("*", "CollisionObject3D", true, false)
				. is_empty()
			)
		)
	)
	player.cast_slot(0)
	renderer._aim_target.sync()
	check(
		"a committed attack keeps its actual selected target",
		(
			player._aimed_enemy.get_ref() == foe
			and renderer._aim_target.target_id == foe.get_instance_id()
		)
	)
	var reduced := Prefs.reduce_motion
	Prefs.reduce_motion = true
	renderer._aim_target.sync()
	check("reduced motion retains the static target information", renderer._aim_target.ring.visible)
	Prefs.reduce_motion = reduced
	foe.dead = true
	renderer._aim_target.sync()
	check(
		"a dead target cannot keep a stale ring",
		not renderer._aim_target.ring.visible and renderer._aim_target.target_id == 0
	)
	foe.dead = false
	player.warp_locked = true
	renderer._aim_target.sync()
	check("warp hides combat targeting", not renderer._aim_target.ring.visible)
	player.warp_locked = false
	get_tree().paused = true
	renderer._aim_target.sync()
	check("menus and pause hide the ring", not renderer._aim_target.ring.visible)
	get_tree().paused = false
	game.queue_free()
	await _frames(3)

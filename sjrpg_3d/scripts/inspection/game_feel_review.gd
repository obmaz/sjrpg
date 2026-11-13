class_name GameFeelReview
extends Node
## feel_preview=1에서만 실제 터치→예약→실행과 확정 보상을 재현한다.
var game: Node
var foe: Enemy
var _waiting := false
var _serial := 0
var _queued := false
var _warnings := 0


func start(source: Node) -> void:
	game = source
	set_process(false)
	await get_tree().create_timer(1.5, false).timeout
	if game.hud.panel_open():
		game.hud.close_panel(false)
	Prefs.sound_enabled = true
	Prefs.reduce_motion = false
	game.set_process(false)
	game.encounters.set_process(false)
	for enemy: Enemy in game.enemies:
		enemy.queue_free()
	game.enemies.clear()
	game.spatial_world.teleport_source_actor(
		game.player, game.village.point(Vector2(.5, 1.15)), Player.RADIUS
	)
	game.hud.controls.release_all()
	game.player.set_process(false)
	game.player.move_input = Vector2.RIGHT
	for frame in 30:
		game.player._process(1.0 / 60.0)
		await get_tree().physics_frame
	game.player.move_input = Vector2.ZERO
	foe = Enemy.new()
	foe.setup(game, "wolf", 1)
	foe.hp = 100000.0
	foe.max_hp = foe.hp
	foe.position = game.player.position + Vector2(60, 0)
	game.world.add_child(foe)
	game.enemies.append(foe)
	foe.set_process(false)
	for frame in 3:
		await get_tree().physics_frame
	SoundFx._last_warning_ms = -100000
	var before := SoundFx.played_serial
	foe.force_chase()
	foe._process(0.01)
	_warnings = SoundFx.played_serial - before
	game.player.resource = game.player.resource_max
	game.player.cast_slot(0)
	var id: String = GameState.slots[0]
	for frame in 120:
		if (
			maxf(
				game.player._attack_time + game.player._hitstop.remaining,
				game.player.cooldowns.get(id, 0.0)
			)
			<= 0.075
		):
			break
		game.player._process(1.0 / 60.0)
		await get_tree().physics_frame
	_serial = game.player._action_serial
	game.inspection.focus_point = (foe.position + game.player.position) * 0.5
	game.camera.position = game._camera_focus()
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	game.hud._toast_queue.clear()
	game.hud._toast_time = 0.0
	game.hud._toast_plaque.hide()
	game.hud._update_layout()
	game.hud.controls.refresh_layout()
	_waiting = true
	set_process(true)
	_publish(false)


func _process(_delta: float) -> void:
	if _waiting and game.player.action_buffer.slot >= 0:
		_waiting = false
		_queued = true
		set_process(false)
		_finish.call_deferred()


func _finish() -> void:
	for frame in 12:
		game.player._process(1.0 / 60.0)
		await get_tree().physics_frame
		if game.player._action_serial > _serial:
			break
	game.hud.controls.release_all()
	game.grant_xp(5, foe.position)
	game.hud.reward_trail.set_process(false)
	game.hud.reward_trail._process(0.26)
	game.hud.reward_trail.set_process(false)
	_publish(game.player._action_serial == _serial + 1)


func _publish(consumed: bool) -> void:
	var center: Vector2 = game.hud.controls._buttons["slot0"]["center"]
	var view: Vector2 = game.get_viewport_rect().size
	JavaScriptBridge.eval(
		(
			"window.__sjrpgFeelReview = "
			+ JSON.stringify(
				{
					"ready": true,
					"queued": _queued,
					"consumed": consumed,
					"button": [center.x / view.x, center.y / view.y],
					"target": foe.get_instance_id(),
					"warnings": _warnings,
					"foot_contacts": game.player.footsteps.contacts,
					"trail_rect": [game.hud.reward_trail.size.x, game.hud.reward_trail.size.y],
					"reward_flights": game.hud.reward_trail.flights.size()
				}
			)
		)
	)

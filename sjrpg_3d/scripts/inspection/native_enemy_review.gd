class_name NativeEnemyReview
extends RefCounted


## 명시적 검수 쿼리에서만 실제 AI의 준비 또는 회피 접촉 순간을 멈춘다.
static func run(game: Node, kind: String, dodge := false) -> void:
	await game.get_tree().create_timer(1.5, false).timeout
	if not is_instance_valid(game) or game.is_queued_for_deletion():
		return
	if game.hud.panel_open():
		game.hud.close_panel()
	game._spawn_timer = 10000.0
	game.encounters.set_process(false)
	for other: Enemy in game.enemies:
		other.queue_free()
	game.enemies.clear()
	game.spatial_world.teleport_source_actor(
		game.player, game.village.point(Vector2(.5, 1.15)), Player.RADIUS
	)
	game.player.move_input = Vector2.ZERO
	game.player.set_process(false)
	game.hud.controls.release_all()
	var enemy := Enemy.new()
	enemy.setup(game, kind, 1)
	enemy.position = game.player.position + Vector2(60, 0)
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	enemy.set_process(false)
	for frame in 3:
		await game.get_tree().physics_frame
		if not is_instance_valid(game) or game.is_queued_for_deletion():
			return
	enemy.force_chase()
	enemy._process(.01)
	if enemy._state != "windup":
		push_error("Enemy preparation review could not start its actual AI attack")
		return
	var elapsed := enemy._windup_duration * .65
	for step in 8:
		enemy._process(elapsed / 8.0)
		enemy.sprite._process(elapsed / 8.0)
	if dodge:
		var hp: float = game.player.hp
		game.player.move_input = Vector2.UP
		game.player.try_roll()
		game.player._process(.04)
		enemy._process(enemy._timer + .001)
		for effect: Effect in Effect.in_world(game.world):
			if effect.kind in ["text", "nova", "dodge_echo"]:
				effect._process(.08)
		if not game.player._roll_confirmed or game.player.hp != hp:
			push_error("Dodge review failed to avoid an actual AI contact")
			return
		JavaScriptBridge.eval("window.__sjrpgDodgeFeedback = {confirmed:true, mode:'enemy'}")
	else:
		game.player.facing = (enemy.position - game.player.position).angle()
	game.inspection.focus_point = (enemy.position + game.player.position) * .5
	game.camera.position = game._camera_focus()
	game.camera.reset_smoothing()
	# 멈추기 전에 Camera2D의 실제 스크롤도 적용해 이전 마을 화면이 남지 않게 한다.
	game.camera.force_update_scroll()
	game.hud._update_layout()
	game.hud.controls.refresh_layout()
	WorldOcclusion.update(game.player.global_position, false)
	game.hud._toast_plaque.hide()
	game.get_tree().paused = true
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sjrpgEnemyPreparationReady = true")

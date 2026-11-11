class_name NativeChestReview
extends RefCounted


## 명시적 검수 쿼리에서 실제 상자를 타격하고 그 상자의 시계만 진행해 멈춘다.
static func run(game: Node, mode: String) -> void:
	await game.get_tree().create_timer(1.5, false).timeout
	if not is_instance_valid(game) or game.is_queued_for_deletion():
		return
	if game.hud.panel_open():
		game.hud.close_panel()
	game.spatial_world.teleport_source_actor(game.player, game.dungeon.entry_point(), Player.RADIUS)
	if not game.dungeon.enter():
		push_error("Chest response review could not enter the actual cave")
		return
	for enemy: Enemy in game.enemies:
		enemy.set_process(false)
	var target: Chest
	for chest: Chest in game.chests:
		if chest.variant == ("iron" if mode == "hit" else "gold"):
			target = chest
			break
	if target == null:
		push_error("Chest response review has no actual treasure")
		return
	game.spatial_world.teleport_source_actor(
		game.player, target.position + Iso.project(Vector2(0, 150)), Player.RADIUS
	)
	game.player.move_input = Vector2.ZERO
	game.player.set_process(false)
	for frame in 3:
		await game.get_tree().physics_frame
		if not is_instance_valid(game) or game.is_queued_for_deletion():
			return
	if mode != "closed":
		target.take_damage(1, game.player)
		target._process(
			.04 if mode == "hit" else (.08 if mode == "opening" else Chest.OPEN_SECONDS)
		)
		target.set_process(false)
	game._fx_review_focus = target.position
	game.camera.position = game._camera_focus()
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	game.player.facing = (target.position - game.player.position).angle()
	game.hud._update_layout()
	game.hud.controls.refresh_layout()
	game.hud.controls.release_all()
	game.hud._toast_plaque.hide()
	WorldOcclusion.update(game.player.global_position, false)
	game.ortho_preview._encounter_props.sync()
	game.get_tree().paused = true
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			(
				"window.__sjrpgChestResponse = "
				+ JSON.stringify(
					{
						"mode": mode,
						"fraction": target.lid_fraction(),
						"hp": target.hp,
						"dead": target.dead
					}
				)
			)
		)

extends TestCase
## 실제 높은 바닥의 배우 위에 연결된 문자가 지형 뒤쪽 높이를 잘못 읽지 않아야 한다.


func run() -> void:
	var game := await make_game("mage")
	game.set_process(false)
	game.player.set_process(false)
	game.player.position = game.dungeon.entry_point()
	check("text anchor fixture enters the actual cave", game.dungeon.enter())
	for enemy: Enemy in game.enemies:
		enemy.set_process(false)
	await _frames(4)
	var preview: Ortho3DPreview = game.ortho_preview
	preview.set_process(false)
	game.spatial_world.teleport_source_actor(
		game.player, Iso.project(Vector2(1125, -500)), Player.RADIUS
	)
	game.camera.position = game.player.position
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	preview._sync_camera()
	game.float_text(game.player.position + Vector2(0, -90), "연결 표시", Color.WHITE, game.player, 20)
	var text: Effect = game.cosmetic_effects.back()
	preview._sync_cards()
	var label: Label3D = preview._labels[text.get_instance_id()]["node"]
	var foot := preview.actor_foot(game.player)
	var factor := Ortho3DPreview.GROUND_PER_METER * Ortho3DPreview.PROJECTION_FACTOR
	var pixels_per_source := preview.viewport.size.y / preview.camera.size / factor
	var expected: Vector2 = (
		preview.camera.unproject_position(foot)
		+ (text.position - game.player.position) * pixels_per_source
	)
	var actual := preview.camera.unproject_position(label.global_position)
	print("TEXT_ANCHOR_ERROR ", actual.distance_to(expected), " floor=", foot.y)
	check(
		"actor-bound text keeps its intended pixel offset above an elevated foot",
		actual.distance_to(expected) < .1
	)
	game.queue_free()
	await _frames(2)

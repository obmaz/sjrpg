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
	var renderer: WorldRenderer3D = game.world_renderer
	renderer.set_process(false)
	game.spatial_world.teleport_source_actor(
		game.player, Iso.project(Vector2(1125, -500)), Player.RADIUS
	)
	game.camera.position = game.player.position
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	renderer._sync_camera()
	game.float_text(game.player.position + Vector2(0, -90), "연결 표시", Color.WHITE, game.player, 20)
	var text: Effect = game.cosmetic_effects.back()
	renderer._sync_cards()
	var label: Label3D = renderer._labels[text.get_instance_id()]["node"]
	var foot := renderer.actor_foot(game.player)
	var factor := WorldRenderer3D.GROUND_PER_METER * WorldRenderer3D.PROJECTION_FACTOR
	var pixels_per_source := renderer.viewport.size.y / renderer.camera.size / factor
	var expected: Vector2 = (
		renderer.camera.unproject_position(foot)
		+ (text.position - game.player.position) * pixels_per_source
	)
	var actual := renderer.camera.unproject_position(label.global_position)
	print("TEXT_ANCHOR_ERROR ", actual.distance_to(expected), " floor=", foot.y)
	check(
		"actor-bound text keeps its intended pixel offset above an elevated foot",
		actual.distance_to(expected) < .1
	)
	var iron: Chest = game.chests[0]
	var bodies: int = game.spatial_world.actor_bodies.size()
	iron.take_damage(1, game.player)
	text = game.cosmetic_effects.back()
	renderer._sync_cards()
	label = renderer._labels[text.get_instance_id()]["node"]
	var chest_foot := WorldRenderer3D.ground_position(iron.position, DungeonRelief.at(iron.position))
	expected = (
		renderer.camera.unproject_position(chest_foot)
		+ (text.position - iron.position) * pixels_per_source
	)
	actual = renderer.camera.unproject_position(label.global_position)
	print("CHEST_TEXT_ANCHOR_ERROR ", actual.distance_to(expected))
	check(
		"the real first iron chest keeps text above its own floor near the upper ramp",
		actual.distance_to(expected) < .1
	)
	check(
		"grounded prop text never creates an actor body",
		game.spatial_world.actor_bodies.size() == bodies
	)
	game.player.hp -= 20
	game.player.use_potion()
	text = game.cosmetic_effects.back()
	renderer._sync_cards()
	label = renderer._labels[text.get_instance_id()]["node"]
	expected = (
		renderer.camera.unproject_position(foot)
		+ (text.position - game.player.position) * pixels_per_source
	)
	actual = renderer.camera.unproject_position(label.global_position)
	print("POTION_TEXT_ANCHOR_ERROR ", actual.distance_to(expected))
	check(
		"free potion rewards retain their ground anchor without joining damage staggering",
		actual.distance_to(expected) < .1 and is_zero_approx(text.age)
	)
	game.queue_free()
	await _frames(2)

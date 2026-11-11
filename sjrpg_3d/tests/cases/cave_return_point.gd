extends TestCase
## 실제 문 주위 보행·이동·제거와 지도/버튼/완료 보상이 같은 접점을 사용해야 한다.


func _marker(game: Node) -> Dictionary:
	for marker in MapGeometry.markers(game):
		if marker["id"] == "cave:return":
			return marker
	return {}


func run() -> void:
	var game := await make_game("mage")
	game.set_process(false)
	game.player.set_process(false)
	game.player.position = game.dungeon.entry_point()
	check("return interaction fixture enters the actual cave", game.dungeon.enter())
	for enemy: Enemy in game.enemies:
		enemy.set_process(false)
	await _frames(4)
	var cave: DungeonRuntime = game.dungeon
	var portal: Node2D = cave.return_portal()
	var original := portal.position
	var clear := 0
	var all_sides := true
	var formerly_missed := Vector2.INF
	for index in 24:
		var point := original + Vector2.from_angle(TAU * index / 24) * 110
		if (
			not cave.layout.contains(point, Player.RADIUS)
			or game.spatial_world.blocked(point, Player.RADIUS)
		):
			continue
		game.spatial_world.teleport_source_actor(game.player, point, Player.RADIUS)
		clear += 1
		all_sides = all_sides and cave.at_exit() and game.near_npc() == "동굴 출구"
		if game.player.position.distance_to(Iso.project(DungeonLayout.EXIT)) >= 150:
			formerly_missed = game.player.position
	check(
		"every physically clear approach activates the actual portal",
		clear >= 8 and all_sides and formerly_missed != Vector2.INF
	)
	check("map and interaction share the live source node", _marker(game)["pos"] == portal.position)
	game.player.position = original
	portal.position += Vector2(300, 40)
	check(
		"relocating the portal clears the old interaction point",
		not cave.at_exit() and _marker(game)["pos"] == portal.position
	)
	game.player.position = portal.position + Vector2(100, 0)
	check(
		"relocated source enables the matching interaction button",
		cave.at_exit() and game.near_npc() == "동굴 출구"
	)
	game.world.remove_child(portal)
	check(
		"a detached portal leaves no phantom pin or completion point",
		cave.return_portal() == null and not cave.at_exit() and _marker(game).is_empty()
	)
	game.world.add_child(portal)
	portal.position = original
	game.spatial_world.teleport_source_actor(game.player, formerly_missed, Player.RADIUS)
	check(
		"being near the correct portal still requires genuine combat completion",
		cave.at_exit() and not cave.complete()
	)
	for enemy: Enemy in game.enemies.duplicate():
		enemy.take_damage(enemy.hp + 1, null)
	var gold := GameState.gold
	var reward := 100 + cave.entry_level * 20
	check(
		"a formerly missed clear side can claim the actual completion reward",
		cave.complete() and not cave.active and GameState.gold == gold + reward
	)
	gold = GameState.gold
	check(
		"completed instances cannot pay again in the forest",
		(
			not cave.complete()
			and not cave.at_exit()
			and cave.return_portal() == null
			and GameState.gold == gold
		)
	)
	game.player.position = cave.entry_point()
	check(
		"fresh entry restores the actual return source",
		cave.enter() and cave.return_portal() != null
	)
	cave.return_portal().queue_free()
	check(
		"queued removal hides both pin and interaction immediately",
		cave.return_portal() == null and not cave.at_exit() and _marker(game).is_empty()
	)
	game.queue_free()
	await _frames(2)

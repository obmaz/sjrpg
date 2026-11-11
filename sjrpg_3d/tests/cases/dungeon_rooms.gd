extends TestCase
## 출신 방의 진행·지도·중복 사망과 반복 입장 수명을 실제 적 처치로 검증한다.


func run() -> void:
	var game := await make_game("mage")
	game.set_process(false)
	game.player.set_process(false)
	game.player.position = game.dungeon.entry_point()
	check("enter through the real cave interaction", game.dungeon.enter())
	await _frames(4)
	for enemy: Enemy in game.enemies:
		enemy.set_process(false)
	var cave: DungeonRuntime = game.dungeon
	var rooms: DungeonRooms = cave.rooms
	check("room counts follow the registered combatants", rooms.remaining == [3, 4, 4, 5, 6])
	var first: Array[Enemy] = []
	for index in 3:
		first.append(game.enemies[index])
	# 적을 다른 방에서 처치해도 출신 방에 반영한다.
	game.spatial_world.teleport_source_actor(
		first[0], Iso.project(DungeonLayout.ROOMS[4]), first[0].radius, true
	)
	first[0].take_damage(999999, null)
	check(
		"pursuit across rooms retains the original encounter ownership",
		rooms.remaining == [2, 4, 4, 5, 6]
	)
	var gold := GameState.gold
	var defeated := cave.defeated
	cave.on_enemy_killed(first[0])
	check(
		"duplicate death cannot add progress or gold",
		cave.defeated == defeated and GameState.gold == gold
	)
	for index in [1, 2]:
		first[index].take_damage(999999, null)
	check("one cleared room is recorded once", rooms.cleared == 1 and rooms.remaining[0] == 0)
	check(
		"next objective moves to the nearest unfinished room",
		rooms.nearest_remaining(Vector2.ZERO) == 1
	)
	var marker_found := false
	for marker: Dictionary in MapGeometry.markers(game):
		if marker["id"] == "cave:room:0":
			marker_found = (
				marker["pos"] == Iso.project(DungeonLayout.ROOMS[0]) and marker["detail"] == "정리 완료"
			)
	check("map progress uses the actual chamber anchor", marker_found)
	for enemy: Enemy in game.enemies.duplicate():
		enemy.take_damage(999999, null)
	check(
		"every genuine kill unlocks the final return objective",
		(
			rooms.cleared == 5
			and rooms.nearest_remaining(Vector2.ZERO) == -1
			and cave.objective().contains("귀환문")
		)
	)
	check("the return portal still requires actually reaching it", not cave.complete())
	game.hud._toast_queue.clear()
	game.hud._toast_time = 0
	game.hud.toast("현재 동굴 전용 알림", cave._root)
	game.hud.toast("대기 동굴 전용 알림", cave._root)
	cave.leave("밖으로 복귀", false)
	await _frames(3)
	game.hud._tick_toasts(0)
	check("leaving discards room progress", cave.rooms == null)
	check(
		"active and queued cave notices do not escape into the forest",
		game.hud._toast.text == "밖으로 복귀" and game.hud._toast_queue.is_empty()
	)
	game.player.position = cave.entry_point()
	check(
		"reentry creates fresh room progress",
		(
			cave.enter()
			and cave.rooms != rooms
			and cave.rooms.cleared == 0
			and cave.rooms.remaining == [3, 4, 4, 5, 6]
		)
	)
	for view: Vector2 in [Vector2(720, 1280), Vector2(1280, 720)]:
		var extent := Vector2(420, 60)
		var notice := Rect2(view.x * .5 - 250, view.y * .18, 500, 100)
		var banner := LevelUpBanner.banner_rect(view)
		var hint := DungeonHazardHint.fit_rect(view, extent, [notice, banner])
		check(
			"trap countdown avoids both confirmation and level announcements %s" % view,
			(
				not hint.intersects(notice)
				and not hint.intersects(banner)
				and Rect2(Vector2.ZERO, view).encloses(hint)
			)
		)
	game.queue_free()
	await _frames(2)

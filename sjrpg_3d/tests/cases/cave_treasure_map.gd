extends TestCase
## 실제 상자 위치·내구도·개봉·지역 수명이 두 지도의 공통 데이터에 반영되어야 한다.


func _treasures(game: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for marker in MapGeometry.markers(game):
		if str(marker["id"]).begins_with("treasure:"):
			result.append(marker)
	return result


func _for_chest(game: Node, chest: Chest) -> Dictionary:
	var key := "treasure:%s:%d" % [chest.variant, chest.index]
	for marker in _treasures(game):
		if marker["id"] == key:
			return marker
	return {}


func run() -> void:
	var game := await make_game("mage")
	game.set_process(false)
	game.player.set_process(false)
	check("forest treasure does not leak into the cave-only list", _treasures(game).is_empty())
	game.player.position = game.dungeon.entry_point()
	check("treasure review enters the real dungeon", game.dungeon.enter())
	await _frames(4)
	for enemy: Enemy in game.enemies:
		enemy.set_process(false)
	var iron: Chest
	var gold: Chest
	for chest: Chest in game.chests:
		if chest.variant == "iron" and iron == null:
			iron = chest
		elif chest.variant == "gold" and gold == null:
			gold = chest
	if not check("the actual cave contains both treasure types", iron != null and gold != null):
		game.queue_free()
		await _frames(2)
		return
	var markers := _treasures(game)
	check("all five actual unopened cave chests have unique markers", markers.size() == 5)
	var match_positions := true
	for chest: Chest in game.chests:
		var marker := _for_chest(game, chest)
		match_positions = (
			match_positions and not marker.is_empty() and marker["pos"] == chest.position
		)
	check("every chest marker uses its actual live object position", match_positions)
	var iron_marker := _for_chest(game, iron)
	var gold_marker := _for_chest(game, gold)
	check(
		"equipment and supply treasure are named and colored separately",
		(
			iron_marker["color"] != gold_marker["color"]
			and MapGeometry.category(iron_marker) == "보급 보물"
			and MapGeometry.category(gold_marker) == "장비 보물"
			and gold_marker["detail"].contains("적이 나오지 않음")
		)
	)
	gold.position += Vector2(30, 10)
	check(
		"moving a chest moves the marker with the same count",
		_for_chest(game, gold)["pos"] == gold.position and _treasures(game).size() == 5
	)
	var minimap: Minimap = game.hud.minimap
	minimap._sync_retained()
	var all := MapGeometry.markers(game)
	var map_dot_matches := false
	for index in all.size():
		if all[index]["id"] == gold_marker["id"]:
			map_dot_matches = minimap._dots[index].position.is_equal_approx(
				minimap._to_map(gold.position, game.player.position)
			)
	check("the retained minimap consumes the same moved treasure marker", map_dot_matches)
	var mesh := minimap._geometry_mesh
	var terrain := minimap.geometry_rebuilds
	var identities := minimap._dots.duplicate()
	for frame in 20:
		minimap._sync_retained()
	check(
		"idle treasure retains its dot nodes and terrain mesh",
		(
			minimap._dots == identities
			and minimap._geometry_mesh == mesh
			and minimap.geometry_rebuilds == terrain
		)
	)
	iron.take_damage(1, game.player)
	check(
		"iron durability comes from actual damage without opening it",
		_for_chest(game, iron)["detail"].contains("3/4") and _treasures(game).size() == 5
	)
	gold.take_damage(1, game.player)
	check(
		"opening treasure removes it from both maps' common data",
		_for_chest(game, gold).is_empty() and _treasures(game).size() == 4
	)
	iron.queue_free()
	check(
		"a queued object cannot leave a phantom treasure marker",
		_for_chest(game, iron).is_empty() and _treasures(game).size() == 3
	)
	# 실제 제거는 소유 목록에서도 분리한다. 표시기의 정상 수명 계약을 깨지 않는다.
	game.chests.erase(iron)
	await _frames(2)
	game.dungeon.leave("", false)
	check("returning to the forest removes every cave treasure", _treasures(game).is_empty())
	game.player.position = game.dungeon.entry_point()
	check(
		"reentry starts five fresh actual treasure objects",
		game.dungeon.enter() and _treasures(game).size() == 5
	)
	game.queue_free()
	await _frames(2)

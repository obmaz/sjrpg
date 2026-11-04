class_name Exploration
extends Node
## Checkpoints require a physical visit; travel starts only at a quiet discovered sanctuary.

const NAMES := {"town": "숲 마을", "tree": "고목의 쉼터", "cave": "동굴 입구"}
var game: Node

func setup(g: Node) -> Exploration:
	game = g
	return self


func nearby() -> String:
	for id in game.village.sanctuary_points:
		if game.player.position.distance_to(game.village.sanctuary_points[id]) < 150.0:
			return id
	return ""


func _process(delta: float) -> void:
	if game.player.dead:
		return
	var id := nearby()
	if id == "":
		return
	if not GameState.discovered_sanctuaries.has(id):
		GameState.discovered_sanctuaries.append(id)
		game.toast("안식처 발견 · " + NAMES[id])
	if GameState.last_sanctuary != id:
		GameState.last_sanctuary = id
		GameState.save_game()
	if travel_block_reason() == "":
		game.player.hp = minf(game.player.max_hp, game.player.hp + game.player.max_hp * 0.15 * delta)
		game.player.resource = minf(game.player.resource_max, game.player.resource + game.player.resource_max * 0.2 * delta)


func travel_block_reason() -> String:
	if game.player.dead:
		return "쓰러진 동안에는 이동할 수 없습니다."
	if nearby() == "":
		return "안식처 곁에서 이동할 수 있습니다."
	if GameState.boss_summoned and not GameState.boss_defeated:
		return "파수꾼 도전 중에는 이동할 수 없습니다."
	if game.quest_runtime.defender_active():
		return "조사관을 보호하는 동안에는 이동할 수 없습니다."
	for enemy in game.enemies:
		if not enemy.dead and enemy.position.distance_to(game.player.position) < 350.0:
			return "주변 적을 정리한 뒤 이동하세요."
	return ""


func safe_point(id: String) -> Vector2:
	var center: Vector2 = game.village.sanctuary_points.get(id, game.village.spawn_point)
	for radius in [0.0, 40.0, 80.0, 120.0, 160.0]:
		for i in 12:
			var candidate: Vector2 = center + Vector2.from_angle(TAU * i / 12.0) * radius
			var resolved: Vector2 = game.resolve_movement(candidate, candidate, Player.RADIUS)
			if resolved.distance_to(candidate) < 1.0 and not game._blocked(candidate, Player.RADIUS):
				return candidate
	return game.village.spawn_point


func respawn_point() -> Vector2:
	return safe_point(GameState.last_sanctuary)


func travel(destination: String) -> bool:
	if not NAMES.has(destination) or not GameState.discovered_sanctuaries.has(destination) or travel_block_reason() != "":
		return false
	game.player.position = safe_point(destination)
	game.player.move_input = Vector2.ZERO
	game.hud.controls.release_all()
	game.player.refresh_stats(true)
	game.player.resource = game.player.resource_max
	game.camera.position = game.player.position
	game.camera.reset_smoothing()
	GameState.last_sanctuary = destination
	GameState.save_game()
	game.toast("안식처 이동 · " + NAMES[destination])
	return true

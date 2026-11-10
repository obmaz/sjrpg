class_name Exploration
extends Node
## Checkpoints require a physical visit; travel starts at a quiet sanctuary or its warp gate.

const NAMES := {"town": "숲 마을", "tree": "고목의 쉼터", "cave": "동굴 입구"}
const GATE_RANGE := 100.0
var game: Node

func setup(g: Node) -> Exploration:
	game = g
	return self


func nearby() -> String:
	if game.dungeon.active:
		return ""
	for id in game.village.sanctuary_points:
		if game.player.position.distance_to(game.village.sanctuary_points[id]) < 150.0:
			return id
	return ""


func gate_point(id: String) -> Vector2:
	return game.village.portal_points.get(id, Vector2.INF)


func gate_origin() -> String:
	if game.dungeon.active:
		return ""
	for id in NAMES:
		if game.player.position.distance_to(gate_point(id)) < GATE_RANGE:
			if id != "town" and not GameState.discovered_sanctuaries.has(id) and not on_waypoint(id):
				continue
			return id
	return ""


func on_waypoint(id: String) -> bool:
	return (Iso.unproject(game.player.position-gate_point(id))/SpatialWorld3D.UNITS).length() <= NativeWaypoint3D.RADIUS*0.86


func gate_nearby() -> bool:
	return gate_origin() != ""


func current_origin() -> String:
	var gate := gate_origin()
	return gate if gate != "" else nearby()


func discover_current() -> String:
	if game.player.dead:
		return ""
	var id := current_origin()
	if id == "":
		return ""
	if id != "town" and not GameState.discovered_sanctuaries.has(id):
		if not on_waypoint(id):
			return ""
	var changed := false
	if not GameState.discovered_sanctuaries.has(id):
		GameState.discovered_sanctuaries.append(id)
		game.toast(("안식처 발견 · " if id == "town" else "웨이포인트 활성화 · ") + NAMES[id])
		SoundFx.play("warp")
		changed = true
	if GameState.last_sanctuary != id:
		GameState.last_sanctuary = id
		changed = true
	if changed:
		GameState.save_game()
	return id


func _process(delta: float) -> void:
	if discover_current() == "":
		return
	if travel_block_reason() == "":
		game.player.hp = minf(game.player.max_hp, game.player.hp + game.player.max_hp * 0.15 * delta)
		game.player.resource = minf(game.player.resource_max, game.player.resource + game.player.resource_max * 0.2 * delta)


func _origin_block_reason(require_gate: bool) -> String:
	if game.dungeon.active:
		return "동굴 안에서는 워프하거나 안식처로 이동할 수 없습니다."
	if game.player.dead:
		return "쓰러진 동안에는 이동할 수 없습니다."
	if require_gate and not gate_nearby():
		return "워프게이트 곁에서 사용할 수 있습니다."
	if not require_gate and current_origin() == "":
		return "워프게이트나 안식처 곁에서 이동할 수 있습니다."
	var origin := current_origin()
	if origin != "" and origin != "town" and not GameState.discovered_sanctuaries.has(origin) and not on_waypoint(origin):
		return "바닥의 웨이포인트를 밟아 활성화하세요."
	if GameState.boss_summoned and not GameState.boss_defeated:
		return "파수꾼 도전 중에는 이동할 수 없습니다."
	if game.quest_runtime.defender_active():
		return "조사관을 보호하는 동안에는 이동할 수 없습니다."
	for enemy in game.enemies:
		if not enemy.dead and enemy.position.distance_to(game.player.position) < 350.0:
			return "주변 적을 정리한 뒤 이동하세요."
	return ""


func travel_block_reason() -> String:
	return _origin_block_reason(false)


func gate_block_reason() -> String:
	return _origin_block_reason(true)


func destination_block_reason(destination: String, require_gate := false) -> String:
	var reason := _origin_block_reason(require_gate)
	if reason != "":
		return reason
	if not NAMES.has(destination):
		return "이동할 수 없는 목적지입니다."
	if not GameState.discovered_sanctuaries.has(destination):
		return "목적지를 직접 방문해 발견하세요."
	if destination == current_origin():
		return "현재 위치입니다."
	return ""


func _safe_near(center: Vector2, gate_id := "") -> Vector2:
	for radius in [0.0, 24.0, 48.0, 80.0, 120.0, 160.0]:
		for i in 12:
			var candidate: Vector2 = center + Vector2.from_angle(TAU * i / 12.0) * radius
			if gate_id != "" and candidate.distance_to(gate_point(gate_id)) >= GATE_RANGE:
				continue
			var resolved: Vector2 = game.resolve_movement(candidate, candidate, Player.RADIUS)
			if resolved.distance_to(candidate) < 1.0 and not game._blocked(candidate, Player.RADIUS):
				return candidate
	return Vector2.INF


func safe_point(id: String) -> Vector2:
	var center: Vector2 = game.village.sanctuary_points.get(id, game.village.spawn_point)
	var point := _safe_near(center)
	return point if point.is_finite() else game.village.spawn_point


func gate_approach(id := "town") -> Vector2:
	if id != "town":
		return _safe_near(gate_point(id),id)
	# 마을의 수직 성문은 앞쪽으로, 야외 지면 표식은 중앙으로 도착한다.
	return _safe_near(gate_point(id) + Vector2(0, 72), id)


func respawn_point() -> Vector2:
	return safe_point(GameState.last_sanctuary)


func travel(destination: String) -> bool:
	return _move_to(destination, false)


func warp(destination: String) -> bool:
	return _move_to(destination, true)


func _move_to(destination: String, require_gate: bool) -> bool:
	if destination_block_reason(destination, require_gate) != "":
		return false
	var arrival := gate_approach(destination)
	if not arrival.is_finite():
		game.toast("도착 지점이 막혀 이동할 수 없습니다")
		return false
	# A paused destination panel must not preserve a held cast or a delayed melee contact across the map.
	game.player.move_input = Vector2.ZERO
	game.player.held_slots.clear()
	game.player._pending = Callable()
	game.player._attack_time = 0.0
	game.player._roll_time = 0.0
	game.player.sprite.clear_contact_hold()
	game.hud.controls.release_all()
	for action in ["move_left", "move_right", "move_up", "move_down", "attack", "skill"]:
		Input.action_release(action)
	var departure: Vector2 = game.player.position
	RewardFx.spawn(game, departure + Vector2(0, -24), 1)
	game.player.position = arrival
	RewardFx.spawn(game, arrival + Vector2(0, -24), 1)
	game.player.refresh_stats(true)
	game.player.resource = game.player.resource_max
	game.camera.position = game.player.position
	game.camera.offset = Vector2.ZERO
	game._impact_offset = Vector2.ZERO
	game.camera.reset_smoothing()
	GameState.last_sanctuary = destination
	GameState.save_game()
	SoundFx.play("warp")
	Prefs.pulse("dodge")
	game.toast("워프 완료 · " + NAMES[destination])
	return true

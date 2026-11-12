class_name DungeonRuntime
extends Node
## Transient cave space. Persistent loot stays on the hero; rooms and timer never resume after reconnect.

const DURATION := 300.0
var game: Node
var active := false
var remaining := DURATION
var entry_level := 1
var defeated := 0
var total := 0
var layout: DungeonLayout
var hazards: DungeonHazards
var rooms: DungeonRooms
var _hazard_hint: DungeonHazardHint
var art: DungeonArt
var _root: Node2D
var _forest_world: Node2D
var _forest_enemies: Array[Enemy] = []
var _forest_chests: Array[Chest] = []
var _forest_corpses: Array = []
var _forest_shapes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func setup(g: Node) -> DungeonRuntime:
	game = g
	return self


func entry_point() -> Vector2:
	return game.village.quest_sites["sun"] + Vector2(-120, 10)


func enter_block_reason() -> String:
	if active or game.player.dead:
		return "지금은 입장할 수 없습니다."
	if game.player.position.distance_to(entry_point()) > 180.0:
		return "동굴 입구 가까이에서 입장하세요."
	if game.quest_runtime.defender_active():
		return "조사관 보호를 마치거나 다시 준비한 뒤 입장하세요."
	if GameState.boss_summoned and not GameState.boss_defeated:
		return "파수꾼 도전을 마친 뒤 입장하세요."
	return ""


func enter() -> bool:
	if enter_block_reason() != "":
		return false
	_rng.randomize()
	layout = DungeonLayout.new()
	hazards = DungeonHazards.new().setup(game)
	rooms = DungeonRooms.new()
	remaining = DURATION
	entry_level = GameState.level + 2
	defeated = 0
	total = 0
	_forest_world = game.world
	_forest_enemies = game.enemies
	_forest_chests = game.chests
	_forest_corpses = game.corpses
	_forest_shapes = game.map_shapes
	_root = Node2D.new()
	_root.visible = false
	game.scene_root.add_child(_root)
	var world := Node2D.new()
	world.y_sort_enabled = true
	_root.add_child(world)
	game.player.reparent(world, false)
	game.world = world
	var enemies: Array[Enemy] = []
	var chests: Array[Chest] = []
	game.enemies = enemies
	game.chests = chests
	game.corpses = []
	game.map_shapes = [] as Array[Dictionary]
	game.set_forest_rendered(false)
	game.field_root.process_mode = Node.PROCESS_MODE_DISABLED
	game.quest_runtime.set_process(false)
	game.exploration.set_process(false)
	active = true
	_hazard_hint = DungeonHazardHint.new().setup(game)
	game.hud.add_child(_hazard_hint)
	GameState.location_mode = "cave"
	_build_art(world)
	_build_enemies()
	_build_chests()
	# The measured base extends left/back from its foot. Keep it inside the exit
	# chamber's wall lip, beside the incoming route rather than across the cliff.
	var portal: IsoSprite = game.village.create_portal(
		Iso.project(DungeonLayout.EXIT + Vector2(50, -110))
	)
	portal.name = "CaveReturnPortal"
	world.add_child(portal)
	layout.obstacles.append(Village.portal_base(portal))
	game.player._pending = Callable()
	game.player._attack_time = 0.0
	game.player.position = Vector2.ZERO
	game.player.z_index = 0
	game.hud.controls.release_all()
	game.camera.position = game.player.position
	game.camera.reset_smoothing()
	game.hud._update_layout()
	GameState.save_game()
	game.hud.toast("바람 동굴 · 5분 안에 적을 정리하고 마지막 귀환문으로 가세요", _root)
	return true


func _build_art(world: Node2D) -> void:
	# The generated design owns the visible stone; the shared layout still owns movement and maps.
	art = DungeonArt.new().setup(layout, world)
	_root.add_child(art)
	for polygon in layout.polygons:
		game.map_shapes.append(
			{"poly": polygon, "bounds": Iso.poly_bounds(polygon), "color": Color("777970")}
		)


func _build_enemies() -> void:
	for room in DungeonLayout.ROOMS.size():
		var center := Iso.project(DungeonLayout.ROOMS[room])
		for index in DungeonLayout.COUNTS[room]:
			var enemy := Enemy.new()
			var kind: String = ["goblin", "wolf", "boar", "skeleton"][(room + index) % 4]
			enemy.setup(game, kind, entry_level)
			enemy.position = (
				center + Vector2.from_angle(index * TAU / DungeonLayout.COUNTS[room]) * 110.0
			)
			enemy.patrol_center = center
			enemy.patrol_radius = 170.0
			game.world.add_child(enemy)
			game.enemies.append(enemy)
			rooms.register(enemy, room)
			total += 1


func tick(delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)
	hazards.tick(delta)
	if not active:
		return
	game._tick_corpses(delta)
	if remaining <= 0.0:
		leave("시간이 끝나 동굴 입구로 돌아왔습니다")


func on_enemy_killed(enemy: Enemy) -> void:
	if not active or rooms == null:
		return
	var room := rooms.defeat(enemy)
	if room < 0:
		return
	defeated += 1
	GameState.gold += 2 + entry_level
	if _rng.randf() < 0.15:
		var gear := Gear.roll_loot(
			GameState.hero_class, GameState.level, GameState.next_serial, _rng
		)
		if GameState.add_gear(gear):
			game.toast("동굴 전리품 · " + gear.display_name())
		else:
			GameState.gold += gear.sale_value()

	if not game.player.dead:
		if defeated == total:
			game.hud.toast("모든 방 정리 완료 · 마지막 귀환문에서 추가 보상을 받으세요", _root)
		elif rooms.remaining[room] == 0:
			game.hud.toast(
				"%d번 방 정리 완료 · %d/%d개 방" % [room + 1, rooms.cleared, rooms.remaining.size()], _root
			)


func objective() -> String:
	var time := "%d:%02d" % [int(remaining) / 60, int(remaining) % 60]
	if rooms == null:
		return "바람 동굴 · " + time
	var next := rooms.nearest_remaining(game.player.position)
	if next < 0:
		return time + " · 정리 완료 · 귀환문으로"
	return (
		"%s · 정리 %d/%d · %d번 방 적 %d"
		% [time, rooms.cleared, rooms.remaining.size(), next + 1, rooms.remaining[next]]
	)


## 표시·지도·상호작용이 같은 실제 소품을 읽는다. 제거된 문은 빈 좌표로 대체하지 않는다.
func return_portal() -> Node2D:
	if not active:
		return null
	var portal := game.world.get_node_or_null("CaveReturnPortal") as Node2D
	return portal if portal != null and not portal.is_queued_for_deletion() else null


func at_exit() -> bool:
	var portal := return_portal()
	return portal != null and game.player.position.distance_to(portal.position) < 150.0


func complete() -> bool:
	if not active or defeated < total or not at_exit() or remaining <= 0.0:
		return false
	var reward := 100 + entry_level * 20
	GameState.gold += reward
	if game.expedition != null:
		game.expedition.optional_completed("cave")
	leave("동굴 탐험 완료 · 추가 보상 %d G" % reward)
	return true


func leave(message: String, save_progress := true) -> void:
	if not active:
		return
	active = false
	hazards = null
	rooms = null
	if is_instance_valid(_hazard_hint):
		_hazard_hint.queue_free()
	_hazard_hint = null
	for corpse in game.corpses.duplicate():
		game.remove_corpse(corpse)
	game.player.reparent(_forest_world, false)
	game.world = _forest_world
	game.enemies = _forest_enemies
	game.chests = _forest_chests
	game.corpses = _forest_corpses
	game.map_shapes = _forest_shapes
	game.set_forest_rendered(true)
	game.field_root.process_mode = Node.PROCESS_MODE_INHERIT
	game.quest_runtime.set_process(true)
	game.exploration.set_process(true)
	if game.player.dead:
		game.player.revive(entry_point())
	else:
		game.player.position = entry_point()
	game.player._invulnerable = 3.0
	game.player.z_index = 0
	game.player.move_input = Vector2.ZERO
	game.player._pending = Callable()
	game.player._attack_time = 0.0
	game.hud.controls.release_all()
	game.hud.hide_death()
	game.camera.position = game.player.position
	game.camera.reset_smoothing()
	_root.visible = false
	_root.process_mode = Node.PROCESS_MODE_DISABLED
	_root.queue_free()
	_root = null
	art = null
	GameState.location_mode = "forest"
	GameState.return_to_cave_entrance = false
	if save_progress:
		GameState.save_game()
	game.toast(message)


func _build_chests() -> void:
	# 각 방의 구석에 보상을 두고 주 통로와 남북 갈림길의 중심선은 비운다.
	var spots := [
		Vector2(850, -210),
		Vector2(1700, -210),
		Vector2(2550, 210),
		Vector2(3400, 210),
		Vector2(4250, -210)
	]
	for index in spots.size():
		var kind := "gold" if index in [1, 3, 4] else "iron"
		var chest := Chest.new().setup(
			game,
			10000 + index,
			Iso.project(spots[index]),
			game.village.data["sprites"]["chest"],
			game.village.data["sprites"]["chest-broken"],
			kind
		)
		game.world.add_child(chest)
		game.chests.append(chest)

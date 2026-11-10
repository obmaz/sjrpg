class_name EncounterRuntime
extends Node
## Forest adaptation of sjrpg EncounterArea: first pack, then attack-triggered re-summons.
## Compact fixed sites replace the original huge world's dynamically discovered 3072-unit areas.

const RECHARGE_SECONDS := 300.0
const MAX_ENEMIES := 30
const CAVE_SITE := "cave_swarm"
const CAVE_WAVE_SIZE := 20
# The cave swarm reserves twenty extra native actors; ordinary spawning still caps at thirty.
const CAVE_ENEMY_LIMIT := MAX_ENEMIES + CAVE_WAVE_SIZE
const CAVE_VISUAL_VARIANT := "cave_crawler"
# Screen-ground offset keeps the marker beside, not over, the entrance/NPC/gate.
const CAVE_STONE_OFFSET := Vector2(210, -200)
const SITES := {
	"west": Vector2(-1700, 320), "north": Vector2(320, -1700),
	"east": Vector2(1700, -320), "south": Vector2(-320, 1700),
	"deep_west": Vector2(-2450, -1650), "deep_east": Vector2(2250, 1700),
}

var game: Node
var states: Dictionary
var stones: Dictionary = {}
var _members: Dictionary = {}
var _cleared_frame: Dictionary = {}
var _poll := 0.0


func setup(world_game: Node) -> EncounterRuntime:
	game = world_game
	states = GameState.encounters
	var sites := SITES.duplicate()
	sites[CAVE_SITE] = Iso.unproject(game.dungeon.entry_point() + CAVE_STONE_OFFSET)
	for key in states.keys():
		if not sites.has(key):
			states.erase(key)
	var asset: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/encounter_stone.json"))
	for id in sites:
		var at := _stone_position(Iso.project(sites[id]))
		var state: Dictionary = states.get(id, {"charges": 3, "recharge": 0.0, "initial_spawned": false, "members": []})
		# This demonstration pack is always attack-triggered, including old saves.
		if id == CAVE_SITE:
			state["initial_spawned"] = true
			state["charges"] = 3
			state["recharge"] = 0.0
		states[id] = state
		_members[id] = []
		_cleared_frame[id] = -1
		var stone := EncounterStone.new().setup(self, id, at, asset["sprite"])
		stones[id] = stone
		game.world.add_child(stone)
		game.village.solids.append(stone.body())
		for record in state["members"]:
			var desired := Vector2(record["position"][0], record["position"][1])
			var point := _spawn_position(desired, at, 0, Enemy.radius_for(str(record["kind"])))
			if point != Vector2.INF:
				var enemy := _create_enemy(id, str(record["kind"]), int(record["level"]), point)
				enemy.hp = minf(enemy.max_hp, float(record["hp"]))
	GameState.encounter_capture = capture
	return self


func _stone_position(desired: Vector2) -> Vector2:
	for index in 100:
		var at := desired if index == 0 else desired + Vector2.from_angle(index * 2.399963) * (50.0 + index * 5.0)
		if game._inside_field(at, 180.0) and not game.in_town(at) and not game._blocked(at, 65.0):
			return at
	return desired


func _process(delta: float) -> void:
	if not game.native_ready or game.dungeon.active or GameState.encounter_capture != capture:
		return
	for id in stones:
		var state: Dictionary = states[id]
		if int(state["charges"]) < 3:
			state["recharge"] = float(state["recharge"]) + delta
			while float(state["recharge"]) >= RECHARGE_SECONDS and int(state["charges"]) < 3:
				state["charges"] = int(state["charges"]) + 1
				state["recharge"] = float(state["recharge"]) - RECHARGE_SECONDS
			if int(state["charges"]) == 3:
				state["recharge"] = 0.0
		for enemy in _members[id]:
			if not is_instance_valid(enemy) or enemy.dead:
				continue
			var awake: bool = enemy.position.distance_to(game.player.position) < 1650.0
			enemy.visible = awake
			enemy.set_process(awake)
			enemy.sprite.set_process(awake)
	_poll -= delta
	if _poll > 0.0 or game.player.dead or game.in_town(game.player.position):
		return
	_poll = 0.3
	for id in stones:
		if not states[id]["initial_spawned"] and stones[id].position.distance_to(game.player.position) < 850.0:
			spawn_wave(id, true)


func living(id: String) -> int:
	var count := 0
	for enemy in _members.get(id, []):
		if is_instance_valid(enemy) and not enemy.dead:
			count += 1
	return count


func can_summon(id: String) -> bool:
	return GameState.encounter_capture == capture and not game.dungeon.active and states[id]["initial_spawned"] and int(states[id]["charges"]) > 0 and living(id) == 0 and int(_cleared_frame.get(id, -1)) < Engine.get_process_frames()


func strike(id: String, source: Node2D) -> bool:
	if not is_instance_valid(source) or game.player.dead or not can_summon(id):
		return false
	if not source is Player and not (source is Effect and is_instance_valid(source.owner_node) and source.owner_node is Player):
		return false
	var origin := source.position
	if source is Effect and is_instance_valid(source.owner_node):
		origin = source.owner_node.position
	if not clear_line(origin, stones[id].position):
		return false
	if spawn_wave(id, false) == 0:
		return false
	GameState.save_game()
	game.spawn_nova(stones[id].position, 75.0, Color("80dccc"), true)
	SoundFx.play("warp")
	Prefs.pulse("hit")
	game.combat_feedback(stones[id].position, 0.65)
	if source is Player:
		source.confirm_melee_contact(false)
	game.float_text(stones[id].position + Vector2(0, -110), "동굴 잠복자 · 20마리" if id == CAVE_SITE else "새로운 적의 기척", Color("b4eee0"))
	return true


func clear_line(from: Vector2, to: Vector2) -> bool:
	if SpatialCombat3D.world(game) != null:
		return SpatialCombat3D.line_clear(game, from, to)
	# Stop before the stone's own solid base. Terrain/walls must block remote activations.
	var approach := to.move_toward(from, 45.0)
	var distance := from.distance_to(approach)
	for step in range(1, maxi(2, ceili(distance / 18.0))):
		if game._blocked(from.lerp(approach, float(step) / maxi(2, ceili(distance / 18.0))), 2.0):
			return false
	return true


func spawn_wave(id: String, initial: bool) -> int:
	if game.dungeon.active or game.player.dead or game.in_town(game.player.position) or living(id) > 0:
		return 0
	if id == CAVE_SITE:
		return 0 if initial else _spawn_cave_wave()
	var available: int = MAX_ENEMIES - game.enemies.filter(func(enemy: Enemy): return is_instance_valid(enemy) and not enemy.dead).size()
	var near: bool = Iso.unproject(stones[id].position).length() < ForestBalance.NEAR_TOWN_RADIUS
	var count := mini(4 if initial and near else 6 if initial or near else 8, available)
	var added := 0
	for index in 72:
		if added >= count:
			break
		var origin: Vector2 = game.player.position
		var desired := origin + Vector2.from_angle(index * 2.399963 + game.player.facing) * ((220.0 if initial else 280.0) + float(index % 5) * 32.0)
		var point := _spawn_position(desired, stones[id].position, index)
		if point == Vector2.INF:
			continue
		var zone := clampi(int((point.length() - 1300.0) / 900.0), 0, 3)
		var kinds := ["goblin", "wolf", "goblin", "boar"] if zone < 2 else ["wolf", "boar", "skeleton", "goblin"]
		var kind: String = kinds[added % kinds.size()]
		# The first search has no chosen species; validate again with its real footprint.
		point = _spawn_position(point, stones[id].position, index + 1, Enemy.radius_for(kind))
		if point == Vector2.INF:
			continue
		_create_enemy(id, kind, ForestBalance.area_level(zone), point)
		added += 1
	if added > 0:
		_record_wave(id, initial)
	return added



## Reserve a complete pack before changing charges or retiring ambient actors.
## A full/blocked battlefield never creates a misleading partial twenty-pack.
func _spawn_cave_wave() -> int:
	if not can_summon(CAVE_SITE):
		return 0
	var live: Array = game.enemies.filter(func(enemy: Enemy): return is_instance_valid(enemy) and not enemy.dead)
	var shortfall := maxi(0, CAVE_WAVE_SIZE - (CAVE_ENEMY_LIMIT - live.size()))
	var reclaimable: Array[Enemy] = []
	for enemy: Enemy in live:
		# Match the ordinary field-spawn retirement rule; never erase another
		# encounter's saved pack, a boss or a protection-quest attacker.
		if enemy.encounter_id.is_empty() and not enemy.is_boss and not enemy.is_threat and enemy.position.distance_to(game.player.position) > 1900.0:
			reclaimable.append(enemy)
	if reclaimable.size() < shortfall:
		game.toast("주변의 적을 정리하면 20마리를 소환할 수 있습니다")
		return 0
	var positions := _cave_wave_positions()
	if positions.size() != CAVE_WAVE_SIZE:
		game.toast("소환 공간이 부족합니다 · 비석 주변을 비워 주세요")
		return 0
	for index in shortfall:
		var enemy: Enemy = reclaimable[index]
		game.enemies.erase(enemy)
		enemy.queue_free()
	for point: Vector2 in positions:
		var zone := clampi(int((point.length() - 1300.0) / 900.0), 0, 3)
		_create_enemy(CAVE_SITE, "goblin", ForestBalance.area_level(zone), point)
	_record_wave(CAVE_SITE, false)
	return CAVE_WAVE_SIZE


func _cave_wave_positions() -> Array[Vector2]:
	var planned: Array[Vector2] = []
	var center: Vector2 = stones[CAVE_SITE].position
	var radius := Enemy.radius_for("goblin")
	for index in 256:
		var distance := 220.0 + floorf(float(index) / 32.0) * 55.0
		var desired := center + Vector2.from_angle(index * 2.399963) * distance
		var point := _spawn_position(desired, center, index + 1, radius)
		if not point.is_finite():
			continue
		var clear := true
		for reserved: Vector2 in planned:
			if point.distance_to(reserved) < radius * 2.0 + 8.0:
				clear = false
				break
		if clear:
			planned.append(point)
			if planned.size() == CAVE_WAVE_SIZE:
				break
	return planned


func _record_wave(id: String, initial: bool) -> void:
	var state: Dictionary = states[id]
	state["initial_spawned"] = true
	if not initial and id != CAVE_SITE:
		if int(state["charges"]) == 3:
			state["recharge"] = 0.0
		state["charges"] = int(state["charges"]) - 1
	capture()


func _spawn_position(desired: Vector2, fallback: Vector2, attempt: int, radius_pixels := Enemy.RADIUS) -> Vector2:
	var candidates: Array[Vector2] = [desired]
	if attempt == 0:
		for index in 24:
			candidates.append(fallback + Vector2.from_angle(index * 2.399963) * (180.0 + index * 7.0))
	for at in candidates:
		if not game._inside_field(at, 80.0) or game.in_town(at) or game.spatial_world.blocked(at, radius_pixels + 10.0, true):
			continue
		var occupied := false
		for enemy in game.enemies:
			if is_instance_valid(enemy) and not enemy.dead and enemy.position.distance_to(at) < radius_pixels + enemy.radius + 8.0:
				occupied = true
				break
		if not occupied and at.distance_to(game.player.position) > 135.0:
			return at
	return Vector2.INF


func _create_enemy(id: String, kind: String, level: int, at: Vector2) -> Enemy:
	var enemy := Enemy.new()
	enemy.setup(game, kind, level)
	enemy.encounter_id = id
	if id == CAVE_SITE:
		enemy.set_meta("visual_variant", CAVE_VISUAL_VARIANT)
		enemy.display_name = "동굴 잠복자"
	enemy.encounter_spawn_frame = Engine.get_process_frames()
	if Iso.unproject(stones[id].position).length() < ForestBalance.NEAR_TOWN_RADIUS:
		enemy.max_hp *= ForestBalance.NEAR_TOWN_HP
		enemy.hp = enemy.max_hp
		enemy.damage *= ForestBalance.NEAR_TOWN_DAMAGE
	enemy.position = at
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	_members[id].append(enemy)
	# Restored packs are created before Game finishes native setup. Do not
	# let their first idle tick wander/attack behind the loading overlay.
	var awake: bool = game.native_ready and enemy.position.distance_to(game.player.position) < 1650.0
	enemy.visible = awake
	enemy.set_process(awake)
	enemy.sprite.set_process(awake)
	return enemy


func on_killed(enemy: Enemy) -> void:
	if enemy.encounter_id.is_empty():
		return
	_cleared_frame[enemy.encounter_id] = Engine.get_process_frames()
	capture()


func capture() -> void:
	for id in stones:
		_members[id] = _members[id].filter(func(enemy): return is_instance_valid(enemy) and not enemy.dead)
		var saved: Array = []
		for enemy in _members[id]:
			if is_instance_valid(enemy) and not enemy.dead:
				saved.append({"kind": enemy.kind, "level": enemy.spawn_level, "hp": enemy.hp, "position": [enemy.position.x, enemy.position.y]})
		states[id]["members"] = saved
	game._update_encounter_audit()


func in_radius(center: Vector2, radius: float, source: Node2D, angle := INF, half_angle := PI, melee := false) -> void:
	if game.dungeon.active or source == null:
		return
	for stone in stones.values():
		var delta: Vector2 = stone.position - center
		if delta.length() <= radius + 26.0 and (is_inf(angle) or absf(angle_difference(angle, delta.angle())) <= half_angle) and (game.can_melee_reach(center, stone.position) if melee else SpatialCombat3D.area_reaches(game, center, stone.position, radius + 26.0)):
			stone.take_damage(1.0, source)


func projectile_contacts(from: Vector2, to: Vector2, native_y := INF) -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	if game.dungeon.active:
		return contacts
	var travel := to - from
	if is_inf(native_y):
		native_y = SpatialCombat3D.launch_height(game, from)
	for stone in stones.values():
		if SpatialCombat3D.world(game) != null and is_inf(SpatialCombat3D.target_fraction(game, from, to, native_y, stone, 0.0, 26.0)):
			continue
		var polygon: PackedVector2Array = stone.body()
		var fraction := 0.0 if Geometry2D.is_point_in_polygon(from, polygon) else INF
		for index in polygon.size():
			var hit: Variant = Geometry2D.segment_intersects_segment(from, to, polygon[index], polygon[(index + 1) % polygon.size()])
			if hit != null and travel.length_squared() > 0.0001:
				fraction = minf(fraction, (Vector2(hit) - from).dot(travel) / travel.length_squared())
		if fraction >= 0.0 and fraction <= 1.0:
			contacts.append({"enemy": stone, "fraction": fraction})
	return contacts

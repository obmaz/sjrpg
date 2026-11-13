class_name ForestTreeRuntime
extends RefCounted
## 숲 나무의 유일한 상태 소유자. 정상 나무는 시계/노드 없이 공간 격자에만 남는다.

const CELL_PIXELS := 256.0
const DURABILITY := 3.0
const BURN_SECONDS := 4.0
const FREEZE_SECONDS := 8.0
const RESPAWN_SECONDS := 240.0
const TICK_SECONDS := 0.1
const STATES := ["healthy", "burning", "frozen", "charred", "ash", "felled"]
var game: Node
var entries: Dictionary = {}
var revision := 0
var _grid: Dictionary = {}
var _sources: Dictionary = {}
var _bodies: Dictionary = {}
var _clock := 0.0
var _events: Array[Dictionary] = []
var _feedback_action := ""


func setup(world_game: Node) -> ForestTreeRuntime:
	game = world_game
	for source in ForestTreeRenderer3D.sources(game.world, game.village.town_trees):
		if (
			not source.def.has("source")
			or not source.def.has("foot")
			or source.clip != Vector2.ZERO
			or source.draw_shift != Vector2.ZERO
		):
			continue
		var key := ForestTreeRenderer3D.source_key(source)
		var point := source.global_position
		var radius := ForestTreeRenderer3D._collision_radius(source, game.village.circles)
		if radius <= 0.0:
			continue
		var frame: Array = source.def["source"]
		entries[key] = {
			"key": key,
			"source": weakref(source),
			"point": point,
			"radius": radius,
			"view_margin_pixels": maxf(float(frame[2]), float(frame[3])) * source.k + 80.0
		}
		_sources[source.get_instance_id()] = key
		var cell := _cell(point)
		if not _grid.has(cell):
			_grid[cell] = []
		_grid[cell].append(key)
	# Only this deterministic forest's keys survive a load; other save slots are independent.
	for key: String in GameState.forest_trees.keys():
		if not entries.has(key) or not _valid_record(GameState.forest_trees[key]):
			GameState.forest_trees.erase(key)
	return self


static func _cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL_PIXELS), floori(point.y / CELL_PIXELS))


static func _valid_record(record: Variant) -> bool:
	if not record is Dictionary or record.get("state", "") not in STATES:
		return false
	for field in ["durability", "hits", "timer", "respawn"]:
		var value: Variant = record.get(field)
		if not (value is float or value is int) or not is_finite(float(value)):
			return false
	return (
		float(record["durability"]) >= 0.0
		and float(record["durability"]) <= DURABILITY
		and int(record["hits"]) >= 0
		and int(record["hits"]) <= 3
		and float(record["timer"]) >= 0.0
		and float(record["timer"]) <= FREEZE_SECONDS
		and float(record["respawn"]) >= 0.0
		and float(record["respawn"]) <= RESPAWN_SECONDS
	)


func state(key: String) -> String:
	return str(GameState.forest_trees.get(key, {}).get("state", "healthy"))


func record(key: String) -> Dictionary:
	return GameState.forest_trees.get(key, {})


func key_for(source: Node2D) -> String:
	return str(_sources.get(source.get_instance_id(), "")) if is_instance_valid(source) else ""


func blocks(key: String) -> bool:
	return state(key) not in ["ash", "felled"]


func bind_body(point: Vector2, body: StaticBody3D) -> void:
	for entry in nearby(point, 1.0, true):
		if point.distance_squared_to(entry["point"]) < 0.000001:
			_bodies[entry["key"]] = weakref(body)
			body.set_meta("forest_tree_key", entry["key"])
			body.collision_layer = SpatialWorld3D.SOLID if blocks(entry["key"]) else 0
			return


func nearby(point: Vector2, reach: float, include_felled := false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if game.dungeon.active:
		return out
	var low := _cell(point - Vector2.ONE * (reach + 64.0))
	var high := _cell(point + Vector2.ONE * (reach + 64.0))
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			for key: String in _grid.get(Vector2i(x, y), []):
				var entry: Dictionary = entries[key]
				if not include_felled and state(key) == "felled":
					continue
				if point.distance_to(entry["point"]) <= reach + float(entry["radius"]):
					out.append(entry)
	return out


func aim_sources(point: Vector2, reach: float) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for entry in nearby(point, reach):
		var source: Node2D = entry["source"].get_ref()
		if source != null and game.spatial_world.can_melee(point, source.position):
			out.append(source)
	return out


func hit_arc(
	point: Vector2,
	facing: float,
	reach: float,
	arc: float,
	element: String,
	action: String,
	strength := 1.0
) -> int:
	var count := 0
	for entry in nearby(point, reach):
		var offset: Vector2 = entry["point"] - point
		if absf(wrapf(offset.angle() - facing, -PI, PI)) > arc * 0.5:
			continue
		if not game.spatial_world.can_melee(point, entry["point"]):
			continue
		if hit(entry["key"], element, action, strength):
			count += 1
	return count


func hit_area(
	point: Vector2,
	reach: float,
	element: String,
	action: String,
	strength := 1.0,
	wall_axis := INF,
	from_floor := INF
) -> void:
	var floor_height := SpatialCombat3D.floor_at(game, point) if is_inf(from_floor) else from_floor
	for entry in nearby(point, reach):
		var offset: Vector2 = entry["point"] - point
		if (
			not is_inf(wall_axis)
			and absf(offset.dot(Vector2.from_angle(wall_axis).orthogonal())) > 26.0
		):
			continue
		var rise := SpatialCombat3D.floor_at(game, entry["point"]) - floor_height
		if (
			Vector2(offset.length(), rise * WorldSpace3D.VERTICAL_PIXELS_PER_METER).length()
			> reach + float(entry["radius"])
		):
			continue
		if game.spatial_world.can_melee(point, entry["point"]):
			hit(entry["key"], element, action, strength)


## A sphere swept against the same trunk as walking collision, including the low ash pile.
func projectile_contacts(
	from: Vector2, to: Vector2, height: float, radius_pixels := 26.0
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var center := (from + to) * 0.5
	for entry in nearby(center, from.distance_to(to) * 0.5 + radius_pixels):
		var point: Vector2 = entry["point"]
		var floor_height := SpatialCombat3D.floor_at(game, point)
		# Ash is low but still catches a deliberately aimed spell at standard hand height.
		var fraction := SpatialCombat3D.cylinder_fraction(
			WorldSpace3D.projected_to_world(from, height),
			WorldSpace3D.projected_to_world(to, height),
			WorldSpace3D.projected_to_world(point, floor_height),
			SpatialWorld3D.radius_metres(entry["radius"]),
			2.2,
			radius_pixels / WorldSpace3D.HORIZONTAL_PIXELS_PER_METER
		)
		if fraction <= 1.0:
			out.append({"tree": entry["key"], "fraction": fraction})
	out.sort_custom(func(a: Dictionary, b: Dictionary): return a["fraction"] < b["fraction"])
	return out


func hit(key: String, element: String, action: String, strength := 1.0) -> bool:
	if game.dungeon.active or not entries.has(key) or action.is_empty() or state(key) == "felled":
		return false
	var entry: Dictionary = entries[key]
	# A bounded recent-action ring handles older projectiles arriving after a newer cast.
	var actions: Array = entry.get("actions", [])
	if actions.has(action):
		return false
	actions.append(action)
	if actions.size() > 64:
		actions.pop_front()
	entry["actions"] = actions
	if _feedback_action != action:
		_feedback_action = action
		var cell := ["", "fire", "lightning", "cold"].find(element)
		SoundFx.play_hit(HitTier.LIGHT, maxi(0, cell))
		game.player.confirm_melee_contact(false)
	var data := record(key)
	if data.is_empty():
		data = {
			"state": "healthy",
			"durability": DURABILITY,
			"hits": 0,
			"timer": 0.0,
			"respawn": RESPAWN_SECONDS
		}
		GameState.forest_trees[key] = data
	var previous := str(data["state"])
	# Brittleness wins before an elemental attack can refresh freeze/char.
	if previous in ["frozen", "charred", "ash"]:
		_transition(key, "felled", 0.0, previous)
		return true
	data["hits"] = mini(3, int(data["hits"]) + 1)
	data["durability"] = maxf(0.0, float(data["durability"]) - clampf(strength, 1.0, 1.5))
	match element:
		"cold":
			_transition(key, "frozen", FREEZE_SECONDS)
		"lightning":
			_transition(key, "charred")
		"fire":
			if previous != "burning":
				_transition(key, "burning", BURN_SECONDS)
		_:
			if int(data["hits"]) >= 2 and float(data["durability"]) <= 0.0:
				_transition(key, "felled", 0.0, previous)
			else:
				_events.append({"key": key, "kind": "chip"})
	while _events.size() > 24:
		_events.pop_front()
	return true


func _transition(key: String, next: String, timer := 0.0, debris := "") -> void:
	var data := record(key)
	data["state"] = next
	data["timer"] = timer
	data["respawn"] = RESPAWN_SECONDS
	if next == "healthy":
		GameState.forest_trees.erase(key)
	var body: StaticBody3D = _bodies[key].get_ref() if _bodies.has(key) else null
	if is_instance_valid(body):
		body.collision_layer = SpatialWorld3D.SOLID if blocks(key) else 0
	revision += 1
	if not debris.is_empty():
		_events.append({"key": key, "kind": debris})
	# Even offscreen mass destruction cannot retain an unbounded presentation queue.
	while _events.size() > 24:
		_events.pop_front()


func tick(delta: float) -> void:
	_clock += delta
	if _clock < TICK_SECONDS:
		return
	var step := _clock
	_clock = 0.0
	for key: String in GameState.forest_trees.keys():
		var data := record(key)
		data["respawn"] = maxf(0.0, float(data["respawn"]) - step)
		var current := str(data["state"])
		if current in ["burning", "frozen"]:
			data["timer"] = maxf(0.0, float(data["timer"]) - step)
			if float(data["timer"]) <= 0.0:
				_transition(
					key,
					"ash" if current == "burning" else "healthy",
					0.0,
					"burning" if current == "burning" else ""
				)
				continue
		if float(data["respawn"]) <= 0.0 and can_regrow(key):
			_transition(key, "healthy")


func can_regrow(key: String) -> bool:
	var point: Vector2 = entries[key]["point"]
	if not game.dungeon.active:
		if game.world_renderer.source_view_rect(entries[key]["view_margin_pixels"]).has_point(
			point
		):
			return false
		for actor in [game.player] + game.enemies:
			if not is_instance_valid(actor) or actor.dead:
				continue
			var radius: float = actor.radius if actor is Enemy else Player.RADIUS
			if point.distance_to(actor.position) <= float(entries[key]["radius"]) + radius + 24.0:
				return false
	return true


func take_events() -> Array[Dictionary]:
	var events := _events
	_events = []
	return events


static func action_id(player: Player) -> String:
	return "%d:%d" % [player.get_instance_id(), player._action_serial]


static func strength(damage: float) -> float:
	# RPG levels never turn a healthy tree into a one-hit prop.
	return 1.5 if damage >= 60.0 else 1.0


static func element(tint: Color) -> String:
	if tint.is_equal_approx(SkillDefs.FIRE):
		return "fire"
	if tint.is_equal_approx(SkillDefs.COLD):
		return "cold"
	if tint.is_equal_approx(SkillDefs.LIGHT):
		return "lightning"
	return ""

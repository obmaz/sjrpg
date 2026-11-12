class_name ForestArt
extends RefCounted
## Generated reference materials and low path-border flora, independent of gameplay RNG/collision.

## Source-albedo gain only for the low grass plane, not tree leaves or earth.
## Native3D grass uses the same value; lighting remains a separate model.
const GRASS_TINT := Color(1.26, 1.30, 1.08, 1.0)

static var _data: Dictionary = {}
static var _textures: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/forest_art.json"))
	return _data


static func texture(key: String) -> Texture2D:
	if not _textures.has(key):
		_textures[key] = load("res://" + str(data()["textures"][key]["path"]))
	return _textures[key]


static func frame(key: String) -> Dictionary:
	return data()["frames"][key]


const MAX_FLORA := 420
const CHAPEL_BUDGET := 70
const UNDERSTORY_BUDGET := 96


static func decorate(village: Village, world: Node2D) -> Array[IsoSprite]:
	var placed: Array[IsoSprite] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 80165
	# Reserve detail for the close, playable chapel scene before long field roads
	# consume the shared sprite budget. All new plants stand on ordinary ground.
	var chapel: IsoSprite = village.buildings["chapel"]
	# The threshold terrace is only a few steps: plant around the whole church,
	# while clear() independently protects its actual doorway and stair corridor.
	var garden := chapel.atlas_polygon(village.data["frames"]["chapel"]["ground"])
	_border(village, world, garden, 72.0, 1.0, rng, placed, "chapel_ground", CHAPEL_BUDGET)
	_understory(village, world, rng, placed)
	# The new doorway path needs its own edge budget before the long field roads.
	var entry_path: PackedVector2Array = ChapelGardenPlan3D.surface(village)["top"]
	_border(village, world, entry_path, 72.0, 0.94, rng, placed, "path_edge", mini(MAX_FLORA, placed.size() + 80))
	for road: PackedVector2Array in village.map_roads:
		_border(village, world, road, 110.0, 0.72, rng, placed)
	for key in village.buildings:
		if key == "chapel":
			continue
		var building: IsoSprite = village.buildings[key]
		_border(village, world, TownPlazaPlan3D.house_footprint(village,key), 85.0, 0.8, rng, placed, "building_edge")
	return placed


static func _border(village: Village, world: Node2D, polygon: PackedVector2Array, spacing: float, chance: float, rng: RandomNumberGenerator, placed: Array[IsoSprite], group := "path_edge", limit := MAX_FLORA) -> void:
	var order: Array[int] = []
	for edge in polygon.size():
		order.append(edge)
	if group == "chapel_ground":
		# The visible two front faces receive flowers first; rear greenery remains
		# eligible if clear, rather than decorating only one bottom corner.
		order.sort_custom(func(a: int, b: int): return polygon[a].y + polygon[(a + 1) % polygon.size()].y > polygon[b].y + polygon[(b + 1) % polygon.size()].y)
	for edge in order:
		var a := polygon[edge]
		var b := polygon[(edge + 1) % polygon.size()]
		var normal := (b - a).normalized().orthogonal()
		if Geometry2D.is_point_in_polygon((a + b) * 0.5 + normal * 3.0, polygon):
			normal = -normal
		var count := maxi(1, floori(a.distance_to(b) / spacing))
		for index in count:
			if placed.size() >= mini(limit, MAX_FLORA):
				return
			if rng.randf() > chance:
				continue
			var at := a.lerp(b, (index + rng.randf_range(0.15, 0.85)) / count) + normal * rng.randf_range(28.0, 60.0)
			_patch(village, world, at, rng.randi_range(4, 7), 48.0, rng, placed, group, limit)


static func _understory(village: Village, world: Node2D, rng: RandomNumberGenerator, placed: Array[IsoSprite]) -> void:
	var limit := mini(MAX_FLORA, placed.size() + UNDERSTORY_BUDGET)
	var trees: Array[IsoSprite] = village.town_trees.duplicate()
	var chapel: IsoSprite = village.buildings["chapel"]
	trees.sort_custom(func(a: IsoSprite, b: IsoSprite): return a.position.distance_squared_to(chapel.position) < b.position.distance_squared_to(chapel.position))
	for tree in trees:
		for side in [-1.0, 1.0]:
			if placed.size() >= limit:
				return
			var center := tree.position + Vector2(side * rng.randf_range(50.0, 80.0), rng.randf_range(-15.0, 40.0))
			_patch(village, world, center, 5, 44.0, rng, placed, "understory", limit)


static func _patch(village: Village, world: Node2D, center: Vector2, count: int, radius: float, rng: RandomNumberGenerator, placed: Array[IsoSprite], group: String, limit: int) -> void:
	var planted := 0
	for attempt in count * 6:
		if placed.size() >= mini(limit, MAX_FLORA) or planted >= count:
			return
		# Projected ground ellipse, with irregular rooted clumps and open gaps.
		var angle := rng.randf_range(0.0, TAU)
		var distance := sqrt(rng.randf()) * radius
		var at := center + Vector2(cos(angle) * distance, sin(angle) * distance * 0.58)
		if not clear(village, at):
			continue
		var crowded := false
		for other in placed:
			if other.position.distance_squared_to(at) < 22.0 * 22.0:
				crowded = true
				break
		if crowded:
			continue
		var choices: Array[String] = ["flowers_white", "flowers_white", "flowers_warm", "fern", "grass"]
		if group == "understory":
			choices = ["fern", "fern", "grass", "flowers_white", "flowers_warm"]
		var kind: String = choices[rng.randi_range(0, choices.size() - 1)]
		var definition := frame(kind)
		var scale := 1.45 if kind.begins_with("flowers") else (1.35 if kind == "fern" else 1.7)
		var plant := IsoSprite.new().setup(definition, float(definition["world_height"]) * scale * rng.randf_range(0.8, 1.2))
		plant.position = at
		plant.z_index = 0
		plant.set_meta("forest_border_flora", true)
		plant.set_meta("forest_cluster", group)
		plant.set_meta("forest_species", kind)
		world.add_child(plant)
		placed.append(plant)
		planted += 1


static func near_polygon(at: Vector2, polygon: PackedVector2Array, distance: float) -> bool:
	for index in polygon.size():
		var closest := Geometry2D.get_closest_point_to_segment(at, polygon[index], polygon[(index + 1) % polygon.size()])
		if at.distance_squared_to(closest) < distance * distance:
			return true
	return false


static func clear(village: Village, at: Vector2, raised := false) -> bool:
	if village.near_water(Iso.unproject(at), 24.0) or (not raised and Geometry2D.is_point_in_polygon(at, village.terrace)):
		return false
	for road in village.map_roads:
		if Geometry2D.is_point_in_polygon(at, road):
			return false
	for solid in village.solids:
		if Geometry2D.is_point_in_polygon(at, solid):
			return false
	for circle in village.circles:
		if at.distance_to(circle[0]) < float(circle[1]) + 18.0:
			return false
	for npc in village.npc_points.values():
		if at.distance_to(npc) < 70.0:
			return false
	for chest in village.chest_points:
		if at.distance_to(chest) < 65.0:
			return false
	for gate in village.gate_points:
		if at.distance_to(gate) < 100.0:
			return false
	# Keep the entire stair/door approach open, including long segments between
	# measured vertices. The flowers add no collision but must not hide the route.
	for index in village.chapel_steps.size():
		var a := village.chapel_steps[index]
		var b := village.chapel_steps[mini(index + 1, village.chapel_steps.size() - 1)]
		if at.distance_to(Geometry2D.get_closest_point_to_segment(at, a, b)) < 75.0:
			return false
	for portal in village.portal_points.values():
		if at.distance_to(portal) < 115.0:
			return false
	return at.distance_to(village.portal_point) > 115.0 and at.distance_to(village.spawn_point) > 70.0

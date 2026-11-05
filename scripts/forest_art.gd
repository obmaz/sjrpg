class_name ForestArt
extends RefCounted
## Generated reference materials and low path-border flora, independent of gameplay RNG/collision.

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


static func decorate(village: Village, world: Node2D) -> Array[IsoSprite]:
	var placed: Array[IsoSprite] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 80165
	for road in village.map_roads:
		_border(village, world, road, 64.0, 0.74, rng, placed)
	for key in village.buildings:
		var building: IsoSprite = village.buildings[key]
		_border(village, world, building.atlas_polygon(village.data["frames"][key]["ground"]), 58.0, 0.8, rng, placed)
	_border(village, world, village.terrace, 48.0, 0.9, rng, placed, true)
	return placed


static func _border(village: Village, world: Node2D, polygon: PackedVector2Array, spacing: float, chance: float, rng: RandomNumberGenerator, placed: Array[IsoSprite], raised := false) -> void:
	for edge in polygon.size():
		var a := polygon[edge]
		var b := polygon[(edge + 1) % polygon.size()]
		if raised and (a.y + b.y) * 0.5 < Iso.poly_bounds(polygon).get_center().y:
			continue
		var normal := (b - a).normalized().orthogonal()
		if Geometry2D.is_point_in_polygon((a + b) * 0.5 + normal * 3.0, polygon):
			normal = -normal
		if raised:
			normal = -normal
		var count := maxi(1, floori(a.distance_to(b) / spacing))
		for index in count:
			if placed.size() >= 420 or rng.randf() > chance:
				continue
			var at := a.lerp(b, (index + rng.randf_range(0.18, 0.82)) / count) + normal * rng.randf_range(15.0, 36.0)
			if not clear(village, at, raised):
				continue
			var crowded := false
			for other in placed:
				if other.position.distance_squared_to(at) < 30.0 * 30.0:
					crowded = true
					break
			if crowded:
				continue
			var kind: String = ["flowers_white", "flowers_white", "flowers_warm", "flowers_warm", "fern", "grass"][rng.randi_range(0, 5)]
			var definition := frame(kind)
			var scale := 1.8 if kind.begins_with("flowers") else 1.2
			var plant := IsoSprite.new().setup(definition, float(definition["world_height"]) * scale * rng.randf_range(0.82, 1.15))
			plant.position = at
			plant.z_index = 1 if raised else 0
			plant.set_meta("forest_border_flora", true)
			world.add_child(plant)
			placed.append(plant)


static func clear(village: Village, at: Vector2, raised := false) -> bool:
	if village.near_water(Iso.unproject(at), 24.0) or (not raised and Geometry2D.is_point_in_polygon(at, village.terrace)):
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
	for step in village.chapel_steps:
		if at.distance_to(step) < 75.0:
			return false
	return at.distance_to(village.portal_point) > 115.0

class_name GroundRenderer3D
extends RefCounted
## 길 거리장과 실제 강둑·동굴 하강로 위에 생성형 재질을 놓는다.
const FIELD := "res://assets/data/native_ground_field.json"
const TILE_METRES := 2.56
static var _shader: Shader


static func grass_material(
	tint: Color = ForestArt.GRASS_TINT, habitat_bias: float = 0.0
) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/materials/grass/grass.gdshader")
	material.set_shader_parameter("grass_layers", NativeTerrainSurfaces.layers("grass"))
	# 낮은 지형의 기준색을 중복 적용하지 않고, 기존 높이별 색 비율만 이어받는다.
	material.set_shader_parameter(
		"surface_tint",
		Color(
			tint.r / ForestArt.GRASS_TINT.r,
			tint.g / ForestArt.GRASS_TINT.g,
			tint.b / ForestArt.GRASS_TINT.b
		)
	)
	material.set_shader_parameter("habitat_bias", habitat_bias)
	return material


static func build(renderer: Node) -> MeshInstance3D:
	if _shader == null:
		_shader = load("res://assets/materials/terrain/ground.gdshader")
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIELD))
	var origin: Array = record["origin"]
	var extent: Array = record["extent"]
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter("grass_layers", NativeTerrainSurfaces.layers("grass"))
	for variant in 6:
		material.set_shader_parameter(
			"paving_%d" % variant,
			load("res://assets/materials/paving/paving-%d.png" % variant)
		)
	var town := PackedVector2Array()
	for point: Vector2 in renderer.game.village.safe_zone:
		town.append(Iso.unproject(point) / WorldRenderer3D.GROUND_PER_METER)
	var town_bounds := Iso.poly_bounds(town)
	material.set_shader_parameter(
		"town_bounds",
		Vector4(
			town_bounds.position.x, town_bounds.position.y, town_bounds.end.x, town_bounds.end.y
		)
	)
	material.set_shader_parameter("distance_field", load("res://" + str(record["field"])))
	material.set_shader_parameter("shore_field", load("res://" + str(record["shore_field"])))
	material.set_shader_parameter("rock_texture", load("res://assets/materials/terrain/rock_base.webp"))
	material.set_shader_parameter("earth_texture", load("res://assets/sprites/forest/earth.webp"))
	material.set_shader_parameter(
		"bank_atlas", load("res://assets/models/environment/riverbank/albedo.png")
	)
	material.set_shader_parameter(
		"site_rock", load("res://assets/models/environment/cave_entrance/albedo.png")
	)
	material.set_shader_parameter(
		"world_to_cave",
		(
			NativeCavePlan
			. frame(Iso.project(renderer.game.village.cave_ground) + NativeCavePlan.ENTRY_OFFSET)
			. affine_inverse()
		)
	)
	material.set_shader_parameter("cave_trail", CaveTrailPlan3D.points(renderer.game.village))
	var trail_bounds := CaveTrailPlan3D.bounds(renderer.game.village)
	material.set_shader_parameter(
		"cave_trail_bounds",
		Vector4(
			trail_bounds.position.x, trail_bounds.position.y, trail_bounds.end.x, trail_bounds.end.y
		)
	)
	material.set_shader_parameter("field_origin", Vector2(origin[0], origin[1]))
	material.set_shader_parameter("field_extent", Vector2(extent[0], extent[1]))
	var faces := GroundRelief3D.faces(renderer.game.village)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(0, faces.size(), 3):
		LandmarkRenderer3D._tri(tool, faces[index], faces[index + 1], faces[index + 2], Vector3.UP)
	var plane := tool.commit()
	var ground: MeshInstance3D = renderer._mesh(plane, material, Vector3.ZERO)
	ground.name = "NativeNaturalGround"
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.set_meta(
		"native_ground",
		{
			"base_variants": 6,
			"edge_variants": 6,
			"paving_tile_metres": 3.2,
			"grass_variants": 10,
			"tile_metres": TILE_METRES,
			"road_count": record["roads"].size(),
			"surfaces": 1,
			"collision_changes": 1,
			"height_bias": 0.0
		}
	)
	return ground


static func roads_match(roads: Array[PackedVector2Array]) -> bool:
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIELD))
	var authored: Array = record["roads"]
	if roads.size() != authored.size():
		return false
	for i: int in roads.size():
		var polygon: Array = authored[i]
		if roads[i].size() != polygon.size():
			return false
		for j: int in roads[i].size():
			var expected: Array = polygon[j]
			var actual := Iso.unproject(roads[i][j]) / WorldRenderer3D.GROUND_PER_METER
			if actual.distance_to(Vector2(expected[0], expected[1])) > 0.0001:
				return false
	return true

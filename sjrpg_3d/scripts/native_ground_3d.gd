class_name NativeGround3D
extends RefCounted
## 실제 길 합집합의 거리장 위에 생성형 바닥/연결 타일을 놓는다. 물리는 바꾸지 않는다.
const BASE := "res://assets/art/preview3d/generated-ground-base.png"
const EDGE := "res://assets/art/preview3d/generated-ground-edge.png"
const GRASS := "res://assets/art/preview3d/generated-grass-variety.png"
const FIELD := "res://assets/data/native_ground_field.json"
const TILE_METRES := 2.56
static var _shader: Shader

static func grass_material(tint: Color = ForestArt.GRASS_TINT, habitat_bias: float = 0.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/native_grass.gdshader")
	material.set_shader_parameter("grass_atlas",load(GRASS))
	# 낮은 지형의 기준색을 중복 적용하지 않고, 기존 높이별 색 비율만 이어받는다.
	material.set_shader_parameter("surface_tint",Color(tint.r/ForestArt.GRASS_TINT.r,tint.g/ForestArt.GRASS_TINT.g,tint.b/ForestArt.GRASS_TINT.b))
	material.set_shader_parameter("habitat_bias",habitat_bias)
	return material

static func build(preview: Node) -> MeshInstance3D:
	if _shader == null:
		_shader = load("res://scripts/native_ground.gdshader")
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIELD))
	var origin: Array = record["origin"]
	var extent: Array = record["extent"]
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter("base_atlas", load(BASE))
	material.set_shader_parameter("edge_atlas", load(EDGE))
	material.set_shader_parameter("grass_atlas", load(GRASS))
	material.set_shader_parameter("distance_field", load("res://" + str(record["field"])))
	material.set_shader_parameter("field_origin", Vector2(origin[0], origin[1]))
	material.set_shader_parameter("field_extent", Vector2(extent[0], extent[1]))
	var plane := PlaneMesh.new()
	plane.size = Vector2(150, 150)
	var ground: MeshInstance3D = preview._mesh(plane, material, Vector3.ZERO)
	ground.name = "NativeNaturalGround"
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.set_meta("native_ground", {"base_variants": 4, "edge_variants": 4, "grass_variants":4,"tile_metres": TILE_METRES, "road_count": record["roads"].size(), "surfaces": 1, "collision_changes": 0, "height_bias": 0.0})
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
			var actual := Iso.unproject(roads[i][j]) / Ortho3DPreview.GROUND_PER_METER
			if actual.distance_to(Vector2(expected[0], expected[1])) > 0.0001:
				return false
	return true

extends TestCase
## 생성 원화와 길 합집합 데이터의 실제 연결·밀도·높이를 검증한다.
func run() -> void:
	var game := await make_game("mage")
	var preview: Ortho3DPreview = game.ortho_preview
	check("ground field still matches every actual road endpoint", NativeGround3D.roads_match(game.village.map_roads))
	var ground := preview._forest_stage.get_node("NativeNaturalGround") as MeshInstance3D
	var report: Dictionary = ground.get_meta("native_ground")
	check("one lit surface supplies four ground and four transition variants", report["base_variants"] == 4 and report["edge_variants"] == 4 and report["surfaces"] == 1 and ground.material_override is ShaderMaterial)
	var material := ground.material_override as ShaderMaterial
	check("four distinct grass families share the original native floor", report["grass_variants"] == 4 and material.get_shader_parameter("grass_atlas") == load(NativeGround3D.GRASS))
	check("ground keeps native floor and adds no obstacles", ground.position == Vector3.ZERO and report["height_bias"] == 0.0 and report["collision_changes"] == 0 and ground.find_children("*", "CollisionObject3D", true, false).is_empty())
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NativeGround3D.FIELD))
	var field_path := "res://" + str(record["field"])
	check("distance data retains the baked original hash", FileAccess.get_sha256(field_path) == record["sha256"])
	var image := Image.load_from_file(field_path)
	var origin: Array = record["origin"]
	var extent: Array = record["extent"]
	var soil_ends := true
	for terminal: Dictionary in record["terminals"]:
		var center: Array = terminal["center"]
		var uv := (Vector2(center[0], center[1]) - Vector2(origin[0], origin[1])) / Vector2(extent[0], extent[1])
		var pixel := Vector2i(uv * Vector2(image.get_width(), image.get_height()))
		soil_ends = soil_ends and image.get_pixelv(pixel).a > 0.85
	check("dead ends have an actual soil fade in the baked data", soil_ends and record["terminals"].size() >= 3)
	check("river bank retains its exact distance data", FileAccess.get_sha256("res://" + str(record["shore_field"])) == record["shore_sha256"] and record["river"].size() == game.village.river.polygon.size())
	var contours: Array[PackedVector2Array] = []
	for source: Array in record["union"]:
		var polygon := PackedVector2Array()
		for point: Array in source:
			polygon.append(Vector2(point[0], point[1]))
		contours.append(polygon)
	var maximum := 0.0
	var near_edge := 0
	for y: int in range(0, image.get_height(), 29):
		for x: int in range(0, image.get_width(), 23):
			var at := Vector2(origin[0], origin[1]) + Vector2((x + 0.5) / image.get_width(), (y + 0.5) / image.get_height()) * Vector2(extent[0], extent[1])
			var expected := INF
			for polygon: PackedVector2Array in contours:
				expected = minf(expected, -GroundEdges.signed_distance(at, polygon))
			var actual := (image.get_pixel(x, y).r * 2.0 - 1.0) * 2.0
			maximum = maxf(maximum, absf(actual - clampf(expected, -2.0, 2.0)))
			if absf(expected) < 1.15:
				near_edge += 1
	check("actual road union has accurate transition distances including corners", maximum < 0.017 and near_edge > 30, "max error=%f, edge samples=%d" % [maximum, near_edge])
	for path: String in [NativeGround3D.BASE, NativeGround3D.EDGE]:
		var texture := load(path) as Texture2D
		check("atlas keeps original generator resolution and metre density", texture.get_width() == 1254 and texture.get_height() == 1254 and is_equal_approx(float(report["tile_metres"]), 2.56))
	game.queue_free()
	await _frames(2)

extends TestCase


## 생성 원화와 길 합집합 데이터의 실제 연결·밀도·높이를 검증한다.
func run() -> void:
	var game := await make_game("mage")
	var renderer: WorldRenderer3D = game.world_renderer
	check(
		"ground field still matches every actual road endpoint",
		GroundRenderer3D.roads_match(game.village.map_roads)
	)
	var ground := renderer._forest_stage.get_node("NativeNaturalGround") as MeshInstance3D
	var report: Dictionary = ground.get_meta("native_ground")
	check(
		"one lit surface supplies six coherent generated paving variations",
		(
			report["base_variants"] == 6
			and report["edge_variants"] == 6
			and report["surfaces"] == 1
			and ground.material_override is ShaderMaterial
		)
	)
	var material := ground.material_override as ShaderMaterial
	check("wall footing reads the actual wall segments including gate openings",
		material.get_shader_parameter("wall_footprint_count") == game.village.wall_footprints.size())
	check(
		"ten distinct grass families share the original native floor",
		(
			report["grass_variants"] == 10
			and (
				material.get_shader_parameter("grass_layers")
				== NativeTerrainSurfaces.layers("grass")
			)
		)
	)
	check(
		"relief shares actual native floor and adds no visual-node blockers",
		(
			ground.position == Vector3.ZERO
			and report["height_bias"] == 0.0
			and report["collision_changes"] == 1
			and ground.find_children("*", "CollisionObject3D", true, false).is_empty()
		)
	)
	var record: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(GroundRenderer3D.FIELD)
	)
	var field_path := "res://" + str(record["field"])
	check(
		"distance data retains the baked original hash",
		FileAccess.get_sha256(field_path) == record["sha256"]
	)
	var image := Image.load_from_file(field_path)
	var origin: Array = record["origin"]
	var extent: Array = record["extent"]
	var soil_ends := true
	for terminal: Dictionary in record["terminals"]:
		var center: Array = terminal["center"]
		var uv := (
			(Vector2(center[0], center[1]) - Vector2(origin[0], origin[1]))
			/ Vector2(extent[0], extent[1])
		)
		var pixel := Vector2i(uv * Vector2(image.get_width(), image.get_height()))
		soil_ends = soil_ends and image.get_pixelv(pixel).a > 0.85
	check(
		"dead ends have an actual soil fade in the baked data",
		soil_ends and record["terminals"].size() >= 3
	)
	check(
		"river bank retains its exact distance data",
		(
			FileAccess.get_sha256("res://" + str(record["shore_field"])) == record["shore_sha256"]
			and record["river"].size() == game.village.river.polygon.size()
		)
	)
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
			var at := (
				Vector2(origin[0], origin[1])
				+ (
					Vector2((x + 0.5) / image.get_width(), (y + 0.5) / image.get_height())
					* Vector2(extent[0], extent[1])
				)
			)
			var expected := INF
			for polygon: PackedVector2Array in contours:
				expected = minf(expected, -GroundEdges.signed_distance(at, polygon))
			var actual := (image.get_pixel(x, y).r * 2.0 - 1.0) * 2.0
			maximum = maxf(maximum, absf(actual - clampf(expected, -2.0, 2.0)))
			if absf(expected) < 1.15:
				near_edge += 1
	check(
		"actual road union has accurate transition distances including corners",
		maximum < 0.017 and near_edge > 30,
		"max error=%f, edge samples=%d" % [maximum, near_edge]
	)
	var hashes := {}
	var sources: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/source/materials/paving/provenance.json")
	)
	var paving := NativeTerrainSurfaces.layers("paving")
	check(
		"six paving images share a single cached sampler array",
		(
			paving.get_layers() == 6
			and material.get_shader_parameter("paving_layers") == paving
			and NativeTerrainSurfaces.layers("paving") == paving
		)
	)
	var all_layers_match := true
	for variant in 6:
		var path := "res://assets/materials/paving/paving-%d.png" % variant
		var texture := load(path) as Texture2D
		var hash := FileAccess.get_sha256(path)
		hashes[hash] = true
		check(
			"paving %d binds an unmodified generated image at its real density" % variant,
			(
				texture.get_width() == 1254
				and texture.get_height() == 1254
				and material.get_shader_parameter("paving_layers") == paving
				and sources["images"][variant]["sha256"] == hash
				and is_equal_approx(float(report["paving_tile_metres"]), 3.2)
			)
		)
		var imported := texture.get_image()
		all_layers_match = (
			all_layers_match
			and paving.get_format() == imported.get_format()
			and paving.get_width() == imported.get_width()
			and paving.get_height() == imported.get_height()
			and paving.has_mipmaps() == imported.has_mipmaps()
		)
	check(
		"paving array retains the imported dimensions, GPU format and mip chain", all_layers_match
	)
	check("six paving images are distinct authored arrangements", hashes.size() == 6)
	var grass := NativeTerrainSurfaces.layers("grass")
	var water := NativeTerrainSurfaces.layers("water")
	check(
		"all terrain materials share one ten-layer array per family",
		(
			grass.get_layers() == 10
			and water.get_layers() == 10
			and grass == NativeTerrainSurfaces.layers("grass")
			and (
				water
				== renderer._world_environment._water_material.get_shader_parameter("water_layers")
			)
		)
	)
	for kind: String in ["grass", "water"]:
		var family: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://assets/source/materials/%s/provenance.json" % kind)
		)
		var unique := {}
		var texture: Texture2DArray = grass if kind == "grass" else water
		var intact: bool = (
			texture.get_width() == 1256
			and texture.get_height() == 1256
			and texture.has_mipmaps()
			and family["images"].size() == 10
		)
		for index in 10:
			var source: Dictionary = family["images"][index]
			var path := "res://" + str(source["path"])
			var hash := FileAccess.get_sha256(path)
			unique[hash] = true
			var imported := (
				ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
				as Texture2D
			)
			var imported_image := imported.get_image()
			intact = (
				intact
				and hash == source["sha256"]
				and imported.get_width() == 1254
				and imported_image.get_width() == texture.get_width()
				and imported_image.get_format() == texture.get_format()
			)
		check(
			"%s binds ten distinct originals at the imported array dimensions and format" % kind,
			intact and unique.size() == 10
		)
	var environment: EnvironmentRenderer3D = renderer._world_environment
	var held: float = environment._water_material.get_shader_parameter("phase")
	get_tree().paused = true
	await _frames(3)
	check(
		"native river pause holds the existing flow phase",
		is_equal_approx(float(environment._water_material.get_shader_parameter("phase")), held)
	)
	get_tree().paused = false
	await _frames(3)
	check(
		"native river resumes continuous flow with the same shared water array",
		(
			float(environment._water_material.get_shader_parameter("phase")) > held
			and environment._water_material.get_shader_parameter("water_layers") == water
		)
	)
	game.queue_free()
	await _frames(2)

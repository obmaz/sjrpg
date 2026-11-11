extends TestCase
## 사용자가 허용한 전체 면 원화 + 실제 입체 실루엣과 L자 충돌을 검증한다.


func run() -> void:
	var game := await make_game("mage")
	var report := {}
	for child in game.ortho_preview._world_environment.forest.find_children("*", "Node3D", true, false):
		if child.has_meta("chapel_detail"):
			report = child.get_meta("chapel_detail")
	check("chapel model is installed", not report.is_empty())
	if report.is_empty():
		game.queue_free()
		return
	check(
		"actual user reference drives the hybrid facade",
		(
			report["hybrid_facade"]
			and report["reference"] == "assets/source/style/approved-game-reference.jpg"
		)
	)
	check(
		"two gables and an offset entrance replace the single narrow church",
		report["gable_count"] == 2 and float(report["entrance_offset"]) < -1.0
	)
	check(
		"the lower broader tower keeps reference proportions",
		report["tower_height"] > 6.0 and report["tower_height"] < 8.0
	)
	check(
		"hybrid detail is merged and bounded",
		report["surfaces"] <= 6 and report["triangles"] < 12000
	)
	var has_facade := false
	var actual_triangles := 0
	var valid := true
	for mesh: MeshInstance3D in report["meshes"]:
		if mesh.name == "ChapelDetail_facade":
			has_facade = (
				(mesh.material_override as StandardMaterial3D).albedo_texture
				== load("res://assets/models/architecture/chapel/albedo.png")
			)
		var arrays := mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		actual_triangles += indices.size() / 3
		for index in vertices.size():
			valid = (
				valid
				and vertices[index].is_finite()
				and uv[index].is_finite()
				and absf(normals[index].length() - 1.0) < 0.001
			)
	check(
		"painted detail is attached to lit wall volume with valid geometry",
		has_facade and valid and actual_triangles == int(report["triangles"])
	)
	var surface: Dictionary = SpatialWorld3D.terrain_surfaces(game.village)[0]
	var size: Vector2 = report["footprint"]
	var bounds: Rect2 = game.ortho_preview._building_bounds("chapel")
	var centre: Vector2 = bounds.get_center()
	var recess: Vector2 = centre + Vector2(size.x * 0.25, size.y * 0.36)
	check(
		"recessed nave forecourt has no invisible rectangular building wall",
		not Geometry2D.is_point_in_polygon(Iso.project(recess * 65.0), surface["building"])
	)
	var stair: Dictionary = surface["native_steps"].back()
	var rect: Rect2 = stair["rect"]
	check(
		"stairs meet the off-centre painted entrance and native floor",
		(
			absf(rect.get_center().x - centre.x - report["entrance_offset"]) < 0.001
			and is_equal_approx(float(stair["height"]), 0.28)
		)
	)
	print(
		"ART_AUDIT reference_chapel ",
		JSON.stringify(
			{
				"triangles": report["triangles"],
				"surfaces": report["surfaces"],
				"tower_m": report["tower_height"],
				"footprint": str(size)
			}
		)
	)
	game.queue_free()
	await _frames(2)

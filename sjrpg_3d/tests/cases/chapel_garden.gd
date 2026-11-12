extends TestCase
## 판석의 실제 바닥·보행 지지와 정원 배칭/동선을 운영 월드에서 검사한다.


func run() -> void:
	var game := await make_game("mage")
	game.player.set_process(false)
	game._spawn_timer = 10000.0
	var garden: Node3D = game.world_renderer._forest_stage.find_child("ChapelGarden", true, false)
	if not check("chapel garden exists in the actual forest", garden != null):
		game.queue_free()
		return
	var report: Dictionary = garden.get_meta("chapel_garden")
	var paving: MeshInstance3D = report["paving"]
	var arrays := paving.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var finite := true
	for i in vertices.size():
		finite = (
			finite
			and vertices[i].is_finite()
			and normals[i].is_finite()
			and absf(normals[i].length() - 1.0) < .001
		)
	check(
		"merged stone geometry stays valid and bounded",
		(
			finite
			and indices.size() / 3 == int(report["paver_triangles"])
			and indices.size() / 3 < 1000
		)
	)
	var spatial: SpatialWorld3D = game.spatial_world
	var stones := ChapelGardenPlan3D.pavers(game.village)
	var worst_floor_error := 0.0
	var worst_foot_error := 0.0
	for stone: Dictionary in stones:
		var cap := GardenPath3D.cap_polygon(stone)
		var triangles := Geometry2D.triangulate_polygon(cap)
		# 삼각형 내부에서 측정한다. 경계 위의 부동소수점 레이 누락과 구별한다.
		var center := (cap[triangles[0]] + cap[triangles[1]] + cap[triangles[2]]) / 3.0
		var projected := Iso.project(center * WorldSpace3D.GROUND_UNITS_PER_METER)
		worst_floor_error = maxf(
			worst_floor_error, absf(spatial.height_at(projected) - float(stone["height"]))
		)
		spatial.teleport_source_actor(game.player, projected, Player.RADIUS)
		var foot := spatial.actor_foot(game.player)
		worst_foot_error = maxf(
			worst_foot_error, absf(foot.y - spatial.height_at(game.player.position))
		)
	check(
		"all visible stone caps have matching native FLOOR",
		worst_floor_error < .001,
		str(worst_floor_error)
	)
	check(
		"teleport support rests actor feet on actual stones",
		worst_foot_error < .001,
		str(worst_foot_error)
	)
	var plan := ChapelGardenPlan3D.layout(game.village)
	var path: Rect2 = plan["path"]
	var start := Iso.project(
		Vector2(path.get_center().x, path.end.y + .25) * WorldSpace3D.GROUND_UNITS_PER_METER
	)
	var target := Iso.project(
		Vector2(path.get_center().x, path.position.y + .15) * WorldSpace3D.GROUND_UNITS_PER_METER
	)
	spatial.teleport_source_actor(game.player, start, Player.RADIUS)
	for step in 140:
		spatial.move_source_actor(
			game.player,
			game.player.position + (target - game.player.position).limit_length(3.0),
			Player.RADIUS
		)
		worst_foot_error = maxf(
			worst_foot_error,
			absf(spatial.actor_foot(game.player).y - spatial.height_at(game.player.position))
		)
	check(
		"garden path remains walkable without lost floor support",
		game.player.position.distance_to(target) < 8.0 and worst_foot_error < .001,
		str(game.player.position.distance_to(target))
	)
	var clear := true
	var chapel := SpatialWorld3D._native_chapel(game.village)
	for plant: Dictionary in ChapelGardenPlan3D.plant_positions(game.village):
		var point: Vector3 = plant["at"]
		var ground := Vector2(point.x, point.z)
		var projected := Iso.project(ground * WorldSpace3D.GROUND_UNITS_PER_METER)
		clear = (
			clear
			and not path.grow(.12).has_point(ground)
			and not Geometry2D.is_point_in_polygon(projected, chapel["top"])
		)
		for npc: Vector2 in game.village.npc_points.values():
			clear = clear and projected.distance_to(npc) >= 65.0
	check(
		"plant roots preserve the actual stairs, path and resident space",
		clear and int(report["plant_instances"]) > 40
	)
	var triangles := int(report["paver_triangles"])
	var batches := 0
	for child in garden.get_children():
		if child is MultiMeshInstance3D:
			batches += 1
			var mesh: Mesh = child.multimesh.mesh
			triangles += mesh.surface_get_array_index_len(0) / 3 * child.multimesh.instance_count
	check(
		"garden uses at most four shared plant draws and no lights",
		(
			batches <= 4
			and garden.find_children("*", "Light3D", true, false).is_empty()
			and triangles < 7500
		)
	)
	var light_energy: float = game.world_renderer.sunlight.light_energy
	game.player.position = game.dungeon.entry_point()
	check("garden does not prevent entering the cave", game.dungeon.enter())
	await _frames(3)
	check("town garden is hidden with the forest inside the cave", not garden.is_visible_in_tree())
	game.dungeon.leave("")
	await _frames(3)
	check(
		"return restores outdoor lighting and garden",
		(
			garden.is_visible_in_tree()
			and is_equal_approx(game.world_renderer.sunlight.light_energy, light_energy)
		)
	)
	print(
		"ART_AUDIT CHAPEL_GARDEN ",
		JSON.stringify(
			{
				"triangles": triangles,
				"plant_draws": batches,
				"plant_instances": report["plant_instances"],
				"worst_floor_error": worst_floor_error,
				"worst_foot_error": worst_foot_error
			}
		)
	)
	game.queue_free()
	await _frames(2)

extends TestCase
## 건물 6곳의 실제 보행·FLOOR·주민 동선과 공용 식생 예산을 운영 월드에서 검사한다.


func run() -> void:
	var game := await make_game("mage")
	game.player.set_process(false)
	game._spawn_timer = 10000.0
	var spatial: SpatialWorld3D = game.spatial_world
	var root: Node3D = game.world_renderer._forest_stage.find_child(
		"VillageCourtyards", true, false
	)
	if not check("all village courtyards have one static rendering root", root != null):
		game.queue_free()
		return
	var sites := VillageCourtyardPlan3D.sites(game.village)
	check("four preserved houses and two dedicated services have courtyards", sites.size() == 6)
	var worst_floor := 0.0
	var worst_foot := 0.0
	var root_clear := true
	for site: Dictionary in sites:
		for stone: Dictionary in site["stones"]:
			var cap := GardenPath3D.cap_polygon(stone)
			var triangle := Geometry2D.triangulate_polygon(cap)
			var point := (cap[triangle[0]] + cap[triangle[1]] + cap[triangle[2]]) / 3.0
			var projected := Iso.project(point * WorldSpace3D.GROUND_UNITS_PER_METER)
			worst_floor = maxf(
				worst_floor, absf(spatial.height_at(projected) - float(stone["height"]))
			)
		var path: Rect2 = site["path"]
		if str(site["id"]) in VillageCourtyardPlan3D.HOUSE_KEYS:
			var key: String = site["id"]
			var visual_report: Dictionary = game.world_renderer._houses[key]
			var entrance: Rect2 = visual_report["door_approach"]
			var center: Vector2 = game.world_renderer._building_bounds(key).get_center()
			check(
				"courtyard follows the actual GLB entrance of " + key,
				(
					absf(path.get_center().x - center.x - entrance.get_center().x) < .00001
					and absf(path.position.y - center.y - entrance.position.y - .12) < .00001
				)
			)
		var footprint: Rect2 = site["footprint"]
		for plant: Dictionary in site["plants"]:
			var at: Vector3 = plant["at"]
			var flat := Vector2(at.x, at.z)
			root_clear = (
				root_clear
				and not path.grow(.18).has_point(flat)
				and not footprint.grow(.18).has_point(flat)
				and not TownPlazaPlan3D.PLAZA.grow(.35).has_point(flat)
			)
			var projected := WorldSpace3D.world_to_projected(at)
			for npc: Vector2 in game.village.npc_points.values():
				root_clear = root_clear and projected.distance_to(npc) >= 65.0
		var reached := false
		var nearest := INF
		# 주민이 서 있는 마당도 실제 캡슐이 지나가는 최소 한 개의 보행 띠를 유지해야 한다.
		for lane: float in [0.0, -.62, .62]:
			var target := Iso.project(
				(
					Vector2(path.get_center().x + lane, path.position.y + .62)
					* WorldSpace3D.GROUND_UNITS_PER_METER
				)
			)
			var start := Iso.project(
				(
					Vector2(path.get_center().x + lane, path.end.y + .35)
					* WorldSpace3D.GROUND_UNITS_PER_METER
				)
			)
			spatial.teleport_source_actor(game.player, start, Player.RADIUS)
			for step in 130:
				spatial.move_source_actor(
					game.player,
					game.player.position + (target - game.player.position).limit_length(3.0),
					Player.RADIUS
				)
				worst_foot = maxf(
					worst_foot,
					absf(
						spatial.actor_foot(game.player).y - spatial.height_at(game.player.position)
					)
				)
			nearest = minf(nearest, game.player.position.distance_to(target))
			if game.player.position.distance_to(target) < 8.0:
				reached = true
				break
		check("actual native capsule can approach " + str(site["id"]), reached, str(nearest))
	check(
		"every visible courtyard stone has matching native FLOOR",
		worst_floor < .001,
		str(worst_floor)
	)
	check(
		"native walking retains FLOOR support across all courtyard paths",
		worst_foot < .001,
		str(worst_foot)
	)
	check("flower beds preserve stoops, the plaza and resident space", root_clear)
	var report: Dictionary = root.get_meta("village_courtyards")
	var chapel: Node3D = game.world_renderer._forest_stage.find_child("ChapelGarden", true, false)
	var triangles := int(report["paver_triangles"])
	var shared := true
	for child in root.get_children():
		if child is MultiMeshInstance3D:
			var matching: MultiMeshInstance3D = chapel.get_node(NodePath(child.name))
			shared = shared and child.multimesh.mesh == matching.multimesh.mesh
			var mesh: Mesh = child.multimesh.mesh
			triangles += mesh.surface_get_array_index_len(0) / 3 * child.multimesh.instance_count
	check(
		"courtyards share the chapel meshes and use at most five static draws",
		(
			shared
			and root.get_child_count() <= 5
			and root.find_children("*", "Light3D", true, false).is_empty()
		)
	)
	check(
		"courtyard geometry and plant counts stay bounded",
		(
			triangles < 14000
			and int(report["plant_instances"]) > 100
			and int(report["plant_instances"]) <= 324
		)
	)
	game.player.position = game.dungeon.entry_point()
	check("courtyards do not prevent cave entry", game.dungeon.enter())
	await _frames(3)
	check("courtyards stay in the forest when entering the cave", not root.is_visible_in_tree())
	game.dungeon.leave("")
	await _frames(3)
	check(
		"return reuses the existing courtyard root",
		(
			root.is_visible_in_tree()
			and (
				(
					game
					. world_renderer
					. _forest_stage
					. find_children("VillageCourtyards", "Node3D", true, false)
					. size()
				)
				== 1
			)
		)
	)
	print(
		"ART_AUDIT VILLAGE_COURTYARDS ",
		JSON.stringify(
			{
				"sites": sites.size(),
				"plants": report["plant_instances"],
				"triangles": triangles,
				"static_draws": root.get_child_count(),
				"floor_error_m": worst_floor,
				"foot_error_m": worst_foot
			}
		)
	)
	game.queue_free()
	await _frames(2)

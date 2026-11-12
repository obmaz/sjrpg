extends TestCase
## 신규 시설의 실제 모델·물리·지도·NPC 접근을 함께 확인한다.


func run() -> void:
	var game := await make_game("mage")
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var spatial: SpatialWorld3D = game.spatial_world
	var space := spatial.get_world_3d().direct_space_state
	for key: String in TownPlazaPlan3D.LEGACY_CENTERS:
		var bounds: Rect2 = game.world_renderer._building_bounds(key)
		check(
			"original house moved outside the plaza " + key,
			not bounds.intersects(TownPlazaPlan3D.PLAZA.grow(-.1))
		)
	for id: String in TownPlazaPlan3D.SERVICES:
		var at := TownPlazaPlan3D.approach(id)
		var name: String = TownPlazaPlan3D.SERVICES[id]["npc"]
		check(
			"service NPC follows dedicated building " + id,
			game.village.npc_nodes[name].position.is_equal_approx(at)
		)
		var ray := PhysicsRayQueryParameters3D.create(
			WorldSpace3D.projected_to_world(at, 1.0),
			WorldSpace3D.projected_to_world(at, .15),
			SpatialWorld3D.SOLID
		)
		check("service approach is clear " + id, space.intersect_ray(ray).is_empty())
		var wall: Dictionary = TownPlazaPlan3D.blockers(id)[0]
		var center: Vector3 = TownPlazaPlan3D.frame(id) * wall["at"]
		var hit := space.intersect_ray(
			PhysicsRayQueryParameters3D.create(
				center + Vector3.UP * 4, center, SpatialWorld3D.SOLID
			)
		)
		check("building has actual shared-plan collision " + id, not hit.is_empty())
		var visual := ArchitectureSceneLibrary.create(id)
		add_child(visual)
		check(
			"new facility is imported GLB " + id,
			visual.get_node("Geometry").scene_file_path.ends_with("/model.glb")
		)
		check(
			"trade model stays within budget " + id,
			int(visual.report["triangles"]) < 24000 and int(visual.report["surfaces"]) <= 8
		)
		if id == "market_shop":
			check("shop has actual merchandise meshes", int(visual.report["goods_count"]) >= 40)
			var roof := visual.get_node("Geometry/House_market_shop_slate") as MeshInstance3D
			check("ridge caps share the roof offset", roof.mesh.get_aabb().end.z <= 1.7)
		else:
			check(
				"forge has large furnace opening",
				visual.report["furnace_opening"] == Vector2(1.68, .98)
			)
		visual.free()
	for definition: Array in Village.NPCS:
		var name: String = definition[1]
		check("town resident remains inside the safe wall interior " + name, Geometry2D.is_point_in_polygon(game.village.npc_nodes[name].position, game.village.safe_zone))
	var shapes := MapGeometry.build(game.village)
	for id: String in TownPlazaPlan3D.SERVICES:
		var found := false
		for shape: Dictionary in shapes:
			if shape["id"] == "building:" + id:
				found = shape["poly"] == TownPlazaPlan3D.footprint(id)
		check("map includes real facility position " + id, found)
	# 실제 화덕과 모루 사이 열린 공간은 본체 사각형으로 막지 않는다.
	var open_at := TownPlazaPlan3D.frame("open_smithy") * Vector3(1.65, 1.0, 3.15)
	check(
		"open workshop remains enterable",
		(
			space
			. intersect_ray(
				PhysicsRayQueryParameters3D.create(
					open_at + Vector3.UP * .4, open_at, SpatialWorld3D.SOLID
				)
			)
			. is_empty()
		)
	)
	var entry := WorldSpace3D.world_to_projected(
		TownPlazaPlan3D.frame("open_smithy") * Vector3(1.65, 0, 3.15)
	)
	check("hero capsule can enter workshop", not spatial.blocked(entry, Player.RADIUS))
	game.queue_free()
	await _frames(2)

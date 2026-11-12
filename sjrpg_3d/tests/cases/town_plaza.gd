extends TestCase
## 신규 시설의 실제 모델·물리·지도·NPC 접근을 함께 확인한다.


func run() -> void:
	var game := await make_game("mage")
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var spatial: SpatialWorld3D = game.spatial_world
	var space := spatial.get_world_3d().direct_space_state
	game.map_state.refresh(true)
	var right_facing := 0
	for key: String in TownPlazaPlan3D.LEGACY_CENTERS:
		var report: Dictionary = game.world_renderer._houses[key]
		var root := NativePlayerOcclusion.static_owner(report["meshes"][0]) as Node3D
		var pose := TownPlazaPlan3D.frame(key)
		check(
			"GLB root keeps shared metre pose " + key, root.global_transform.is_equal_approx(pose)
		)
		var forward := root.global_basis.z
		if forward.dot(Vector3.RIGHT) > .999:
			right_facing += 1
			var axis := (
				WorldSpace3D.world_to_projected(root.global_position + forward)
				- WorldSpace3D.world_to_projected(root.global_position)
			)
			check(
				"rotated house front projects to the lower right " + key, axis.x > 0 and axis.y > 0
			)
		var footprint: Vector2 = report["footprint"]
		var expected := TownPlazaPlan3D.project(
			ChapelPlan3D.polygon(Rect2(-footprint * .5, footprint)), root.global_transform
		)
		var matching_map := false
		for shape: Dictionary in game.map_shapes:
			if shape["id"] == "building:" + key:
				var polygon: PackedVector2Array = shape["poly"]
				matching_map = polygon.size() == expected.size()
				for index in polygon.size():
					matching_map = (
						matching_map and polygon[index].distance_to(expected[index]) < .001
					)
		check("minimap follows actual rotated GLB footprint " + key, matching_map)
		var center := root.global_position
		check(
			"rotated building body remains solid " + key,
			not (
				space
				. intersect_ray(
					PhysicsRayQueryParameters3D.create(
						center + Vector3.UP * 4.0, center + Vector3.UP, SpatialWorld3D.SOLID
					)
				)
				. is_empty()
			)
		)
		var native_points := PackedVector2Array()
		for projected: Vector2 in TownPlazaPlan3D.house_footprint(game.village, key):
			var point := WorldSpace3D.projected_to_world(projected)
			native_points.append(Vector2(point.x, point.z))
		var bounds := Iso.poly_bounds(native_points)
		check(
			"original house moved outside the plaza " + key,
			not bounds.intersects(TownPlazaPlan3D.PLAZA.grow(-.1))
		)
	check("two houses offer the alternative courtyard frontage", right_facing >= 2)
	_audit_actual_clearance(game)
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
		check(
			"town resident remains inside the safe wall interior " + name,
			Geometry2D.is_point_in_polygon(
				game.village.npc_nodes[name].position, game.village.safe_zone
			)
		)
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


func _ground_rect(bounds: AABB) -> Rect2:
	return Rect2(bounds.position.x, bounds.position.z, bounds.size.x, bounds.size.z)


func _gap(a: Rect2, b: Rect2) -> float:
	return (
		Vector2(
			maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x)),
			maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
		)
		. length()
	)


func _audit_actual_clearance(game: Node) -> void:
	var buildings := {}
	for root: Node in game.world_renderer._forest_stage.get_children():
		if not root.has_meta("native_house") and not root.has_meta("chapel_detail"):
			continue
		var bound := AABB()
		var first := true
		for node: Node in root.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			if not "slate" in str(mesh.name).to_lower():
				continue
			var box: AABB = mesh.global_transform * mesh.mesh.get_aabb()
			bound = box if first else bound.merge(box)
			first = false
		if not first:
			buildings[str(root.get_path())] = _ground_rect(bound)
	var wall_parts: Array[Rect2] = []
	for footprint: PackedVector2Array in game.village.wall_footprints:
		var points := PackedVector2Array()
		for point: Vector2 in footprint:
			var native := WorldSpace3D.projected_to_world(point)
			points.append(Vector2(native.x, native.z))
		wall_parts.append(Iso.poly_bounds(points))
	for part: Dictionary in FortressPlan3D.wall_walk(game.village)["parts"]:
		var size: Vector3 = part["size"]
		var box: AABB = part["frame"] * AABB(-size * .5, size)
		wall_parts.append(_ground_rect(box))
	var minimum_building := INF
	var minimum_wall := INF
	for key: String in buildings:
		var roof: Rect2 = buildings[key]
		for other: String in buildings:
			if key != other:
				minimum_building = minf(minimum_building, _gap(roof, buildings[other]))
		for wall: Rect2 in wall_parts:
			minimum_wall = minf(minimum_wall, _gap(roof, wall))
	check(
		"actual roof silhouettes leave building alleys",
		buildings.size() == 7 and minimum_building >= 1.2,
		str(minimum_building)
	)
	check("actual eaves clear inner wall walks", minimum_wall >= 1.0, str(minimum_wall))
	print(
		"ART_AUDIT TOWN_ROOF_CLEARANCE ",
		JSON.stringify(
			{"roofs": buildings, "building_gap_m": minimum_building, "wall_gap_m": minimum_wall}
		)
	)

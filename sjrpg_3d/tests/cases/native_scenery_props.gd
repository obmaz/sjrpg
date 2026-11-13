extends TestCase
## Native scene geometry must leave the measured cave opening physically visible.
func run() -> void:
	for width in [1.4, 3.0, 4.0]:
		var mesh := SceneryRenderer3D.arch_mesh(width, 4.0)
		var arrays := mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var valid := points.size() > 100 and normals.size() == points.size() and uv.size() == points.size()
		for i in range(0, points.size(), 3):
			var geometric := (points[i + 1] - points[i]).cross(points[i + 2] - points[i])
			valid = valid and geometric.length_squared() > 0.00000001 and geometric.dot(normals[i]) < 0.0
			valid = valid and absf((uv[i + 1] - uv[i]).cross(uv[i + 2] - uv[i])) > 0.00000001
		check("native arch has valid closed-volume normals, clockwise winding and full UV area", valid)
		var open := true
		for x in [-0.25, 0.0, 0.25]:
			for y in [0.1, 0.9, 1.7]:
				for i in range(0, points.size(), 3):
					open = open and Geometry3D.ray_intersects_triangle(Vector3(x, y, -4), Vector3.BACK, points[i], points[i + 1], points[i + 2]) == null
		check("native arch does not fill its capsule-clear central passage", open)
	var game := await make_game("mage")
	if game.world_renderer == null:
		game._create_world_renderer()
	await _frames(3)
	var renderer: WorldRenderer3D = game.world_renderer
	var environment: EnvironmentRenderer3D = renderer._world_environment
	var forest := environment.forest.get_node("NativeFieldScenery")
	var report: Dictionary = forest.get_meta("native_scenery_report")
	var rock_count := 0
	var entrance_count := 0
	for entry: Dictionary in report["entries"]:
		if entry["role"] == "boulder":
			rock_count += 1
			var transform: Transform3D = entry["transform"]
			var point: Vector2 = entry["source_foot"]
			check("field rock keeps its original native foot", transform.origin.is_equal_approx(WorldSpace3D.projected_to_world(point, renderer.surface_height(point))))
		elif entry["role"] == "entrance":
			entrance_count += 1
			var transform: Transform3D = entry["transform"]
			var source_foot: Vector2 = entry["source_foot"]
			var body_centre := WorldSpace3D.projected_to_world(source_foot + NativeCavePlan.CENTER_OFFSET)
			var native_mesh: ArrayMesh = entry["mesh"]
			check("cave is a broad hill with a large entrance", native_mesh.get_aabb().size.x > 10.0 and native_mesh.get_aabb().end.y > 4.5 and float(entry["clear_width"]) > 3.0)
			var arrays := native_mesh.surface_get_arrays(0)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var fits_original_circle := not points.is_empty()
			var maximum_distance := 0.0
			var has_ground_contact := false
			var radius := SpatialWorld3D.radius_metres(NativeCavePlan.SOURCE_RADIUS)
			for point in points:
				var world := transform * point
				var distance := Vector2(world.x - body_centre.x, world.z - body_centre.z).length()
				maximum_distance = maxf(maximum_distance,distance)
				fits_original_circle = fits_original_circle and distance <= radius + 0.002
				has_ground_contact = has_ground_contact or (absf(point.y)<0.05)
			check("hill fits its shared placement envelope and meets the real ground", fits_original_circle and has_ground_contact,"radius=%f max=%f contact=%s" % [radius,maximum_distance,has_ground_contact])
			var edges := {}
			var winding := true
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for triangle in range(0, points.size(), 3):
				var a: Vector3 = points[triangle]
				var b: Vector3 = points[triangle + 1]
				var c: Vector3 = points[triangle + 2]
				winding = winding and (b - a).cross(c - a).dot(normals[triangle]) <= .000001
				for pair: Array in [[a, b], [b, c], [c, a]]:
					var first := _cave_vertex_key(pair[0])
					var last := _cave_vertex_key(pair[1])
					if first == last:
						continue
					var edge := first + "/" + last if first < last else last + "/" + first
					edges[edge] = int(edges.get(edge, 0)) + 1
			var open_edges := 0
			for count: int in edges.values():
				if count != 2:
					open_edges += 1
			check("entrance has outward clockwise faces without missing rock triangles", winding and open_edges == 0, "open_edges=%d" % open_edges)
			var roof_samples: Array[Dictionary] = []
			var intact_roof := true
			for x: float in [-1.3, 0.0, 1.3]:
				for z: float in [.15, -1.0, -2.0]:
					var sample := _cave_roof_sample(points, Vector2(x, z))
					roof_samples.append(sample)
					intact_roof = intact_roof and bool(sample["valid"])
			check("the mouth and both shoulders retain a real roof above capsule headroom", intact_roof, JSON.stringify(roof_samples))
			var deep_rock := true
			var depths := []
			for x: float in [-1.0, 0.0, 1.0]:
				for y: float in [0.1, 0.5, 1.0]:
					var nearest := -INF
					for i in range(0,points.size(),3):
						var hit: Variant = Geometry3D.ray_intersects_triangle(Vector3(x,y,4),Vector3.FORWARD,points[i],points[i+1],points[i+2])
						if hit is Vector3:
							nearest = maxf(nearest,hit.z)
					depths.append({"x":x,"y":y,"z":nearest})
					deep_rock = deep_rock and nearest < -NativeCavePlan.RECESS_DEPTH + .35 and nearest > -NativeCavePlan.RECESS_DEPTH - .35
			var depth_min := INF
			var depth_max := -INF
			for sample: Dictionary in depths:
				depth_min = minf(depth_min, float(sample["z"]))
				depth_max = maxf(depth_max, float(sample["z"]))
			check("entrance retains a deep irregular rock recess instead of a flat dark plane", deep_rock and depth_max - depth_min > .12 and forest.find_children("TunnelDepth","MeshInstance3D",true,false).is_empty(),JSON.stringify(depths))
			# 고정 직교 카메라의 실제 방향으로도 가까운 벽이 개구부를 막지 않아야 한다.
			var camera_direction := Vector3(0, -1, -sqrt(2.0)).normalized()
			var sight_depths := []
			var open_camera_sight := true
			for y: float in [1.1, 1.7, 2.3]:
				var origin := Vector3(0, y, .2)
				var nearest := INF
				var contact := Vector3.ZERO
				for triangle in range(0, points.size(), 3):
					var hit: Variant = Geometry3D.ray_intersects_triangle(origin, camera_direction, points[triangle], points[triangle + 1], points[triangle + 2])
					if hit is Vector3 and origin.distance_to(hit) < nearest:
						nearest = origin.distance_to(hit)
						contact = hit
				sight_depths.append({"y": y, "depth": contact.z})
				open_camera_sight = open_camera_sight and is_finite(nearest) and contact.z < (-4.0 if y > 2.0 else -1.6)
			check("the fixed camera sees descending space before contacting deep rock", open_camera_sight, JSON.stringify(sight_depths))
	check("actual field rocks and the existing scene-transition cave mouth have native owners", rock_count > 0 and entrance_count == 1)
	game.player.set_process(false)
	game.spatial_world.teleport_source_actor(game.player, game.dungeon.entry_point() + Vector2(0, 260), Player.RADIUS)
	for step: int in 80:
		game.spatial_world.move_source_actor(game.player, game.player.position.move_toward(game.dungeon.entry_point(), 4.0), Player.RADIUS)
	check("real capsule can approach the enlarged hill and use the original cave interaction", game.dungeon.enter_block_reason().is_empty(), JSON.stringify({"at":str(game.player.position),"entry":str(game.dungeon.entry_point()),"reason":game.dungeon.enter_block_reason()}))
	var cave_frame := NativeCavePlan.frame(game.dungeon.entry_point())
	var rear_target := WorldSpace3D.world_to_projected(cave_frame * Vector3(0, 0, -NativeCavePlan.RECESS_DEPTH - 2.0))
	for step: int in 180:
		game.spatial_world.move_source_actor(game.player, game.player.position.move_toward(rear_target, 4.0), Player.RADIUS)
	var local := cave_frame.affine_inverse() * WorldSpace3D.projected_to_world(game.player.position)
	check("real capsule descends into the recess and stops at the rear rock", absf(local.x) < 1.96 and local.z < -NativeCavePlan.RECESS_DEPTH + 1.0 and local.z > -NativeCavePlan.RECESS_DEPTH - .1 and game.spatial_world.height_at(game.player.position) < -0.75,"local=%s height=%f" % [local,game.spatial_world.height_at(game.player.position)])
	var side_ray := PhysicsRayQueryParameters3D.create(cave_frame * Vector3(0,1.0,-1.0), cave_frame * Vector3(3.0,1.0,-1.0), SpatialWorld3D.SOLID)
	check("the actual entrance has solid rock at its side rather than a full circular blocker", not game.spatial_world.get_world_3d().direct_space_state.intersect_ray(side_ray).is_empty())
	var roof_ray := PhysicsRayQueryParameters3D.create(cave_frame * Vector3(0,1.0,-1.0), cave_frame * Vector3(0,4.0,-1.0), SpatialWorld3D.SOLID)
	var roof_hit: Dictionary = game.spatial_world.get_world_3d().direct_space_state.intersect_ray(roof_ray)
	check("the walkable entrance also has actual solid rock overhead", not roof_hit.is_empty() and roof_hit["collider"].get_meta("physics_kind","") == "NativeCaveHill")
	for z: float in [-1.0, -3.5, -5.7]:
		var source := WorldSpace3D.world_to_projected(cave_frame * Vector3(0, 0, z))
		check("deep visible recess retains the same descending FLOOR support", absf(game.spatial_world.height_at(source) - (-NativeCavePlan.SITE_DEPTH + NativeCavePlan.floor_height(z))) < .06, "z=%f actual=%f" % [z, game.spatial_world.height_at(source)])
	for step: int in 220:
		game.spatial_world.move_source_actor(game.player, game.player.position.move_toward(game.dungeon.entry_point(), 4.0), Player.RADIUS)
	check("walking out of the rock recess retains the existing transition interaction", game.dungeon.enter_block_reason().is_empty())
	await _frames(2)
	if check("existing cave entry remains playable", game.dungeon.enter()):
		renderer._sync_scope()
		environment.sync(0, true)
		var cave := environment.cave.get_node("NativeCaveScenery")
		var cave_report: Dictionary = cave.get_meta("native_scenery_report")
		check("all five room ribs have native owners while the first spike approach stays clear", cave_report["entries"].size() == 5 and cave_report["owned_source_ids"].size() == 5)
		for entry: Dictionary in cave_report["entries"]:
			var transform: Transform3D = entry["transform"]
			check("cave arch retains an upright positive native basis and measured opening", transform.basis.y.is_equal_approx(Vector3.UP) and transform.basis.determinant() > 0.99 and float(entry["clear_width"]) > 2.0)
		var low_rock_in_floor := 0
		for entry: Dictionary in cave_report["entries"]:
			var transform: Transform3D = entry["transform"]
			var arch: ArrayMesh = entry["mesh"]
			var vertices: PackedVector3Array = arch.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for triangle in range(0, vertices.size(), 3):
				# 실제 표면의 꼭짓점과 중심도 확인해 넓은 앞면의 침범을 놓치지 않는다.
				var samples: Array[Vector3] = [vertices[triangle], vertices[triangle + 1], vertices[triangle + 2], (vertices[triangle] + vertices[triangle + 1] + vertices[triangle + 2]) / 3.0]
				for point: Vector3 in samples:
					var world := transform * point
					var ground := Vector2(world.x, world.z) * WorldSpace3D.GROUND_UNITS_PER_METER
					if world.y - DungeonRelief.flat_height(ground) <= 1.85 and game.dungeon.layout.contains(Iso.project(ground)):
						var boundary_gap := INF
						for boundary: Dictionary in game.dungeon.layout.relief.boundary_segments:
							boundary_gap = minf(boundary_gap, ground.distance_to(Geometry2D.get_closest_point_to_segment(ground, boundary["a"], boundary["b"])))
						# contains는 공유 경계도 포함한다. 1mm보다 안쪽의 실제 침범만 센다.
						if boundary_gap > .065:
							low_rock_in_floor += 1
		check("room rib columns stay outside actual walkable floor below capsule headroom", low_rock_in_floor == 0, "overlapping samples=%d" % low_rock_in_floor)
		var cave_instance := cave.get_instance_id()
		game.dungeon.leave("")
		renderer._sync_scope()
		environment.sync(0, true)
		check("leaving cave hides its native props without a scenery leak", not environment.cave.visible and cave.get_instance_id() == cave_instance)
	game.queue_free()
	await _frames(2)


func _cave_vertex_key(point: Vector3) -> String:
	return "%d:%d:%d" % [roundi(point.x * 10000), roundi(point.y * 10000), roundi(point.z * 10000)]


## 앞면 천공이 둔덕 위로 뚫리는 결함은 깊은 중앙 한 점의 레이로 잡히지 않는다.
func _cave_roof_sample(points: PackedVector3Array, at: Vector2) -> Dictionary:
	var floor_height := NativeCavePlan.floor_height(at.y)
	var from_inside := Vector3(at.x, floor_height + 1.0, at.y)
	var from_above := Vector3(at.x, 7.0, at.y)
	var underside := INF
	var outside := -INF
	for triangle in range(0, points.size(), 3):
		var a := points[triangle]
		var b := points[triangle + 1]
		var c := points[triangle + 2]
		if at.x < minf(a.x, minf(b.x, c.x)) or at.x > maxf(a.x, maxf(b.x, c.x)):
			continue
		if at.y < minf(a.z, minf(b.z, c.z)) or at.y > maxf(a.z, maxf(b.z, c.z)):
			continue
		var inner_hit: Variant = Geometry3D.ray_intersects_triangle(from_inside, Vector3.UP, a, b, c)
		var outer_hit: Variant = Geometry3D.ray_intersects_triangle(from_above, Vector3.DOWN, a, b, c)
		if inner_hit is Vector3:
			underside = minf(underside, inner_hit.y)
		if outer_hit is Vector3:
			outside = maxf(outside, outer_hit.y)
	var valid := is_finite(underside) and is_finite(outside) and underside - floor_height > 1.90 and outside - underside >= .15
	return {"x": at.x, "z": at.y, "underside": underside, "outside": outside, "valid": valid}

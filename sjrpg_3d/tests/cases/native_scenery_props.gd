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
					deep_rock = deep_rock and nearest < -3.25 and nearest > -3.65
			check("entrance shows three metres of actual recessed stone instead of a flat dark plane", deep_rock and forest.find_children("TunnelDepth","MeshInstance3D",true,false).is_empty(),JSON.stringify(depths))
	check("actual field rocks and the existing scene-transition cave mouth have native owners", rock_count > 0 and entrance_count == 1)
	game.player.set_process(false)
	game.spatial_world.teleport_source_actor(game.player, game.dungeon.entry_point() + Vector2(0, 260), Player.RADIUS)
	for step: int in 80:
		game.spatial_world.move_source_actor(game.player, game.player.position.move_toward(game.dungeon.entry_point(), 4.0), Player.RADIUS)
	check("real capsule can approach the enlarged hill and use the original cave interaction", game.dungeon.enter_block_reason().is_empty(), JSON.stringify({"at":str(game.player.position),"entry":str(game.dungeon.entry_point()),"reason":game.dungeon.enter_block_reason()}))
	var hill_center := NativeCavePlan.body_center(game.dungeon.entry_point())
	for step: int in 100:
		game.spatial_world.move_source_actor(game.player, game.player.position.move_toward(hill_center, 4.0), Player.RADIUS)
	var cave_frame := NativeCavePlan.frame(game.dungeon.entry_point())
	var local := cave_frame.affine_inverse() * WorldSpace3D.projected_to_world(game.player.position)
	check("real capsule descends into the recess and stops at the rear rock", absf(local.x) < 1.96 and local.z < -2.0 and local.z > -3.5 and game.spatial_world.height_at(game.player.position) < -0.75,"local=%s height=%f" % [local,game.spatial_world.height_at(game.player.position)])
	var side_ray := PhysicsRayQueryParameters3D.create(cave_frame * Vector3(0,1.0,-1.0), cave_frame * Vector3(3.0,1.0,-1.0), SpatialWorld3D.SOLID)
	check("the actual entrance has solid rock at its side rather than a full circular blocker", not game.spatial_world.get_world_3d().direct_space_state.intersect_ray(side_ray).is_empty())
	var roof_ray := PhysicsRayQueryParameters3D.create(cave_frame * Vector3(0,1.0,-1.0), cave_frame * Vector3(0,4.0,-1.0), SpatialWorld3D.SOLID)
	var roof_hit: Dictionary = game.spatial_world.get_world_3d().direct_space_state.intersect_ray(roof_ray)
	check("the walkable entrance also has actual solid rock overhead", not roof_hit.is_empty() and roof_hit["collider"].get_meta("physics_kind","") == "NativeCaveHill")
	for step: int in 120:
		game.spatial_world.move_source_actor(game.player, game.player.position.move_toward(game.dungeon.entry_point(), 4.0), Player.RADIUS)
	check("walking out of the rock recess retains the existing transition interaction", game.dungeon.enter_block_reason().is_empty())
	await _frames(2)
	if check("existing cave entry remains playable", game.dungeon.enter()):
		renderer._sync_scope()
		environment.sync(0, true)
		var cave := environment.cave.get_node("NativeCaveScenery")
		var cave_report: Dictionary = cave.get_meta("native_scenery_report")
		check("all six actual passage arches have native owners", cave_report["entries"].size() == 6 and cave_report["owned_source_ids"].size() == 6)
		for entry: Dictionary in cave_report["entries"]:
			var transform: Transform3D = entry["transform"]
			check("cave arch retains an upright positive native basis and measured opening", transform.basis.y.is_equal_approx(Vector3.UP) and transform.basis.determinant() > 0.99 and float(entry["clear_width"]) > 2.0)
		var cave_instance := cave.get_instance_id()
		game.dungeon.leave("")
		renderer._sync_scope()
		environment.sync(0, true)
		check("leaving cave hides its native props without a scenery leak", not environment.cave.visible and cave.get_instance_id() == cave_instance)
	game.queue_free()
	await _frames(2)

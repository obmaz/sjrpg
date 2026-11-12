extends TestCase
## 알려진 방/분기의 고도, 같은 바닥 메시·실제 FLOOR·영웅의 경사 이동을 확인한다.


func run() -> void:
	var layout := DungeonLayout.new()
	var relief := layout.relief
	var expected := [0.0, -1.2, -.25, -1.8, -.7]
	for index in DungeonLayout.ROOMS.size():
		check(
			"each chamber has its authored plateau height %d" % index,
			is_equal_approx(DungeonRelief.flat_height(DungeonLayout.ROOMS[index]), expected[index])
		)
	check(
		"north and south branches offer visibly different elevations",
		is_equal_approx(
			(
				DungeonRelief.flat_height(Vector2(1100, -500))
				- DungeonRelief.flat_height(Vector2(1100, 500))
			),
			1.7
		)
	)
	var valid := true
	for index in range(0, relief.floor_faces.size(), 3):
		var a := relief.floor_faces[index]
		var b := relief.floor_faces[index + 1]
		var c := relief.floor_faces[index + 2]
		var at := (a + b + c) / 3.0
		valid = valid and absf(at.y - DungeonRelief.flat_height(Vector2(at.x, at.z) * 65)) < .002
		valid = valid and absf((b - a).cross(c - a).normalized().y) > .72
	check("the shared floor is continuous and every walking slope stays below forty degrees", valid)
	check("floor mesh resources are reused", relief.mesh() == relief.mesh())
	check(
		"union sampling never invents floor in the branch gap",
		not bool(relief.sample(Vector2(1100.0 / 65.0, 0)).get("found", false))
	)
	var no_slivers := true
	for cell: Rect2 in relief.cells:
		no_slivers = no_slivers and minf(cell.size.x, cell.size.y) > .01
	check("millimetre-canonical axes cannot produce microscopic duplicate cells", no_slivers)

	var boundaries := true
	for edge in relief.boundary_segments:
		var at: Vector2 = (edge["a"] + edge["b"]) * .5
		var normal: Vector2 = edge["outward"]
		boundaries = boundaries and layout.contains(Iso.project(at - normal * 4))
		boundaries = boundaries and not layout.contains(Iso.project(at + normal * 4))
	check("wall edges only enclose the actual floor union", boundaries)
	var game := await make_game("mage")
	game.set_process(false)
	game.player.set_process(false)
	game.player.position = game.dungeon.entry_point()
	check("enter the elevated cave through its normal interaction", game.dungeon.enter())
	await _frames(4)
	var spatial: SpatialWorld3D = game.spatial_world
	spatial.sync_scope()
	for enemy: Enemy in game.enemies:
		enemy.set_process(false)
	for index in DungeonLayout.ROOMS.size():
		var at := Iso.project(DungeonLayout.ROOMS[index])
		check(
			"real cave FLOOR reaches the measured chamber height %d" % index,
			absf(spatial.height_at(at) - float(expected[index])) < .002
		)
	var slope := WorldSpace3D.projected_to_world(Iso.project(Vector2(1975, 17)))
	var ray := PhysicsRayQueryParameters3D.create(
		slope + Vector3.UP * 20, slope - Vector3.UP * 20, SpatialWorld3D.FLOOR
	)
	ray.hit_back_faces = true
	var slope_hit: Dictionary = spatial.get_world_3d().direct_space_state.intersect_ray(ray)
	check(
		"the native FLOOR shape itself has the correct sloping surface",
		not slope_hit.is_empty() and absf(slope_hit["position"].y + .725) < .002
	)
	spatial.teleport_source_actor(game.player, Iso.project(Vector2(1550, 0)), Player.RADIUS)
	var supported := true
	var failed_steps: Array[String] = []
	for x in range(1558, 2401, 8):
		var target := Iso.project(Vector2(x, 0))
		spatial.move_source_actor(game.player, target, Player.RADIUS)
		var foot := spatial.actor_foot(game.player)
		supported = supported and game.player.position.distance_to(target) < .1
		supported = supported and absf(foot.y - spatial.height_at(game.player.position)) < .02
		if (
			(
				game.player.position.distance_to(target) >= .1
				or absf(foot.y - spatial.height_at(game.player.position)) >= .02
			)
			and failed_steps.size() < 4
		):
			failed_steps.append(
				(
					"x=%d hero=%s target=%s foot=%s floor=%.5f target_sample=%s blocked=%s"
					% [
						x,
						game.player.position,
						target,
						foot,
						spatial.height_at(game.player.position),
						spatial._floor_sample(target),
						spatial.blocked(target, Player.RADIUS)
					]
				)
			)
	check(
		"the actual capsule climbs the connecting ramp without skating or losing support",
		supported,
		"; ".join(failed_steps)
	)
	var surface := (
		game.world_renderer._world_environment.cave.get_node("CaveFloor") as MeshInstance3D
	)
	check(
		"one cached floor mesh replaces overlapping room surfaces",
		surface.mesh == game.dungeon.layout.relief.mesh()
	)
	spatial._cave_floor.collision_layer = 0
	await _frames(2)
	check(
		"support repair never overrides a disabled physical floor",
		not bool(spatial._floor_sample(game.player.position).get("found", false))
	)
	spatial._cave_floor.collision_layer = SpatialWorld3D.FLOOR
	await _frames(2)
	game.dungeon.leave("고도 검수 완료")
	await _frames(3)
	check("leaving restores forest physics", spatial.realm == "forest" and not game.dungeon.active)
	game.queue_free()
	await _frames(2)

extends TestCase
## The hero passage exemption never becomes a monster entrance. Source iron
## edges are checked at all heights through each actual rendered door plane.


func run() -> void:
	var game := await make_game()
	var gates: TownGateRuntime = game.town_gates
	gates.set_process(false)
	_check_art(gates)
	_check_boundary(game, gates)
	_check_melee_barrier(game, gates)
	await _check_threat_and_hero(game, gates)
	game.queue_free()
	await _frames(2)


func _check_art(gates: TownGateRuntime) -> void:
	var art := TownGateRuntime.Portcullis.art()
	for key in ["source", "texture", "generation", "measure"]:
		var record: Dictionary = art[key]
		check("portcullis source-backed %s hash" % key, FileAccess.get_sha256("res://" + str(record["path"])) == str(record["sha256"]))
	for record: Dictionary in art["references"]:
		check("portcullis retains its actual family reference", FileAccess.get_sha256("res://" + str(record["path"])) == str(record["sha256"]))
	var source := Image.load_from_file("res://" + str(art["source"]["path"]))
	check("iron lattice holes are actual transparency", source.get_pixel(160, 400).a < 0.01 and source.get_pixel(115, 400).a > 0.9)
	var worst := 0.0
	var parallel := 0.0
	var straightness := 0.0
	for index in gates.doors.size():
		var door: TownGateRuntime.Portcullis = gates.doors[index]
		door.set_progress(1.0)
		var horizontal: Array[float] = []
		var vertical: Array[float] = []
		var sampled := 0
		for segment: Dictionary in art["native_segments"]:
			var ends: Array = segment["points"]
			var first := Vector2(ends[0][0], ends[0][1])
			var last := Vector2(ends[1][0], ends[1][1])
			check("native measured iron endpoint exists", source.get_pixelv(Vector2i(first)).a > 0.4 and source.get_pixelv(Vector2i(last)).a > 0.4)
			var a := door.native_point(first)
			var b := door.native_point(last)
			var angle := rad_to_deg((b - a).angle())
			var expected := (30.0 if index < 2 else -30.0) if str(segment["axis"]) == "across" else 90.0
			var difference := absf(fposmod(angle - expected + 90.0, 180.0) - 90.0)
			worst = maxf(worst, difference)
			var relative := fposmod(angle - expected + 90.0, 180.0) - 90.0
			if str(segment["axis"]) == "across":
				horizontal.append(relative)
			else:
				vertical.append(relative)
			for sample in 11:
				var t := sample / 10.0
				var actual := door.drawn_native_point(first.lerp(last, t))
				if not is_finite(actual.x):
					continue
				sampled += 1
				straightness = maxf(straightness, actual.distance_to(a.lerp(b, t)))
		for axis in [horizontal, vertical]:
			axis.sort()
			parallel = maxf(parallel, float(axis[-1]) - float(axis[0]))
		check("door %d samples the real clipped upper/middle/lower iron mesh" % index, sampled >= 24, str(sampled))
		check("closed iron stays behind the existing arch and wooden leaves", door.z_index == -1 and not door.z_as_relative)
		door.set_progress(0.0)
	check("all four iron planes retain120-degree axes and parallel source edges", worst <= 2.5 and parallel <= 2.5, "axis=%f parallel=%f" % [worst, parallel])
	check("actual rendered iron edges stay straight internally", straightness < 0.02, str(straightness))


func _outward(index: int) -> Vector2:
	var axis := Iso.project(Vector2(0, 1) if index < 2 else Vector2(1, 0)).normalized()
	return axis * (-1.0 if index in [0, 2] else 1.0)


func _check_melee_barrier(game: Node, gates: TownGateRuntime) -> void:
	for index in 4:
		var center: Vector2 = game.village.gate_points[index]
		var direction := _outward(index)
		var outside := center + direction * 40.0
		var inside := center - direction * 40.0
		gates.closed[index] = false
		check("open passage adds no iron melee barrier", not gates.blocks_melee(outside, inside))
		gates.closed[index] = true
		check("closed iron blocks melee from both sides", not game.can_melee_reach(outside, inside) and not game.can_melee_reach(inside, outside))
		gates.closed[index] = false


func _check_boundary(game: Node, gates: TownGateRuntime) -> void:
	var native_safe := PackedVector2Array()
	for point: Vector2 in game.village.safe_zone:
		var native := WorldSpace3D.projected_to_world(point)
		native_safe.append(Vector2(native.x, native.z))
	var radius := SpatialWorld3D.radius_metres(float(Enemy.RADIUS))
	for index in 4:
		var centre: Vector2 = game.village.gate_points[index]
		var direction: Vector2 = _outward(index)
		var from := centre + direction * 300.0
		var target := centre - direction * 250.0
		var stopped: Vector2 = game.move_actor(from, target, Enemy.RADIUS, true)
		var native := WorldSpace3D.projected_to_world(stopped)
		# A circular native capsule projects to an ellipse. Its stand-off must be
		# measured in the same nativeXZ metres as the real safe-boundary collider.
		var clearance := TownGateRuntime.distance_to_polygon(Vector2(native.x, native.z), native_safe)
		check("monsters cannot cross open gate%d even in one long movement" % index, not game.in_town(stopped) and clearance >= radius - 0.005, "clearance=%s m, capsule=%s m" % [clearance, radius])
		check("direct long monster movement cannot tunnel into town", gates.resolve_actor(from, target, Enemy.RADIUS, true) == from)
	var centre := Vector2.ZERO
	for corner: Vector2 in game.village.safe_zone:
		centre += corner
	centre /= game.village.safe_zone.size()
	for corner: Vector2 in game.village.safe_zone:
		var direction: Vector2 = (corner - centre).normalized()
		var stopped: Vector2 = game.move_actor(corner + direction * 240.0, corner - direction * 120.0, Enemy.RADIUS, true)
		var native := WorldSpace3D.projected_to_world(stopped)
		var clearance := TownGateRuntime.distance_to_polygon(Vector2(native.x, native.z), native_safe)
		check("monster bodies cannot cut across a town corner", not game.in_town(stopped) and clearance >= radius - 0.005, "clearance=%s m, capsule=%s m" % [clearance, radius])


func _minimum_distance(gates: TownGateRuntime, point: Vector2) -> float:
	var distance := INF
	for polygon in gates._walls:
		distance = minf(distance, TownGateRuntime.distance_to_polygon(point, polygon))
	return distance


func _check_threat_and_hero(game: Node, gates: TownGateRuntime) -> void:
	var enemy := Enemy.new()
	enemy.setup(game, "goblin", 1)
	var centre: Vector2 = game.village.gate_points[0]
	var outward: Vector2 = _outward(0)
	enemy.position = centre + outward * 120.0
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	enemy.set_process(false)
	game.player.set_process(false)
	game.player.position = game.village.spawn_point
	gates.advance(0.15)
	check("a live monster near a wall closes all four gates", gates.danger and gates.closed.all(func(value: bool) -> bool: return value))
	check("closed gates have real passage collision", game._blocked(centre, Player.RADIUS) and gates.blocks(centre, Player.RADIUS))
	var lingering := false
	for distance in range(200, 501, 10):
		var point := centre + outward * float(distance)
		var nearest := _minimum_distance(gates, point)
		if nearest > TownGateRuntime.CLOSE_DISTANCE + 5.0 and nearest < TownGateRuntime.CLEAR_DISTANCE - 5.0:
			enemy.position = point
			lingering = true
			break
	gates.advance(0.2)
	check("distance hysteresis prevents gate chatter", lingering and gates.danger)
	game.player.position = centre
	gates.advance(0.15)
	check("the hero in the doorway opens only that safe passage", not gates.closed[0] and gates.closed[1] and gates.closed[2] and gates.closed[3])
	var from := centre + outward * 250.0
	var to := centre - outward * 100.0
	check("hero access cannot admit a pursuing monster", gates.resolve_actor(from, to, Enemy.RADIUS, true) == from)
	game.player.position = game.village.spawn_point
	gates.advance(0.15)
	check("the threatened door closes again after the hero clears it", gates.closed[0])
	get_tree().paused = true
	gates.set_process(true)
	var before: float = gates.progress[0]
	await _frames(3)
	check("menu pause stops gate animation and threat scanning", gates.progress[0] == before)
	get_tree().paused = false
	gates.set_process(false)
	enemy.dead = true
	gates.advance(0.15)
	check("gates do not reopen on a single empty scan", gates.danger)
	for step in 10:
		gates.advance(0.15)
	check("dead threats release the gates after the clear delay", not gates.danger and gates.closed.all(func(value: bool) -> bool: return not value))
	game.player.position = game.dungeon.entry_point()
	check("forest gate control does not block cave entry", game.dungeon.enter())
	gates.advance(1.0)
	check("forest closed geometry is inactive in caves", not gates.blocks(Vector2.ZERO, Player.RADIUS))
	game.dungeon.leave("")

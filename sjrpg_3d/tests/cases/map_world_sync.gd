extends TestCase
## 실제 GLB 루트/문짝과 같은 개수의 도형 이동·변형·제거를 두 지도에 반영한다.


func _shape(game: Node, id: String) -> Dictionary:
	for shape in game.map_shapes:
		if shape["id"] == id:
			return shape
	return {}


func _marker(game: Node, id: String) -> Dictionary:
	for marker in MapGeometry.markers(game):
		if marker["id"] == id:
			return marker
	return {}


func run() -> void:
	var game := await make_game("mage")
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var model: MapWorldState = game.map_state
	model.refresh(true)
	var mesh := model.full_mesh
	var revision := model.revision
	var checks := model.source_checks
	for index in 120:
		model.refresh()
	check("all consumers share one source check in the same frame", model.source_checks == checks)
	for index in 10:
		model.refresh(true)
	check(
		"unchanged world retains the same uploaded whole-map mesh",
		model.revision == revision and model.full_mesh == mesh
	)
	var house: Dictionary = game.world_renderer._houses["nw"]
	var root := NativePlayerOcclusion.static_owner(house["meshes"][0]) as Node3D
	var original := root.transform
	var before: PackedVector2Array = _shape(game, "building:nw")["poly"]
	var count: int = game.map_shapes.size()
	var displacement := Vector3(3, 0, -2)
	root.position += displacement
	model.refresh(true)
	var after: PackedVector2Array = _shape(game, "building:nw")["poly"]
	var delta := WorldSpace3D.world_to_projected(displacement)
	var moved := before.size() == after.size()
	for index in before.size():
		moved = moved and after[index].distance_to(before[index] + delta) < .001
	check(
		"same-count GLB relocation changes the map by the actual native displacement",
		moved and count == game.map_shapes.size() and model.revision == revision + 1
	)
	var minimap: Minimap = game.hud.minimap
	minimap._update_geometry(game.player.position)
	var mini_before := minimap.geometry_rebuilds
	root.scale *= 1.2
	model.refresh(true)
	minimap._update_geometry(game.player.position)
	check(
		"resizing a real static object invalidates the minimap while the hero stands still",
		minimap.geometry_rebuilds == mini_before + 1
	)
	root.transform = original
	model.refresh(true)
	var stage: Node = root.get_parent()
	var detached := Node3D.new()
	root.reparent(detached, false)
	model.refresh(true)
	check(
		"removing a rendered building removes its outline without changing marker count",
		_shape(game, "building:nw").is_empty()
	)
	root.reparent(stage, false)
	root.transform = original
	model.refresh(true)
	# 원래 루트가 살아 있고 자식 수도 같은 한 프레임 내 교체를 검사한다.
	root.reparent(detached, false)
	var replacement := Node3D.new()
	replacement.set_meta("native_house", house)
	stage.add_child(replacement)
	replacement.transform = original
	replacement.position += Vector3(2, 0, 1)
	model.refresh(true)
	check(
		"same-count replacement uses the new root while the detached old root remains alive",
		(_shape(game, "building:nw")["poly"] as PackedVector2Array) != before
	)
	stage.remove_child(replacement)
	replacement.free()
	root.reparent(stage, false)
	root.transform = original
	detached.free()
	model.refresh(true)
	check(
		"restoring the same building restores its actual footprint",
		(_shape(game, "building:nw")["poly"] as PackedVector2Array) == before
	)
	var fortress: FortificationRenderer3D = game.world_renderer._fortification
	var saved: Array = game.town_gates.progress.duplicate()
	var old_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = false
	game.town_gates.progress.assign([1.0, 1.0, 1.0, 1.0])
	fortress.sync()
	model.refresh(true)
	var closed: PackedVector2Array = _shape(game, "gate:0:0")["poly"]
	game.town_gates.progress[0] = .5
	fortress.sync()
	model.refresh(true)
	var opening: PackedVector2Array = _shape(game, "gate:0:0")["poly"]
	check(
		"gate outline follows the actual opening leaf rather than a cached closed passage",
		opening != closed and opening[0].distance_to(closed[0]) > 1
	)
	game.town_gates.progress.assign(saved)
	Prefs.reduce_motion = old_reduce
	fortress.sync()
	var npc: Node2D = game.village.npc_nodes["상인"]
	var npc_original := npc.position
	npc.position += Vector2(90, 35)
	check(
		"facility marker follows the live NPC rather than npc_points",
		(
			_marker(game, "npc:상인")["pos"] == npc.position
			and _marker(game, "npc:상인")["pos"] != game.village.npc_points["상인"]
		)
	)
	npc.position = npc_original
	GameState.discovered_sanctuaries.append("cave")
	var waypoint: Node2D = game.village.portal_sprites["cave"]
	var waypoint_original := waypoint.position
	waypoint.position += Vector2(70, 15)
	check(
		"discovered waypoint follows the rendered source rather than cached sanctuary_points",
		_marker(game, "sanctuary:cave")["pos"] == waypoint.position
	)
	waypoint.position = waypoint_original
	GameState.discovered_sanctuaries.erase("cave")
	check(
		"forest cave pin is the real entry interaction point",
		(
			_marker(game, "cave:entrance")["pos"] == game.dungeon.entry_point()
			and _marker(game, "cave:entrance")["pos"] != Iso.project(game.village.cave_ground)
		)
	)
	game.spatial_world.teleport_source_actor(game.player, game.dungeon.entry_point(), Player.RADIUS)
	if check("real cave entry succeeds", game.dungeon.enter()):
		model.refresh(true)
		check(
			"cave transition immediately removes all forest building shapes",
			_shape(game, "building:nw").is_empty() and not _shape(game, "cave:0").is_empty()
		)
		var portal := game.world.get_node("CaveReturnPortal") as Node2D
		portal.position += Vector2(45, 10)
		check(
			"return marker tracks the real portal rather than the EXIT constant",
			_marker(game, "cave:return")["pos"] == portal.position
		)
		# 지도는 이전 평면 방 배열이 아니라 실제 FLOOR 설계의 합집합 셀을 읽는다.
		var relief: DungeonRelief = game.dungeon.layout.relief
		var cell: Rect2 = relief.cells[0]
		var previous := model.revision
		cell.position += Vector2(-.12, 0)
		relief.cells[0] = cell
		model.refresh(true)
		check(
			"same-count shared cave floor edits invalidate geometry",
			(
				model.revision == previous + 1
				and (
					_shape(game, "cave:0")["poly"][0].distance_to(Iso.project(cell.position * 65))
					< .001
				)
			)
		)
		game.dungeon.leave("", false)
		model.refresh(true)
		check(
			"return restores current forest geometry and discards cave floor",
			not _shape(game, "building:nw").is_empty() and _shape(game, "cave:0").is_empty()
		)
	game.queue_free()
	await _frames(2)

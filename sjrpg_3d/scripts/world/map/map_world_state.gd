class_name MapWorldState
extends RefCounted
## 두 지도에 같은 스냅샷을 공급한다. 도형의 내용/실제 정적 루트 변환이 바뀔 때만 재생성한다.
var game: Node
var revision := 0
var full_mesh: ArrayMesh
var _signature := 0
var _ready_snapshot := false
var _roots := {}
var _registry_key: Array = []
var _native_bound := false
var source_checks := 0
var _polled_frame := -1
var _polled_cave := false


func setup(source: Node) -> MapWorldState:
	game = source
	return self


func _bind_native() -> void:
	if not game.native_ready or game.world_renderer == null:
		return
	var renderer: WorldRenderer3D = game.world_renderer
	var stage := renderer.stage
	var forest := renderer._forest_stage
	if stage == null or forest == null:
		return
	var key := [stage.get_instance_id(), stage.get_child_count(), forest.get_child_count()]
	var valid := key == _registry_key
	for reference: WeakRef in _roots.values():
		var root: Node3D = reference.get_ref()
		valid = (
			valid
			and is_instance_valid(root)
			and not root.is_queued_for_deletion()
			and root.get_parent() in [stage, forest]
		)
	if valid:
		return
	_registry_key = key
	_roots.clear()
	for root in stage.get_children() + forest.get_children():
		if root.is_queued_for_deletion():
			continue
		if root.has_meta("native_house"):
			var report: Dictionary = root.get_meta("native_house")
			_roots["building:" + str(report["key"])] = weakref(root)
		elif root.has_meta("chapel_detail"):
			_roots["building:chapel"] = weakref(root)
		elif root.has_meta("fortification_detail"):
			_roots["fortress"] = weakref(root)
	var bridge := forest.get_node_or_null("NativeDetailedBridge")
	if bridge != null and not bridge.is_queued_for_deletion():
		_roots["bridge"] = weakref(bridge)
	_native_bound = true


func _root(id: String) -> Node3D:
	var reference: WeakRef = _roots.get(id)
	if reference == null:
		return null
	var root: Node3D = reference.get_ref()
	return root if is_instance_valid(root) and not root.is_queued_for_deletion() else null


func _source_signature() -> int:
	if game.dungeon.active:
		return hash(
			[
				"cave",
				game.dungeon.get_instance_id(),
				game.dungeon.layout.relief.cells if game.dungeon.layout != null else game.map_shapes
			]
		)
	_bind_native()
	var village: Village = game.village
	var source: Array = [
		"forest",
		village.safe_zone,
		village.river.polygon,
		village.map_roads,
		village.bridge.deck_polygon(),
		village.wall_footprints,
		village.sanctuary_points,
		village.cave_ground,
		_native_bound
	]
	for surface: Dictionary in SpatialWorld3D.terrain_surfaces(village):
		source.append([surface["id"], surface["top"]])
	for landmark in village.landmarks:
		source.append(landmark.water)
	for key: String in village.buildings:
		var sprite: IsoSprite = village.buildings[key]
		source.append(sprite.global_transform)
	for id: String in _roots:
		var root := _root(id)
		if root == null:
			continue
		source.append([id, root.global_transform])
		if id == "fortress":
			var report: Dictionary = root.get_meta("fortification_detail")
			source.append([report["wall_polygons"], report["corners"]])
			for gate: Dictionary in report["gates"]:
				for leaf: Node3D in gate["leaves"]:
					if is_instance_valid(leaf) and not leaf.is_queued_for_deletion():
						source.append(leaf.global_transform)
		elif id == "bridge":
			var data: Dictionary = root.get_meta("bridge_detail")
			source.append([data["length_m"], data["width_m"]])
		elif root.has_meta("native_house"):
			var data: Dictionary = root.get_meta("native_house")
			source.append(data["footprint"])
		elif root.has_meta("chapel_detail"):
			var data: Dictionary = root.get_meta("chapel_detail")
			source.append(data["footprint"])
	return source.hash()


func refresh(force_check := false) -> bool:
	var frame := Engine.get_process_frames()
	if not force_check and frame == _polled_frame and _polled_cave == game.dungeon.active:
		return false
	_polled_frame = frame
	_polled_cave = game.dungeon.active
	source_checks += 1
	var current := _source_signature()
	if _ready_snapshot and current == _signature:
		return false
	_signature = current
	_ready_snapshot = true
	var shapes: Array[Dictionary] = []
	if game.dungeon.active:
		if game.dungeon.layout == null:
			shapes = game.map_shapes
		else:
			# 실제 FLOOR 셀과 높이를 그대로 표시한다. 위/아래 길의 좌표는 바꾸지 않는다.
			var relief: DungeonRelief = game.dungeon.layout.relief
			for index in relief.cells.size():
				var cell: Rect2 = relief.cells[index]
				var polygon := PackedVector2Array()
				for point: Vector2 in [
					cell.position,
					Vector2(cell.end.x, cell.position.y),
					cell.end,
					Vector2(cell.position.x, cell.end.y)
				]:
					polygon.append(Iso.project(point * 65))
				var height := DungeonRelief.flat_height(cell.get_center() * 65)
				var ink := Color("565c60").lerp(Color("a39b83"), clampf((height + 2.4) / 3.5, 0, 1))
				shapes.append(MapGeometry.shape("cave:%d" % index, "floor", polygon, ink))

	else:
		shapes = MapGeometry.build(game.village)
		if _native_bound:
			shapes = _native_shapes(shapes)
	game.map_shapes = shapes
	full_mesh = MapMesh.update(shapes, full_mesh)
	revision += 1
	return true


static func _project(points: PackedVector2Array, frame: Transform3D) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(WorldSpace3D.world_to_projected(frame * Vector3(point.x, 0, point.y)))
	return result


static func _rectangle(size: Vector2) -> PackedVector2Array:
	return ChapelPlan3D.polygon(Rect2(-size * 0.5, size))


func _native_shapes(source: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in source:
		var kind: String = entry["kind"]
		var id: String = entry["id"]
		if kind == "wall":
			continue
		if kind not in ["building", "bridge"]:
			result.append(entry)
			continue
		var root := _root(id)
		if root == null:
			continue
		var local: PackedVector2Array
		if kind == "bridge":
			var data: Dictionary = root.get_meta("bridge_detail")
			local = ChapelPlan3D.polygon(
				Rect2(0, 0, float(data["length_m"]), float(data["width_m"]))
			)
		else:
			var data: Dictionary = root.get_meta(
				"chapel_detail" if id == "building:chapel" else "native_house"
			)
			var footprint: Vector2 = data["footprint"]
			local = (
				ChapelPlan3D.body_polygon(Vector2.ZERO, footprint.x, footprint.y)
				if id == "building:chapel"
				else _rectangle(footprint)
			)
		result.append(
			MapGeometry.shape(id, kind, _project(local, root.global_transform), entry["color"])
		)
	var fortress := _root("fortress")
	if fortress != null:
		var data: Dictionary = fortress.get_meta("fortification_detail")
		for index in data["wall_polygons"].size():
			result.append(
				MapGeometry.shape(
					"wall:%d" % index,
					"wall",
					_project(data["wall_polygons"][index], fortress.global_transform),
					Color("42423c")
				)
			)
		for index in data["corners"].size():
			var centre: Vector3 = data["corners"][index]
			var circle := PackedVector2Array()
			for step in 16:
				circle.append(
					(
						Vector2(centre.x, centre.z)
						+ Vector2.from_angle(TAU * step / 16.0) * FortressPlan3D.CORNER_RADIUS
					)
				)
			result.append(
				MapGeometry.shape(
					"tower:%d" % index,
					"tower",
					_project(circle, fortress.global_transform),
					Color("55534a")
				)
			)
		for index in data["gates"].size():
			var gate: Dictionary = data["gates"][index]
			for side in gate["leaves"].size():
				var leaf: Node3D = gate["leaves"][side]
				if not is_instance_valid(leaf) or leaf.is_queued_for_deletion():
					continue
				var bounds := _leaf_bounds(leaf)
				result.append(
					MapGeometry.shape(
						"gate:%d:%d" % [index, side],
						"gate",
						_project(ChapelPlan3D.polygon(bounds), leaf.global_transform),
						Color("946b46")
					)
				)
	return result


func _leaf_bounds(leaf: Node3D) -> Rect2:
	if leaf.has_meta("map_footprint"):
		return leaf.get_meta("map_footprint")
	var bounds := Rect2()
	var first := true
	for node in leaf.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var frame := leaf.global_transform.affine_inverse() * mesh.global_transform
		for index in 8:
			var point := frame * mesh.get_aabb().get_endpoint(index)
			var at := Vector2(point.x, point.z)
			bounds = Rect2(at, Vector2.ZERO) if first else bounds.expand(at)
			first = false
	leaf.set_meta("map_footprint", bounds)
	return bounds

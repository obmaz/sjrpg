class_name TreeDamageRenderer3D
extends RefCounted
## 정상 숲의 청크/인덱스는 고정. 바뀐 상태만 같은 청크의 공유 메시 배치로 옮긴다.

var renderer: WorldRenderer3D
var root: Node3D
var debris: TreeDebris3D
var _entries: Dictionary = {}
var _batches: Dictionary = {}
var _shown: Dictionary = {}
var _revision := -1


func setup(presenter: WorldRenderer3D) -> TreeDamageRenderer3D:
	renderer = presenter
	var forest: Node3D = renderer._world_environment.forest
	root = Node3D.new()
	root.name = "TreeDamage"
	forest.add_child(root)
	var normal := forest.get_node("NativeForestTrees")
	for entry: Dictionary in normal.get_meta("native_forest_tree_report")["trees"]:
		_entries[entry["key"]] = entry
		var batch: MultiMeshInstance3D = entry["batch"]
		if not batch.has_meta("occlusion_transforms"):
			var frames: Array[Transform3D] = []
			frames.resize(batch.multimesh.instance_count)
			batch.set_meta("occlusion_transforms", frames)
		var frames: Array = batch.get_meta("occlusion_transforms")
		frames[entry["index"]] = entry["local_transform"]
	for variant in TreeGeometry3D.PATHS.size():
		for state in ["burning", "frozen", "charred", "ash", "felled"]:
			renderer._occlusion.prepare_mesh(TreeDamageGeometry3D.mesh(variant, state))
	debris = TreeDebris3D.new().setup(root)
	renderer._occlusion.prepare_mesh(debris.embers.multimesh.mesh)
	return self


func _state_batch(entry: Dictionary, state: String) -> MultiMeshInstance3D:
	var original: MultiMeshInstance3D = entry["batch"]
	var key := "%d:%s" % [original.get_instance_id(), state]
	if _batches.has(key):
		return _batches[key]
	var group := Node3D.new()
	group.name = "Tree_%s_%d" % [state, _batches.size()]
	root.add_child(group)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = TreeDamageGeometry3D.mesh(entry["variant"], state)
	multi.instance_count = original.multimesh.instance_count
	multi.custom_aabb = original.multimesh.custom_aabb
	var draw := MultiMeshInstance3D.new()
	draw.name = "DamageInstances"
	draw.multimesh = multi
	draw.transform = original.transform
	draw.set_meta("occlusion_static_instances", true)
	draw.set_meta("occlusion_transforms", original.get_meta("occlusion_transforms"))
	var mask := PackedByteArray()
	mask.resize(multi.instance_count)
	mask.fill(0)
	draw.set_meta("occlusion_enabled_instances", mask)
	draw.set_meta("tree_active_count", 0)
	draw.visible = false
	group.add_child(draw)
	for index in multi.instance_count:
		multi.set_instance_transform(index, TreeDebris3D._hidden())
		multi.set_instance_color(index, Color.WHITE)
	renderer._occlusion.register_static_root(group)
	_batches[key] = draw
	return draw


func sync(delta: float) -> void:
	var runtime: ForestTreeRuntime = renderer.game.forest_trees
	if _revision != runtime.revision:
		for key: String in _entries:
			var state := runtime.state(key)
			if _shown.get(key, "") != state:
				_show(_entries[key], state)
				_shown[key] = state
		_revision = runtime.revision
	var visible := renderer.source_view_rect(150.0)
	for event in runtime.take_events():
		if (
			not renderer.game.dungeon.active
			and visible.has_point(runtime.entries[event["key"]]["point"])
		):
			debris.burst(_entries[event["key"]]["position"], event["kind"])
	var burning: Array[Vector3] = []
	if not renderer.game.dungeon.active:
		for key: String in GameState.forest_trees:
			if runtime.state(key) == "burning" and visible.has_point(runtime.entries[key]["point"]):
				burning.append(_entries[key]["position"])
				if burning.size() == TreeDebris3D.FIRE_LIMIT:
					break
	debris.sync(delta, burning, renderer.camera.global_basis)


func _show(entry: Dictionary, state: String) -> void:
	var key: String = entry["key"]
	var old: String = _shown.get(key, "healthy")
	var normal: MultiMeshInstance3D = entry["batch"]
	var index: int = entry["index"]
	if old != "healthy":
		_set_enabled(_state_batch(entry, old), index, false)
	var original := state == "healthy"
	_set_enabled(normal, index, original)
	if not original:
		_set_enabled(_state_batch(entry, state), index, true)


func _set_enabled(draw: MultiMeshInstance3D, index: int, enabled: bool) -> void:
	var previous := NativePlayerOcclusion.instance_enabled(draw, index)
	if previous != enabled:
		var count: int = draw.get_meta("tree_active_count", draw.multimesh.instance_count)
		count += 1 if enabled else -1
		draw.set_meta("tree_active_count", count)
		draw.visible = count > 0
	renderer._occlusion.set_instance_enabled(draw, index, enabled)


func snapshot() -> Dictionary:
	return {
		"changed": GameState.forest_trees.size(),
		"state_batches": _batches.size(),
		"fragments": debris._particles.size(),
		"fragment_limit": TreeDebris3D.LIMIT,
		"emitted": debris.emitted,
		"revision": _revision
	}

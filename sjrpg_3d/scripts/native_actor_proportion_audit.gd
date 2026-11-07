class_name NativeActorProportionAudit
extends RefCounted
## Explicit review only. CPU rest-space bounds + current bone poses; never read
## GPU buffers or modify model/skeleton/gameplay transforms to make a ratio fit.
static var _cache: Dictionary = {}


static func _bounds(model: Node3D, camera: Camera3D, exclude_equipment: bool) -> Dictionary:
	var nodes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		nodes.append(model)
	var bounds: AABB = AABB()
	var first: bool = true
	var excluded: Array[String] = []
	var included: Array[String] = []
	var skinned: Array[String] = []
	for node: Node in nodes:
		var instance: MeshInstance3D = node as MeshInstance3D
		if instance.mesh == null or not instance.visible:
			continue
		var path: String = str(model.get_path_to(instance))
		var lower: String = path.to_lower()
		if exclude_equipment and ("wand" in lower or "crystal" in lower or "sword" in lower):
			excluded.append(path)
			continue
		var box: AABB = instance.global_transform * instance.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		included.append(path)
		if instance.skin != null:
			skinned.append(path)
	if first:
		return {"valid": false, "included": included, "excluded": excluded}
	var screen_min: Vector2 = Vector2(INF, INF)
	var screen_max: Vector2 = Vector2(-INF, -INF)
	for corner: int in 8:
		var point: Vector3 = bounds.get_endpoint(corner)
		var pixel: Vector2 = camera.unproject_position(point)
		screen_min = screen_min.min(pixel)
		screen_max = screen_max.max(pixel)
	return {"valid": true, "bounds_kind": "mesh_rest_aabb_with_instance_global_transforms", "posed_geometry": false,
		"height_m": bounds.size.y, "width_m": bounds.size.x, "depth_m": bounds.size.z,
		"min": [bounds.position.x, bounds.position.y, bounds.position.z], "max": [bounds.end.x, bounds.end.y, bounds.end.z],
		"screen_aabb_height_upper_bound_px": screen_max.y - screen_min.y,
		"included": included, "excluded": excluded, "skinned_meshes": skinned}


static func _bones(model: Node3D) -> Dictionary:
	var results: Array[Dictionary] = []
	var head_y: float = -INF
	var foot_y: float = INF
	for candidate: Node in model.find_children("*", "Skeleton3D", true, false):
		var skeleton: Skeleton3D = candidate as Skeleton3D
		for index: int in skeleton.get_bone_count():
			var name: String = skeleton.get_bone_name(index)
			var key: String = name.to_lower()
			if key != "head" and not key.contains("foot") and not key.contains("toe"):
				continue
			var pose: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(index)
			var at: Vector3 = pose.origin
			results.append({"name": name, "world": [at.x, at.y, at.z]})
			if key == "head":
				head_y = maxf(head_y, at.y)
			else:
				foot_y = minf(foot_y, at.y)
	var available: bool = is_finite(head_y) and is_finite(foot_y)
	return {"bones": results, "current_head_to_lowest_foot_m": head_y - foot_y if available else -1.0,
		"current_head_y": head_y if is_finite(head_y) else null, "current_foot_y": foot_y if is_finite(foot_y) else null,
		"available": available, "note": "current bone origins; head origin excludes skull/hood height"}


static func measure(presenter: Node) -> Dictionary:
	var actor: Node3D = presenter.actor
	if not is_instance_valid(actor):
		return {"available": false}
	var id: int = actor.get_instance_id()
	if _cache.has(id):
		return _cache[id]
	var camera: Camera3D = presenter.camera
	var hero: Dictionary = _bounds(actor, camera, true)
	var npc_heights: Array[float] = []
	var residents: Array[Dictionary] = []
	var renderer: RefCounted = presenter.get("_native_residents")
	if renderer != null:
		var entries: Dictionary = renderer.get("entries")
		for entry: Dictionary in entries.values():
			var model: Node3D = entry["node"]
			var source: Villager = entry["owner"].get_ref()
			if not is_instance_valid(model) or not is_instance_valid(source):
				continue
			var report: Dictionary = _bounds(model, camera, false)
			report["label"] = source.display_name
			residents.append(report)
			if bool(report.get("valid", false)):
				npc_heights.append(float(report["height_m"]))
	npc_heights.sort()
	var median: float = npc_heights[npc_heights.size() / 2] if not npc_heights.is_empty() else 0.0
	var report: Dictionary = {"available": bool(hero.get("valid", false)), "hero_class": GameState.hero_class,
		"measured_frame": Engine.get_process_frames(), "hero_root_scale": [actor.scale.x, actor.scale.y, actor.scale.z],
		"hero": hero, "current_skeleton": _bones(actor), "residents": residents, "npc_median_height_m": median,
		"hero_rest_to_npc_median_ratio": float(hero.get("height_m", 0.0)) / median if median > 0.0 else -1.0,
		"interpretation": "CPU rest AABB is not posed/skinned silhouette and includes hidden geometry; bone origins are current pose. Screen AABB is an upper bound, not pixel visibility/occlusion. No GPU bake performed."}
	_cache[id] = report
	return report

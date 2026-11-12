class_name NativePlayerOcclusion
extends RefCounted
## 시각 전용. 충돌·배칭 원본·공유 재질은 보존하고 가리는 인스턴스만 잠시 분리한다.
const MIN_OPACITY := 0.20
const INTERVAL := 0.10
const CACHE_OBJECTS := 16
var renderer: WorldRenderer3D
var material_builds := 0
var instance_builds := 0
var triangle_builds := 0
var warmed_materials := 0
var last_query_us := 0
var maximum_query_us := 0
var query_candidates := 0
var _roots := {}
var _shaders := {}
var _triangles := {}
var _entries: Array[Dictionary] = []
var _active := {}
var _objects := {}
var _fades := {}
var _retired: Array[Dictionary] = []
var _templates := {}
var _samples := {}
var _prepared := {}
var _object_inks := {}
var _recent: Array[String] = []
var _spatial_index := NativeOcclusionIndex.new()
var _clock := INTERVAL
var _debug_disabled := false


func setup(presenter: WorldRenderer3D) -> NativePlayerOcclusion:
	renderer = presenter
	if OS.has_feature("web") and renderer._probe_enabled:
		_debug_disabled = bool(
			JavaScriptBridge.eval("new URLSearchParams(location.search).get('occlusion') === 'off'")
		)
	return self


## 제작자 계약: 분리된 벽·지붕도 같은 루트에 표시하면 하나의 정적 오브젝트다.
static func mark_object(node: Node) -> void:
	node.set_meta("occlusion_static_object", true)


static func static_owner(node: Node) -> Node:
	var owner: Node
	var cursor := node
	while cursor != null:
		if (
			cursor.get_meta("occlusion_dynamic", false)
			or cursor is CharacterBody3D
			or cursor is Skeleton3D
		):
			return null
		if owner == null and cursor.get_meta("occlusion_static_object", false):
			owner = cursor
		cursor = cursor.get_parent()
	return owner


func _register(root: Node3D) -> void:
	if not is_instance_valid(root) or _roots.has(root.get_instance_id()):
		return
	_entries = _entries.filter(func(entry: Dictionary): return is_instance_valid(entry["node"]))
	for key in _objects.keys():
		_objects[key] = _objects[key].filter(
			func(entry: Dictionary): return is_instance_valid(entry["node"])
		)
		if _objects[key].is_empty():
			_objects.erase(key)
	_roots[root.get_instance_id()] = true
	for child in root.find_children("*", "GeometryInstance3D", true, false):
		var owner := static_owner(child)
		var object_key := "object:%s" % owner.get_instance_id() if owner != null else ""
		if child is MeshInstance3D and child.mesh != null and not object_key.is_empty():
			_add_entry(
				{"node": child, "index": -1, "box": child.mesh.get_aabb(), "object": object_key}
			)
		elif (
			child is MultiMeshInstance3D
			and child.multimesh != null
			and child.multimesh.mesh != null
		):
			var mesh: MultiMesh = child.multimesh
			var owners: Array = child.get_meta("occlusion_objects", [])
			var frames: Array = child.get_meta("occlusion_transforms", [])
			for index in mesh.instance_count:
				var key: String = owners[index] if index < owners.size() else object_key
				if key.is_empty() and child.get_meta("occlusion_static_instances", false):
					key = "instance:%s:%s" % [child.get_instance_id(), index]
				if key.is_empty():
					continue
				_add_entry(
					{
						"node": child,
						"index": index,
						"box": mesh.mesh.get_aabb(),
						"transform":
						(
							frames[index]
							if index < frames.size()
							else mesh.get_instance_transform(index)
						),
						"object": key
					}
				)


func _add_entry(entry: Dictionary) -> void:
	_spatial_index.add(entry)
	_prime(entry)
	_entries.append(entry)
	var key: String = entry["object"]
	if not _objects.has(key):
		_objects[key] = []
	_objects[key].append(entry)


func _collect() -> void:
	_register(renderer._forest_stage)
	_register(renderer._world_environment.cave)
	for props in [renderer._town_props, renderer._encounter_props]:
		for entry: Dictionary in props._entries.values():
			mark_object(entry["root"])
			_register(entry["root"])


## 첫 가림 때 BVH·투명 셰이더를 만들지 않고 로딩 화면 뒤에서 실제로 그린다.
func warm_up() -> void:
	_collect()
	if _debug_disabled or DisplayServer.get_name() == "headless":
		return
	warmed_materials = await NativeOcclusionWarmup.draw(renderer, _samples.values())


func _prime(entry: Dictionary) -> void:
	var source: GeometryInstance3D = entry["node"]
	var mesh: Mesh = source.multimesh.mesh if entry["index"] >= 0 else source.mesh
	var mesh_id := mesh.get_instance_id()
	var box: AABB = entry["world_box"]
	if box.size.y >= 0.45 and not _triangles.has(mesh_id):
		_triangles[mesh_id] = mesh.generate_triangle_mesh()
		triangle_builds += 1
	for index in mesh.get_surface_count():
		var material: Material = source.material_override
		if material == null:
			material = (
				source.get_surface_override_material(index) if source is MeshInstance3D else null
			)
		if material == null:
			material = mesh.surface_get_material(index)
		var ink := _template(material)
		var format: String = (
			str(mesh.surface_get_format(index)) if mesh is ArrayMesh else mesh.get_class()
		)
		var key := "%s:%s" % [ink.get_instance_id(), format]
		if not _samples.has(key):
			_samples[key] = {"mesh": mesh, "ink": ink}


func sync(delta: float) -> void:
	if _debug_disabled or not renderer.game.native_ready:
		return
	_retired = _retired.filter(
		func(entry: Dictionary): return entry["until"] > Engine.get_process_frames()
	)
	_collect()
	_clock += delta
	if _clock >= INTERVAL:
		_clock = 0.0
		_find_occluders()
	for fade: Dictionary in _fades.values():
		fade["alpha"] = move_toward(
			fade["alpha"], MIN_OPACITY if fade["wanted"] else 1.0, delta * 4.5
		)
	for key in _active.keys():
		var state: Dictionary = _active[key]
		if not is_instance_valid(state["source"]) or not is_instance_valid(state["draw"]):
			_active.erase(key)
			continue
		var fade: Dictionary = _fades[state["object"]]
		state["alpha"] = fade["alpha"]
		state["wanted"] = fade["wanted"]
		for material: Material in state["inks"]:
			if material is BaseMaterial3D:
				var color: Color = material.get_meta("occlusion_color")
				color.a *= state["alpha"]
				material.albedo_color = color
			else:
				var source: ShaderMaterial = material.get_meta("occlusion_source")
				for parameter: StringName in material.get_meta("occlusion_animated"):
					material.set_shader_parameter(parameter, source.get_shader_parameter(parameter))
				material.set_shader_parameter("occlusion_opacity", state["alpha"])
		if state["alpha"] >= 1.0 and not state["wanted"]:
			_restore(state)
			_active.erase(key)

	for key in _fades.keys():
		if _fades[key]["alpha"] >= 1.0 and not _fades[key]["wanted"]:
			_fades.erase(key)
	_trim_cache()


func _find_occluders() -> void:
	var started := Time.get_ticks_usec()
	for fade: Dictionary in _fades.values():
		fade["wanted"] = false
	var wanted := {}
	var foot := renderer.actor_foot(renderer.game.player)
	var toward := renderer.camera.global_basis.z * 45.0
	var candidates := _spatial_index.candidates(foot, toward)
	query_candidates = candidates.size()
	for entry: Dictionary in candidates:
		if not is_instance_valid(entry["node"]):
			continue
		var node: GeometryInstance3D = entry["node"]
		if (
			not is_instance_valid(node)
			or not node.is_visible_in_tree()
			or node.is_queued_for_deletion()
		):
			continue
		var box: AABB = entry["world_box"]
		if box.size.y < 0.45 or box.end.y < foot.y + 0.35:
			continue
		var hit := false
		for height: float in [0.35, 1.0, 1.65]:
			var target := foot + Vector3.UP * height
			if (
				box.grow(0.12).intersects_segment(
					target + toward, target + toward.normalized() * 0.35
				)
				!= null
			):
				var inverse: Transform3D = entry["inverse"]
				var local_box: AABB = entry["box"]
				if (
					local_box.intersects_segment(
						inverse * (target + toward), inverse * (target + toward.normalized() * 0.35)
					)
					== null
				):
					continue

				var mesh: Mesh = node.multimesh.mesh if entry["index"] >= 0 else node.mesh
				var mesh_id := mesh.get_instance_id()
				if not _triangles.has(mesh_id):
					_triangles[mesh_id] = mesh.generate_triangle_mesh()
					triangle_builds += 1
				var triangles: TriangleMesh = _triangles[mesh_id]
				if (
					triangles == null
					or (
						triangles
						. intersect_segment(
							inverse * (target + toward),
							inverse * (target + toward.normalized() * 0.35)
						)
						. is_empty()
					)
				):
					continue
				hit = true
				break
		if not hit:
			continue
		wanted[entry["object"]] = true
	for object_key: String in wanted:
		_recent.erase(object_key)
		_recent.append(object_key)
		if not _fades.has(object_key):
			_fades[object_key] = {"alpha": 1.0, "wanted": true}
		_fades[object_key]["wanted"] = true
		for entry: Dictionary in _objects[object_key]:
			if (
				not is_instance_valid(entry["node"])
				or not entry["node"].is_visible_in_tree()
				or entry["node"].is_queued_for_deletion()
			):
				continue
			var key := "%s:%s" % [entry["node"].get_instance_id(), entry["index"]]
			if not _active.has(key):
				_active[key] = _activate(entry)
			_active[key]["object"] = object_key
	last_query_us = Time.get_ticks_usec() - started
	maximum_query_us = maxi(maximum_query_us, last_query_us)


func _template(source: Material) -> Material:
	var key := source.get_instance_id() if source != null else 0
	if not _templates.has(key):
		var unused: Array[Material] = []
		_templates[key] = _new_ink(source, unused)
	return _templates[key]


func _ink(source: Material, inks: Array[Material], group: String, tint := Color.WHITE) -> Material:
	if not _object_inks.has(group):
		_object_inks[group] = {}
	var key := "%s:%s" % [source.get_instance_id() if source != null else 0, tint.to_html()]
	var shared: Dictionary = _object_inks[group]
	if not shared.has(key):
		var ink := _template(source).duplicate() as Material
		if ink is BaseMaterial3D:
			ink.set_meta("occlusion_color", ink.get_meta("occlusion_color") * tint)
		shared[key] = ink
		material_builds += 1
	var ink: Material = shared[key]
	if not inks.has(ink):
		inks.append(ink)
	return ink


func _new_ink(source: Material, inks: Array[Material]) -> Material:
	if source == null:
		source = StandardMaterial3D.new()
	var ink := source.duplicate() as Material
	if ink is BaseMaterial3D:
		ink.set_meta("occlusion_color", ink.albedo_color)
		ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	elif ink is ShaderMaterial:
		ink.set_meta("occlusion_source", source)
		var animated: Array[StringName] = []
		for uniform: Dictionary in ink.shader.get_shader_uniform_list():
			if uniform["type"] in [TYPE_FLOAT, TYPE_BOOL, TYPE_INT]:
				animated.append(uniform["name"])
		ink.set_meta("occlusion_animated", animated)
		var shader_key: int = ink.shader.get_instance_id()
		if _shaders.has(shader_key):
			ink.shader = _shaders[shader_key]
			inks.append(ink)
			return ink
		var code: String = ink.shader.code
		var start := code.find("void fragment()")
		if start < 0:
			return source
		var opening := code.find("{", start)
		var end := opening + 1
		var depth := 1
		while depth > 0 and end < code.length():
			if code[end] == "{":
				depth += 1
			elif code[end] == "}":
				depth -= 1
			end += 1
		# 원래 표면 알파만 보존하고 오브젝트 전체에 동일한 승수를 적용한다.
		var assignment := RegEx.create_from_string("\\bALPHA\\s*=")
		var alpha := "ALPHA" if assignment.search(code) != null else "1.0"
		var shader := Shader.new()
		shader.code = code.insert(end - 1, "\nALPHA = %s * occlusion_opacity;\n" % alpha).replace(
			"shader_type spatial;", "shader_type spatial;\nuniform float occlusion_opacity = 1.0;"
		)
		_shaders[shader_key] = shader
		ink.shader = shader
	else:
		return source
	inks.append(ink)
	return ink


func _activate(entry: Dictionary) -> Dictionary:
	var source: GeometryInstance3D = entry["node"]
	var cache_key := "%s:%s" % [source.get_instance_id(), entry["index"]]
	if _prepared.has(cache_key):
		var cached: Dictionary = _prepared[cache_key]
		if entry["index"] >= 0:
			source.multimesh.set_instance_transform(
				entry["index"], Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
			)
			cached["draw"].visible = true
		else:
			cached["draw"].material_override = cached["ink_override"]
			for index in cached["ink_surfaces"].size():
				cached["draw"].set_surface_override_material(index, cached["ink_surfaces"][index])
		return cached
	var group: String = entry["object"]
	var draw: MeshInstance3D
	var inks: Array[Material] = []
	var overrides: Array[Material] = []
	var original: Material = source.material_override
	if entry["index"] >= 0:
		draw = MeshInstance3D.new()
		draw.name = "PlayerOcclusionInstance"
		draw.set_meta("occlusion_dynamic", true)
		instance_builds += 1
		draw.mesh = source.multimesh.mesh
		draw.transform = entry["transform"]
		draw.cast_shadow = source.cast_shadow
		# 원본 슬롯은 유지하여 복원해도 순서·색·청크 구성이 변하지 않는다.
		source.multimesh.set_instance_transform(
			entry["index"], Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
		)
	else:
		draw = source as MeshInstance3D
	if original != null:
		draw.material_override = _ink(original, inks, group)
	else:
		for surface in draw.mesh.get_surface_count():
			var material := draw.get_surface_override_material(surface)
			overrides.append(material)
			if material == null:
				material = draw.mesh.surface_get_material(surface)
			var tint := Color.WHITE
			if entry["index"] >= 0 and source.multimesh.use_colors:
				tint = source.multimesh.get_instance_color(entry["index"])
			var ink := _ink(material, inks, group, tint)
			draw.set_surface_override_material(surface, ink)
	if entry["index"] >= 0:
		source.add_child(draw)
	var ink_surfaces: Array[Material] = []
	for index in overrides.size():
		ink_surfaces.append(draw.get_surface_override_material(index))
	var state := {
		"source": source,
		"draw": draw,
		"index": entry["index"],
		"transform": entry.get("transform", Transform3D.IDENTITY),
		"original": original,
		"overrides": overrides,
		"inks": inks,
		"alpha": 1.0,
		"wanted": true,
		"object": group,
		"ink_override": draw.material_override,
		"ink_surfaces": ink_surfaces
	}
	_prepared[cache_key] = state
	return state


func _restore(state: Dictionary) -> void:
	if state["index"] >= 0:
		state["source"].multimesh.set_instance_transform(state["index"], state["transform"])
		state["draw"].visible = false
	else:
		var draw: MeshInstance3D = state["draw"]
		draw.material_override = state["original"]
		for surface in state["overrides"].size():
			draw.set_surface_override_material(surface, state["overrides"][surface])


## 지나간 모델은 제한된 수만 재사용한다. 큰 건물도 부품 단위로 쪼개 퇴출하지 않는다.
func _trim_cache() -> void:
	for key in _prepared.keys():
		if not is_instance_valid(_prepared[key]["source"]):
			_prepared.erase(key)
	var remove: Array[String] = []
	for group in _recent:
		if _recent.size() - remove.size() <= CACHE_OBJECTS:
			break
		if not _fades.has(group):
			remove.append(group)
	for group in remove:
		for key in _prepared.keys():
			var state: Dictionary = _prepared[key]
			if state["object"] != group:
				continue
			_retired.append({"until": Engine.get_process_frames() + 3, "inks": state["inks"]})
			if state["index"] >= 0 and is_instance_valid(state["draw"]):
				state["draw"].queue_free()
			_prepared.erase(key)
		_object_inks.erase(group)
		_recent.erase(group)

class_name NativePlayerOcclusion
extends RefCounted
## 시각 전용. 충돌·배칭 원본·공유 재질은 보존하고 가리는 인스턴스만 잠시 분리한다.
const MIN_OPACITY := 0.20
const INTERVAL := 0.10
var preview: Ortho3DPreview
var _roots := {}
var _shaders := {}
var _triangles := {}
var _entries: Array[Dictionary] = []
var _active := {}
var _objects := {}
var _fades := {}
var _retired: Array[Dictionary] = []
var _clock := INTERVAL
var _debug_disabled := false

func setup(presenter: Ortho3DPreview) -> NativePlayerOcclusion:
	preview = presenter
	if OS.has_feature("web") and preview._probe_enabled:
		_debug_disabled = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('occlusion') === 'off'"))
	return self

## 제작자 계약: 분리된 벽·지붕도 같은 루트에 표시하면 하나의 정적 오브젝트다.
static func mark_object(node: Node) -> void:
	node.set_meta("occlusion_static_object", true)

static func static_owner(node: Node) -> Node:
	var owner: Node
	var cursor := node
	while cursor != null:
		if cursor.get_meta("occlusion_dynamic", false) or cursor is CharacterBody3D or cursor is Skeleton3D:
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
		_objects[key] = _objects[key].filter(func(entry: Dictionary): return is_instance_valid(entry["node"]))
		if _objects[key].is_empty():
			_objects.erase(key)
	_roots[root.get_instance_id()] = true
	for child in root.find_children("*", "GeometryInstance3D", true, false):
		var owner := static_owner(child)
		var object_key := "object:%s" % owner.get_instance_id() if owner != null else ""
		if child is MeshInstance3D and child.mesh != null and not object_key.is_empty():
			_add_entry({"node": child, "index": -1, "box": child.mesh.get_aabb(), "object": object_key})
		elif child is MultiMeshInstance3D and child.multimesh != null and child.multimesh.mesh != null:
			var mesh: MultiMesh = child.multimesh
			var owners: Array = child.get_meta("occlusion_objects", [])
			var frames: Array = child.get_meta("occlusion_transforms", [])
			for index in mesh.instance_count:
				var key: String = owners[index] if index < owners.size() else object_key
				if key.is_empty() and child.get_meta("occlusion_static_instances", false):
					key = "instance:%s:%s" % [child.get_instance_id(), index]
				if key.is_empty():
					continue
				_add_entry({"node": child, "index": index, "box": mesh.mesh.get_aabb(), "transform": frames[index] if index < frames.size() else mesh.get_instance_transform(index), "object": key})

func _add_entry(entry: Dictionary) -> void:
	_entries.append(entry)
	var key: String = entry["object"]
	if not _objects.has(key):
		_objects[key] = []
	_objects[key].append(entry)

func sync(delta: float) -> void:
	if _debug_disabled:
		return
	_retired = _retired.filter(func(entry: Dictionary): return entry["until"] > Engine.get_process_frames())
	_register(preview._forest_stage)
	_register(preview._world_environment.cave)
	for props in [preview._town_props, preview._encounter_props]:
		for entry: Dictionary in props._entries.values():
			mark_object(entry["root"])
			_register(entry["root"])
	_clock += delta
	if _clock >= INTERVAL:
		_clock = 0.0
		_find_occluders()
	for fade: Dictionary in _fades.values():
		fade["alpha"] = move_toward(fade["alpha"], MIN_OPACITY if fade["wanted"] else 1.0, delta * 4.5)
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

func _find_occluders() -> void:
	for fade: Dictionary in _fades.values():
		fade["wanted"] = false
	var wanted := {}
	var foot := preview.actor_foot(preview.game.player)
	var toward := preview.camera.global_basis.z * 45.0
	for entry: Dictionary in _entries:
		if not is_instance_valid(entry["node"]):
			continue
		var node: GeometryInstance3D = entry["node"]
		if not is_instance_valid(node) or not node.is_visible_in_tree() or node.is_queued_for_deletion():
			continue
		var frame := node.global_transform
		if entry["index"] >= 0:
			frame *= entry["transform"]
		var box: AABB = frame * entry["box"]
		if box.size.y < 0.45 or box.end.y < foot.y + 0.35:
			continue
		var hit := false
		for height: float in [0.35, 1.0, 1.65]:
			var target := foot + Vector3.UP * height
			if box.grow(0.12).intersects_segment(target + toward, target + toward.normalized() * 0.35) != null:
				var inverse := frame.affine_inverse()
				var local_box: AABB = entry["box"]
				if local_box.intersects_segment(inverse * (target + toward), inverse * (target + toward.normalized() * 0.35)) == null:
					continue

				var mesh: Mesh = node.multimesh.mesh if entry["index"] >= 0 else node.mesh
				var mesh_id := mesh.get_instance_id()
				if not _triangles.has(mesh_id):
					_triangles[mesh_id] = mesh.generate_triangle_mesh()
				var triangles: TriangleMesh = _triangles[mesh_id]
				if triangles == null or triangles.intersect_segment(inverse * (target + toward), inverse * (target + toward.normalized() * 0.35)).is_empty():
					continue
				hit = true
				break
		if not hit:
			continue
		wanted[entry["object"]] = true
	for object_key: String in wanted:
		if not _fades.has(object_key):
			_fades[object_key] = {"alpha": 1.0, "wanted": true}
		_fades[object_key]["wanted"] = true
		for entry: Dictionary in _objects[object_key]:
			if not is_instance_valid(entry["node"]) or not entry["node"].is_visible_in_tree() or entry["node"].is_queued_for_deletion():
				continue
			var key := "%s:%s" % [entry["node"].get_instance_id(), entry["index"]]
			if not _active.has(key):
				_active[key] = _activate(entry)
			_active[key]["object"] = object_key

func _ink(source: Material, inks: Array[Material]) -> Material:
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
			if code[end] == "{": depth += 1
			elif code[end] == "}": depth -= 1
			end += 1
		# 원래 표면 알파만 보존하고 오브젝트 전체에 동일한 승수를 적용한다.
		var assignment := RegEx.create_from_string("\\bALPHA\\s*=")
		var alpha := "ALPHA" if assignment.search(code) != null else "1.0"
		var shader := Shader.new()
		shader.code = code.insert(end - 1, "\nALPHA = %s * occlusion_opacity;\n" % alpha).replace("shader_type spatial;", "shader_type spatial;\nuniform float occlusion_opacity = 1.0;")
		_shaders[shader_key] = shader
		ink.shader = shader
	else:
		return source
	inks.append(ink)
	return ink

func _activate(entry: Dictionary) -> Dictionary:
	var source: GeometryInstance3D = entry["node"]
	var draw: MeshInstance3D
	var inks: Array[Material] = []
	var overrides: Array[Material] = []
	var original: Material = source.material_override
	if entry["index"] >= 0:
		draw = MeshInstance3D.new()
		draw.name = "PlayerOcclusionInstance"
		draw.mesh = source.multimesh.mesh
		draw.transform = entry["transform"]
		draw.cast_shadow = source.cast_shadow
		# 원본 슬롯은 유지하여 복원해도 순서·색·청크 구성이 변하지 않는다.
		source.multimesh.set_instance_transform(entry["index"], Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	else:
		draw = source as MeshInstance3D
	if original != null:
		draw.material_override = _ink(original, inks)
	else:
		for surface in draw.mesh.get_surface_count():
			var material := draw.get_surface_override_material(surface)
			overrides.append(material)
			if material == null:
				material = draw.mesh.surface_get_material(surface)
			var ink := _ink(material, inks)
			if entry["index"] >= 0 and source.multimesh.use_colors and ink is BaseMaterial3D:
				var tint: Color = ink.get_meta("occlusion_color")
				tint *= source.multimesh.get_instance_color(entry["index"])
				ink.set_meta("occlusion_color", tint)
			draw.set_surface_override_material(surface, ink)
	if entry["index"] >= 0:
		source.add_child(draw)
	return {"source": source, "draw": draw, "index": entry["index"], "transform": entry.get("transform", Transform3D.IDENTITY), "original": original, "overrides": overrides, "inks": inks, "alpha": 1.0, "wanted": true}

func _restore(state: Dictionary) -> void:
	# 렌더 서버의 지연된 인스턴스 매개변수 갱신이 끝나기 전에 RID를 해제하지 않는다.
	_retired.append({"until": Engine.get_process_frames() + 3, "inks": state["inks"]})
	if state["index"] >= 0:
		state["source"].multimesh.set_instance_transform(state["index"], state["transform"])
		state["draw"].queue_free()
	else:
		var draw: MeshInstance3D = state["draw"]
		draw.material_override = state["original"]
		for surface in state["overrides"].size():
			draw.set_surface_override_material(surface, state["overrides"][surface])

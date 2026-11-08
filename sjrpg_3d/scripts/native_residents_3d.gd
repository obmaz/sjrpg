class_name NativeResidents3D
extends RefCounted
## Two distinct imported CC0 residents plus six authored resident identities.
## Gameplay clocks, feet, local visibility and injury state remain owned by Villager.
const IDS := ["merchant", "smith", "stable", "elder", "mira", "elin", "noah", "rowen"]
const IMPORTED_MERCHANT := "res://assets/art/native_residents/merchant.glb"
const IMPORTED_MODELS := {"merchant": IMPORTED_MERCHANT, "mira": "res://assets/art/native_residents/mira.glb"}
const AUTHORED_IDS := ["smith", "stable", "elder", "elin", "noah", "rowen"]
const COATS := ["74634c", "59605b", "68684c", "626e7a", "607b79", "677687", "637452", "526d7c"]
static var _meshes: Dictionary = {}
var preview: Node
var entries: Dictionary = {}


func setup(presenter: Node) -> NativeResidents3D:
	preview = presenter
	sync()
	return self


static func _part(buckets: Dictionary, key: String, mesh: Mesh, at: Vector3, stretch: Vector3 = Vector3.ONE, angle: float = 0.0, lean: float = 0.0) -> void:
	var palette: Dictionary = {"leather": Color("8b7051"), "trouser": Color("555d59"), "skin": Color("f0c7a1"), "hair": Color("514539"), "greyhair": Color("c1baa3"), "bronze": Color("c6a66d"), "iron": Color("a4b3b0"), "ivory": Color("d8d4be"), "wood": Color("9d7d53"), "olive": Color("8da361"), "eye": Color("b2ad94"), "pupil": Color("282d2a")}
	var color: Color = palette.get(key, Color.WHITE)
	if key.begins_with("cloth"):
		color = Color(COATS[int(key.trim_prefix("cloth"))])
	var group: String = "iron" if key in ["bronze", "iron"] else "skin" if key in ["skin", "hair", "greyhair", "eye", "pupil"] else "cloth" if key.begins_with("cloth") or key in ["ivory", "olive"] else "leather"
	if not buckets.has(group):
		var fresh: SurfaceTool = SurfaceTool.new()
		fresh.begin(Mesh.PRIMITIVE_TRIANGLES)
		buckets[group] = fresh
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = PackedColorArray()
	colors.resize(vertices.size())
	colors.fill(color)
	arrays[Mesh.ARRAY_COLOR] = colors
	var colored: ArrayMesh = ArrayMesh.new()
	colored.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var tool: SurfaceTool = buckets[group]
	var basis: Basis = Basis(Vector3.UP, angle) * Basis(Vector3.RIGHT, lean)
	tool.append_from(colored, 0, Transform3D(basis.scaled(stretch), at))


static func _box(b: Dictionary, key: String, at: Vector3, size: Vector3, angle: float = 0.0) -> void:
	var mesh: PrimitiveMesh = BoxMesh.new()
	mesh.size = size
	_part(b, key, mesh, at, Vector3.ONE, angle)


static func _round(b: Dictionary, key: String, at: Vector3, size: Vector3) -> void:
	var mesh: PrimitiveMesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 6
	_part(b, key, mesh, at, size)


static func _loft(b: Dictionary, key: String, rings: Array[Vector4], at: Vector3 = Vector3.ZERO, folds: float = 0.0, segments: int = 16, start: float = 0.0, span: float = TAU, thickness: float = 0.0) -> void:
	_part(b, key, NativeActorShapes.loft(rings, segments, folds, start, span, thickness), at)


static func _face(b: Dictionary, base: float, female: bool, older: bool, identity: String) -> void:
	var scale: Vector3 = Vector3(0.90 if female else 1.0, 1, 1)
	_part(b, "skin", NativeActorShapes.head(), Vector3(0, base, 0.015), scale)
	# Eye whites, pupils and brows sit outside the actual cheek/temple section.
	for side: float in [-1.0, 1.0]:
		_round(b, "eye", Vector3(side * 0.046, base + 0.167, 0.119), Vector3(0.040, 0.017, 0.023))
		_round(b, "pupil", Vector3(side * 0.046, base + 0.166, 0.131), Vector3(0.016, 0.015, 0.007))
		_box(b, "greyhair" if older else "hair", Vector3(side * 0.046, base + 0.189, 0.120), Vector3(0.051, 0.014, 0.018), side * 0.08)
	_loft(b, "skin", [Vector4(0, 0.027, 0.016, 0), Vector4(0.027, 0.024, 0.041, 0.010), Vector4(0.079, 0.014, 0.015, -0.007)], Vector3(0, base + 0.105, 0.116), 0, 8)
	_box(b, "leather", Vector3(0, base + 0.058, 0.101), Vector3(0.047, 0.007, 0.006))
	var hair: String = "greyhair" if older else "hair"
	# The cap follows the skull sides and back; individually tapered locks
	# break its edge instead of presenting a flat circular disk.
	_loft(b, hair, [Vector4(base + 0.085, 0.108, 0.103, -0.012), Vector4(base + 0.20, 0.116, 0.108, -0.014), Vector4(base + 0.268, 0.085, 0.080, -0.01), Vector4(base + 0.29, 0.015, 0.020, -0.01)], Vector3.ZERO, 0.006, 16, PI * 0.80, PI * 1.40, 0.012)
	for index: int in 6:
		var x: float = (float(index) - 2.5) * 0.031
		_loft(b, hair, [Vector4(0, 0.009, 0.012, 0.022), Vector4(0.038, 0.023, 0.022, 0.007), Vector4(0.087, 0.019, 0.022, -0.015), Vector4(0.108, 0.004, 0.006, -0.025)], Vector3(x, base + 0.168 + absf(x) * 0.12, 0.091), 0, 8)
	if female:
		_loft(b, hair, [Vector4(0, 0.025, 0.025, 0), Vector4(0.12, 0.040, 0.034, -0.01), Vector4(0.28, 0.052, 0.050, 0)], Vector3(0.07, base - 0.14, -0.11), 0.005, 10)
	if older or identity == "smith":
		_loft(b, hair, [Vector4(0, 0.014, 0.018, 0.025), Vector4(0.07, 0.055, 0.040, 0.016), Vector4(0.15, 0.083, 0.035, 0)], Vector3(0, base - (0.11 if older else 0.025), 0.095), 0.004, 12)


static func build(identity: String) -> ArrayMesh:
	if not AUTHORED_IDS.has(identity):
		return null
	if _meshes.has(identity):
		return _meshes[identity]
	var index: int = IDS.find(identity)
	if index < 0:
		return null
	var b: Dictionary = {}
	var cloth: String = "cloth" + str(index)
	var female: bool = identity == "elin"
	var elder: bool = identity == "elder"
	var smith: bool = identity == "smith"
	var width: float = 1.15 if smith else 0.90 if female else 1.0
	var shift: float = -0.065 if elder else -0.025 if female else 0.0
	for side: float in [-1.0, 1.0]:
		_part(b, "leather", NativeActorShapes.boot(), Vector3(side * 0.115, 0, 0))
		_loft(b, "trouser", [Vector4(0.25, 0.068, 0.076, 0), Vector4(0.47, 0.078, 0.083, 0), Vector4(0.56, 0.072, 0.080, 0.02), Vector4(0.82, 0.10, 0.10, 0)], Vector3(side * 0.11, 0, 0), 0.003, 12)
		var arm_key: String = "skin" if smith or identity == "stable" else cloth
		_part(b, arm_key, NativeActorShapes.sleeve(0.49, 0.095 if smith else 0.076), Vector3(side * 0.273 * width, 1.34 + shift, 0), Vector3.ONE, side * -0.10, -0.10 if identity == "rowen" else 0.04)
		_loft(b, "leather" if smith else cloth, [Vector4(0, 0.060, 0.065, 0), Vector4(0.055, 0.065, 0.068, 0)], Vector3(side * 0.276 * width, 0.87 + shift, 0.047), 0.003, 12)
		_round(b, "skin", Vector3(side * 0.276 * width, 0.79 + shift, 0.070), Vector3(0.104, 0.15, 0.091))
	_part(b, cloth if not smith else "leather", NativeActorShapes.chest(), Vector3(0, shift, 0.045 if elder else 0), Vector3(width, 1, 1.0))
	var long_robe: bool = identity in ["elder", "elin", "noah"]
	var hem: float = 0.14 if long_robe else 0.69
	_loft(b, cloth, [Vector4(hem, 0.29 if long_robe else 0.24 * width, 0.195, 0), Vector4(0.78, 0.225 * width, 0.15, 0), Vector4(0.99, 0.177 * width, 0.13, 0)], Vector3.ZERO, 0.014 if long_robe else 0.009, 24)
	_loft(b, "leather", [Vector4(0.94, 0.19 * width, 0.153, 0), Vector4(1.01, 0.19 * width, 0.153, 0)], Vector3.ZERO, 0, 16)
	_box(b, "bronze", Vector3(0, 0.974, 0.169), Vector3(0.069, 0.059, 0.020))
	# Open collar and two lapels, not a peg below a detached head.
	_loft(b, "ivory" if female else "leather", [Vector4(1.32 + shift, 0.106, 0.085, 0), Vector4(1.43 + shift, 0.079, 0.071, 0)], Vector3(0, 0, 0.015), 0, 16, PI * 0.03, PI * 0.94, 0.016)
	_loft(b, "skin", [Vector4(1.36 + shift, 0.063, 0.058, 0.02), Vector4(1.54 + shift, 0.064, 0.059, 0.025)], Vector3.ZERO, 0, 12)
	var face_base: float = 1.49 + shift
	_face(b, face_base, female, elder, identity)
	match identity:
		"smith":
			_loft(b, "leather", [Vector4(0.43, 0.20, 0.025, 0.23), Vector4(0.65, 0.20, 0.025, 0.23), Vector4(0.98, 0.17, 0.025, 0.19), Vector4(1.28, 0.14, 0.025, 0.18)], Vector3.ZERO, 0.006, 16)
			for side: float in [-1.0, 1.0]:
				_box(b, "leather", Vector3(side * 0.09, 1.31, 0.15), Vector3(0.028, 0.20, 0.025))
			_box(b, "wood", Vector3(0.32, 0.77, 0.13), Vector3(0.030, 0.39, 0.035))
			_box(b, "iron", Vector3(0.32, 0.99, 0.13), Vector3(0.19, 0.085, 0.085))
		"stable":
			_loft(b, "leather", [Vector4(1.02, 0.21, 0.16, 0), Vector4(1.29, 0.257, 0.17, 0), Vector4(1.38, 0.17, 0.10, 0)], Vector3.ZERO, 0, 16, PI * 0.14, PI * 1.72, 0.016)
			_round(b, "leather", Vector3(-0.22, 0.91, -0.06), Vector3(0.20, 0.29, 0.15))
		"elder":
			_part(b, "wood", NativeActorShapes.sleeve(1.62, 0.023), Vector3(0.35, 1.64, 0.12))
			_round(b, "bronze", Vector3(0.35, 1.65, 0.12), Vector3(0.10, 0.11, 0.10))
		"elin":
			_loft(b, "ivory", [Vector4(1.39, 0.18, 0.15, -0.025), Vector4(1.60, 0.17, 0.14, -0.025), Vector4(1.72, 0.145, 0.13, -0.02), Vector4(1.81, 0.065, 0.06, -0.02)], Vector3.ZERO, 0.004, 20, PI * 0.80, PI * 1.40, 0.018)
			_loft(b, "ivory", [Vector4(0.28, 0.083, 0.022, 0.20), Vector4(1.20, 0.090, 0.025, 0.18)], Vector3.ZERO, 0.006, 12)
		"noah":
			_loft(b, cloth, [Vector4(1.21, 0.28, 0.21, 0), Vector4(1.42, 0.17, 0.13, 0)], Vector3.ZERO, 0.008, 20, PI * 0.1, PI * 1.8, 0.025)
			_round(b, "wood", Vector3(0.21, 0.82, 0.20), Vector3(0.19, 0.23, 0.18))
			for side: float in [-1.0, 1.0]:
				_loft(b, "olive", [Vector4(0, 0.01, 0.01, 0), Vector4(0.08, 0.03, 0.018, 0.02), Vector4(0.18, 0.003, 0.004, 0.06)], Vector3(0.21 + side * 0.04, 0.92, 0.20), 0, 8)
		"rowen":
			_loft(b, cloth, [Vector4(0.78, 0.24, 0.18, -0.03), Vector4(1.35, 0.24, 0.19, 0)], Vector3.ZERO, 0.012, 18, PI * 1.04, PI * 0.96, 0.020)
			_box(b, "leather", Vector3(0.27, 0.82, 0.13), Vector3(0.12, 0.20, 0.075))
			_box(b, "ivory", Vector3(0.27, 0.82, 0.17), Vector3(0.10, 0.17, 0.016))
			_loft(b, "iron", [Vector4(1.30, 0.11, 0.12, 0), Vector4(1.37, 0.135, 0.15, 0), Vector4(1.43, 0.06, 0.09, 0)], Vector3(-0.22, 0, 0), 0, 12)
	var result: ArrayMesh = ArrayMesh.new()
	for group: String in b:
		var tool: SurfaceTool = b[group]
		tool.commit(result)
		result.surface_set_material(result.get_surface_count() - 1, NativeActorMaterials.material(group))
	_meshes[identity] = result
	return result


## Runtime and review gallery share this factory; imports never silently use an authored substitute.
static func create(identity: String) -> Node3D:
	if not IDS.has(identity):
		return null
	var model: Node3D
	if IMPORTED_MODELS.has(identity):
		var path: String = IMPORTED_MODELS[identity]
		if not ResourceLoader.exists(path):
			return null
		var scene: PackedScene = load(path) as PackedScene
		if scene == null:
			return null
		var candidate: Node = scene.instantiate()
		model = candidate as Node3D
		if model == null:
			candidate.free()
			return null
		model.set_meta("resident_source", "cc0_import")
		model.set_meta("resident_asset", path)
		_configure_idle(model)
	else:
		var mesh: ArrayMesh = build(identity)
		if mesh == null:
			return null
		var body: MeshInstance3D = MeshInstance3D.new()
		body.mesh = mesh
		model = body
		model.set_meta("resident_source", "authored")
	model.name = "NativeResident_" + identity
	model.set_meta("resident_identity", identity)
	return model


static func descendant_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		result.append_array(descendant_meshes(child))
	return result


static func _find_animation(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found: AnimationPlayer = _find_animation(child)
		if found != null:
			return found
	return null


static func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found: Skeleton3D = _find_skeleton(child)
		if found != null:
			return found
	return null


static func _configure_idle(model: Node3D) -> void:
	var animator: AnimationPlayer = _find_animation(model)
	if animator == null:
		return
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animator.playback_default_blend_time = 0.0
	animator.autoplay = ""
	var selected := ""
	for name: StringName in animator.get_animation_list():
		if str(name).to_lower().contains("idle"):
			selected = str(name)
			break
	# A relative node path is valid both before and after this root enters the tree.
	var names := PackedStringArray()
	var current: Node = animator
	while current != null and current != model:
		names.insert(0, str(current.name))
		current = current.get_parent()
	model.set_meta("resident_idle_player", NodePath("/".join(names)))
	model.set_meta("resident_idle_clip", selected)


static func idle_player(model: Node3D) -> AnimationPlayer:
	if model == null or not model.has_meta("resident_idle_player"):
		return null
	var path: NodePath = model.get_meta("resident_idle_player")
	return model.get_node_or_null(path) as AnimationPlayer


## Sample the original resident clock, never a second timer or automatic playback.
static func sample_idle(model: Node3D, source_time: float) -> Dictionary:
	var animator: AnimationPlayer = idle_player(model)
	var selected: String = str(model.get_meta("resident_idle_clip", "")) if model != null else ""
	if animator == null or selected.is_empty() or not is_finite(source_time):
		return {}
	var clip: Animation = animator.get_animation(selected)
	if clip == null or clip.length <= 0.0:
		return {}
	var sample: float = fposmod(maxf(source_time, 0.0), clip.length)
	var previous: float = float(model.get_meta("resident_idle_sample", -1.0))
	var changed: bool = animator.current_animation != selected
	if changed:
		animator.play(selected, 0.0)
	if changed or not is_equal_approx(sample, previous):
		# seek(update=true) applies the pose; a zero advance repeats the same evaluation.
		animator.seek(sample, true)
		model.set_meta("resident_idle_sample", sample)
	return {"clip": selected, "sample_time": sample, "source_time": source_time}


## Mesh-space bounds include every descendant transform but exclude the actor's world placement.
static func local_bounds(model: Node3D) -> AABB:
	if model == null:
		return AABB()
	var boxes: Array[AABB] = []
	_collect_bounds(model, Transform3D.IDENTITY, boxes, true)
	if boxes.is_empty():
		return AABB()
	var bounds: AABB = boxes[0]
	for index: int in range(1, boxes.size()):
		bounds = bounds.merge(boxes[index])
	return bounds


static func _collect_bounds(node: Node, parent: Transform3D, boxes: Array[AABB], root := false) -> void:
	var at := parent
	if node is Node3D and not root:
		at = parent * (node as Node3D).transform
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		if instance.mesh != null:
			boxes.append(at * instance.mesh.get_aabb())
	for child: Node in node.get_children():
		_collect_bounds(child, at, boxes)


func sync() -> void:
	for id: int in entries.keys():
		var owner: Villager = entries[id]["owner"].get_ref()
		if not is_instance_valid(owner) or owner.is_queued_for_deletion():
			entries[id]["node"].queue_free()
			entries.erase(id)
	for candidate: Variant in preview.game.village.npc_nodes.values():
		if not is_instance_valid(candidate):
			continue
		var resident: Villager = candidate as Villager
		if not is_instance_valid(resident) or resident.is_queued_for_deletion():
			continue
		var id: int = resident.get_instance_id()
		if not entries.has(id):
			var identity: String = NpcArt.identity(resident.display_name)
			var instance: Node3D = create(identity)
			if instance == null:
				continue
			preview.stage.add_child(instance)
			entries[id] = {"owner": weakref(resident), "node": instance,
				"source": str(instance.get_meta("resident_source", "")),
				"meshes": descendant_meshes(instance), "animation": idle_player(instance),
				"skeleton": _find_skeleton(instance), "clip": "", "sample_time": 0.0}
		var model: Node3D = entries[id]["node"]
		model.visible = resident.visible and resident.get_parent() == preview.game.world and not preview.game.dungeon.active
		model.position = preview.actor_foot(resident)
		var direction: Vector3 = Ortho3DPreview.ground_position(Vector2.from_angle(resident.facing))
		model.rotation.y = atan2(direction.x, direction.z)
		if model.visible and str(entries[id]["source"]) == "cc0_import":
			var pose: Dictionary = sample_idle(model, resident._time)
			entries[id]["clip"] = str(pose.get("clip", ""))
			entries[id]["sample_time"] = float(pose.get("sample_time", 0.0))
		# Original injury overlays every imported mesh without changing shared base materials.
		var flash: ShaderMaterial = null
		if resident._hurt_flash > 0.0:
			if not entries[id].has("flash"):
				var shader := Shader.new()
				shader.code = Ortho3DPreview.ACTOR_FLASH_CODE
				flash = ShaderMaterial.new()
				flash.shader = shader
				entries[id]["flash"] = flash
			flash = entries[id]["flash"]
			flash.set_shader_parameter("flash_color", Color(1.0, 0.64, 0.59))
			flash.set_shader_parameter("flash_strength", resident._hurt_flash * 0.65)
		var meshes: Array[MeshInstance3D] = entries[id]["meshes"]
		for mesh: MeshInstance3D in meshes:
			if mesh.material_overlay != flash:
				mesh.material_overlay = flash


func review_snapshot() -> Dictionary:
	var identities: Array[String] = []
	var visible := 0
	var imported := 0
	var animated := 0
	var details: Array[Dictionary] = []
	for entry: Dictionary in entries.values():
		var node: Node3D = entry["node"]
		if node.visible:
			visible += 1
		var is_imported: bool = str(entry["source"]) == "cc0_import"
		imported += 1 if is_imported else 0
		animated += 1 if not str(entry["clip"]).is_empty() else 0
		identities.append(str(node.name))
		details.append({"identity": str(node.get_meta("resident_identity", "")),
			"source": str(entry["source"]), "clip": str(entry["clip"]),
			"sample_time": float(entry["sample_time"]), "meshes": entry["meshes"].size()})
	return {"mapped": IDS, "instances": entries.size(), "visible": visible,
		"identities": identities, "imported_count": imported, "animated_count": animated,
		"details": details, "camera_facing_cards": 0}


func snapshot() -> Dictionary:
	return review_snapshot()

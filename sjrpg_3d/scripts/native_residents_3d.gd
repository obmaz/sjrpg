class_name NativeResidents3D
extends RefCounted
## Two distinct imported CC0 residents plus six authored resident identities.
## Gameplay clocks, feet, local visibility and injury state remain owned by Villager.
const IDS := ["merchant", "smith", "stable", "elder", "mira", "elin", "noah", "rowen"]
const IMPORTED_MERCHANT := "res://assets/art/native_residents/merchant.glb"
const IMPORTED_MODELS := {"merchant": IMPORTED_MERCHANT, "mira": "res://assets/art/native_residents/mira.glb"}
const AUTHORED_IDS := ["smith", "stable", "elder", "elin", "noah", "rowen"]
var preview: Node
var entries: Dictionary = {}


func setup(presenter: Node) -> NativeResidents3D:
	preview = presenter
	sync()
	return self


## 어댑터 호환 API: 형상은 GLB의 공유 메시이며 게임 중 정점을 만들지 않는다.
static func build(identity: String) -> ArrayMesh:
	if not AUTHORED_IDS.has(identity):
		return null
	return NativePropAssets.mesh("residents/" + identity, "Body")


## Runtime and review gallery share this factory; imports never silently use an authored substitute.
static func create(identity: String) -> Node3D:
	if not IDS.has(identity):
		return null
	var model: Node3D
	if IMPORTED_MODELS.has(identity):
		var path: String = IMPORTED_MODELS[identity]
		if not ResourceLoader.exists(path):
			return null
		var scene: PackedScene = load("res://assets/models/residents/" + identity + "/visual.tscn") as PackedScene
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
		model = NativePropAssets.create("residents/" + identity)
		if model == null:
			return null
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

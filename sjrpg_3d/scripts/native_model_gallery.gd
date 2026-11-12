class_name NativeModelGallery
extends Control
## Explicit review overlay only. Actual runtime mesh constructors are instanced
## into an isolated World3D. Source game transforms/physics/state are never edited.
const ROWS := 4
const COLS := 4
const ELEVATION := 35.264389682754654
var game: Node
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
var _layer: CanvasLayer
var _sheet: Control
var _texture: TextureRect
var _title: Label
var _names: Array[Label] = []
var _models: Array[Node3D] = []
var _keys: Array[String] = []
var face := 0
var requested_frame := 0
var merchant_only := false
var _resident_factory: Script
var _resident_sources: Dictionary = {}
var _resident_samples: Dictionary = {}


func setup(source_game: Node) -> NativeModelGallery:
	game = source_game
	return self


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.handle_input_locally = false
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("1b2426")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b9c7cc")
	settings.ambient_light_energy = 0.55
	environment.environment = settings
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.light_color = game.ortho_preview.sunlight.light_color
	sun.light_energy = game.ortho_preview.sunlight.light_energy
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.transform = game.ortho_preview.sunlight.transform
	stage.add_child(sun)
	var ground_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(70, 70)
	ground_mesh.mesh = plane
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("34403d")
	stone.roughness = 0.95
	ground_mesh.material_override = stone
	stage.add_child(ground_mesh)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 16.0
	camera.near = 18.0
	camera.far = 52.0
	stage.add_child(camera)
	camera.make_current()
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_sheet = Control.new()
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_sheet)
	_texture = TextureRect.new()
	_texture.texture = viewport.get_texture()
	_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(_texture)
	_title = EntryUi.label("", 23, Color("e0d6c2"), true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sheet.add_child(_title)
	var warrior := NativeWarrior3D.new().build()
	_add(warrior, "warrior")
	var enemy_script: Script = load("res://scripts/enemy.gd")
	var native_heights: Dictionary = enemy_script.get_script_constant_map().get("NATIVE_HEIGHT_METRES", {})
	for kind: String in ["goblin", "wolf", "boar", "skeleton", "golem"]:
		var model := NativeEnemyModels.build(kind)
		var root: Node3D = model["root"]
		var legacy_height: float = float(Enemy.KINDS[kind]["height"]) / (Ortho3DPreview.GROUND_PER_METER * Iso.S)
		var height_metres: float = float(native_heights.get(kind, legacy_height))
		root.scale = Vector3.ONE * height_metres / float(model["base_height"])
		_add(root, kind)
	_resident_factory = load("res://scripts/native_residents_3d.gd")
	for source: Villager in game.village.npc_nodes.values():
		_resident_sources[NpcArt.identity(source.display_name)] = weakref(source)
	for identity: String in NativeResidents3D.IDS:
		var model: Node3D
		if _factory_has("create"):
			model = _resident_factory.call("create", identity)
		else:
			var legacy := MeshInstance3D.new()
			legacy.mesh = NativeResidents3D.build(identity)
			model = legacy
		if model == null:
			push_error("Runtime resident factory did not create " + identity)
			continue
		_add(model, identity)
	resized.connect(_layout)
	visibility_changed.connect(_visibility)
	_layout()
	set_face(face)


func _add(model: Node3D, key: String) -> void:
	stage.add_child(model)
	_models.append(model)
	_keys.append(key)
	var label := EntryUi.label(key, 20, Color("dfd8c4"), true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(label)
	_names.append(label)


func set_merchant_only(value: bool) -> void:
	merchant_only = value
	set_face(face)


func set_face(index: int) -> void:
	face = clampi(index, 0, 3)
	if camera == null:
		return
	var yaw := deg_to_rad(45.0 + face * 90.0)
	var toward := Vector3(sin(yaw), 0, cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var direction := Vector3(toward.x, tan(deg_to_rad(ELEVATION)), toward.z).normalized()
	camera.size = 3.3 if merchant_only else 16.0
	var focus := Vector3(0, 0.89 if merchant_only else 0.85, 0)
	camera.position = focus + direction * 35.0
	camera.look_at(focus, Vector3.UP)
	for index_model in _models.size():
		_models[index_model].visible = not merchant_only or _keys[index_model] == "merchant"
		if merchant_only:
			_models[index_model].position = Vector3.ZERO
			continue
		var column := index_model % COLS
		var row := index_model / COLS
		# Ground spacing compensates the true isometric elevation, not a
		# model distortion: labels stay in screen cells as the camera turns.
		_models[index_model].position = right * (float(column) - 1.5) * 3.8 + toward * (float(row) - 1.5) * (3.4 / sin(deg_to_rad(ELEVATION)))
	_title.text = "Native model inspection · azimuth %d° · elevation 35.264°" % (45 + face * 90)
	_sample_residents()
	requested_frame = Engine.get_process_frames()
	_layout()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _layout() -> void:
	if viewport == null or camera == null:
		return
	var screen := get_viewport_rect().size
	viewport.size = Vector2i(maxi(1, roundi(screen.x)), maxi(1, roundi(screen.y)))
	_title.position = Vector2(16, 18)
	_title.size = Vector2(screen.x - 32, 38)
	for index in _models.size():
		_names[index].visible = not merchant_only or _keys[index] == "merchant"
		var foot := camera.unproject_position(_models[index].position)
		_names[index].position = foot + Vector2(-100, 9)
		_names[index].size = Vector2(200, 30)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _visibility() -> void:
	if _layer != null:
		_layer.visible = visible
	if viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if visible else SubViewport.UPDATE_DISABLED


func review_snapshot() -> Dictionary:
	var models := []
	for index in _models.size():
		var model := _models[index]
		if merchant_only and _keys[index] != "merchant":
			continue
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		if model is MeshInstance3D:
			meshes.append(model)
		var envelope := AABB()
		var first := true
		var triangles := 0
		var surfaces := 0
		for candidate in meshes:
			var mesh := candidate as MeshInstance3D
			var transform := model.global_transform.affine_inverse() * mesh.global_transform
			var bounds: AABB = transform * mesh.get_aabb()
			envelope = bounds if first else envelope.merge(bounds)
			first = false
			surfaces += mesh.mesh.get_surface_count()
			for surface in mesh.mesh.get_surface_count():
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices := PackedInt32Array()
				if arrays[Mesh.ARRAY_INDEX] != null:
					indices = arrays[Mesh.ARRAY_INDEX]
				triangles += (indices.size() if not indices.is_empty() else points.size()) / 3
		var skinned := 0
		for candidate: Node in meshes:
			if (candidate as MeshInstance3D).skin != null:
				skinned += 1
		models.append({"asset": model.get_meta("resident_asset", ""), "scene_paths": _model_scene_paths(model), "skeletons": model.find_children("*", "Skeleton3D", true, false).size(), "skinned_meshes": skinned, "sample": _resident_samples.get(_keys[index], {}), "identity": _keys[index], "triangles": triangles, "surfaces": surfaces, "bounds_min": [envelope.position.x, envelope.position.y, envelope.position.z], "bounds_max": [envelope.end.x, envelope.end.y, envelope.end.z], "scale": [model.scale.x, model.scale.y, model.scale.z]})
	return {"face": face, "azimuth": 45 + face * 90, "elevation": ELEVATION, "projection": "orthographic", "models": models, "mapped": ["merchant"] if merchant_only else _keys, "merchant_only": merchant_only, "count": models.size(), "visible": visible, "requested_frame": requested_frame, "current_frame": Engine.get_process_frames()}


func _factory_has(method: String) -> bool:
	for item: Dictionary in _resident_factory.get_script_method_list():
		if item["name"] == method:
			return true
	return false


func _sample_residents() -> bool:
	if _resident_factory == null or not _factory_has("sample_idle"):
		return false
	var changed := false
	for index in _models.size():
		var key: String = _keys[index]
		if not _resident_sources.has(key):
			continue
		var source: Villager = (_resident_sources[key] as WeakRef).get_ref()
		if not is_instance_valid(source):
			continue
		var sample: Dictionary = _resident_factory.call("sample_idle", _models[index], source._time)
		var old: Dictionary = _resident_samples.get(key, {})
		changed = changed or sample.get("sample_time", -1.0) != old.get("sample_time", -1.0)
		_resident_samples[key] = sample
	return changed


func _process(_delta: float) -> void:
	# The imported gallery body reads the real town resident's clock.
	# Other inspection modes retain their one-frame rendering behavior.
	if merchant_only and visible and _sample_residents():
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _model_scene_paths(root: Node3D) -> Array[String]:
	var paths: Array[String] = []
	var nodes: Array[Node] = root.find_children("*", "Node3D", true, false)
	nodes.append(root)
	for node: Node in nodes:
		if not node.scene_file_path.is_empty() and not paths.has(node.scene_file_path):
			paths.append(node.scene_file_path)
	return paths

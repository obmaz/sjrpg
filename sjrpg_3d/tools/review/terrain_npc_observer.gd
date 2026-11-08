extends Node
## CI-only observer copied into the exported project by its focused workflow.
## Photography changes only the render camera; physical actors/surfaces stay live.
const ELEVATION := 35.264389682754654
const NAMES := {"warrior": "전사 · 크기 비교", "merchant": "상인", "smith": "대장장이", "stable": "마구간지기", "elder": "촌장", "mira": "보급원 미라", "elin": "수녀 엘린", "noah": "약초사 노아", "rowen": "조사관 로웬"}
var root: Node
var callback: JavaScriptObject
var mode := ""
var role := 0
var face := 0
var requested_frame := 0
var gallery: NativeModelGallery
var elapsed := 0.0
var terrain_cache: Array = []
var terrain_owner := 0

func setup(source: Node) -> Node:
	root = source
	return self

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100
	callback = JavaScriptBridge.create_callback(_action)
	var window := JavaScriptBridge.get_interface("window")
	window.__sjrpgTerrainNpcAction = callback

func _action(arguments: Array) -> void:
	if arguments.size() != 3:
		return
	var next_mode := str(arguments[0])
	var next_role := int(arguments[1])
	var next_face := int(arguments[2])
	if next_mode not in ["terrain", "residents", "clear"] or next_face < 0 or next_face > 3:
		return
	if next_mode == "terrain" and (next_role < 0 or next_role > 3):
		return
	mode = next_mode
	role = next_role
	face = next_face
	requested_frame = Engine.get_process_frames()
	if is_instance_valid(gallery):
		gallery.hide()
	if mode == "residents" and is_instance_valid(root.current) and root.current is NativeAdventure:
		if not is_instance_valid(gallery):
			gallery = NativeModelGallery.new().setup(root.current.simulation)
			add_child(gallery)
		gallery.show()
		_layout_residents()

func _layout_residents() -> void:
	gallery.set_face(face)
	var keys: Array[String] = ["warrior"]
	if role == 1:
		keys.append_array(["merchant", "mira"])
	else:
		keys.append_array(NativeResidents3D.IDS)
	var yaw := deg_to_rad(45.0 + face * 90.0)
	var toward := Vector3(sin(yaw), 0, cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var focus := Vector3(0, 0.9, 0)
	gallery.camera.size = 4.0 if role == 1 else 10.4
	gallery.camera.position = focus + Vector3(toward.x, tan(deg_to_rad(ELEVATION)), toward.z).normalized() * 35.0
	gallery.camera.look_at(focus, Vector3.UP)
	for index in gallery._models.size():
		var key: String = gallery._keys[index]
		var slot := keys.find(key)
		gallery._models[index].visible = slot >= 0
		gallery._names[index].visible = slot >= 0
		if slot >= 0:
			if role == 1:
				gallery._models[index].position = right * (float(slot) - 1.0) * 1.18
			else:
				gallery._models[index].position = right * (float(slot % 3) - 1.0) * 3.0 + toward * (float(slot / 3) - 1.0) * (3.0 / sin(deg_to_rad(ELEVATION)))
			gallery._names[index].text = NAMES[key]
	gallery._title.text = ("크기 · 얼굴 · 의상 비교 · %d°" if role == 1 else "마을 주민 · 실제 게임 모델 · %d°") % (45 + face * 90)
	gallery._sample_residents()
	gallery._layout()
	for index in gallery._models.size():
		gallery._names[index].visible = gallery._models[index].visible
	gallery.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _process(delta: float) -> void:
	if not is_instance_valid(root.current) or not (root.current is NativeAdventure):
		return
	var game: Node = root.current.simulation
	if not is_instance_valid(game.ortho_preview) or not is_instance_valid(game.spatial_world):
		return
	var preview: Node = game.ortho_preview
	if terrain_owner != game.get_instance_id():
		terrain_owner = game.get_instance_id()
		terrain_cache = _terrain_report(game, preview)
	if mode == "terrain":
		_photograph(preview)
	elif mode == "residents" and is_instance_valid(gallery):
		if gallery._sample_residents():
			gallery.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	elapsed += delta
	if elapsed < 0.2:
		return
	elapsed = 0.0
	var inspection_camera: Camera3D = gallery.camera if mode == "residents" and is_instance_valid(gallery) else preview.camera
	var eye := inspection_camera.global_basis.z.normalized()
	var origin := inspection_camera.unproject_position(inspection_camera.global_position - eye * 20.0)
	var axes := []
	for axis: Vector3 in [Vector3.RIGHT, Vector3.FORWARD, Vector3.UP]:
		var point := inspection_camera.unproject_position(inspection_camera.global_position - eye * 20.0 + axis) - origin
		axes.append([point.x, point.y])
	var data := {"mode": mode, "role": role, "face": face, "frame": Engine.get_process_frames(), "requested_frame": requested_frame, "terrain": terrain_cache, "physics": _physical_surfaces(game), "projection": "orthographic" if inspection_camera.projection == Camera3D.PROJECTION_ORTHOGONAL else "perspective", "azimuth": fposmod(rad_to_deg(atan2(eye.x, eye.z)), 360.0), "elevation": rad_to_deg(asin(eye.y)), "axes": axes, "player": [game.player.position.x, game.player.position.y], "residents": preview._native_residents.review_snapshot()}
	if mode == "residents" and is_instance_valid(gallery):
		var snapshot := gallery.review_snapshot()
		var selected := []
		for model: Dictionary in snapshot["models"]:
			var model_index: int = gallery._keys.find(str(model["identity"]))
			if model_index >= 0 and gallery._models[model_index].visible:
				selected.append(model)
		snapshot["models"] = selected
		snapshot["count"] = selected.size()
		data["gallery"] = snapshot
		data["native_poses"] = _native_poses(preview)
	JavaScriptBridge.eval("window.__sjrpgTerrainNpcReview = " + JSON.stringify(data), true)

func _physical_surfaces(game: Node) -> Array:
	var result := []
	for item: Dictionary in SpatialWorld3D.terrain_surfaces(game.village):
		var points := []
		for point: Vector3 in SpatialWorld3D.surface_faces(item):
			points.append([point.x, point.y, point.z])
		result.append({"id": item["id"], "faces": points, "surface": _plain(item)})
	return result

func _plain(value: Variant) -> Variant:
	if value is Vector2:
		return [value.x, value.y]
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			result[str(key)] = _plain(value[key])
		return result
	if value is Array or value is PackedVector2Array or value is PackedVector3Array:
		var result := []
		for item: Variant in value:
			result.append(_plain(item))
		return result
	return value

func _terrain_report(game: Node, preview: Node) -> Array:
	var result := []
	var container: Node = preview._world_environment.forest.get_node("NativeLandmarks")
	for entry: Dictionary in container.get_meta("native_landmark_report")["entries"]:
		var group: Node3D = entry["root"]
		var top: MeshInstance3D = group.get_node("WalkableTop")
		var upper := top.material_override as StandardMaterial3D
		var lower := preview._materials["grass"] as StandardMaterial3D
		var earth: MeshInstance3D = group.get_node_or_null("ExposedEarth")
		var earth_material := earth.material_override as StandardMaterial3D if earth else null
		result.append({"role": entry["role"], "upper_color": [upper.albedo_color.r, upper.albedo_color.g, upper.albedo_color.b], "lower_color": [lower.albedo_color.r, lower.albedo_color.g, lower.albedo_color.b], "upper_texture": upper.albedo_texture.resource_path if upper.albedo_texture else "", "lower_texture": lower.albedo_texture.resource_path if lower.albedo_texture else "", "earth": earth != null, "earth_texture": earth_material.albedo_texture.resource_path if earth_material else "", "rise": entry["surface"]["rise"], "floor_height": game.spatial_world.height_at(game.player.position)})
	return result

func _photograph(preview: Node) -> void:
	var container: Node = preview._world_environment.forest.get_node("NativeLandmarks")
	var group: Node3D = container.get_node("Landmark%d" % role)
	var bounds: AABB = group.get_node("WalkableTop").get_aabb()
	# Enclose the actual walkable top and its exposed native cliff, with valley
	# grass around it. No hidden/cropped replacement geometry is constructed.
	bounds = group.get_node("WalkableTop").global_transform * bounds
	bounds.position.y = minf(0.0, bounds.position.y)
	bounds.size.y = maxf(0.1, group.get_node("WalkableTop").get_aabb().end.y) - bounds.position.y
	var focus := bounds.get_center()
	var yaw := deg_to_rad(45.0 + face * 90.0)
	var direction := Vector3(sin(yaw), tan(deg_to_rad(ELEVATION)), cos(yaw)).normalized()
	var camera: Camera3D = preview.camera
	camera.position = focus + direction * 52.0
	camera.look_at(focus, Vector3.UP)
	var width := 0.0
	var height := 0.0
	for corner in 8:
		var offset: Vector3 = bounds.get_endpoint(corner) - focus
		width = maxf(width, absf(offset.dot(camera.global_basis.x)) * 2.0)
		height = maxf(height, absf(offset.dot(camera.global_basis.y)) * 2.0)
	var aspect := float(preview.viewport.size.x) / float(preview.viewport.size.y)
	camera.size = maxf(height + 5.0, (width + 6.0) / aspect)
	camera.near = 0.05
	camera.far = 125.0
	preview.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _native_poses(preview: Node) -> Dictionary:
	var result := {}
	for entry: Dictionary in preview._native_residents.entries.values():
		if str(entry["source"]) != "cc0_import":
			continue
		var body: Node3D = entry["node"]
		var identity: String = str(body.get_meta("resident_identity", ""))
		var source: Villager = (entry["owner"] as WeakRef).get_ref()
		if not is_instance_valid(source):
			continue
		var poses := []
		for child: Node in body.find_children("*", "Skeleton3D", true, false):
			var skeleton := child as Skeleton3D
			for index in skeleton.get_bone_count():
				var at := skeleton.get_bone_pose(index)
				var rotation := at.basis.orthonormalized().get_rotation_quaternion()
				poses.append([at.origin.x, at.origin.y, at.origin.z, rotation.x, rotation.y, rotation.z, rotation.w])
		result[identity] = {"source_time": source._time, "sample_time": entry["sample_time"], "clip": entry["clip"], "bone_poses": poses}
	return result

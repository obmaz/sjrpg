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
var chapel_group: Node3D
var static_physics_digest := ""
var sampled_physics_digest := ""
var static_physics_count := 0
var static_physics_original: Array = []
var static_physics_original_json := ""
var static_physics_delta: Dictionary = {}
var static_shape_owners: Dictionary = {}
var hid_hud := false
var original_hud_visible := true

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
	if next_mode not in ["terrain", "residents", "house", "chapel", "gate", "corner", "wall_detail", "clear"] or next_face < 0 or next_face > 3:
		return
	if next_mode == "terrain" and (next_role < 0 or next_role > 3):
		return
	mode = next_mode
	role = next_role
	face = next_face
	requested_frame = Engine.get_process_frames()
	if is_instance_valid(root.current) and root.current is NativeAdventure:
		var game: Node = root.current.simulation
		if is_instance_valid(game.spatial_world):
			# Resample actual installed collider geometry for every requested view,
			# rather than comparing an initial cache against itself.
			var current := _static_geometry(game)
			var serialized := JSON.stringify(current)
			sampled_physics_digest = serialized.sha256_text()
			static_physics_delta = _static_delta(current, serialized) if sampled_physics_digest != static_physics_digest else {}
			JavaScriptBridge.eval("window.__sjrpgTerrainNpcCurrentStaticPhysics = " + serialized, true)
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
	# Game._ready awaits the first physics frame, installs all six encounter
	# stones, rebuilds native geometry, awaits the broad phase, then marks ready.
	# Early renderer probes are not the completed construction boundary.
	if not game.native_ready:
		return
	var preview: Node = game.ortho_preview
	if terrain_owner != game.get_instance_id():
		terrain_owner = game.get_instance_id()
		terrain_cache = _terrain_report(game, preview)
		chapel_group = null
		for candidate: Node in preview.stage.find_children("*", "Node3D", true, false):
			if candidate.has_meta("chapel_detail"):
				chapel_group = candidate as Node3D
				break
		var construction := _static_geometry(game)
		var serialized := JSON.stringify(construction)
		static_physics_digest = serialized.sha256_text()
		sampled_physics_digest = static_physics_digest
		static_physics_count = construction.size()
		static_physics_original = construction
		static_physics_original_json = serialized
		JavaScriptBridge.eval("window.__sjrpgTerrainNpcStaticPhysics = " + serialized, true)
	var architecture_mode := mode in ["house", "chapel", "gate", "corner", "wall_detail"]
	if architecture_mode and not hid_hud:
		original_hud_visible = game.hud.visible
		game.hud.visible = false
		hid_hud = true
	elif not architecture_mode and hid_hud:
		game.hud.visible = original_hud_visible
		hid_hud = false
	if mode == "terrain":
		_photograph(preview)
	elif architecture_mode:
		_architecture_photograph(preview)
	elif mode == "residents" and is_instance_valid(gallery):
		# The opaque isolated gallery fully covers the world. Keep real physics,
		# source clocks and native skeleton sync alive, but do not shade an unseen
		# forest behind this explicit CI photograph.
		preview.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
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
	var data := {"mode": mode, "role": role, "face": face, "frame": Engine.get_process_frames(), "requested_frame": requested_frame, "terrain": terrain_cache, "physics": _physical_surfaces(game), "projection": "orthographic" if inspection_camera.projection == Camera3D.PROJECTION_ORTHOGONAL else "perspective", "azimuth": fposmod(rad_to_deg(atan2(eye.x, eye.z)), 360.0), "elevation": rad_to_deg(asin(eye.y)), "axes": axes, "player": [game.player.position.x, game.player.position.y], "residents": preview._native_residents.review_snapshot(), "quality": "low" if Prefs.low_resolution else "high", "render_size": [preview.viewport.size.x, preview.viewport.size.y], "hud_hidden": not game.hud.visible, "static_physics_sha256": sampled_physics_digest, "initial_static_physics_sha256": static_physics_digest, "static_physics_shapes": static_physics_count, "static_physics_delta": static_physics_delta, "camera_size": inspection_camera.size, "camera_position": _plain(inspection_camera.global_position)}
	if architecture_mode:
		data["architecture"] = _architecture_report(preview)
	if mode == "residents" and is_instance_valid(gallery):
		var snapshot := gallery.review_snapshot()
		var selected := []
		for model: Dictionary in snapshot["models"]:
			var model_index: int = gallery._keys.find(str(model["identity"]))
			if model_index >= 0 and gallery._models[model_index].visible:
				selected.append(model)
		snapshot["models"] = selected
		snapshot["count"] = selected.size()
		snapshot["render_size"] = [gallery.viewport.size.x, gallery.viewport.size.y]
		snapshot["msaa"] = gallery.viewport.msaa_3d
		snapshot["world_render_disabled_behind_opaque_gallery"] = preview.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED
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
	if value is AABB:
		return {"position": _plain(value.position), "size": _plain(value.size)}
	if value is Rect2:
		return {"position": _plain(value.position), "size": _plain(value.size)}
	if value is Transform3D:
		return {"origin": _plain(value.origin), "x": _plain(value.basis.x), "y": _plain(value.basis.y), "z": _plain(value.basis.z)}
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
	_frame_bounds(preview, bounds, Vector2(6.0, 5.0))

func _frame_bounds(preview: Node, bounds: AABB, margin: Vector2) -> void:
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
	camera.size = maxf(height + margin.y, (width + margin.x) / aspect)
	# Match the real presenter's fitted shadow depth slab instead of casting
	# through an arbitrary 125m forest while photographing a nearby terrace.
	var ground_depth := camera.size * 0.5 * sqrt(2.0)
	camera.near = maxf(0.05, 52.0 - ground_depth - 20.0)
	# Inspection focuses on building mid-height; visible ground behind that
	# elevated target lies focus.y/sin(elevation) farther than a foot-level view.
	# Keep the actual foreground/whole house while avoiding a clipped black band.
	var ground_focus_depth := maxf(4.0, focus.y / sin(deg_to_rad(ELEVATION)) + 1.0)
	camera.far = 52.0 + ground_depth + ground_focus_depth
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

func _static_geometry(game: Node) -> Array:
	var result := []
	for child: Node in game.spatial_world._geometry.find_children("*", "CollisionShape3D", true, false):
		var collider := child as CollisionShape3D
		var shape: Shape3D = collider.shape
		var data: Variant = null
		if shape is BoxShape3D:
			data = (shape as BoxShape3D).size
		elif shape is CylinderShape3D:
			data = [(shape as CylinderShape3D).radius, (shape as CylinderShape3D).height]
		elif shape is SphereShape3D:
			data = (shape as SphereShape3D).radius
		elif shape is CapsuleShape3D:
			data = [(shape as CapsuleShape3D).radius, (shape as CapsuleShape3D).height]
		elif shape is ConvexPolygonShape3D:
			data = (shape as ConvexPolygonShape3D).points
		elif shape is ConcavePolygonShape3D:
			data = (shape as ConcavePolygonShape3D).get_faces()
		var record := {"kind": shape.get_class(), "transform": _plain(collider.global_transform), "data": _plain(data)}
		static_shape_owners[JSON.stringify(record)] = {"body_kind": str(collider.get_parent().get_meta("physics_kind", "")), "path": str(collider.get_path())}
		result.append(record)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return JSON.stringify(a) < JSON.stringify(b))
	return result

func _architecture_bounds(preview: Node) -> AABB:
	var fort: Ortho3DFortification = preview._fortification
	var report: Dictionary = fort.report
	var wall_height: float = report["wall_top"]
	if mode == "chapel":
		var chapel: Dictionary = chapel_group.get_meta("chapel_detail")
		var footprint: Vector2 = chapel["footprint"]
		# Chapel footprint and tower height are unchanged by slate UV/pixels.
		# The actual metadata group includes nave, bell shaft and entire spire.
		return chapel_group.global_transform * AABB(Vector3(-footprint.x * 0.5 - 0.45, 0, -footprint.y * 0.5 - 0.45), Vector3(footprint.x + 0.9, float(chapel["tower_height"]) + 0.25, footprint.y + 0.9))
	if mode == "house":
		var key: String = ["nw", "ne", "sw", "se"][role]
		var house: Dictionary = preview._houses[key]
		var footprint: Vector2 = house["footprint"]
		var peak: float = float(house["eaves_height"]) + float(house["roof_rise"]) + 1.80
		var meshes: Array = house["meshes"]
		var owner: Node3D = (meshes[0] as MeshInstance3D).get_parent()
		# Nominal unchanged footprint/roof height fixes the paired camera even
		# when a small coping/bevel changes the candidate's true mesh bounds.
		return owner.global_transform * AABB(Vector3(-footprint.x * 0.5 - 0.4, 0, -footprint.y * 0.5 - 0.4), Vector3(footprint.x + 0.8, peak, footprint.y + 0.8))
	if mode == "gate":
		var gate: Dictionary = fort.gates[role]
		var width: float = gate["width"]
		var depth: float = gate["depth"]
		var frame: Transform3D = gate["frame"]
		return frame * AABB(Vector3(-width * 0.5 - 2.4, 0, -depth * 0.5 - 1.2), Vector3(width + 4.8, wall_height + 2.0, depth + 2.4))
	if mode == "corner":
		var point: Vector3 = report["corners"][role]
		return AABB(point + Vector3(-3.0, 0, -3.0), Vector3(6.0, wall_height + 0.8, 6.0))
	var longest := 0.0
	var start := Vector2.ZERO
	var end := Vector2.ZERO
	for polygon: PackedVector2Array in report["wall_polygons"]:
		for index in polygon.size():
			var a := polygon[index]
			var b := polygon[(index + 1) % polygon.size()]
			if a.distance_squared_to(b) > longest:
				longest = a.distance_squared_to(b)
				start = a
				end = b
	# 37% avoids centering exactly on a repeated support pier, while deriving
	# the target solely from the unchanged original wall footprint.
	var flat := start.lerp(end, 0.37)
	return AABB(Vector3(flat.x - 1.4, wall_height - 2.4, flat.y - 1.4), Vector3(2.8, 3.2, 2.8))

func _architecture_photograph(preview: Node) -> void:
	_frame_bounds(preview, _architecture_bounds(preview), Vector2(0.6, 0.6))

func _material_report(material: StandardMaterial3D) -> Dictionary:
	return {"texture": material.albedo_texture.resource_path if material.albedo_texture else "", "color": [material.albedo_color.r, material.albedo_color.g, material.albedo_color.b], "uv_scale": _plain(material.uv1_scale), "triplanar": material.uv1_triplanar, "world_triplanar": material.uv1_world_triplanar, "roughness": material.roughness, "texture_size": [material.albedo_texture.get_width(), material.albedo_texture.get_height()] if material.albedo_texture else []}

func _architecture_report(preview: Node) -> Dictionary:
	var fort: Ortho3DFortification = preview._fortification
	var data := {"kind": mode, "index": role, "bounds": _plain(_architecture_bounds(preview)), "stone": _material_report(preview._materials["stone"]), "wood": _material_report(preview._materials["wood"]), "slate": _material_report(preview._materials["slate"]), "same_fortification_stone": fort.report["stone"] == preview._materials["stone"], "fortification_triangles": fort.report["triangles"], "fortification_surfaces": fort.report["static_surfaces"]}
	if mode == "chapel":
		var chapel: Dictionary = chapel_group.get_meta("chapel_detail")
		data["key"] = "chapel"
		data["triangles"] = chapel["triangles"]
		data["surfaces"] = chapel["surfaces"]
		data["footprint"] = _plain(chapel["footprint"])
		data["tower_height"] = chapel["tower_height"]
		data["floor_height"] = chapel["floor_height"]
		var shared := true
		for mesh: MeshInstance3D in chapel["meshes"]:
			if mesh.name == "ChapelDetail_stone":
				shared = shared and mesh.material_override == preview._materials["stone"]
			elif mesh.name == "ChapelDetail_slate":
				data["slate"] = _material_report(mesh.material_override as StandardMaterial3D)
		data["same_chapel_stone"] = shared
	if mode == "house":
		var key: String = ["nw", "ne", "sw", "se"][role]
		var house: Dictionary = preview._houses[key]
		data["key"] = key
		data["triangles"] = house["triangles"]
		data["surfaces"] = house["surfaces"]
		data["footprint"] = _plain(house["footprint"])
		data["closed_door"] = house["closed_door"]
		var shared := true
		for mesh: MeshInstance3D in house["meshes"]:
			if mesh.name.ends_with("_stone"):
				shared = shared and mesh.material_override == preview._materials["stone"]
			elif mesh.name.ends_with("_wood"):
				data["wood"] = _material_report(mesh.material_override as StandardMaterial3D)
			elif mesh.name.ends_with("_slate"):
				data["slate"] = _material_report(mesh.material_override as StandardMaterial3D)
		data["same_house_stone"] = shared
	if mode == "gate":
		var gate: Dictionary = fort.gates[role]
		var outward: Vector3 = gate["outward"]
		var frame: Transform3D = gate["frame"]
		data["view_side"] = "outside" if (preview.camera.global_position - frame.origin).dot(outward) > 0 else "inside"
		data["progress"] = gate["progress"]
		data["frame"] = _plain(frame)
		data["width"] = gate["width"]
		data["depth"] = gate["depth"]
	return data

func _static_delta(current: Array, current_json: String) -> Dictionary:
	var index := 0
	while index < mini(static_physics_original_json.length(), current_json.length()) and static_physics_original_json[index] == current_json[index]:
		index += 1
	var old_counts := {}
	var new_counts := {}
	for item: Dictionary in static_physics_original:
		var key := JSON.stringify(item)
		old_counts[key] = int(old_counts.get(key, 0)) + 1
	for item: Dictionary in current:
		var key := JSON.stringify(item)
		new_counts[key] = int(new_counts.get(key, 0)) + 1
	var all_keys := old_counts.keys()
	for key: String in new_counts:
		if not old_counts.has(key):
			all_keys.append(key)
	var changes := []
	for key: String in all_keys:
		var before: int = int(old_counts.get(key, 0))
		var after: int = int(new_counts.get(key, 0))
		if before == after:
			continue
		var item: Dictionary = JSON.parse_string(key)
		var data: Variant = item["data"]
		changes.append({"owner": static_shape_owners.get(key, {}), "kind": item["kind"], "transform": item["transform"], "data_sha256": JSON.stringify(data).sha256_text(), "data_length": data.size() if data is Array or data is Dictionary else -1, "data_head": data.slice(0, 3) if data is Array else data, "count_before": before, "count_current": after, "record_text_head": key.left(240)})
		if changes.size() >= 5:
			break
	return {"initial_count": static_physics_original.size(), "current_count": current.size(), "initial_text_length": static_physics_original_json.length(), "current_text_length": current_json.length(), "first_text_difference": index, "initial_text_slice": static_physics_original_json.substr(maxi(0, index - 90), 250), "current_text_slice": current_json.substr(maxi(0, index - 90), 250), "changed_records": changes}

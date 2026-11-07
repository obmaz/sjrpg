class_name NativeStyleReview
extends Node
## Read-only inspection of the actual native scene; enabled only by explicit URL.
var _root: Node
var _elapsed := 0.0
var _callback: JavaScriptObject
var _gallery: Control
func setup(root: Node) -> NativeStyleReview:
	_root = root
	return self
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		_callback = JavaScriptBridge.create_callback(_action)
		var window := JavaScriptBridge.get_interface("window")
		window.__sjrpgNativeStyleAction = _callback
func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.25 or not OS.has_feature("web"):
		return
	_elapsed = 0.0
	if not is_instance_valid(_root) or not (_root.current is NativeAdventure):
		return
	var game: Node = _root.current.simulation
	if not is_instance_valid(game) or not is_instance_valid(game.hud):
		return
	var hud: Hud = game.hud
	var buttons := {}
	for key: String in hud.controls._buttons:
		var b: Dictionary = hud.controls._buttons[key]
		var center: Vector2 = b["center"]
		var radius: float = b["radius"]
		var half: Vector2 = b.get("half_size", Vector2.ONE * radius)
		buttons[key] = [center.x - half.x, center.y - half.y, half.x * 2.0, half.y * 2.0]
	var geometry: Dictionary = hud.status_geometry()
	var portrait: Vector2 = geometry["portrait"]
	var radius: float = geometry["radius"]
	var panel := {}
	if is_instance_valid(hud._panel):
		var p: PanelFrame = hud._panel
		var targets := []
		for child in p.find_children("*", "Button", true, false):
			var button := child as Button
			if button.is_visible_in_tree():
				targets.append({"text": button.text, "rect": rect(button), "disabled": button.disabled, "in_body": p.body.is_ancestor_of(button), "world_zoom": button.get_meta("world_zoom", -1.0)})
		panel = {"rect": rect(p._panel), "title": rect(p.title_label), "subtitle": rect(p.subtitle_label), "body": rect(p.body_holder), "body_clip": rect(p.scroll), "subtitle_text": p.subtitle_label.text, "subtitle_visible": p.subtitle_label.is_visible_in_tree(), "title_text": p.title_label.text, "shopping": p is BagPanel and p.shopping, "buttons": targets, "type": p.get_script().resource_path}
		if p is SkillTreePanel:
			var nodes := []
			for id: String in p._nodes:
				var box: Rect2 = p._nodes[id]
				box.position += p._tree.global_position
				nodes.append({"id": id, "rect": [box.position.x, box.position.y, box.size.x, box.size.y], "hit_rect": rect_value(box.grow(8.0)), "rank": GameState.rank(id), "reason": GameState.learn_block_reason(GameState.skill(id))})
			panel["nodes"] = nodes
			panel["tree_clip"] = rect(p._tree_scroll)
			panel["tree_scroll_value"] = p._tree_scroll.scroll_vertical
			var tree_bar: VScrollBar = p._tree_scroll.get_v_scroll_bar()
			panel["tree_scroll_max"] = maxf(0.0, tree_bar.max_value - tree_bar.page)
			panel["selected"] = p._selected
	var coverage := {}
	var preview: Node = game.ortho_preview
	if is_instance_valid(preview):
		coverage["environment"] = preview._world_environment.report if is_instance_valid(preview._world_environment) else {}
		var retained := []
		for entry: Dictionary in preview._cards.values():
			var source: Node = entry["owner"].get_ref()
			if not is_instance_valid(source) or source is Effect:
				continue
			var foot: Vector2 = source.position
			retained.append({"id": source.get_instance_id(), "name": source.name, "type": source.get_script().resource_path, "foot": [foot.x, foot.y]})
		coverage["actor_cards"] = retained
		var corpse_cards := []
		var corpse_count := 0
		if is_instance_valid(preview._world_environment):
			corpse_count = preview._world_environment._corpses.size()
			for id: int in preview._world_environment._corpses:
				if preview._world_environment._corpses[id] is MeshInstance3D:
					corpse_cards.append(id)
		coverage["corpse_count"] = corpse_count
		coverage["corpse_cards"] = corpse_cards
		coverage["landmark_views"] = _landmark_views(preview)
		for property: Dictionary in preview.get_property_list():
			var key: String = property["name"]
			if key.begins_with("_native_") or key.begins_with("_resident") or key.begins_with("_enemy"):
				var renderer: Variant = preview.get(key)
				if renderer is Object and is_instance_valid(renderer):
					if renderer.has_method("review_snapshot"):
						coverage[key] = renderer.review_snapshot()
					elif renderer.has_method("snapshot"):
						coverage[key] = renderer.snapshot()
	var audit_path: String = "res://scripts/native_actor_proportion_audit.gd"
	if is_instance_valid(preview) and ResourceLoader.exists(audit_path):
		var audit: Script = load(audit_path)
		coverage["actor_proportions"] = audit.measure(preview)
	var view := hud.controls.get_viewport_rect().size
	var report := {"viewport": [view.x, view.y], "frame": Engine.get_process_frames(), "class": GameState.hero_class, "buttons": buttons, "avatar": [portrait.x-radius, portrait.y-radius, radius*2.0, radius*2.0], "hp": rect_value(geometry["hp"]), "mp": rect_value(geometry["mp"]), "level_badge": rect_value(geometry["level_badge"]), "level": GameState.level, "panel": panel, "paused": get_tree().paused, "native": game.native_ready, "dungeon_active": game.dungeon.active, "entry_distance": game.player.position.distance_to(game.dungeon.entry_point()), "coverage": coverage, "player": [game.player.position.x, game.player.position.y], "potions": [GameState.potions, GameState.mana_potions], "zoom": game.camera.zoom.x, "native_camera_size": game.ortho_preview.camera.size, "world_zoom": Prefs.world_zoom}
	report["merchant"] = _merchant_review(game, preview)
	report["gallery_available"] = ResourceLoader.exists("res://scripts/native_model_gallery.gd")
	if is_instance_valid(_gallery) and _gallery.visible:
		report["gallery"] = _gallery.review_snapshot()
	JavaScriptBridge.eval("window.__sjrpgNativeStyleReview = " + JSON.stringify(report), true)
static func rect(control: Control) -> Array:
	return rect_value(control.get_global_rect())
static func rect_value(box: Rect2) -> Array:
	return [box.position.x, box.position.y, box.size.x, box.size.y]

func _action(arguments: Array) -> void:
	if arguments.size() != 2 or str(arguments[0]) not in ["gallery", "merchant_gallery"]:
		return
	var face := int(arguments[1])
	if face < 0:
		if is_instance_valid(_gallery):
			_gallery.hide()
		return
	if face > 3 or not ResourceLoader.exists("res://scripts/native_model_gallery.gd") or not (_root.current is NativeAdventure):
		return
	if not is_instance_valid(_gallery):
		var source: Script = load("res://scripts/native_model_gallery.gd")
		_gallery = source.new().setup(_root.current.simulation)
		add_child(_gallery)
	if _gallery.has_method("set_merchant_only"):
		_gallery.set_merchant_only(str(arguments[0]) == "merchant_gallery")
	_gallery.show()
	_gallery.set_face(face)

## Actual authored mesh envelope projected through the live game camera.
## No camera/model transforms are modified by this observer.
func _landmark_views(preview: Node) -> Array:
	var result: Array = []
	var environment: Object = preview._world_environment
	if not is_instance_valid(environment) or not is_instance_valid(environment.forest):
		return result
	var container: Node = environment.forest.get_node_or_null("NativeLandmarks")
	if not is_instance_valid(container) or not container.has_meta("native_landmark_report"):
		return result
	var metadata: Dictionary = container.get_meta("native_landmark_report")
	var camera: Camera3D = preview.camera
	var native_size: Vector2 = Vector2(preview.viewport.size)
	var display_box: Rect2 = preview.display.get_global_rect()
	for entry: Dictionary in metadata.get("entries", []):
		var group: Node3D = entry.get("root")
		if not is_instance_valid(group):
			continue
		var mesh_count: int = 0
		var bounds: AABB = AABB()
		for child: Node in group.find_children("*", "MeshInstance3D", true, false):
			var instance: MeshInstance3D = child as MeshInstance3D
			if instance.mesh == null or not instance.is_visible_in_tree():
				continue
			var mesh_bounds: AABB = instance.global_transform * instance.mesh.get_aabb()
			bounds = mesh_bounds if mesh_count == 0 else bounds.merge(mesh_bounds)
			mesh_count += 1
		if mesh_count == 0:
			continue
		var projected: Rect2 = Rect2()
		for corner_index: int in range(8):
			var point: Vector2 = camera.unproject_position(bounds.get_endpoint(corner_index))
			point = display_box.position + point / native_size * display_box.size
			projected = Rect2(point, Vector2.ZERO) if corner_index == 0 else projected.expand(point)
		var clipped: Rect2 = projected.intersection(display_box)
		var ratio: float = clipped.get_area() / maxf(1.0, projected.get_area())
		result.append({"role": entry.get("role", -1), "source_id": entry.get("source_id", -1), "meshes": mesh_count, "bounds_min": [bounds.position.x, bounds.position.y, bounds.position.z], "bounds_max": [bounds.end.x, bounds.end.y, bounds.end.z], "projected": rect_value(projected), "visible_area_ratio": ratio, "center_behind_camera": camera.is_position_behind(bounds.get_center())})
	return result


func _merchant_review(game: Node, preview: Node) -> Dictionary:
	if not is_instance_valid(preview):
		return {}
	var renderer: Object
	for property: Dictionary in preview.get_property_list():
		if property["name"] == "_native_residents":
			renderer = preview.get("_native_residents")
			break
	if not is_instance_valid(renderer):
		return {}
	var entries: Dictionary = renderer.get("entries")
	for entry: Dictionary in entries.values():
		var source: Villager = (entry["owner"] as WeakRef).get_ref()
		if not is_instance_valid(source) or NpcArt.identity(source.display_name) != "merchant":
			continue
		var model: Node3D = entry["node"]
		var skinned := 0
		var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
		if model is MeshInstance3D:
			meshes.append(model)
		for node: Node in meshes:
			if (node as MeshInstance3D).skin != null:
				skinned += 1
		var poses: Array = []
		var bone_count := 0
		var foot_origins: Array = []
		for node: Node in model.find_children("*", "Skeleton3D", true, false):
			var skeleton: Skeleton3D = node as Skeleton3D
			for index in skeleton.get_bone_count():
				var pose: Transform3D = skeleton.get_bone_pose(index)
				var rotation: Quaternion = pose.basis.orthonormalized().get_rotation_quaternion()
				poses.append([pose.origin.x, pose.origin.y, pose.origin.z, rotation.x, rotation.y, rotation.z, rotation.w])
				bone_count += 1
				var bone_name: String = skeleton.get_bone_name(index)
				if "foot" in bone_name.to_lower() or "toe" in bone_name.to_lower():
					var world_pose: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(index)
					foot_origins.append({"name": bone_name, "world": [world_pose.origin.x, world_pose.origin.y, world_pose.origin.z]})
		var native_foot: Vector3 = Ortho3DPreview.ground_position(source.position, preview.surface_height(source.position))
		var approaches: Array = []
		for offset: Vector2 in [Vector2(-160, 50), Vector2(-150, 75), Vector2(160, 50), Vector2(150, 75), Vector2(-130, 60), Vector2(130, 60)]:
			var point: Vector2 = source.position + offset
			var legal: bool = not game.spatial_world.blocked(point, Player.RADIUS)
			var native: Vector3 = Ortho3DPreview.ground_position(point, preview.surface_height(point))
			var display_box: Rect2 = preview.display.get_global_rect()
			var projected: Vector2 = display_box.position + preview.camera.unproject_position(native) / Vector2(preview.viewport.size) * display_box.size
			approaches.append({"point": [point.x, point.y], "projected": [projected.x, projected.y], "legal": legal})
		var circle := {}
		for value: Array in game.village.circles:
			var point: Vector2 = value[0]
			if point.distance_squared_to(source.position) < 0.01:
				circle = {"position": [point.x, point.y], "radius": value[1]}
				break
		return {"identity": "merchant", "source": entry.get("source", "authored"), "asset": model.get_meta("resident_asset", ""), "scene_paths": _model_scene_paths(model), "meshes": meshes.size(), "skinned_meshes": skinned, "bone_count": bone_count, "bone_poses": poses, "foot_bone_origins": foot_origins, "floor_height": preview.surface_height(source.position), "clip": entry.get("clip", ""), "sample_time": entry.get("sample_time", 0.0), "source_time": source._time, "source_position": [source.position.x, source.position.y], "review_approaches": approaches, "native_foot": [native_foot.x, native_foot.y, native_foot.z], "model_position": [model.global_position.x, model.global_position.y, model.global_position.z], "model_scale": [model.scale.x, model.scale.y, model.scale.z], "circle": circle, "near_name": game.near_npc(), "quests": GameState.quests.duplicate(true)}
	return {}

func _model_scene_paths(root: Node3D) -> Array[String]:
	var paths: Array[String] = []
	var nodes: Array[Node] = root.find_children("*", "Node3D", true, false)
	nodes.append(root)
	for node: Node in nodes:
		if not node.scene_file_path.is_empty() and not paths.has(node.scene_file_path):
			paths.append(node.scene_file_path)
	return paths

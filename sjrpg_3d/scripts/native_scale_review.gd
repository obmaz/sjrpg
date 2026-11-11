class_name NativeScaleReview
extends Node
## Explicit ?scale_review=1 only; fresh browser fixtures use actual sources,
## native presenters and collision. Normal adventures never instantiate this.
var _root: Node
var _game: Node
var _preview: Ortho3DPreview
var _callback: JavaScriptObject
var _configured := false
var _ready_for_review := false
var _scene := "town"
var _phase := "initializing"
var _elapsed := 0.0
var _review_enemies: Array[Enemy] = []
var _chest: Chest
var _chest_index := 0
var _walking := false

func _physics_process(delta: float) -> void:
	if not _ready_for_review or not _walking or get_tree().paused:
		return
	var centre := Vector2.ZERO
	var count := 0
	for enemy: Enemy in _review_enemies:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		# 격리 검수에서도 운영 이동 모터·거리 누적·표시기를 그대로 사용한다.
		enemy._state = "chase"
		enemy._step(Vector2.DOWN, delta)
		centre += enemy.position
		count += 1
	if count > 0:
		_game._fx_review_focus = centre / count + Vector2(0, 15)

func setup(root: Node) -> NativeScaleReview:
	_root = root
	return self

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 2000
	_callback = JavaScriptBridge.create_callback(_action)
	JavaScriptBridge.get_interface("window").__sjrpgScaleAction = _callback
	_scene = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('scale_scene') || 'town'", true))
	_chest_index = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('scale_chest') || '0'", true)).to_int()

func _process(delta: float) -> void:
	if not _configured and _root.current is NativeAdventure:
		var candidate: Node = _root.current.simulation
		if is_instance_valid(candidate) and candidate.native_ready:
			_configured = true
			_game = candidate
			_preview = candidate.ortho_preview
			_prepare.call_deferred()
	if not _ready_for_review:
		return
	_elapsed += delta
	if _elapsed < 0.15:
		return
	_elapsed = 0.0
	JavaScriptBridge.eval("window.__sjrpgScaleReview = " + JSON.stringify(_snapshot()), true)

func _prepare() -> void:
	# Suppress unrelated ambient packs in this explicitly isolated review profile.
	_game._spawn_timer = 1000000000.0
	_game.encounters.set_process(false)
	for enemy: Enemy in _game.enemies:
		enemy.queue_free()
	_game.enemies.clear()
	for id in _game.encounters._members:
		_game.encounters._members[id] = []
	await get_tree().physics_frame
	await get_tree().process_frame
	if _scene == "actors":
		var centre: Vector2 = _game.village.boss_point
		_game.spatial_world.teleport_source_actor(_game.player, centre + Vector2(0, 160), Player.RADIUS)
		var index := 0
		var kinds: Array = Enemy.KINDS.keys()
		if str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('scale_crawler') || '0'", true)) == "1":
			kinds.append(NativeEnemyModels.CRAWLER)
		for kind: String in kinds:
			var enemy := Enemy.new()
			enemy.setup(_game, "goblin" if kind == NativeEnemyModels.CRAWLER else kind, 1)
			if kind == NativeEnemyModels.CRAWLER:
				enemy.set_meta("visual_variant", NativeEnemyModels.CRAWLER)
			enemy.position = centre + Vector2((index - (kinds.size() - 1) * 0.5) * 95.0, 0)
			enemy.facing = PI * 0.5
			enemy.xp_reward = 0
			_game.world.add_child(enemy)
			_game.enemies.append(enemy)
			# Same production setup/register/sync; stop AI only for like-for-like poses.
			enemy.set_process(false)
			_review_enemies.append(enemy)
			index += 1
		_game.player.set_process(false)
		_game._fx_review_focus = centre + Vector2(0, 15)
	elif _scene == "chest":
		_chest = _game.chests[clampi(_chest_index, 0, _game.chests.size() - 1)]
		var approach: Vector2 = _chest.position + Vector2(70, 100)
		_game.spatial_world.teleport_source_actor(_game.player, approach, Player.RADIUS)
		_game._fx_review_focus = _chest.position + Vector2(0, -42)
	elif _scene in ["landmark0", "landmark2", "landmark3", "cave_mouth", "chapel", "fountain", "shop", "stable", "wall", "bank", "road_end"]:
		_frame_environment(_scene)
	_game.camera.position = _game._camera_focus()
	_game.camera.reset_smoothing()
	await get_tree().physics_frame
	await get_tree().process_frame
	_phase = "live"
	_ready_for_review = true

func _action(args: Array) -> void:
	if not _ready_for_review or args.is_empty():
		return
	match str(args[0]):
		"walk":
			if _scene == "actors":
				_walking = bool(args[1]) if args.size() > 1 else true
				for enemy: Enemy in _review_enemies:
					enemy._state = "chase" if _walking else "idle"
				_phase = "walking" if _walking else "live"
		"face":
			var angle: float = float(args[1]) if args.size() > 1 else PI * 0.5
			for enemy: Enemy in _review_enemies:
				if is_instance_valid(enemy) and not enemy.dead:
					enemy.facing = angle
			_game.player.facing = angle
		"environment":
			_walking = false
			if args.size() > 1:
				_scene = str(args[1])
				_frame_environment(_scene)
		"freeze":
			get_tree().paused = true
			_preview._presentation_dirty = true
		"attack":
			_walking = false
			var phase := clampf(float(args[1]), 0.0, 1.0) if args.size() > 1 else 0.60
			for enemy: Enemy in _review_enemies:
				enemy._state = "windup" if phase < 0.60 else "recover"
				enemy._timer = enemy._windup_duration * (1.0 - phase / 0.60) if phase < 0.60 else enemy._recover_duration - (phase - 0.60) / 0.40 * enemy._recover_visual_duration
			_preview._presentation_dirty = true

		"corpses":
			_walking = false
			if _scene == "actors" and _phase == "live":
				_make_corpses.call_deferred()


func _frame_environment(scene: String) -> void:
	var focus: Vector2 = _game.player.position
	if scene.begins_with("landmark"):
		var index := int(scene.trim_prefix("landmark"))
		var source: Landmark = _game.village.landmarks[clampi(index, 0, 3)]
		focus = Iso.poly_bounds(source.top).get_center()
	elif scene == "cave_mouth":
		focus = _game.dungeon.entry_point() + Vector2(0, -110)
	elif scene == "chapel":
		var surface := SpatialWorld3D._native_chapel(_game.village)
		focus = Iso.poly_bounds(surface["building"]).get_center() + Vector2(0, -140)
	elif scene == "fountain":
		focus = Iso.poly_bounds(_game.village.fountain.atlas_polygon(_game.village.data["frames"]["pool"]["ground"])).get_center() + Vector2(0, -80)
	elif scene in ["shop", "stable"]:
		var key := "nw" if scene == "shop" else "sw"
		var house: IsoSprite = _game.village.buildings[key]
		focus = Iso.poly_bounds(house.atlas_polygon(_game.village.data["frames"][key]["ground"])).get_center() + Vector2(0, -100)
	elif scene == "wall":
		focus = _game.village.point(Vector2(0.04, 0.10)) + Vector2(0, -60)
	elif scene == "bank":
		focus = Iso.project(_game.village.forecourt_g + Vector2(140, 0))
	elif scene == "road_end":
		focus = Iso.project(Vector2(0, -4520))
	_game._fx_review_focus = focus
	_game.camera.position = focus
	_game.camera.reset_smoothing()
	_game.camera.force_update_scroll()
	_preview._presentation_dirty = true

func _make_corpses() -> void:
	_phase = "dying"
	for enemy: Enemy in _review_enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			enemy.take_damage(enemy.hp + 1.0, null)
	await get_tree().create_timer(0.4, false).timeout
	await get_tree().physics_frame
	await get_tree().process_frame
	# Explicit photograph after real deaths/sync; the production expiry clock
	# remains unchanged and is exercised separately by existing corpse tests.
	get_tree().paused = true
	_phase = "corpse_photo"

func _snapshot() -> Dictionary:
	var actors: Array = []
	for entry: Dictionary in _preview._enemy_models.entries.values():
		var enemy: Enemy = (entry["owner"] as WeakRef).get_ref()
		if not is_instance_valid(enemy):
			continue
		var model: Node3D = entry["root"]
		var body: CharacterBody3D = _game.spatial_world.actor_bodies.get(enemy.get_instance_id())
		actors.append({"kind": enemy.kind, "source_id": enemy.get_instance_id(), "dead": enemy.dead, "source_height_px": enemy.sprite.body_height, "facing": enemy.facing, "foot": _vec2(enemy.position), "model": _measure(model), "collision": _capsule(body)})
	var corpses: Array = []
	for corpse: Dictionary in _game.corpses:
		var visual: Node = corpse.get("visual")
		if not is_instance_valid(visual):
			continue
		var id: int = visual.get_instance_id()
		var model: Dictionary = _preview._world_environment._corpses.get(id, {})
		if not model.is_empty():
			corpses.append({"kind": corpse.get("kind", ""), "source_height_px": corpse.get("height", 0), "time": corpse.get("time", 0), "model": _measure(model["root"])})
	var chests: Array = []
	for entry: Dictionary in _preview._encounter_props._entries.values():
		if entry.get("role", "") != "chest":
			continue
		var chest: Chest = (entry["owner"] as WeakRef).get_ref()
		if not is_instance_valid(chest):
			continue
		var collision: Dictionary = {}
		for prop: Dictionary in _game.spatial_world._props:
			if (prop["owner"] as WeakRef).get_ref() == chest:
				var body: StaticBody3D = prop["body"]
				var shape: CylinderShape3D = (body.get_child(0) as CollisionShape3D).shape as CylinderShape3D
				var player_body: CharacterBody3D = _game.spatial_world.actor_bodies.get(_game.player.get_instance_id())
				var player_radius: float = float(_capsule(player_body).get("radius_m", 0))
				collision = {"center_m": _vec3(body.global_position), "radius_m": shape.radius, "height_m": shape.height, "radius_px": shape.radius * SpatialWorld3D.HORIZONTAL, "layer": body.collision_layer, "player_distance_m": Vector2(player_body.position.x - body.position.x, player_body.position.z - body.position.z).length(), "contact_min_m": player_radius + shape.radius}
		var root: Node3D = entry["root"]
		chests.append({"index": chest.index, "selected": chest == _chest, "opened": chest.dead, "foot": _vec2(chest.position), "screen_foot": _vec2(_project(Ortho3DPreview.ground_position(chest.position, _preview.surface_height(chest.position)))), "model": _measure(root), "collision": collision, "lid_angle": (entry["lid"] as Node3D).rotation.x, "splinters_visible": (entry["splinters"] as MeshInstance3D).visible})
	var logical_view: Vector2 = _game.get_viewport_rect().size
	return {"logical_view": _vec2(logical_view), "minimap": [_game.hud.minimap.global_position.x, _game.hud.minimap.global_position.y, _game.hud.minimap.size.x, _game.hud.minimap.size.y], "scene": _scene, "phase": _phase, "frame": Engine.get_process_frames(), "paused": get_tree().paused, "world_zoom": Prefs.world_zoom, "debug_zoom": _game._debug_zoom, "legacy_zoom": _game.camera.zoom.x, "native_camera_size": _preview.camera.size, "player": _vec2(_game.player.position), "player_moving": _game.player.has_move_target, "player_radius_px": Player.RADIUS, "enemy_default_radius_px": Enemy.RADIUS, "hero": _measure(_preview.actor), "actors": actors, "corpses": corpses, "chests": chests, "opened_chests": GameState.opened_chests, "gold": GameState.gold, "physics_ticks": _game.spatial_world.physics_ticks, "bounds_kind": "CPU mesh AABB with actual hierarchy transforms; hero skinned envelope is an upper bound, not a GPU silhouette"}

func _capsule(body: CharacterBody3D) -> Dictionary:
	if not is_instance_valid(body):
		return {}
	var shape: CapsuleShape3D = (body.get_child(0) as CollisionShape3D).shape as CapsuleShape3D
	return {"center_m": _vec3(body.global_position), "radius_m": shape.radius, "height_m": shape.height, "radius_px": body.get_meta("radius_pixels"), "layer": body.collision_layer}

func _measure(root: Node3D) -> Dictionary:
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.push_front(root)
	var bounds := AABB()
	var local_bounds := AABB()
	var count := 0
	for child: Node in meshes:
		var instance: MeshInstance3D = child as MeshInstance3D
		if instance.mesh == null or not instance.is_visible_in_tree():
			continue
		var world_box: AABB = instance.global_transform * instance.mesh.get_aabb()
		var local_box: AABB = root.global_transform.affine_inverse() * instance.global_transform * instance.mesh.get_aabb()
		bounds = world_box if count == 0 else bounds.merge(world_box)
		local_bounds = local_box if count == 0 else local_bounds.merge(local_box)
		count += 1
	var projected := Rect2()
	for i in 8:
		var point: Vector2 = _project(bounds.get_endpoint(i))
		projected = Rect2(point, Vector2.ZERO) if i == 0 else projected.expand(point)
	return {"meshes": count, "root_position_m": _vec3(root.global_position), "world_min_m": _vec3(bounds.position), "world_max_m": _vec3(bounds.end), "scale": _vec3(root.scale), "world_size_m": _vec3(bounds.size), "root_local_size_m": _vec3(local_bounds.size), "projected": [projected.position.x, projected.position.y, projected.size.x, projected.size.y]}

func _project(point: Vector3) -> Vector2:
	var box: Rect2 = _preview.display.get_global_rect()
	return box.position + _preview.camera.unproject_position(point) / Vector2(_preview.viewport.size) * box.size

static func _vec2(point: Vector2) -> Array:
	return [point.x, point.y]
static func _vec3(point: Vector3) -> Array:
	return [point.x, point.y, point.z]

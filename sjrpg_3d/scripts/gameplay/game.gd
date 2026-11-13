extends Node2D
## 숲1장의 월드·진행·HUD를 조립하고 공유 게임 규칙의 수명을 관리한다.

signal quit_requested
signal restart_requested
signal reload_requested

## Field in ground units (original scale): the town perimeter is data-driven.
const FIELD := ForestRegion.FIELD
const CORPSE_LIFETIME := 15.0
const CORPSE_LIMIT := 32
const CAMERA_WORLD_SCALE := 1.6
## Periodic safety net only. Loot, level-ups, quests, purchases and backgrounding
## save at once; a synchronous write every few seconds caused needless hitches.
const AUTOSAVE_SECONDS := 30.0

var scene_view: Viewport
var scene_root: Node
var world: Node2D
var forest_details: Array[IsoSprite] = []
var forest_lighting: ForestLighting
var forest_atmosphere: ForestAtmosphere
var world_renderer: WorldRenderer3D
var spatial_world: SpatialWorld3D
var native_ready := false
var inspection: AdventureInspection
var player: Player
var _impact_offset := Vector2.ZERO
var _impact_fresh := false
var _impact_impulse := Vector2.ZERO
var _impact_age := 1.0
const IMPACT_LIMIT := 2.0
var contact_rhythm := ContactRhythm.new()
var forest_trees: ForestTreeRuntime
var camera: Camera2D
var hud: Hud
var encounters: EncounterRuntime
var music: MusicDirector
var village: Village
var town_gates: TownGateRuntime
var expedition: ExpeditionRun
var quest_runtime: QuestRuntime
var exploration: Exploration
var dungeon: DungeonRuntime
var field_root: Node2D
var map_shapes: Array[Dictionary] = []
var map_state: MapWorldState
var enemies: Array[Enemy] = []
var chests: Array[Chest] = []
var cosmetic_effects: Array[Effect] = []
var corpses: Array = []  # Transient image + skill eligibility; shared lifetime keeps visuals and targeting in sync.
var _spawn_timer := 0.0
var _save_timer := 0.0
var _menu_exit_committed := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	Gamepad.set_combat_enabled(false)
	Gamepad.action_pressed.connect(_gamepad_action)
	_rng.seed = 7
	scene_root = self
	scene_view = get_viewport()
	field_root = Node2D.new()
	# This project's canvas is a rules/art adapter only. Hide before its first
	# draw so Compatibility never uploads cached Polygon2D buffers on rotation.
	field_root.visible = false
	field_root.add_to_group("forest_daylight")
	scene_root.add_child(field_root)
	dungeon = DungeonRuntime.new().setup(self)
	add_child(dungeon)
	# Ground plane: everything under this node is authored in ground units and
	# projected into the 120° quarter view by its transform.
	var ground_layer := Node2D.new()
	ground_layer.transform = Iso.ground_transform()
	ground_layer.z_index = -10
	field_root.add_child(ground_layer)
	# Continue the textured backdrop beyond collision bounds so edge cameras never reveal a void.
	var backdrop := FIELD.grow(3500.0)
	var meadow := Sprite2D.new()
	meadow.texture = ForestArt.texture("grass")
	meadow.centered = false
	meadow.region_enabled = true
	var units_per_tex := 260.0
	var texture_side := meadow.texture.get_width()
	meadow.region_rect = Rect2(Vector2.ZERO, backdrop.size / units_per_tex * texture_side)
	meadow.scale = Vector2.ONE * units_per_tex / texture_side
	meadow.position = backdrop.position
	meadow.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	meadow.modulate = Color.WHITE
	ground_layer.add_child(meadow)

	world = Node2D.new()
	world.y_sort_enabled = true
	field_root.add_child(world)
	village = Village.new()
	village.build(ground_layer, world)
	village.build_field(world, FIELD.grow(-150), _rng)
	forest_trees = ForestTreeRuntime.new().setup(self)
	forest_lighting = ForestLighting.new()
	field_root.add_child(forest_lighting)
	forest_lighting.setup(ground_layer, village)
	WorldLighting.configure(forest_lighting.openings, field_root, forest_lighting.materials)
	forest_atmosphere = ForestAtmosphere.new().setup(forest_lighting.openings)
	field_root.add_child(forest_atmosphere)
	map_shapes = MapGeometry.build(village)
	map_state = MapWorldState.new().setup(self)
	var chest_def: Dictionary = village.data["sprites"]["chest"]
	var broken_def: Dictionary = village.data["sprites"]["chest-broken"]
	for i in village.chest_points.size():
		village.chest_points[i] = ChestPlacement.find(village,village.chest_points[i])
		var chest := Chest.new().setup(self, i, village.chest_points[i], chest_def, broken_def)
		world.add_child(chest)
		if i == 8:
			chest.z_index = 1
		chests.append(chest)
		village.circles.append([chest.position, Chest.COLLISION_RADIUS])

	# 확대된 상자의 최종 기준점·반경을 정한 뒤 식생을 배치해야 재생성도 같다.
	forest_details = ForestArt.decorate(village, world)

	quest_runtime = QuestRuntime.new().setup(self)
	add_child(quest_runtime)
	quest_runtime.defender = village.npc_nodes["조사관 로웬"]

	exploration = Exploration.new().setup(self)
	add_child(exploration)
	player = Player.new()
	player.setup(self)
	player.died.connect(_on_player_died)
	player.open_skills_requested.connect(func(): hud.open_skill_tree())
	player.position = dungeon.entry_point() if GameState.return_to_cave_entrance else exploration.respawn_point()
	GameState.return_to_cave_entrance = false
	world.add_child(player)
	town_gates = TownGateRuntime.new().setup(self)
	field_root.add_child(town_gates)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	scene_root.add_child(camera)
	camera.make_current()
	camera.position = player.position
	Prefs.graphics_changed.connect(_update_render_quality)

	hud = Hud.new()
	hud.game = self
	add_child(hud)
	# Keep the adapter available to scenery without processing it before setup.
	encounters = EncounterRuntime.new()
	add_child(encounters)
	music = MusicDirector.new()
	music.game = self
	add_child(music)
	encounters.set_process(false)
	_update_zoom()
	get_viewport().size_changed.connect(_update_zoom)
	_create_world_renderer()
	# Actual3D shapes enter the physics broad phase before validating restored
	# encounter positions or creating the first ambient packs.
	await get_tree().physics_frame
	await get_tree().process_frame
	if is_queued_for_deletion():
		return
	encounters.setup(self)
	encounters.set_process(true)
	spatial_world.sync_scope(true)
	await get_tree().physics_frame
	await get_tree().process_frame
	if is_queued_for_deletion():
		return
	inspection = AdventureInspection.create_for_web(self)
	if inspection != null:
		inspection.apply()
	for i in 12:
		_spawn_enemy(true)
	await world_renderer._occlusion.warm_up()
	if is_queued_for_deletion():
		return
	await world_renderer._warp_fx.warm_up()
	if is_queued_for_deletion():
		return
	expedition = ExpeditionRun.new().setup(self)
	add_child(expedition)
	native_ready = true
	# 첫 의뢰는 상태창의 목표와 미라의 표식으로 안내한다. 중복 배너로 장면을 가리지 않는다.
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sjrpgAdventureReady = true")


func _update_zoom() -> void:
	var size := get_viewport_rect().size
	# Keep characters similarly sized in portrait and landscape.
	var short_side := minf(size.x, size.y)
	var z := clampf(short_side / 720.0, 0.5, 1.6)
	_base_zoom = Vector2(z, z) * CAMERA_WORLD_SCALE * Prefs.actual_world_zoom() * (inspection.zoom_multiplier if is_instance_valid(inspection) else 1.0)
	camera.zoom = _base_zoom * (1.0 + _zoom_punch)


## JUICE #14: a brief zoom-in on heavy contact. It multiplies the selected zoom (never replaces it), is
## capped, decays in ~0.1s and is off for reduced motion. The native 3D camera reads camera.zoom each sync.
const ZOOM_PUNCH_LIMIT := 0.002
var _base_zoom := Vector2.ONE
var _zoom_punch := 0.0
var _zoom_punch_fresh := false


func zoom_punch(amount: float, at := Vector2.INF) -> void:
	if Prefs.reduce_motion or (at.is_finite() and player.position.distance_to(at) > 650.0):
		return
	_zoom_punch = minf(ZOOM_PUNCH_LIMIT, _zoom_punch + amount)
	_zoom_punch_fresh = true
	camera.zoom = _base_zoom * (1.0 + _zoom_punch)


func _update_zoom_punch(delta: float) -> void:
	if Prefs.reduce_motion:
		_zoom_punch = 0.0
	elif _zoom_punch > 0.0:
		_zoom_punch *= exp(-18.0 * (minf(delta, 0.012) if _zoom_punch_fresh else delta))
		if _zoom_punch < 0.0005:
			_zoom_punch = 0.0
	_zoom_punch_fresh = false
	camera.zoom = _base_zoom * (1.0 + _zoom_punch)


## Keep the hero near 60% height in either orientation while revealing the scene ahead.
func _camera_focus() -> Vector2:
	if is_instance_valid(inspection) and inspection.focus_point != Vector2.ZERO:
		return inspection.focus_point
	var view_height := scene_view.get_visible_rect().size.y
	var lead := minf(110.0, view_height * 0.10 / maxf(0.01, camera.zoom.y))
	return player.position + Vector2(0, -lead)


func _update_render_quality() -> void:
	# 숨겨진 Canvas는 규칙 어댑터다. 부모를 바꾸면
	# 캐시된 Polygon2D 표면에서 4.7.2 WebGL 인덱스 버퍼 갱신 오류가 발생한다.
	# 실제 월드 해상도는 WorldRenderer3D._resize가 관리한다.
	_update_zoom()
	camera.make_current()


## 표시기와 같은 World3D에 실제 이동·충돌 공간을 만든다.
func _create_world_renderer() -> void:
	if is_instance_valid(world_renderer):
		world_renderer.refresh()
		return
	world_renderer = WorldRenderer3D.new().setup(self)
	add_child(world_renderer)
	spatial_world = SpatialWorld3D.new().setup(self, world_renderer.stage)
	spatial_world.register_actor(player, Player.RADIUS, false)
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			spatial_world.register_actor(enemy, enemy.radius, true)


## 숨겨진 Canvas는 표시 소스와 진행 소유권을 유지하며 동굴 귀환 때도 직접 그리지 않는다.
func set_forest_rendered(_value: bool) -> void:
	field_root.hide()
	field_root.visibility_layer = 0
	_sync_forest_daylight()


func _sync_forest_daylight() -> void:
	WorldLighting.set_enabled(forest_lighting.enabled and not dungeon.active and field_root.visibility_layer != 0)


## 상인 곁에서는 가방에서 상점으로 전환할 수 있습니다 (원본의 근처 행동 버튼).
func near_merchant() -> bool:
	if dungeon.active:
		return false
	return player.position.distance_to(village.merchant_point) < 210.0


## Name of the town NPC within talking range, or "".
func near_npc() -> String:
	if dungeon.active:
		return "동굴 출구" if dungeon.at_exit() or player.position.length() < 150.0 else ""
	if exploration.gate_nearby():
		return "워프게이트"
	if quest_runtime.boss_ready() and player.position.distance_to(village.boss_point) < 240.0:
		return "숲의 파수꾼"
	var best := ""
	var best_d := 210.0
	for name in village.npc_points:
		var d := player.position.distance_to(village.npc_points[name])
		if d < best_d:
			best_d = d
			best = name
	var cave_distance := player.position.distance_to(dungeon.entry_point())
	if cave_distance < best_d:
		best = "바람 동굴"
		best_d = cave_distance
	var sanctuary := exploration.nearby()
	if sanctuary != "":
		var distance := player.position.distance_to(village.sanctuary_points[sanctuary])
		if distance < best_d:
			best = "안식처"
	return best


func in_town(p: Vector2) -> bool:
	return not dungeon.active and Geometry2D.is_point_in_polygon(p, village.safe_zone)


## Only confirmed nearby hits nudge the camera; gameplay clocks and hitboxes stay unchanged.
func combat_feedback(at: Vector2, strength: float, hurt := false) -> void:
	if Prefs.reduce_motion or player.position.distance_to(at) > 650.0:
		return
	var direction := (player.position - at).normalized()
	if direction.length_squared() < 0.1:
		direction = Vector2(0.6, -0.8)
	var impulse := direction * clampf(strength, 0.0, 1.0) * (IMPACT_LIMIT if hurt else 1.5)
	# 같은 프레임의 약한 타격이 강한 피격을 덮거나 변위를 누적하지 않는다.
	if _impact_fresh and impulse.length_squared() <= _impact_impulse.length_squared():
		return
	_impact_impulse = impulse
	_impact_age = 0.0
	_impact_offset = impulse
	_impact_fresh = true
	camera.offset = _impact_offset


## Present a confirmed contact before a slow next frame can decay its whole pulse away.
func _update_impact_camera(delta: float) -> void:
	if Prefs.reduce_motion:
		_impact_impulse = Vector2.ZERO
		_impact_age = 1.0
		_impact_offset = Vector2.ZERO
	else:
		_impact_age += minf(delta, 0.006) if _impact_fresh else delta
		_impact_offset = _impact_impulse * exp(-24.0 * _impact_age) * cos(34.0 * _impact_age) if _impact_age < 0.18 else Vector2.ZERO
	_impact_fresh = false
	camera.offset = _impact_offset


func refresh_map(force_check := false) -> void:
	if map_state != null:
		map_state.refresh(force_check)


func _process(delta: float) -> void:
	Gamepad.set_combat_enabled(_gamepad_playable())
	if not native_ready:
		return
	refresh_map()
	# Forest-root visibility disables/restores lighting in the same cave-transition frame.
	_sync_forest_daylight()
	WorldLighting.advance(delta)
	_update_impact_camera(delta)
	contact_rhythm.tick(self, delta)
	forest_trees.tick(delta)
	_update_zoom_punch(delta)
	camera.position = _camera_focus()
	if dungeon.active:
		WorldOcclusion.update(player.global_position, false, field_root.is_visible_in_tree())
		dungeon.tick(delta)
		_save_timer += delta
		if _save_timer >= AUTOSAVE_SECONDS:
			_save_timer = 0.0
			GameState.save_game()
		return
	# Raised terraces (landmarks, chapel yard): actors on top draw over the terrace art.
	var elevated := Geometry2D.is_point_in_polygon(player.position, village.terrace)
	for lm in village.landmarks:
		if lm.contains_top(player.position):
			elevated = true
			break
	# Passing beneath an arch stays on the ground; local occlusion keeps the body readable.
	player.z_index = 1 if elevated else 0
	WorldOcclusion.update(player.global_position if not player.dead else Vector2(1000000, 1000000), elevated, field_root.is_visible_in_tree())
	_tick_corpses(delta)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = ForestBalance.SPAWN_SECONDS
		# Distant ambient enemies must not consume the local encounter budget.
		for enemy in enemies.duplicate():
			if not enemy.is_boss and not enemy.is_threat and enemy.encounter_id.is_empty() and enemy.position.distance_to(player.position) > 1900.0:
				enemies.erase(enemy)
				enemy.queue_free()
		var near_home := Iso.unproject(player.position).length() < ForestBalance.NEAR_TOWN_RADIUS
		var ambient := enemies.filter(func(enemy: Enemy): return not enemy.dead and enemy.encounter_id.is_empty() and not enemy.is_threat and not enemy.is_boss).size()
		if ambient < ForestBalance.field_limit(near_home) and enemies.size() < EncounterRuntime.MAX_ENEMIES:
			_spawn_enemy()
	_save_timer += delta
	if _save_timer >= AUTOSAVE_SECONDS:
		_save_timer = 0.0
		GameState.save_game()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		if is_node_ready() and process_mode != Node.PROCESS_MODE_DISABLED:
			set_meta("last_background_notification", what)
			_pause_in_background()


func _pause_in_background() -> void:
	Gamepad.require_neutral()
	# Releasing both sources prevents a lost touch/key-up from moving the hero on return.
	hud.controls.release_all()
	player.move_input = Vector2.ZERO
	player.held_slots.clear()
	for action in ["move_left", "move_right", "move_up", "move_down", "attack", "skill", "potion"]:
		Input.action_release(action)
	GameState.save_game()
	hud.pause_for_background()


## Screen positions first enter the render viewport, then undo its actual camera transform.
## Economy quality renders the world at half resolution while the HUD stays full size.
func screen_to_world(screen: Vector2) -> Vector2:
	if is_instance_valid(spatial_world) and is_instance_valid(world_renderer):
		var logical := get_viewport_rect().size
		var native := screen * Vector2(world_renderer.viewport.size) / logical
		var origin := world_renderer.camera.project_ray_origin(native)
		var direction := world_renderer.camera.project_ray_normal(native)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 180.0, SpatialWorld3D.FLOOR)
		query.hit_back_faces = true
		var hit := spatial_world.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			return WorldSpace3D.world_to_projected(hit["position"])
	var render_position := screen * scene_view.get_visible_rect().size / get_viewport_rect().size
	return scene_view.canvas_transform.affine_inverse() * render_position


## Pad actions are device-owned; they never synthesize keyboard or touch holds.
func _gamepad_playable() -> bool:
	return native_ready and is_instance_valid(player) and not player.dead and not player.warp_locked and not get_tree().paused and is_instance_valid(hud) and not hud.panel_open() and not Gamepad.loading_blocked() and not Gamepad.navigation_scope()


func _gamepad_action(action: String) -> void:
	if not _gamepad_playable() or not Gamepad.combat_enabled():
		return
	match action:
		"primary":
			player.cast_slot(0)
		"aux1", "aux2", "aux3", "aux4":
			player.cast_slot(int(action.trim_prefix("aux")))
		"roll":
			player.try_roll()
		"health":
			player.use_potion()
		"mana":
			player.use_mana_potion()
		"interact":
			var nearby: String = near_npc()
			if not nearby.is_empty():
				hud.interact(nearby)


func _exit_tree() -> void:
	Gamepad.set_combat_enabled(false)


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or hud.panel_open():
		return
	if (
		event is InputEventMouseButton
		and event.device != InputEvent.DEVICE_ID_EMULATION
		and event.pressed
	):
		if player.dead:
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			player.set_pointer_aim(screen_to_world(event.position))
			hud.controls.hold_mouse_primary()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Drawn HUD buttons are not Control nodes; reserve their right-click area too.
			if (
				hud.controls._hit_button(event.position) == ""
				and not hud.minimap.get_global_rect().has_point(event.position)
			):
				player.set_move_target(screen_to_world(event.position))
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("attack") and not event.is_echo():
		player.cast_slot(0)
	elif event.is_action_pressed("skill") and not event.is_echo():
		player.cast_slot(1)
	elif event.is_action_pressed("potion"):
		player.use_potion()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		player.use_mana_potion()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				hud.toggle_menu()
			KEY_B:
				hud.open_bag(near_merchant())
			KEY_1, KEY_2, KEY_3, KEY_4:
				player.cast_slot(event.keycode - KEY_0)
			KEY_L, KEY_SHIFT:
				player.try_roll()
			KEY_M:
				hud.open_map()
			KEY_F:
				var nearby := near_npc()
				if nearby != "":
					hud.interact(nearby)
			KEY_T:
				hud.open_skill_tree()


func _spawn_enemy(anywhere := false) -> void:
	if enemies.size() >= EncounterRuntime.MAX_ENEMIES:
		return
	for attempt in 30:
		var p: Vector2
		if anywhere:
			p = Iso.project(Vector2(_rng.randf_range(FIELD.position.x, FIELD.end.x), _rng.randf_range(FIELD.position.y, FIELD.end.y)) * 0.8)
		else:
			p = player.position + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(440, 720)
		if not _inside_field(p, 200.0) or in_town(p) or p.distance_to(player.position) < 400.0:
			continue
		if Geometry2D.is_point_in_polygon(p, _town_buffer()):
			continue
		var zone := ForestBalance.zone_at(p)
		var pool := ["goblin", "goblin", "wolf"]
		if zone >= 1:
			pool.append_array(["wolf", "boar"])
		if zone >= 2:
			pool.append_array(["boar", "skeleton"])
		if zone >= 3:
			pool.append_array(["skeleton", "skeleton"])
		var kind: String = pool[_rng.randi_range(0, pool.size() - 1)]
		if spatial_world.blocked(p, Enemy.radius_for(kind) + 10.0, true):
			continue
		var enemy := Enemy.new()
		enemy.setup(self, kind, ForestBalance.area_level(zone))
		if Iso.unproject(p).length() < ForestBalance.NEAR_TOWN_RADIUS:
			enemy.max_hp *= ForestBalance.NEAR_TOWN_HP
			enemy.hp = enemy.max_hp
			enemy.damage *= ForestBalance.NEAR_TOWN_DAMAGE
		enemy.position = p
		world.add_child(enemy)
		enemies.append(enemy)
		return


var _buffer_cache: PackedVector2Array


func _town_buffer() -> PackedVector2Array:
	if _buffer_cache.is_empty():
		var out := PackedVector2Array()
		for c in [Vector2(-0.08, -0.02), Vector2(1.06, -0.02), Vector2(1.06, 1.02), Vector2(-0.08, 1.02)]:
			out.append(village.point(c))
		_buffer_cache = out
	return _buffer_cache


func _inside_field(p: Vector2, margin: float) -> bool:
	return spatial_world.contains(p, margin) if is_instance_valid(spatial_world) else false


func _blocked(p: Vector2, r: float) -> bool:
	return spatial_world.blocked(p, r) if is_instance_valid(spatial_world) else true


## Source coordinates adapt native physics; gameplay actors use their persistent
## CharacterBody3D through SpatialWorld3D.move_source_actor directly.
func move_actor(from: Vector2, to: Vector2, r: float, keep_out_town := false) -> Vector2:
	return spatial_world.move_actor(from, to, r, keep_out_town) if is_instance_valid(spatial_world) else from


## Before native world setup only initial/debug placement is recorded. Once
## attached, both placement and movement are validated in the real World3D.
func resolve_movement(from: Vector2, to: Vector2, r: float, keep_out_town := false) -> Vector2:
	return spatial_world.resolve_movement(from, to, r, keep_out_town) if is_instance_valid(spatial_world) else to


func separation(enemy: Enemy) -> Vector2:
	var push := Vector2.ZERO
	for other in enemies:
		if other == enemy or other.dead:
			continue
		var d := enemy.position - other.position
		var spacing: float = enemy.radius + other.radius + 4.0
		# Most pairs are far apart: reject them before taking a square root.
		var squared := d.length_squared()
		if squared >= spacing * spacing or squared <= 0.0001:
			continue
		var l := sqrt(squared)
		push += d / l * (1.0 - l / spacing)
	return push


func nearest_enemy(from: Vector2, max_range: float) -> Enemy:
	var best: Enemy = null
	var best_d := max_range
	for e in enemies:
		if not is_instance_valid(e) or e.dead or e.is_queued_for_deletion():
			continue
		var d := from.distance_to(e.position)
		if d < best_d:
			best_d = d
			best = e
	return best


func nearest_ready_stone(from: Vector2, max_range: float) -> EncounterStone:
	var best: EncounterStone
	if encounters == null or dungeon.active:
		return null
	for stone in encounters.stones.values():
		var distance: float = from.distance_to(stone.position)
		if encounters.can_summon(stone.id) and distance < max_range and encounters.clear_line(from, stone.position):
			max_range = distance
			best = stone
	return best


func nearest_attackable_prop(from: Vector2, max_range: float) -> Node2D:
	var best: Node2D = nearest_ready_stone(from, max_range)
	if best != null:
		max_range = from.distance_to(best.position)
	for chest in chests:
		var distance: float = from.distance_to(chest.position)
		if not chest.dead and distance < max_range:
			max_range = distance
			best = chest
	return best


## Melee uses measured walkable surfaces; ranged/AOE queries deliberately keep their rules.
func can_melee_reach(from: Vector2, to: Vector2) -> bool:
	return spatial_world.can_melee(from, to) if is_instance_valid(spatial_world) else false


func enemies_in_radius(center: Vector2, radius: float, melee := false) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in enemies:
		if not is_instance_valid(e) or e.dead or center.distance_to(e.position) > radius + e.radius:
			continue
		var reachable := can_melee_reach(center, e.position) if melee else SpatialCombat3D.area_reaches(self, center, e.position, radius + e.radius)
		if reachable:
			out.append(e)
	return out


func enemies_in_arc(
	center: Vector2, angle: float, radius: float, half_angle: float, melee := false
) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in enemies_in_radius(center, radius, melee):
		var d := e.position - center
		if DirectionalAim.contains(d, Vector2.from_angle(angle), half_angle):
			out.append(e)
	return out


## Physical swings share actor elevation/wall reach; ranged spells retain their area rules.
func break_chests_in_radius(center: Vector2, radius: float, source: Node2D = null, melee := false) -> void:
	if encounters != null:
		encounters.in_radius(center, radius, source, INF, PI, melee)
	for c in chests:
		if not c.dead and center.distance_to(c.position) <= radius + Chest.COLLISION_RADIUS and (can_melee_reach(center, c.position) if melee else SpatialCombat3D.area_reaches(self, center, c.position, radius + Chest.COLLISION_RADIUS)):
			c.take_damage(1.0, source)


func break_chests_in_arc(
	center: Vector2,
	angle: float,
	radius: float,
	half_angle: float,
	source: Node2D = null,
	melee := false
) -> void:
	if encounters != null:
		encounters.in_radius(center, radius, source, angle, half_angle, melee)
	for c in chests:
		if c.dead:
			continue
		var d := c.position - center
		if (
			d.length() <= radius + Chest.COLLISION_RADIUS
			and DirectionalAim.contains(d, Vector2.from_angle(angle), half_angle)
			and (
				can_melee_reach(center, c.position)
				if melee
				else SpatialCombat3D.area_reaches(
					self, center, c.position, radius + Chest.COLLISION_RADIUS
				)
			)
		):
			c.take_damage(1.0, source)


func break_chests_at(p: Vector2, r: float, source: Node2D = null, include_stones := true) -> void:
	if encounters != null and include_stones:
		encounters.in_radius(p, r, source)
	for c in chests:
		if not c.dead and p.distance_to(c.position) <= r + Chest.COLLISION_RADIUS and SpatialCombat3D.area_reaches(self, p, c.position, r + Chest.COLLISION_RADIUS):
			c.take_damage(1.0, source)


func on_chest_broken(chest: Chest) -> void:
	spawn_nova(chest.position, 70.0, Color(0.95, 0.8, 0.45), true)
	SoundFx.play("loot")
	Prefs.pulse("loot")
	var content := "gear" if chest.variant == "gold" else (("supplies" if _rng.randf() < 0.55 else "coins") if chest.variant == "iron" else GameState.chest_content(chest.index))
	var gold: int = {"gear": 18, "supplies": 8, "coins": 10, "ambush": 0}[content]
	if content == "ambush":
		gold = 6
		toast("매복이다!")
		for i in 2:
			_spawn_enemy_near(chest.position)
	if chest.variant == "iron":
		gold += 20 + GameState.level * 5
	GameState.gold += gold
	if gold > 0:
		hud.reward_trail.offer("gold", chest.position)
		RewardFx.spawn(self, chest.position + Vector2(0, -35), 0)
	float_text(chest.position + Vector2(0, -70), "+%d G" % gold, Color(1, 0.88, 0.45)).anchor_text_ground(chest.position)
	# 원본: 보급 상자와 숲의 첫 상자는 치유·자원 물약을 하나씩 줌.
	if content == "supplies" or chest.index == 0:
		GameState.potions += 1
		GameState.mana_potions += 1
		toast("보급품: 치유 물약 +1 · %s 물약 +1" % GameState.class_info()["resource"])
	if chest.index == 8:
		content = "gear"
	if content == "gear":
		var g := Gear.roll_loot(GameState.hero_class, GameState.level, GameState.next_serial, _rng, true)
		if chest.variant == "gold":
			g = Gear.make(g.serial, str(g.base["id"]), 3 if _rng.randf() < 0.10 else 2, maxi(g.power,4),maxi(g.vitality,8),maxi(g.focus,4),GameState.level+1)
		if chest.index == 8:
			g = GameState.new_gear("shortsword" if GameState.hero_class == "warrior" else "wand", 2, 4, 8)
		if GameState.add_gear(g):
			hud.reward_trail.offer("gear", chest.position)
			if g.rarity >= 2:
				RewardFx.spawn(self, chest.position + Vector2(0, -42), 2)
			toast("획득: %s" % g.display_name())
			player.refresh_stats()
		else:
			GameState.gold += g.sale_value()
			hud.reward_trail.offer("gold", chest.position)
			toast("보관함이 가득 차 %s을(를) %d G에 팔았습니다" % [g.display_name(), g.sale_value()])
	if GameState.collect_memory_reward():
		toast("세 기억을 모았습니다 · 스킬 포인트 +1")
	GameState.save_game()
	var mem := chest.index - MemoryPanel.FIRST_CHEST
	if mem >= 0 and mem < MemoryPanel.MEMORIES.size():
		get_tree().create_timer(0.6, false).timeout.connect(func():
			if is_instance_valid(hud):
				hud.open_memory(mem))


func _spawn_enemy_near(at: Vector2) -> void:
	var enemy := Enemy.new()
	enemy.setup(self, "goblin", maxi(1, GameState.level))
	enemy.position = spatial_world.resolve_movement(at, at + Vector2.from_angle(_rng.randf() * TAU) * 70.0, enemy.radius, true)
	if spatial_world.blocked(enemy.position, enemy.radius, true):
		enemy.free()
		return
	world.add_child(enemy)
	enemies.append(enemy)


func rng_int(a: int, b: int) -> int:
	return _rng.randi_range(a, b)


func rng_float() -> float:
	return _rng.randf()


func rng_range(a: float, b: float) -> float:
	return _rng.randf_range(a, b)


## JUICE #6: the 1.2s before the victory panel carries the moment: a short world pause, a large burst, a light
## pulse, a deep cry, a restrained zoom and a second subpixel camera pulse. Presentation only; reduced motion drops
## the pause, zoom and shake (the burst, light and sound remain).
const BOSS_DEFEAT_PAUSE := 0.12
const BOSS_DEFEAT_PAUSE_LIMIT := 0.15


func _boss_defeat_presentation(boss: Enemy) -> void:
	player._hitstop.trigger(BOSS_DEFEAT_PAUSE, BOSS_DEFEAT_PAUSE_LIMIT)
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			enemy._hitstop.trigger(BOSS_DEFEAT_PAUSE, BOSS_DEFEAT_PAUSE_LIMIT)
	spawn_nova(boss.position, 260.0, Color(1.0, 0.85, 0.5))
	WorldLighting.pulse(boss.position, Color(1.0, 0.9, 0.6), true)
	SoundFx.play("warcry")
	combat_feedback(boss.position, 1.0)
	zoom_punch(ZOOM_PUNCH_LIMIT, boss.position)
	get_tree().create_timer(0.25, false).timeout.connect(func() -> void:
		if is_instance_valid(self) and is_instance_valid(boss):
			combat_feedback(boss.position, 0.8))


func on_boss_defeated(boss: Enemy) -> void:
	if GameState.boss_defeated:
		return
	GameState.boss_defeated = true
	GameState.boss_summoned = true
	if ExpeditionState.active():
		expedition.boss_defeated()
		_boss_defeat_presentation(boss)
		return
	GameState.boss_heart_pending = true
	if GameState.claim_boss_heart():
		toast("파수꾼의 심장을 얻었습니다!")
	else:
		toast("가방을 비우면 파수꾼의 심장을 받을 수 있습니다")
	GameState.save_game()
	_boss_defeat_presentation(boss)
	await get_tree().create_timer(1.2, false).timeout
	hud.open_victory()


func on_enemy_killed(enemy: Enemy) -> void:
	enemies.erase(enemy)
	if encounters != null:
		encounters.on_killed(enemy)
	if expedition != null:
		expedition.enemy_killed(enemy)
	Prefs.pulse("kill")
	GameState.kills += 1
	if dungeon.active:
		dungeon.on_enemy_killed(enemy)
	else:
		quest_runtime.on_enemy_killed(enemy)
	if GameState.has_gift("renewal") and not player.dead:
		player.hp = minf(player.max_hp, player.hp + 4.0)
		float_text(player.position + Vector2(0, -80), "+%s" % HudArt.stat(4.0), Color(0.6, 1, 0.7)).anchor_text_ground(player.position)
	if enemy.is_boss:
		on_boss_defeated(enemy)
	float_text(enemy.position + Vector2(0, -enemy.sprite.body_height - 40), "+%d XP" % enemy.xp_reward, Color(0.7, 0.85, 1)).anchor_text_ground(enemy.position)
	if enemy.xp_reward > 0:
		RewardFx.spawn(self, enemy.position + Vector2(0, -28), 1)
	# 원본: 몬스터 처치로는 물약이 나오지 않음 (상자·구매·물약 발견만).
	# Every death has a body; the original 30% skill-search eligibility remains independent.
	add_corpse(enemy, _rng.randf() < 0.3)
	grant_xp(enemy.xp_reward, enemy.position)


func grant_xp(amount: int, source_point := Vector2.INF, save_progress := true) -> void:
	var gained := GameState.add_xp(amount)
	if amount > 0:
		hud.reward_trail.offer("xp", source_point if source_point.is_finite() else player.position)
	if gained > 0:
		player.refresh_stats(true)
		RewardFx.spawn(self, player.position + Vector2(0, -32), 1, true)
		SoundFx.play("levelup")
		SoundFx.play("loot")
		hud.show_level_up(GameState.level)
		if save_progress:
			GameState.save_game()


## One bounded record owns the picture and any corpse-skill target. No actor/collision survives death.
func add_corpse(enemy: Enemy, searchable: bool) -> Dictionary:
	var corpse := {
		"pos": enemy.position, "time": CORPSE_LIFETIME, "lifetime": CORPSE_LIFETIME, "used": false,
		"kind": enemy.kind, "facing": enemy.facing, "height": enemy.sprite.body_height,
		"visual_variant": str(enemy.get_meta("visual_variant", "")),
		"searchable": searchable,
	}
	var visual := CorpseArt.new()
	visual.corpse = corpse
	visual.position = enemy.position
	# Above bridge floors, beneath normal actors; raised yards share the actors' elevation.
	visual.z_index = -1
	if not dungeon.active:
		var elevated := Geometry2D.is_point_in_polygon(enemy.position, village.terrace)
		for landmark in village.landmarks:
			if landmark.contains_top(enemy.position):
				elevated = true
				break
		if elevated:
			visual.z_index = 1
	corpse["visual"] = visual
	world.add_child(visual)
	corpses.append(corpse)
	while corpses.size() > CORPSE_LIMIT:
		remove_corpse(corpses[0])
	return corpse


func _tick_corpses(delta: float) -> void:
	_tick_corpse_list(corpses, delta)
	if dungeon.active:
		_tick_corpse_list(dungeon._forest_corpses, delta)


func _tick_corpse_list(records: Array, delta: float) -> void:
	for corpse in records.duplicate():
		corpse["time"] = maxf(0.0, float(corpse["time"]) - delta)
		if corpse["time"] <= 0.0:
			remove_corpse(corpse)
			# 활성 목록 외에 보관 중인 필드 목록에서도 만료 기록을 지운다.
			records.erase(corpse)
		else:
			var visual: Node2D = corpse.get("visual")
			if is_instance_valid(visual) and visual.is_visible_in_tree():
				visual.queue_redraw()


## Validate again when a delayed skill lands: selection may have expired, been consumed or changed maps.
func corpse_available(corpse: Dictionary) -> bool:
	return corpses.has(corpse) and not corpse.get("used", false) and float(corpse.get("time", 0.0)) > 0.0 and corpse.get("searchable", true)


## 가까운 사용 가능 시체 Dictionary, 없으면 null을 돌려준다.
func nearest_corpse(from: Vector2, max_range: float) -> Variant:
	var best: Variant = null
	var best_d := max_range
	for corpse in corpses:
		var distance := from.distance_to(corpse["pos"])
		if corpse_available(corpse) and distance < best_d:
			best_d = distance
			best = corpse
	return best


func remove_corpse(corpse: Dictionary) -> void:
	# Invalidate captured dictionaries before removal, including pool eviction and cave exit.
	corpse["used"] = true
	corpse["time"] = 0.0
	var visual: Node2D = corpse.get("visual")
	if is_instance_valid(visual):
		visual.hide()
		visual.queue_free()
	corpse.erase("visual")
	corpses.erase(corpse)


## Walks from `from` along `dir` up to `distance`, stopping before trees and the world edge.
func find_open_point(from: Vector2, dir: Vector2, distance: float, r: float) -> Vector2:
	var p := from
	var steps := int(ceil(distance / 12.0))
	for i in steps:
		var next := from + dir * minf(distance, (i + 1) * 12.0)
		if not _inside_field(next, r):
			break
		if _blocked(next, r * 0.6):
			continue  # leap/blink may cross ledges, but never land inside solids
		p = next
	return p


func _on_player_died() -> void:
	Gamepad.set_combat_enabled(false)
	Gamepad.require_neutral()
	hud.controls.release_all()
	# Releasing pointers can leave false slot entries; death discards every prior hold.
	player.held_slots.clear()
	hud.show_death()
	await get_tree().create_timer(2.5, false).timeout
	if not player.dead:
		hud.hide_death()
		return
	if ExpeditionState.active():
		if not expedition.settle(false):
			hud.hide_death()
			player.revive(player.position)
			toast(expedition.error)
		return
	if dungeon.active:
		dungeon.leave("쓰러져 동굴 입구로 돌아왔습니다")
		return
	quest_runtime.reset_boss()
	player.revive(exploration.respawn_point())
	hud.hide_death()
	GameState.save_game()


func _add_effect(e: Effect) -> void:
	if e.owner_node is Player and not e.params.has("tree_action"):
		e.params["tree_action"] = ForestTreeRuntime.action_id(e.owner_node)
	# Bound only cosmetic nodes; projectiles, damage zones and summons keep their gameplay.
	if e.kind not in ["proj", "orb", "zone", "hydra", "ward"]:
		cosmetic_effects = cosmetic_effects.filter(func(effect): return is_instance_valid(effect) and not effect.is_queued_for_deletion())
		if cosmetic_effects.size() >= Effect.COSMETIC_LIMIT:
			cosmetic_effects.pop_front().queue_free()
		cosmetic_effects.append(e)
	e.game = self
	world.add_child(e)


func spawn_slash(at: Vector2, angle: float, color: Color, reach := 80.0, arc := 1.2) -> void:
	var e := Effect.new()
	e.kind = "slash"
	e.position = at
	e.angle = angle
	e.color = color
	e.radius = reach
	e.params["arc"] = arc
	e.life = 0.22
	e.z_index = 5
	_add_effect(e)


## Authored skill shapes share the cosmetic budget and never introduce a second hitbox.
func spawn_reference_fx(key: String, at: Vector2, reach: float, owner: Node2D = null, duration := 0.42) -> Effect:
	var effect := Effect.new()
	effect.kind = "skill_fx"
	effect.position = at
	effect.radius = reach
	effect.life = duration
	effect.owner_node = owner
	effect.params["visual"] = key
	effect.z_index = owner.z_index if is_instance_valid(owner) else 0
	if key == "spin" and owner is Player:
		effect.params["action_serial"] = owner._action_serial
	_add_effect(effect)
	return effect


func spawn_nova(at: Vector2, radius: float, color: Color, small := false) -> void:
	var e := Effect.new()
	e.kind = "nova"
	e.position = at
	e.radius = radius
	e.color = color
	e.life = 0.3 if small else 0.45
	e.z_index = -5
	e.z_as_relative = false
	_add_effect(e)


func spawn_projectile(p: Dictionary, owner: Node2D) -> void:
	var e := Effect.new()
	e.kind = "proj"
	e.position = p["pos"]
	e.velocity = p["dir"] * float(p["speed"])
	e.damage = p["damage"]
	e.color = p.get("color", SkillDefs.FIRE)
	e.life = p.get("life", 0.95)
	e.owner_node = owner
	e.params = p
	e.params["seed"] = randf() * TAU
	_add_effect(e)


func spawn_orb(at: Vector2, dir: Vector2, d: Dictionary, damage: float, owner: Node2D) -> void:
	var e := Effect.new()
	e.kind = "orb"
	e.position = at
	e.velocity = dir * float(d["speed"])
	e.damage = damage
	e.color = d["color"]
	e.life = d["life"]
	e.owner_node = owner
	_add_effect(e)


func spawn_zone(z: Dictionary) -> void:
	var e := Effect.new()
	e.kind = "zone"
	e.position = z["pos"]
	e.radius = z["radius"]
	e.damage = z["damage"]
	e.color = z["color"]
	e.life = float(z["duration"]) + float(z.get("delay", 0.0))
	e.params = z
	e.owner_node = player
	e.z_index = -6
	e.z_as_relative = false
	_add_effect(e)


func spawn_beam(from: Vector2, angle: float, length: float, damage: float, color: Color, _owner: Node2D) -> void:
	var dir := Vector2.from_angle(angle)
	var native_y := SpatialCombat3D.launch_height(self, from, _owner)
	var tree_contacts := forest_trees.projectile_contacts(from, from + dir * length, native_y, 14.0)
	var full_length := length
	var trace := SpatialCombat3D.wall_trace(self, from, from + dir * length, native_y, 14.0)
	length *= float(trace["fraction"])
	if _owner is Player:
		for contact in tree_contacts:
			if trace["trees"].has(contact["tree"]) or float(contact["fraction"]) * full_length <= length:
				forest_trees.hit(contact["tree"], "lightning", ForestTreeRuntime.action_id(_owner))
	for en: Enemy in enemies.duplicate():
		if en.dead:
			continue
		var d := en.position - from
		var along := d.dot(dir)
		var native_hit := spatial_world == null or SpatialCombat3D.target_fraction(self, from, from + dir * length, native_y, en, 14.0) <= 1.0
		if along > 0.0 and along < length and absf(d.dot(dir.orthogonal())) < 34.0 and native_hit:
			en.take_damage(damage, player)
	if encounters != null:
		for contact in encounters.projectile_contacts(from, from + dir * length, native_y):
			contact["enemy"].take_damage(damage, _owner)
	var pts := PackedVector2Array()
	var steps := 10
	for i in steps + 1:
		var p := dir * length * i / steps + Vector2(0, -32)
		if i > 0 and i < steps:
			p += dir.orthogonal() * randf_range(-14, 14)
		pts.append(p)
	_line_effect("beam", from, pts, color, 0.25)


func chain_lightning(from: Vector2, first: Enemy, jumps: int, radius: float, damage: float, _owner: Node2D) -> void:
	if not is_instance_valid(first) or first.dead or not SpatialCombat3D.line_clear(self, from, first.position):
		return
	var pts := PackedVector2Array([Vector2(0, -32)])
	var hit := []
	var current := first
	for i in jumps + 1:
		if not is_instance_valid(current) or current.dead:
			break
		var contact := current.position
		hit.append(current)
		current.take_damage(damage, player)
		pts.append(contact - from + Vector2(0, -36))
		var next: Enemy = null
		var best := radius
		for e in enemies_in_radius(contact, radius):
			if hit.has(e):
				continue
			var d := contact.distance_to(e.position)
			if d < best:
				best = d
				next = e
		current = next
	_line_effect("chain", from, pts, SkillDefs.LIGHT, 0.3)


func spawn_bolt_strike(at: Vector2) -> void:
	var pts := PackedVector2Array()
	for i in 7:
		pts.append(Vector2(randf_range(-12, 12) if i > 0 and i < 6 else 0.0, -420.0 + 70.0 * i))
	pts[6] = Vector2.ZERO
	_line_effect("strike", at, pts, SkillDefs.LIGHT, 0.3)
	spawn_nova(at, 50.0, SkillDefs.LIGHT, true)


func _line_effect(kind: String, at: Vector2, pts: PackedVector2Array, color: Color, life: float) -> void:
	var e := Effect.new()
	e.kind = kind
	e.position = at
	e.points = pts
	e.color = color
	e.life = life
	e.z_index = 6
	_add_effect(e)


func spawn_cone(at: Vector2, angle: float, length: float, color: Color) -> void:
	var e := Effect.new()
	e.kind = "cone"
	e.position = at
	e.angle = angle
	e.radius = length
	e.color = color
	e.life = 0.3
	e.z_index = 5
	_add_effect(e)


func spawn_trail(from: Vector2, to: Vector2, color: Color) -> void:
	_line_effect("trail", Vector2.ZERO, PackedVector2Array([from + Vector2(0, -30), to + Vector2(0, -30)]), color, 0.3)


func spawn_hydra(at: Vector2, duration: float, rate: float, reach: float, damage: float, owner: Node2D) -> void:
	var e := Effect.new()
	e.kind = "hydra"
	e.position = find_open_point(player.position, (at - player.position).normalized(), at.distance_to(player.position), 20.0)
	e.life = duration
	e.damage = damage
	e.owner_node = owner
	e.params = {"rate": rate, "range": reach}
	_add_effect(e)


func spawn_ward(at: Vector2, duration: float, radius: float) -> void:
	var e := Effect.new()
	e.kind = "ward"
	e.position = at
	e.life = duration
	e.radius = radius
	_add_effect(e)


func float_text(at: Vector2, text: String, color: Color, damage_target: Node2D = null, font_size := 22, pop := false) -> Effect:
	var e := Effect.new()
	e.kind = "text"
	e.font_size = font_size
	e.pop = pop
	e.position = at
	e.text = text
	e.color = color
	e.life = 0.9
	e.z_index = 20
	e.place_text(cosmetic_effects, damage_target)
	_add_effect(e)
	return e


func toast(text: String) -> void:
	if hud:
		hud.toast(text)


func quit_to_title() -> bool:
	return _leave_to_menu(false)


func return_to_selection() -> bool:
	return _leave_to_menu(true)


## Commit progress before releasing the paused settings panel or retiring the cave.
func _leave_to_menu(restart: bool) -> bool:
	if _menu_exit_committed:
		return false
	hud.apply_panel_changes()
	var previous_location := GameState.location_mode
	if dungeon.active:
		# Match the existing menu-exit checkpoint without moving the live world yet.
		GameState.location_mode = "forest"
	if not GameState.save_game():
		GameState.location_mode = previous_location
		var panel: PanelFrame = hud._panel
		if is_instance_valid(panel) and panel.has_method("show_save_error"):
			panel.call("show_save_error", GameState.save_error)
		return false
	_menu_exit_committed = true
	if dungeon.active:
		dungeon.leave("동굴 입구로 돌아왔습니다", false)
	hud.close_panel(false)
	if restart:
		restart_requested.emit()
	else:
		quit_requested.emit()
	return true

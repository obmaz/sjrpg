extends Node2D
## The adventure field (원본: lib/src/game/adventure.dart의 핵심 루프 일부).

signal quit_requested
signal restart_requested

## Field in ground units (original scale): the town perimeter is data-driven.
const FIELD := Rect2(-3600, -3600, 7200, 7200)
const CORPSE_LIFETIME := 30.0
const CORPSE_LIMIT := 32
const CAMERA_WORLD_SCALE := 1.6

var scene_view: Viewport
var scene_root: Node
var _low_view: SubViewport
var _view_container: SubViewportContainer
var world: Node2D
var forest_details: Array[IsoSprite] = []
var forest_lighting: ForestLighting
var forest_atmosphere: ForestAtmosphere
var ortho_preview: Ortho3DPreview
var spatial_world: SpatialWorld3D
var native_ready := false
var _fx_review_focus := Vector2.ZERO
var player: Player
var _impact_offset := Vector2.ZERO
var _impact_fresh := false
var _impact_age := 1.0
var _impact_cross := Vector2.ZERO
var camera: Camera2D
var hud: Hud
var encounters: EncounterRuntime
var village: Village
var town_gates: TownGateRuntime
var quest_runtime: QuestRuntime
var exploration: Exploration
var dungeon: DungeonRuntime
var field_root: Node2D
var map_shapes: Array[Dictionary] = []
var enemies: Array[Enemy] = []
var chests: Array[Chest] = []
var cosmetic_effects: Array[Effect] = []
var corpses: Array = []  # Transient image + skill eligibility; shared lifetime keeps visuals and targeting in sync.
var _spawn_timer := 0.0
var _save_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	# Allocate the optional economy render target; full quality keeps drawing directly into the main viewport.
	_view_container = SubViewportContainer.new()
	_view_container.stretch = true
	_view_container.stretch_shrink = 2
	_view_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view_container.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_view_container)
	_low_view = SubViewport.new()
	_low_view.disable_3d = true
	_low_view.handle_input_locally = false
	_view_container.add_child(_low_view)
	_view_container.visible = false
	_low_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
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
	forest_details = ForestArt.decorate(village, world)
	forest_lighting = ForestLighting.new()
	field_root.add_child(forest_lighting)
	forest_lighting.setup(ground_layer, village)
	WorldLighting.configure(forest_lighting.openings, field_root, forest_lighting.materials)
	forest_atmosphere = ForestAtmosphere.new().setup(forest_lighting.openings)
	field_root.add_child(forest_atmosphere)
	map_shapes = MapGeometry.build(village)
	var chest_def: Dictionary = village.data["sprites"]["chest"]
	var broken_def: Dictionary = village.data["sprites"]["chest-broken"]
	for i in village.chest_points.size():
		var chest := Chest.new().setup(self, i, village.chest_points[i], chest_def, broken_def)
		world.add_child(chest)
		if i == 8:
			chest.z_index = 1
		chests.append(chest)
		village.circles.append([chest.position, 24.0])

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
	encounters.set_process(false)
	_update_zoom()
	get_viewport().size_changed.connect(_update_zoom)
	_enable_ortho_preview()
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
	_read_debug_params()
	for i in 12:
		_spawn_enemy(true)
	native_ready = true
	toast("미니맵에서 의뢰 위치를 확인하세요 · 마을의 미라가 기다립니다")
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sjrpgAdventureReady = true")


func _update_zoom() -> void:
	var size := get_viewport_rect().size
	_view_container.size = size
	# Keep characters similarly sized in portrait and landscape.
	var short_side := minf(size.x, size.y)
	var z := clampf(short_side / 720.0, 0.5, 1.6)
	camera.zoom = Vector2(z, z) * CAMERA_WORLD_SCALE * Prefs.world_zoom * _debug_zoom


## Keep the hero near 60% height in either orientation while revealing the scene ahead.
func _camera_focus() -> Vector2:
	if _fx_review_focus != Vector2.ZERO:
		return _fx_review_focus
	var view_height := scene_view.get_visible_rect().size.y
	var lead := minf(110.0, view_height * 0.10 / maxf(0.01, camera.zoom.y))
	return player.position + Vector2(0, -lead)


func _update_render_quality() -> void:
	# The legacy canvas is a hidden rules adapter, never a render target. Reparenting
	# its cached Polygon2D surfaces triggers a4.7.2 WebGL index-buffer update bug.
	# Native viewport quality is owned by Ortho3DPreview._resize instead.
	_view_container.visible = false
	_low_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_update_zoom()
	camera.make_current()


## Web debug: ?zoom=0.4 widens the camera (used for layout screenshots).
var _debug_zoom := 1.0
var _encounter_audit := false


func _debug_open_panel(which: String) -> void:
	# Debug rewards may have opened a memory; always show the requested capture panel.
	if hud.panel_open():
		hud.close_panel()
	match which:
		"warp":
			hud.interact("워프게이트")
		"bag":
			hud.open_bag(false)
		"shop":
			hud.open_bag(true)
		"skills":
			hud.open_skill_tree()
		"settings":
			hud.open_settings()
		"journal":
			hud.open_journal()
		"elin":
			hud.interact("수녀 엘린")
		"mira":
			hud.interact("보급원 미라")
		"smith":
			hud.open_smith()
		"dungeon":
			player.position = dungeon.entry_point()
			dungeon.enter()
		"dungeon_map":
			player.position = dungeon.entry_point()
			dungeon.enter()
			hud._bars.queue_redraw()
			hud.minimap.queue_redraw()
			hud.controls._layout()
			hud.controls.queue_redraw()
			hud.open_map()
		"map":
			hud.open_map()
		"travel":
			hud.open_map(true)
		"boss":
			hud._open(BossPanel.new().setup(self))
		"victory":
			hud.open_victory()


func _read_debug_params() -> void:
	if not OS.has_feature("web"):
		return
	var query = JavaScriptBridge.eval("window.location.search", true)
	if typeof(query) != TYPE_STRING:
		return
	for part in String(query).trim_prefix("?").split("&"):
		var kv := part.split("=")
		if kv.size() == 2 and kv[0] == "zoom":
			_debug_zoom = clampf(float(kv[1]), 0.1, 4.0)
		elif kv.size() == 2 and kv[0] == "benchmark" and kv[1] == "1":
			add_child(RenderProbe.new().setup(self))
		elif kv.size() == 2 and kv[0] == "defender_preview" and kv[1] == "1":
			_defender_feedback_preview.call_deferred()
		elif kv.size() == 2 and kv[0] == "quality":
			Prefs.set_low_resolution(kv[1] == "low")
		elif kv.size() == 2 and kv[0] == "lighting":
			forest_lighting.set_enabled(kv[1] != "off")
			WorldLighting.set_enabled(forest_lighting.enabled)
		elif kv.size() == 2 and kv[0] == "atmosphere":
			forest_atmosphere.set_enabled(kv[1] == "trial")
		elif kv.size() == 2 and kv[0] == "panel":
			var which: String = kv[1]
			get_tree().create_timer(1.5).timeout.connect(_debug_open_panel.bind(which))
		elif kv.size() == 2 and kv[0] == "hud_preview" and kv[1] in ["full", "low", "nearfull", "large", "danger"]:
			_hud_preview.call_deferred(kv[1])
		elif kv.size() == 2 and kv[0] == "encounter_preview" and kv[1] in ["ready", "active", "empty"]:
			_encounter_preview.call_deferred(kv[1])
		elif kv.size() == 2 and kv[0] == "dungeon_preview" and kv[1] in ["entry", "room", "branch", "exit"]:
			_dungeon_preview.call_deferred(kv[1])
		elif kv.size() == 2 and kv[0] == "warp_preview" and kv[1] == "1":
			_warp_preview.call_deferred()
		elif kv.size() == 2 and kv[0] == "combat_preview":
			_combat_preview.call_deferred()
		elif kv.size() == 2 and kv[0] == "combat_text_preview" and kv[1] == "1":
			_damage_stream_preview.call_deferred()
		elif kv.size() == 2 and kv[0] == "fx_preview" and kv[1] in ["cleave", "whirlwind", "leapAttack", "iceBolt", "frostNova", "meteor"]:
			_reference_fx_preview.call_deferred(kv[1])
		elif kv.size() == 2 and kv[0] == "gate_preview" and kv[1] in ["0", "1", "2", "3"]:
			_gate_closure_preview.call_deferred(int(kv[1]))
		elif kv.size() == 2 and kv[0] == "corpse_preview" and kv[1] in ["1", "bridge", "terrace"]:
			_corpse_preview.call_deferred(kv[1])
		elif kv.size() == 2 and kv[0] == "reward_preview" and kv[1] in ["1", "levelup"]:
			_reward_preview.call_deferred(kv[1])
		elif kv.size() == 2 and kv[0] == "gold":
			GameState.gold = int(kv[1])
		elif kv.size() == 2 and kv[0] == "chests":
			for c in chests:
				c.take_damage(1.0, null)
		elif kv.size() == 2 and kv[0] == "at":
			match kv[1]:
				"npc_nw", "npc_ne", "npc_sw", "npc_se":
					var key := kv[1].trim_prefix("npc_")
					for service in Village.NPCS:
						if service[0] == key:
							var resident: Vector2 = village.npc_points[service[1]]
							player.position = resolve_movement(resident, resident + Vector2(65, 75), Player.RADIUS)
							_fx_review_focus = resident + Vector2(25, -60)
				"npc_courtyard":
					var middle: Vector2 = (village.npc_points["탈것 상인"] + village.npc_points["촌장"]) * 0.5
					player.position = resolve_movement(middle, middle + Vector2(0, 70), Player.RADIUS)
					_fx_review_focus = middle + Vector2(0, -140)
				"portal":
					player.position = exploration.gate_approach("town")
				"boss":
					player.position = village.boss_point + Vector2(0, 130)
				"field":
					player.position = village.point(Vector2(0.5, 1.15))
				"gate0", "gate1", "gate2", "gate3":
					player.position = village.gate_points[int(kv[1].substr(4))] + Vector2(0, 150)
				"bridge":
					player.position = village.bridge.axis_point(0.5)
				"mira":
					var approach: Vector2 = village.spawn_point.lerp(village.npc_points["보급원 미라"], 0.55)
					player.position = resolve_movement(village.spawn_point, approach, Player.RADIUS)
				"elin":
					player.position = village.quest_sites["roots"] + Vector2(60, 40)
				"rowen":
					player.position = village.quest_sites["sun"] + Vector2(-90, 110)
				"lm0", "lm1", "lm2", "lm3":
					var lmk: Landmark = village.landmarks[int(kv[1].substr(2))]
					player.position = lmk.position + Vector2(0, 140)
				"occlusion":
					var building: IsoSprite = village.buildings["nw"]
					var footprint := building.atlas_polygon(village.data["frames"]["nw"]["ground"])
					var bounds := Iso.poly_bounds(footprint)
					player.position = Vector2(bounds.get_center().x, bounds.position.y - Player.RADIUS - 10.0)
				"chapel":
					player.position = village.chapel_steps[village.chapel_steps.size() - 1]
				"chapel_reference":
					_place_at_chapel_reference()
				"bank":
					player.position = Iso.project(village.forecourt_g + Vector2(0, -60))
				"corner0":
					player.position = village.point(Vector2(0.04, 0.10)) + Vector2(0, 150)
				"corner1":
					player.position = village.point(Vector2(0.94, 0.10)) + Vector2(0, 150)
				"corner2":
					player.position = village.point(Vector2(0.04, 0.90)) + Vector2(0, 150)
				"corner3":
					player.position = village.point(Vector2(0.94, 0.90)) + Vector2(0, 150)
			camera.position = player.position
			camera.reset_smoothing()
	# Debug zoom is parsed after initial camera setup. Apply it independent of
	# query ordering or whether a quality setting happens to emit a resize.
	_update_zoom()


func _place_at_chapel_reference() -> void:
	# Use the same real walkable entry for direct links and saved adventures.
	var entry: Vector2 = village.chapel_steps[0]
	player.position = entry
	for offset: Vector2 in [Vector2(80, 75), Vector2(100, 100), Vector2(120, 130)]:
		if not _blocked(entry + offset, Player.RADIUS):
			player.position = entry + offset
			break


## Native3D owns spatial movement; this node adapts the existing rules and HUD.
func _enable_ortho_preview() -> void:
	if is_instance_valid(ortho_preview):
		ortho_preview.set_enabled(true)
		return
	ortho_preview = Ortho3DPreview.new().setup(self)
	add_child(ortho_preview)
	spatial_world = SpatialWorld3D.new().setup(self, ortho_preview.stage)
	spatial_world.register_actor(player, Player.RADIUS, false)
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			spatial_world.register_actor(enemy, Enemy.RADIUS, true)


## Native3D never restores source canvas rendering, including cave return.
## Keep children's local visibility and processing for native cards and rules.
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


## Explicit cave-art review only: enter the real instance and freeze a reproducible view.
func _dungeon_preview(which: String) -> void:
	JavaScriptBridge.eval("window.__sjrpgDungeonPreviewReady = false")
	await get_tree().create_timer(1.5, false).timeout
	if is_queued_for_deletion():
		return
	if hud.panel_open():
		hud.close_panel()
	player.position = dungeon.entry_point()
	if not dungeon.enter():
		push_error("Cave preview could not enter the actual dungeon")
		return
	var ground := Vector2.ZERO
	match which:
		"room":
			ground = DungeonLayout.ROOMS[0]
		"branch":
			ground = Vector2(1125, -500)
		"exit":
			ground = DungeonLayout.EXIT
	player.position = Iso.project(ground)
	player.move_input = Vector2.ZERO
	hud.controls.release_all()
	_impact_offset = Vector2.ZERO
	camera.offset = Vector2.ZERO
	camera.position = _camera_focus()
	camera.reset_smoothing()
	camera.force_update_scroll()
	WorldOcclusion.update(player.global_position, false)
	hud._update_layout()
	hud.controls._layout()
	hud.controls.queue_redraw()
	hud._bars.queue_redraw()
	hud.minimap.queue_redraw()
	# The fresh entry notice would otherwise stay frozen across the cave artwork.
	hud._toast_plaque.hide()
	get_tree().paused = true
	JavaScriptBridge.eval("window.__sjrpgDungeonPreviewReady = true")


## Explicit visual audit only: freeze genuine numeric state at difficult fill/label cases.
func _encounter_preview(which: String) -> void:
	await get_tree().create_timer(2.0, false).timeout
	if is_queued_for_deletion():
		return
	_encounter_audit = true
	_spawn_timer = 10000.0
	encounters.set_process(false)
	for enemy in enemies:
		enemy.queue_free()
	enemies.clear()
	for id in encounters._members:
		encounters._members[id] = []
	var stone: EncounterStone = encounters.stones["west"]
	player.position = resolve_movement(stone.position + Vector2(60, 45), stone.position + Vector2(60, 45), Player.RADIUS)
	player.facing = (stone.position - player.position).angle()
	encounters.states["west"]["initial_spawned"] = true
	if which == "empty":
		encounters.states["west"]["charges"] = 0
	elif which == "active":
		encounters.spawn_wave("west", false)
	camera.position = _camera_focus()
	camera.reset_smoothing()
	hud._toast_queue.clear()
	hud._toast_time = 0.0
	hud._toast_plaque.hide()
	_update_encounter_audit()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sjrpgEncounterPreviewReady = true")


func _update_encounter_audit() -> void:
	if not _encounter_audit or not OS.has_feature("web"):
		return
	var state: Dictionary = encounters.states["west"]
	JavaScriptBridge.eval("window.__sjrpgEncounterAudit = " + JSON.stringify({"charges": state["charges"], "living": encounters.living("west"), "ready": encounters.can_summon("west")}))


func _hud_preview(which: String) -> void:
	await get_tree().create_timer(2.0, false).timeout
	if is_queued_for_deletion():
		return
	match which:
		"low", "danger":
			player.hp = player.max_hp * 0.05
			player.resource = player.resource_max * 0.01
			GameState.xp = 1
		"nearfull":
			player.hp = player.max_hp * 0.99
			player.resource = player.resource_max * 0.99
			GameState.xp = GameState.xp_to_next() - 1
		"large":
			GameState.level = 100
			player.max_hp = 99999.99
			player.hp = 79543.21
			player.resource_max = 99999.9
			player.resource = 12345.6
		_:
			player.hp = player.max_hp
			player.resource = player.resource_max
	# Inspect the steady fill rather than a transient damage trail.
	hud._health_trail = player.hp / player.max_hp
	hud._last_hp = player.hp
	hud._last_max_hp = player.max_hp
	hud._hurt_feedback = 0.0
	hud._heal_feedback = 0.0
	hud._update_critical_warning(0.0)
	hud._update_layout()
	hud._bars.queue_redraw()
	hud.minimap.queue_redraw()
	if which == "danger":
		# Keep the genuine HUD pulse running while holding the audit hero and enemies still.
		set_process(false)
		player.set_process(false)
		exploration.set_process(false)  # The portal's independent rest healing would clear the audit warning.
		for enemy in enemies:
			enemy.set_process(false)
	else:
		get_tree().paused = true
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sjrpgHudPreviewReady = true")


## Explicit browser review only: discover by visiting, then exercise a real destination button.
func _warp_preview() -> void:
	await get_tree().create_timer(2.0, false).timeout
	if is_queued_for_deletion():
		return
	player.position = exploration.gate_approach("tree")
	exploration.discover_current()
	player.position = exploration.gate_approach("town")
	exploration.discover_current()
	camera.position = player.position
	camera.reset_smoothing()
	hud.interact("워프게이트")
	var panel: WarpGatePanel = hud._panel
	for frame in 3:
		await get_tree().process_frame
	var button: Button = panel.destination_buttons["tree"]
	panel.scroll.ensure_control_visible(button)
	for frame in 3:
		await get_tree().process_frame
	var center := button.get_global_rect().get_center() / get_viewport_rect().size
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sjrpgWarpPreviewButton = " + JSON.stringify([center.x, center.y]))
	await panel.closed
	if not is_queued_for_deletion() and OS.has_feature("web"):
		var arrived := GameState.last_sanctuary == "tree" and exploration.gate_origin() == "tree" and not _blocked(player.position, Player.RADIUS)
		JavaScriptBridge.eval("window.__sjrpgWarpPreviewArrived = " + ("true" if arrived else "false"))


## Explicit visual-review query only: real equipped-skill casts against a stationary target.
func _combat_preview() -> void:
	encounters.set_process(false)
	_spawn_timer = 10000.0
	for enemy in enemies:
		enemy.queue_free()
	enemies.clear()
	await get_tree().create_timer(2.0).timeout
	var target := Enemy.new()
	target.setup(self, "goblin", 1)
	target.position = player.position + Vector2(65, 10)
	target.hp = 100000.0
	target.max_hp = target.hp
	world.add_child(target)
	enemies.append(target)
	# Keep presentation and timers running; only prevent this review target from attacking.
	target.stun(60.0)
	for i in 120:
		if not is_inside_tree() or is_queued_for_deletion():
			return
		if player._attack_time <= 0.0 and float(player.cooldowns.get(GameState.slots[0], 0.0)) <= 0.0:
			# Re-seat the review dummy between swings after real knockback moved it away.
			target.position = player.position + Vector2(65, 10)
			target._knockback = Vector2.ZERO
			player.cast_slot(0, true)
		await get_tree().create_timer(0.37, false).timeout


## Real zone ticks create the per-monster streams for an explicit visual review.
func _damage_stream_preview() -> void:
	encounters.set_process(false)
	_spawn_timer = 10000.0
	for enemy in enemies:
		enemy.queue_free()
	enemies.clear()
	await get_tree().create_timer(2.0, false).timeout
	var targets: Array[Enemy] = []
	for offset in [Vector2(70, 75), Vector2(-70, 75)]:
		var enemy := Enemy.new()
		enemy.setup(self, "goblin", 1)
		enemy.position = player.position + offset
		enemy.hp = 100000.0
		enemy.max_hp = enemy.hp
		world.add_child(enemy)
		enemies.append(enemy)
		enemy.stun(60.0)
		targets.append(enemy)
	spawn_zone({"pos": player.position + Vector2(0, 75), "radius": 110.0,
		"duration": 2.0, "tick": 0.10, "damage": 16.81, "color": SkillDefs.FIRE})
	for frame in 200:
		await get_tree().process_frame
		var rows := 0
		for effect in cosmetic_effects:
			if is_instance_valid(effect) and not effect.is_queued_for_deletion() and effect is Effect and effect.kind == "text" and effect._text_target_id == targets[0].get_instance_id():
				rows += 1
		if rows >= 4:
			get_tree().paused = true
			JavaScriptBridge.eval("window.__sjrpgDamageStreamReady = true")
			return


## Explicit visual review only: equip one existing skill, perform its real cast,
## then pause the actual simulation near the authored effect's peak for inspection.
func _reference_fx_preview(which: String) -> void:
	encounters.set_process(false)
	for enemy in enemies:
		enemy.queue_free()
	enemies.clear()
	_spawn_timer = 10000.0
	await get_tree().create_timer(4.0, false).timeout
	for enemy in enemies:
		enemy.queue_free()
	enemies.clear()
	GameState.ranks[which] = 1
	GameState.slots[0] = which
	player.resource = player.resource_max
	var offsets: Array[Vector2] = [Vector2(60, 0), Vector2(-55, 10), Vector2(0, -65)]
	if which in ["iceBolt", "meteor"]:
		offsets = [Vector2(430 if which == "iceBolt" else 240, -50)]
	_fx_review_focus = player.position + offsets[0] * 0.45 + Vector2(0, -65)
	camera.position = _fx_review_focus
	camera.reset_smoothing()
	for offset in offsets:
		var target := Enemy.new()
		target.setup(self, "goblin", 1)
		target.position = player.position + offset
		target.hp = 100000.0
		target.max_hp = target.hp
		target.xp_reward = 0
		world.add_child(target)
		enemies.append(target)
		target.stun(60.0)
	var cast_started := player.cast_slot(0)
	JavaScriptBridge.eval("window.__sjrpgFxReviewStatus = " + JSON.stringify({"started": cast_started, "skill": which}))
	var key: String = {"cleave": "slash", "whirlwind": "spin", "leapAttack": "slam", "iceBolt": "bolt", "frostNova": "frost", "meteor": "meteor"}[which]
	for frame in 300:
		await get_tree().process_frame
		for node in world.get_children():
			var effect := node as Effect
			if effect == null or effect.is_queued_for_deletion():
				continue
			var matches: bool = (effect.kind == "slash" and key == "slash") or str(effect.params.get("visual", "")) == key
			if matches and ((key == "bolt" and effect.kind == "proj" and effect.age >= 0.10) or (effect.kind in ["slash", "skill_fx"] and effect.visual_phase() >= 0.24)):
				get_tree().paused = true
				JavaScriptBridge.eval("window.__sjrpgFxReview = " + JSON.stringify({"skill": which, "key": key, "phase": effect.visual_phase(), "actual_cast": true}))
				return


## Isolated visual inspection: one real threat completes its attack against the protected NPC.
func _defender_feedback_preview() -> void:
	encounters.set_process(false)
	quest_runtime.set_process(false)
	_spawn_timer = 10000.0
	for enemy in enemies:
		enemy.queue_free()
	enemies.clear()
	quest_runtime.accept("sun")
	quest_runtime.start_protection()
	var defender := quest_runtime.defender as Villager
	player.position = resolve_movement(player.position, defender.position + Vector2(-90, 110), Player.RADIUS)
	_fx_review_focus = defender.position + Vector2(0, -45)
	camera.position = _fx_review_focus
	camera.reset_smoothing()
	await get_tree().create_timer(4.0, false).timeout
	var target := Enemy.new()
	target.setup(self, "goblin", 1)
	target.position = defender.position + Vector2(30, 0)
	target.is_threat = true
	target.force_chase()
	world.add_child(target)
	enemies.append(target)
	var hp: float = Quests.state("sun")["defender_hp"]
	for frame in 300:
		await get_tree().process_frame
		if float(Quests.state("sun")["defender_hp"]) < hp and defender._hurt_flash > 0.0:
			get_tree().paused = true
			JavaScriptBridge.eval("window.__sjrpgDefenderReview = true")
			return


## Actual threat scan and door animation; the dummy cannot attack during visual review.
func _gate_closure_preview(index: int) -> void:
	await get_tree().create_timer(4.0, false).timeout
	for enemy in enemies:
		enemy.queue_free()
	enemies.clear()
	_spawn_timer = 10000.0
	player.position = village.spawn_point
	var at := village.gate_points[index]
	_fx_review_focus = at + Vector2(0, 20)
	camera.position = _fx_review_focus
	camera.reset_smoothing()
	var direction := (at - village.spawn_point).normalized()
	var target := Enemy.new()
	target.setup(self, "goblin", 1)
	target.position = at + direction * 140.0
	world.add_child(target)
	enemies.append(target)
	target.stun(60.0)
	target.set_process(false)
	for frame in 300:
		await get_tree().process_frame
		if town_gates.closed[index] and town_gates.progress[index] >= 0.99:
			JavaScriptBridge.eval("window.__sjrpgGateReview = " + JSON.stringify({"gate": index, "closed": true, "progress": town_gates.progress[index]}))
			return


## Explicit art review only: real deaths keep all five body illustrations visible in the plaza.
func _corpse_preview(surface := "1") -> void:
	await get_tree().create_timer(2.0, false).timeout
	if is_queued_for_deletion():
		return
	player.position = resolve_movement(village.spawn_point, village.spawn_point + Vector2(0, -10), Player.RADIUS)
	var positions: Array[Vector2] = []
	var kinds: Array[String] = []
	if surface == "bridge":
		player.position = village.bridge.axis_point(0.5)
		positions = [village.bridge.axis_point(0.4), village.bridge.axis_point(0.65)]
		kinds = ["wolf", "skeleton"]
	elif surface == "terrace":
		player.position = village.chapel_steps[village.chapel_steps.size() - 2]
		var body: Vector2 = village.chapel_steps[village.chapel_steps.size() - 1]
		var further := body + Vector2(-60, -35)
		if Geometry2D.is_point_in_polygon(further, village.terrace) and not _blocked(further, Enemy.RADIUS):
			body = further
		positions = [body]
		kinds = ["goblin"]
	else:
		var offsets := [Vector2(-330, 70), Vector2(-175, 70), Vector2(-20, 70), Vector2(140, 70), Vector2(330, 70)]
		var offset_index := 0
		for kind in Enemy.KINDS:
			kinds.append(kind)
			positions.append(player.position + offsets[offset_index])
			offset_index += 1
	camera.position = player.position
	camera.reset_smoothing()
	var index := 0
	var review_bodies: Array = []
	for kind in kinds:
		var enemy := Enemy.new()
		enemy.setup(self, kind, 1)
		enemy.position = positions[index]
		enemy.xp_reward = 0
		world.add_child(enemy)
		enemies.append(enemy)
		enemy.take_damage(enemy.hp + 1.0, null)
		review_bodies.append(corpses.back())
		index += 1
	await get_tree().create_timer(0.25, false).timeout
	if not is_queued_for_deletion() and OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sjrpgCorpsePreviewReady = true")
	await get_tree().create_timer(CORPSE_LIFETIME + 0.1, false).timeout
	if not is_queued_for_deletion() and OS.has_feature("web"):
		# Read-only browser assertion: normal gameplay ticks, without aging or removing the review bodies here.
		var expired := review_bodies.all(func(body): return float(body["time"]) <= 0.0 and body["used"])
		JavaScriptBridge.eval("window.__sjrpgCorpsePreviewExpired = " + ("true" if expired else "false"))


## Explicit review query only. Exercise real grant/chest paths, never run in a normal adventure.
func _reward_preview(mode := "1") -> void:
	await get_tree().create_timer(2.0, false).timeout
	if is_queued_for_deletion():
		return
	if mode == "1":
		for chest in chests:
			if not chest.dead:
				player.position = chest.position + Vector2(70, 35)
				chest.take_damage(1.0, player)
				break
	await get_tree().create_timer(0.8, false).timeout
	if not is_queued_for_deletion():
		if mode == "levelup":
			hud._toast_queue.clear()
			hud._toast_time = 0.0
			hud._toast_plaque.hide()
			camera.position = _camera_focus()
			camera.reset_smoothing()
		grant_xp(GameState.xp_to_next())
		if mode == "levelup" and OS.has_feature("web"):
			# Let the real character effect rise before the explicit capture pause.
			await get_tree().create_timer(0.30, false).timeout
		if OS.has_feature("web"):
			hud._update_vital_feedback(0.0)
			hud._update_layout()
			if is_instance_valid(hud._level_up):
				hud._level_up._process(0.06)
				hud._level_up._process(0.06)
			hud._bars.queue_redraw()
			hud.controls.queue_redraw()
			get_tree().paused = true  # Explicit capture preview freezes the confirmed reward at its visual peak.
			JavaScriptBridge.eval("window.__sjrpgRewardPreviewReady = true")


func in_town(p: Vector2) -> bool:
	return not dungeon.active and Geometry2D.is_point_in_polygon(p, village.safe_zone)


## Only confirmed nearby hits nudge the camera; gameplay clocks and hitboxes stay unchanged.
func combat_feedback(at: Vector2, strength: float, hurt := false) -> void:
	if Prefs.reduce_motion or player.position.distance_to(at) > 650.0:
		return
	var direction := (player.position - at).normalized()
	if direction.length_squared() < 0.1:
		direction = Vector2(0.6, -0.8)
	_impact_offset = (_impact_offset + direction * clampf(strength, 0.0, 1.0) * (5.0 if hurt else 3.8)).limit_length(7.0)
	_impact_age = 0.0
	_impact_cross = direction.orthogonal() * clampf(strength, 0.0, 1.0) * 0.65
	_impact_fresh = true
	camera.offset = _impact_offset


## Present a confirmed contact before a slow next frame can decay its whole pulse away.
func _update_impact_camera(delta: float) -> void:
	if Prefs.reduce_motion:
		_impact_offset = Vector2.ZERO
		_impact_cross = Vector2.ZERO
	else:
		_impact_offset *= exp(-18.0 * (minf(delta, 0.012) if _impact_fresh else delta))
	_impact_age += minf(delta, 0.012) if _impact_fresh else delta
	_impact_fresh = false
	var ripple := _impact_cross * sin(_impact_age * TAU * 32.0) * maxf(0.0, 1.0 - _impact_age / 0.16)
	camera.offset = (_impact_offset + ripple).limit_length(7.0)


func _process(delta: float) -> void:
	if not native_ready:
		return
	# Forest-root visibility disables/restores lighting in the same cave-transition frame.
	_sync_forest_daylight()
	WorldLighting.advance(delta)
	_update_impact_camera(delta)
	camera.position = _camera_focus()
	if dungeon.active:
		WorldOcclusion.update(player.global_position, false)
		dungeon.tick(delta)
		_save_timer += delta
		if _save_timer >= 5.0:
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
	WorldOcclusion.update(player.global_position if not player.dead else Vector2(1000000, 1000000), elevated)
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
	if _save_timer >= 5.0:
		_save_timer = 0.0
		GameState.save_game()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		if is_node_ready() and process_mode != Node.PROCESS_MODE_DISABLED:
			_pause_in_background()


func _pause_in_background() -> void:
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
	if is_instance_valid(spatial_world) and is_instance_valid(ortho_preview):
		var logical := get_viewport_rect().size
		var native := screen * Vector2(ortho_preview.viewport.size) / logical
		var origin := ortho_preview.camera.project_ray_origin(native)
		var direction := ortho_preview.camera.project_ray_normal(native)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 180.0, SpatialWorld3D.FLOOR)
		query.hit_back_faces = true
		var hit := spatial_world.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			return SpatialWorld3D.projected(hit["position"])
	var render_position := screen * scene_view.get_visible_rect().size / get_viewport_rect().size
	return scene_view.canvas_transform.affine_inverse() * render_position


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or hud.panel_open():
		return
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.pressed:
		if player.dead:
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			var direction := screen_to_world(event.position) - player.position
			if direction.length() > 1.0:
				player.facing = direction.angle()
			hud.controls.hold_mouse_primary()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Drawn HUD buttons are not Control nodes; reserve their right-click area too.
			if hud.controls._hit_button(event.position) == "" and not hud.minimap.get_global_rect().has_point(event.position):
				player.set_move_target(screen_to_world(event.position))
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("skill"):
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
		if _blocked(p, Enemy.RADIUS + 10.0):
			continue
		var zone := clampi(int((p.length() - 1300.0) / 900.0), 0, 3)
		var pool := ["goblin", "goblin", "wolf"]
		if zone >= 1:
			pool.append_array(["wolf", "boar"])
		if zone >= 2:
			pool.append_array(["boar", "skeleton"])
		if zone >= 3:
			pool.append_array(["skeleton", "skeleton"])
		var enemy := Enemy.new()
		enemy.setup(self, pool[_rng.randi_range(0, pool.size() - 1)], ForestBalance.area_level(zone))
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
		var l := d.length()
		if l < 48.0 and l > 0.01:
			push += d / l * (1.0 - l / 48.0)
	return push


func nearest_enemy(from: Vector2, max_range: float) -> Enemy:
	var best: Enemy = null
	var best_d := max_range
	for e in enemies:
		if e.dead:
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
		if not is_instance_valid(e) or e.dead or center.distance_to(e.position) > radius + Enemy.RADIUS:
			continue
		var reachable := can_melee_reach(center, e.position) if melee else SpatialCombat3D.area_reaches(self, center, e.position, radius + Enemy.RADIUS)
		if reachable:
			out.append(e)
	return out


func enemies_in_arc(center: Vector2, angle: float, radius: float, half_angle: float, melee := false) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in enemies_in_radius(center, radius, melee):
		var d := e.position - center
		if d.length() < 30.0 or absf(angle_difference(angle, d.angle())) <= half_angle:
			out.append(e)
	return out


## Physical swings share actor elevation/wall reach; ranged spells retain their area rules.
func break_chests_in_radius(center: Vector2, radius: float, source: Node2D = null, melee := false) -> void:
	if encounters != null:
		encounters.in_radius(center, radius, source, INF, PI, melee)
	for c in chests:
		if not c.dead and center.distance_to(c.position) <= radius + 26.0 and (can_melee_reach(center, c.position) if melee else SpatialCombat3D.area_reaches(self, center, c.position, radius + 26.0)):
			c.take_damage(1.0, source)


func break_chests_in_arc(center: Vector2, angle: float, radius: float, half_angle: float, source: Node2D = null, melee := false) -> void:
	if encounters != null:
		encounters.in_radius(center, radius, source, angle, half_angle, melee)
	for c in chests:
		if c.dead:
			continue
		var d := c.position - center
		if d.length() <= radius + 26.0 and (d.length() < 40.0 or absf(angle_difference(angle, d.angle())) <= half_angle) and (can_melee_reach(center, c.position) if melee else SpatialCombat3D.area_reaches(self, center, c.position, radius + 26.0)):
			c.take_damage(1.0, source)


func break_chests_at(p: Vector2, r: float, source: Node2D = null, include_stones := true) -> void:
	if encounters != null and include_stones:
		encounters.in_radius(p, r, source)
	for c in chests:
		if not c.dead and p.distance_to(c.position) <= r + 26.0 and SpatialCombat3D.area_reaches(self, p, c.position, r + 26.0):
			c.take_damage(1.0, source)


func on_chest_broken(chest: Chest) -> void:
	spawn_nova(chest.position, 70.0, Color(0.95, 0.8, 0.45), true)
	SoundFx.play("loot")
	Prefs.pulse("loot")
	var content := GameState.chest_content(chest.index)
	var gold: int = {"gear": 18, "supplies": 8, "coins": 10, "ambush": 0}[content]
	if content == "ambush":
		gold = 6
		toast("매복이다!")
		for i in 2:
			_spawn_enemy_near(chest.position)
	GameState.gold += gold
	if gold > 0:
		RewardFx.spawn(self, chest.position + Vector2(0, -35), 0)
	float_text(chest.position + Vector2(0, -70), "+%d G" % gold, Color(1, 0.88, 0.45))
	# 원본: 보급 상자와 숲의 첫 상자는 치유·자원 물약을 하나씩 줌.
	if content == "supplies" or chest.index == 0:
		GameState.potions += 1
		GameState.mana_potions += 1
		toast("보급품: 치유 물약 +1 · %s 물약 +1" % GameState.class_info()["resource"])
	if chest.index == 8:
		content = "gear"
	if content == "gear":
		var g := Gear.roll_loot(GameState.hero_class, GameState.level, GameState.next_serial, _rng, true)
		if chest.index == 8:
			g = GameState.new_gear("shortsword" if GameState.hero_class == "warrior" else "wand", 2, 4, 8)
		if GameState.add_gear(g):
			if g.rarity >= 2:
				RewardFx.spawn(self, chest.position + Vector2(0, -42), 2)
			toast("획득: %s" % g.display_name())
			player.refresh_stats()
		else:
			GameState.gold += g.sale_value()
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
	enemy.position = resolve_movement(at, at + Vector2.from_angle(_rng.randf() * TAU) * 70.0, Enemy.RADIUS)
	world.add_child(enemy)
	enemies.append(enemy)


func enemy_hit_by_point(p: Vector2, r: float) -> Enemy:
	for e in enemies:
		if not e.dead and p.distance_to(e.position) <= r + Enemy.RADIUS:
			return e
	return null


func rng_int(a: int, b: int) -> int:
	return _rng.randi_range(a, b)


func rng_float() -> float:
	return _rng.randf()


func rng_range(a: float, b: float) -> float:
	return _rng.randf_range(a, b)


func on_boss_defeated(boss: Enemy) -> void:
	if GameState.boss_defeated:
		return
	GameState.boss_defeated = true
	GameState.boss_summoned = true
	GameState.boss_heart_pending = true
	if GameState.claim_boss_heart():
		toast("파수꾼의 심장을 얻었습니다!")
	else:
		toast("가방을 비우면 파수꾼의 심장을 받을 수 있습니다")
	GameState.save_game()
	await get_tree().create_timer(1.2, false).timeout
	hud.open_victory()


func on_enemy_killed(enemy: Enemy) -> void:
	enemies.erase(enemy)
	if encounters != null:
		encounters.on_killed(enemy)
	Prefs.pulse("kill")
	GameState.kills += 1
	if dungeon.active:
		dungeon.on_enemy_killed(enemy)
	else:
		quest_runtime.on_enemy_killed(enemy)
	if GameState.has_gift("renewal") and not player.dead:
		player.hp = minf(player.max_hp, player.hp + 4.0)
		float_text(player.position + Vector2(0, -80), "+%s" % HudArt.stat(4.0), Color(0.6, 1, 0.7))
	if enemy.is_boss:
		on_boss_defeated(enemy)
	float_text(enemy.position + Vector2(0, -enemy.sprite.body_height - 40), "+%d XP" % enemy.xp_reward, Color(0.7, 0.85, 1))
	if enemy.xp_reward > 0:
		RewardFx.spawn(self, enemy.position + Vector2(0, -28), 1)
	# 원본: 몬스터 처치로는 물약이 나오지 않음 (상자·구매·물약 발견만).
	# Every death has a body; the original 30% skill-search eligibility remains independent.
	add_corpse(enemy, _rng.randf() < 0.3)
	grant_xp(enemy.xp_reward)


func grant_xp(amount: int) -> void:
	var gained := GameState.add_xp(amount)
	if gained > 0:
		player.refresh_stats(true)
		RewardFx.spawn(self, player.position + Vector2(0, -32), 1, true)
		SoundFx.play("levelup")
		SoundFx.play("loot")
		hud.show_level_up(GameState.level)
		GameState.save_game()


## One bounded record owns the picture and any corpse-skill target. No actor/collision survives death.
func add_corpse(enemy: Enemy, searchable: bool) -> Dictionary:
	var corpse := {
		"pos": enemy.position, "time": CORPSE_LIFETIME, "lifetime": CORPSE_LIFETIME, "used": false,
		"kind": enemy.kind, "facing": enemy.facing, "height": enemy.sprite.body_height,
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
	for corpse in corpses.duplicate():
		corpse["time"] = maxf(0.0, float(corpse["time"]) - delta)
		if corpse["time"] <= 0.0:
			remove_corpse(corpse)
		else:
			var visual: Node2D = corpse.get("visual")
			if is_instance_valid(visual):
				visual.queue_redraw()


## Validate again when a delayed skill lands: selection may have expired, been consumed or changed maps.
func corpse_available(corpse: Dictionary) -> bool:
	return corpses.has(corpse) and not corpse.get("used", false) and float(corpse.get("time", 0.0)) > 0.0 and corpse.get("searchable", true)


func nearest_corpse(from: Vector2, max_range: float):
	var best = null
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
	hud.controls.release_all()
	# Releasing pointers can leave false slot entries; death discards every prior hold.
	player.held_slots.clear()
	hud.show_death()
	await get_tree().create_timer(2.5, false).timeout
	if not player.dead:
		hud.hide_death()
		return
	if dungeon.active:
		dungeon.leave("쓰러져 동굴 입구로 돌아왔습니다")
		return
	quest_runtime.reset_boss()
	player.revive(exploration.respawn_point())
	hud.hide_death()
	GameState.save_game()


func _add_effect(e: Effect) -> void:
	# Bound only cosmetic nodes; projectiles, damage zones and summons keep their gameplay.
	if e.kind not in ["proj", "orb", "zone", "hydra", "ward"]:
		cosmetic_effects = cosmetic_effects.filter(func(effect): return is_instance_valid(effect) and not effect.is_queued_for_deletion())
		if cosmetic_effects.size() >= 64:
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
	length *= SpatialCombat3D.wall_fraction(self, from, from + dir * length, native_y, 14.0)
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


func float_text(at: Vector2, text: String, color: Color, damage_target: Node2D = null) -> void:
	var e := Effect.new()
	e.kind = "text"
	e.position = at
	e.text = text
	e.color = color
	e.life = 0.9
	e.z_index = 20
	e.place_text(cosmetic_effects, damage_target)
	_add_effect(e)


func toast(text: String) -> void:
	if hud:
		hud.toast(text)


func quit_to_title() -> void:
	if dungeon.active:
		dungeon.leave("동굴 입구로 돌아왔습니다")
	if GameState.save_game():
		quit_requested.emit()

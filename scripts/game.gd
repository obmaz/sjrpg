extends Node2D
## The adventure field (원본: lib/src/game/adventure.dart의 핵심 루프 일부).

signal quit_requested
signal restart_requested

## Field in ground units (original scale): the 2400 town sits in the middle.
const FIELD := Rect2(-3600, -3600, 7200, 7200)
const MEADOW := preload("res://assets/art/village/meadow-a.webp")

var scene_view: Viewport
var scene_root: Node
var _low_view: SubViewport
var _view_container: SubViewportContainer
var world: Node2D
var player: Player
var camera: Camera2D
var hud: Hud
var village: Village
var quest_runtime: QuestRuntime
var exploration: Exploration
var dungeon: DungeonRuntime
var field_root: Node2D
var map_shapes: Array[Dictionary] = []
var enemies: Array[Enemy] = []
var chests: Array[Chest] = []
var cosmetic_effects: Array[Effect] = []
var corpses: Array = []  # {"pos": Vector2, "time": float, "used": bool}
var _corpse_layer: Node2D
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
	_view_container.visible = Prefs.low_resolution
	scene_root = _low_view if Prefs.low_resolution else self
	scene_view = _low_view if Prefs.low_resolution else get_viewport()
	field_root = Node2D.new()
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
	meadow.texture = MEADOW
	meadow.centered = false
	meadow.region_enabled = true
	var units_per_tex := 170.0
	meadow.region_rect = Rect2(Vector2.ZERO, backdrop.size / units_per_tex * 418.0)
	meadow.scale = Vector2.ONE * units_per_tex / 418.0
	meadow.position = backdrop.position
	meadow.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	# ForestScenePalette: bright, low-saturation warm grass.
	meadow.modulate = Color(0.58, 0.70, 0.50)
	ground_layer.add_child(meadow)

	# Dappled forest shade: a multiply layer of soft light patches over the ground.
	var shade := Sprite2D.new()
	shade.texture = _dapple_texture()
	shade.centered = false
	shade.region_enabled = true
	shade.region_rect = Rect2(Vector2.ZERO, backdrop.size / 1500.0 * 192.0)
	shade.scale = Vector2.ONE * 1500.0 / 192.0
	shade.position = backdrop.position
	shade.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	var mul := CanvasItemMaterial.new()
	mul.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	shade.material = mul
	shade.z_index = 3
	ground_layer.add_child(shade)

	_corpse_layer = Node2D.new()
	_corpse_layer.z_index = -8
	_corpse_layer.draw.connect(_draw_corpses)
	field_root.add_child(_corpse_layer)

	world = Node2D.new()
	world.y_sort_enabled = true
	field_root.add_child(world)
	village = Village.new()
	village.build(ground_layer, world)
	village.build_field(world, FIELD.grow(-150), _rng)
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
	_read_debug_params()
	_update_zoom()
	get_viewport().size_changed.connect(_update_zoom)
	for i in 8:
		_spawn_enemy(true)
	toast("미니맵에서 의뢰 위치를 확인하세요 · 마을의 미라가 기다립니다")
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sjrpgAdventureReady = true")


func _update_zoom() -> void:
	var size := get_viewport_rect().size
	_view_container.size = size
	# Keep characters similarly sized in portrait and landscape.
	var short_side := minf(size.x, size.y)
	var z := clampf(short_side / 720.0 * 0.8, 0.5, 1.6)
	camera.zoom = Vector2(z, z) * _debug_zoom / (2.0 if Prefs.low_resolution else 1.0)


func _update_render_quality() -> void:
	scene_root = _low_view if Prefs.low_resolution else self
	scene_view = _low_view if Prefs.low_resolution else get_viewport()
	field_root.reparent(scene_root, false)
	camera.reparent(scene_root, false)
	if dungeon.active:
		dungeon._root.reparent(scene_root, false)
	_view_container.visible = Prefs.low_resolution
	if Prefs.low_resolution:
		get_viewport().canvas_transform = Transform2D.IDENTITY
	camera.make_current()
	_update_zoom()
	camera.reset_smoothing()


## Web debug: ?zoom=0.4 widens the camera (used for layout screenshots).
var _debug_zoom := 1.0


func _debug_open_panel(which: String) -> void:
	# Debug rewards may have opened a memory; always show the requested capture panel.
	if hud.panel_open():
		hud.close_panel()
	match which:
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
		elif kv.size() == 2 and kv[0] == "quality":
			Prefs.set_low_resolution(kv[1] == "low")
		elif kv.size() == 2 and kv[0] == "panel":
			var which: String = kv[1]
			get_tree().create_timer(1.5).timeout.connect(_debug_open_panel.bind(which))
		elif kv.size() == 2 and kv[0] == "gold":
			GameState.gold = int(kv[1])
		elif kv.size() == 2 and kv[0] == "chests":
			for c in chests:
				c.take_damage(1.0, null)
		elif kv.size() == 2 and kv[0] == "at":
			match kv[1]:
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
				"bank":
					player.position = Iso.project(village.forecourt_g + Vector2(0, -60))
				"corner0":
					player.position = village.point(Vector2(0.04, 0.10)) + Vector2(0, 150)
				"corner3":
					player.position = village.point(Vector2(0.94, 0.90)) + Vector2(0, 150)
			camera.position = player.position
			camera.reset_smoothing()


func _dapple_texture() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.03
	noise.fractal_octaves = 3
	noise.seed = 11
	var img := noise.get_seamless_image(192, 192)
	img.convert(Image.FORMAT_RGB8)
	var dark := Color(0.40, 0.48, 0.45)
	var lit := Color(1.0, 0.97, 0.88)
	for y in img.get_height():
		for x in img.get_width():
			var n := img.get_pixel(x, y).r
			img.set_pixel(x, y, dark.lerp(lit, smoothstep(0.40, 0.60, n)))
	return ImageTexture.create_from_image(img)


## 상인 곁에서는 가방에서 상점으로 전환할 수 있습니다 (원본의 근처 행동 버튼).
func near_merchant() -> bool:
	if dungeon.active:
		return false
	return player.position.distance_to(village.merchant_point) < 210.0


## Name of the town NPC within talking range, or "".
func near_npc() -> String:
	if dungeon.active:
		return "동굴 출구" if dungeon.at_exit() or player.position.length() < 150.0 else ""
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


func _process(delta: float) -> void:
	camera.position = player.position + Vector2(0, -30)
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
	# Gate passages: the gatehouse art would hide the player in its arch, so draw above it there.
	for passage in village.gate_passages:
		if Geometry2D.is_point_in_polygon(player.position, passage):
			elevated = true
			break
	player.z_index = 1 if elevated else 0
	WorldOcclusion.update(player.global_position if not player.dead else Vector2(1000000, 1000000), elevated)
	for c in corpses.duplicate():
		c["time"] -= delta
		if c["time"] <= 0.0:
			corpses.erase(c)
	_corpse_layer.queue_redraw()
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = ForestBalance.SPAWN_SECONDS
		# Distant ambient enemies must not consume the local encounter budget.
		for enemy in enemies.duplicate():
			if not enemy.is_boss and not enemy.is_threat and enemy.position.distance_to(player.position) > 1900.0:
				enemies.erase(enemy)
				enemy.queue_free()
		var near_home := Iso.unproject(player.position).length() < ForestBalance.NEAR_TOWN_RADIUS
		if enemies.size() < ForestBalance.field_limit(near_home):
			_spawn_enemy()
	_save_timer += delta
	if _save_timer >= 5.0:
		_save_timer = 0.0
		GameState.save_game()


func _unhandled_input(event: InputEvent) -> void:
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
	for attempt in 30:
		var p: Vector2
		if anywhere:
			p = Iso.project(Vector2(_rng.randf_range(FIELD.position.x, FIELD.end.x), _rng.randf_range(FIELD.position.y, FIELD.end.y)) * 0.8)
		else:
			p = player.position + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(560, 1000)
		if not _inside_field(p, 200.0) or in_town(p) or p.distance_to(player.position) < 450.0:
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
	if dungeon.active:
		return dungeon.layout.contains(p, margin)
	return FIELD.grow(-margin).has_point(Iso.unproject(p))


func _blocked(p: Vector2, r: float) -> bool:
	if dungeon.active:
		return not dungeon.layout.contains(p, r)
	for c in village.circles:
		if p.distance_to(c[0]) < c[1] + r:
			return true
	for poly in village.solids:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


## Slides a moving circle against trees, buildings, walls and cliffs.
## Monsters (`keep_out_town`) never enter the safe town.
func resolve_movement(from: Vector2, to: Vector2, r: float, keep_out_town := false) -> Vector2:
	if dungeon.active:
		return dungeon.layout.resolve(from, to, r)
	var p := to
	if not _inside_field(p, r):
		var g := Iso.unproject(p)
		var f := FIELD.grow(-r)
		g = Vector2(clampf(g.x, f.position.x, f.end.x), clampf(g.y, f.position.y, f.end.y))
		p = Iso.project(g)
	for iteration in 2:
		for c in village.circles:
			var d: Vector2 = p - c[0]
			var min_d: float = c[1] + r
			if absf(d.x) < min_d and absf(d.y) < min_d and d.length() < min_d:
				p = c[0] + (d.normalized() if d.length() > 0.01 else (from - c[0]).normalized()) * min_d
		for poly in village.solids:
			var b := Iso.poly_bounds(poly).grow(r)
			if b.has_point(p):
				p = Iso.push_out(p, poly, r * 0.6)
	if keep_out_town and in_town(p) and not in_town(from):
		return from
	for poly in village.solids:
		if Geometry2D.is_point_in_polygon(p, poly):
			return from
	return p


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


func enemies_in_radius(center: Vector2, radius: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in enemies:
		if not e.dead and center.distance_to(e.position) <= radius + Enemy.RADIUS:
			out.append(e)
	return out


func enemies_in_arc(center: Vector2, angle: float, radius: float, half_angle: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in enemies_in_radius(center, radius):
		var d := e.position - center
		if d.length() < 30.0 or absf(angle_difference(angle, d.angle())) <= half_angle:
			out.append(e)
	return out


## 상자는 공격 기술의 범위·투사체에 맞으면 부서집니다.
func break_chests_in_radius(center: Vector2, radius: float, source: Node2D = null) -> void:
	for c in chests:
		if not c.dead and center.distance_to(c.position) <= radius + 26.0:
			c.take_damage(1.0, source)


func break_chests_in_arc(center: Vector2, angle: float, radius: float, half_angle: float, source: Node2D = null) -> void:
	for c in chests:
		if c.dead:
			continue
		var d := c.position - center
		if d.length() <= radius + 26.0 and (d.length() < 40.0 or absf(angle_difference(angle, d.angle())) <= half_angle):
			c.take_damage(1.0, source)


func break_chests_at(p: Vector2, r: float, source: Node2D = null) -> void:
	for c in chests:
		if not c.dead and p.distance_to(c.position) <= r + 26.0:
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
		get_tree().create_timer(0.6).timeout.connect(func():
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
	await get_tree().create_timer(1.2).timeout
	hud.open_victory()


func on_enemy_killed(enemy: Enemy) -> void:
	enemies.erase(enemy)
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
	# 원본: 몬스터 처치로는 물약이 나오지 않음 (상자·구매·물약 발견만).
	# Corpses feed 물약 발견 · 아이템 발견 · 섬뜩한 수호물.
	if _rng.randf() < 0.3:
		corpses.append({"pos": enemy.position, "time": 30.0, "used": false})
		if corpses.size() > 32:
			corpses.pop_front()
	grant_xp(enemy.xp_reward)


func grant_xp(amount: int) -> void:
	var gained := GameState.add_xp(amount)
	if gained > 0:
		player.refresh_stats(true)
		spawn_nova(player.position, 120.0, Color(1, 0.9, 0.4))
		toast("레벨 업! Lv.%d · 스킬 포인트 %d" % [GameState.level, GameState.skill_points])
		GameState.save_game()


func nearest_corpse(from: Vector2, max_range: float):
	var best = null
	var best_d := max_range
	for c in corpses:
		var d := from.distance_to(c["pos"])
		if not c["used"] and d < best_d:
			best_d = d
			best = c
	return best


func remove_corpse(c: Dictionary) -> void:
	corpses.erase(c)


func _draw_corpses() -> void:
	for c in corpses:
		var p: Vector2 = c["pos"]
		var a := clampf(c["time"] / 3.0, 0.0, 1.0) * 0.8
		_corpse_layer.draw_set_transform(p, 0.0, Vector2(1.0, 0.5))
		_corpse_layer.draw_circle(Vector2.ZERO, 20.0, Color(0.25, 0.05, 0.04, a))
		_corpse_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_corpse_layer.draw_line(p + Vector2(-12, -4), p + Vector2(12, 4), Color(0.85, 0.8, 0.7, a), 4.0)
		_corpse_layer.draw_line(p + Vector2(-12, 4), p + Vector2(12, -4), Color(0.85, 0.8, 0.7, a), 4.0)


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
	hud.show_death()
	await get_tree().create_timer(2.5).timeout
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


func spawn_slash(at: Vector2, angle: float, color: Color) -> void:
	var e := Effect.new()
	e.kind = "slash"
	e.position = at
	e.angle = angle
	e.color = color
	e.life = 0.22
	e.z_index = 5
	_add_effect(e)


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
	e.z_index = -6
	e.z_as_relative = false
	_add_effect(e)


func spawn_beam(from: Vector2, angle: float, length: float, damage: float, color: Color, _owner: Node2D) -> void:
	var dir := Vector2.from_angle(angle)
	for en: Enemy in enemies.duplicate():
		if en.dead:
			continue
		var d := en.position - from
		var along := d.dot(dir)
		if along > 0.0 and along < length and absf(d.dot(dir.orthogonal())) < 34.0:
			en.take_damage(damage, player)
	var pts := PackedVector2Array()
	var steps := 10
	for i in steps + 1:
		var p := dir * length * i / steps + Vector2(0, -32)
		if i > 0 and i < steps:
			p += dir.orthogonal() * randf_range(-14, 14)
		pts.append(p)
	_line_effect("beam", from, pts, color, 0.25)


func chain_lightning(from: Vector2, first: Enemy, jumps: int, radius: float, damage: float, _owner: Node2D) -> void:
	var pts := PackedVector2Array([Vector2(0, -32)])
	var hit := []
	var current := first
	for i in jumps + 1:
		if current == null:
			break
		hit.append(current)
		current.take_damage(damage, player)
		pts.append(current.position - from + Vector2(0, -36))
		var next: Enemy = null
		var best := radius
		for e in enemies_in_radius(current.position, radius):
			if hit.has(e):
				continue
			var d := current.position.distance_to(e.position)
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


func float_text(at: Vector2, text: String, color: Color) -> void:
	var e := Effect.new()
	e.kind = "text"
	e.position = at
	e.text = text
	e.color = color
	e.life = 0.9
	e.z_index = 20
	_add_effect(e)


func toast(text: String) -> void:
	if hud:
		hud.toast(text)


func quit_to_title() -> void:
	if dungeon.active:
		dungeon.leave("동굴 입구로 돌아왔습니다")
	if GameState.save_game():
		quit_requested.emit()

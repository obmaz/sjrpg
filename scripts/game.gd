extends Node2D
## The adventure field (원본: lib/src/game/adventure.dart의 핵심 루프 일부).

signal quit_requested

const WORLD := Rect2(-2400, -2400, 4800, 4800)
const CAMP_RADIUS := 320.0
const TREE_TEXTURE := preload("res://assets/art/world/forest-trees.webp")
const GROUND_TEXTURE := preload("res://assets/art/world/field-ground-meadow.webp")

var world: Node2D
var player: Player
var camera: Camera2D
var hud: Hud
var enemies: Array[Enemy] = []
var corpses: Array = []  # {"pos": Vector2, "time": float, "used": bool}
var _corpse_layer: Node2D
var obstacles: Array = []  # [Vector2 position, float radius]
var _spawn_timer := 0.0
var _save_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	var ground := Sprite2D.new()
	ground.texture = GROUND_TEXTURE
	ground.centered = false
	ground.region_enabled = true
	ground.region_rect = Rect2(Vector2.ZERO, WORLD.size * 2.0)
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	ground.scale = Vector2(0.5, 0.5)
	ground.position = WORLD.position
	ground.z_index = -10
	add_child(ground)

	var camp := Node2D.new()
	camp.z_index = -9
	camp.draw.connect(func():
		camp.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
		camp.draw_circle(Vector2.ZERO, CAMP_RADIUS * 0.75, Color(0.75, 0.62, 0.38, 0.35))
		camp.draw_arc(Vector2.ZERO, CAMP_RADIUS * 0.75, 0, TAU, 64, Color(0.95, 0.85, 0.55, 0.5), 4.0, true))
	add_child(camp)

	_corpse_layer = Node2D.new()
	_corpse_layer.z_index = -8
	_corpse_layer.draw.connect(_draw_corpses)
	add_child(_corpse_layer)

	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	_plant_trees()

	player = Player.new()
	player.setup(self)
	player.died.connect(_on_player_died)
	player.open_skills_requested.connect(func(): hud.open_skill_tree())
	world.add_child(player)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = int(WORLD.position.x)
	camera.limit_top = int(WORLD.position.y)
	camera.limit_right = int(WORLD.end.x)
	camera.limit_bottom = int(WORLD.end.y)
	add_child(camera)
	camera.make_current()

	hud = Hud.new()
	hud.game = self
	add_child(hud)
	_update_zoom()
	get_viewport().size_changed.connect(_update_zoom)
	for i in 6:
		_spawn_enemy()
	toast("%s Lv.%d — 몬스터를 처치하고 성장하세요" % [GameState.class_info()["name"], GameState.level])


func _update_zoom() -> void:
	var size := get_viewport_rect().size
	# Keep characters similarly sized in portrait and landscape.
	var short_side := minf(size.x, size.y)
	var z := clampf(short_side / 620.0, 0.8, 1.6)
	camera.zoom = Vector2(z, z)


func _plant_trees() -> void:
	var placed := 0
	var attempts := 0
	while placed < 170 and attempts < 4000:
		attempts += 1
		var p := Vector2(_rng.randf_range(WORLD.position.x + 60, WORLD.end.x - 60),
			_rng.randf_range(WORLD.position.y + 60, WORLD.end.y - 60))
		if p.length() < CAMP_RADIUS + 80.0:
			continue
		var ok := true
		for o in obstacles:
			if p.distance_to(o[0]) < 150.0:
				ok = false
				break
		if not ok:
			continue
		var index := _rng.randi_range(0, 8)
		var tree := Sprite2D.new()
		tree.texture = TREE_TEXTURE
		tree.region_enabled = true
		tree.region_rect = Rect2((index % 3) * 480, (index / 3) * 480, 480, 480)
		tree.centered = false
		tree.offset = Vector2(-240, -446)
		var s := _rng.randf_range(0.5, 0.68)
		tree.scale = Vector2(s, s)
		tree.flip_h = _rng.randf() < 0.5
		tree.position = p
		world.add_child(tree)
		obstacles.append([p, 26.0 * s / 0.58])
		placed += 1


func _process(delta: float) -> void:
	camera.position = player.position + Vector2(0, -30)
	for c in corpses.duplicate():
		c["time"] -= delta
		if c["time"] <= 0.0:
			corpses.erase(c)
	_corpse_layer.queue_redraw()
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = 2.2
		if enemies.size() < 9 + mini(GameState.level, 10):
			_spawn_enemy()
	_save_timer += delta
	if _save_timer > 15.0:
		_save_timer = 0.0
		GameState.save_game()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skill"):
		player.cast_slot(1)
	elif event.is_action_pressed("potion"):
		player.use_potion()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				hud.toggle_menu()
			KEY_1, KEY_2, KEY_3, KEY_4:
				player.cast_slot(event.keycode - KEY_0)
			KEY_L, KEY_SHIFT:
				player.try_roll()
			KEY_T:
				hud.open_skill_tree()


func _spawn_enemy() -> void:
	for attempt in 20:
		var p := player.position + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(520, 950)
		if not WORLD.grow(-80).has_point(p) or p.length() < CAMP_RADIUS + 120.0:
			continue
		if _blocked(p, Enemy.RADIUS + 10.0):
			continue
		var zone := clampi(int(p.length() / 600.0), 0, 3)
		var pool := ["goblin", "goblin", "wolf"]
		if zone >= 1:
			pool.append_array(["wolf", "boar"])
		if zone >= 2:
			pool.append_array(["boar", "skeleton"])
		if zone >= 3:
			pool.append_array(["skeleton", "skeleton"])
		var enemy := Enemy.new()
		enemy.setup(self, pool[_rng.randi_range(0, pool.size() - 1)], maxi(1, GameState.level - 1 + zone))
		enemy.position = p
		world.add_child(enemy)
		enemies.append(enemy)
		return


func _blocked(p: Vector2, r: float) -> bool:
	for o in obstacles:
		if p.distance_to(o[0]) < o[1] + r:
			return true
	return false


func resolve_movement(from: Vector2, to: Vector2, r: float) -> Vector2:
	var p := to
	for o in obstacles:
		var c: Vector2 = o[0]
		var min_d: float = o[1] + r
		var d := p - c
		if absf(d.x) > min_d or absf(d.y) > min_d:
			continue
		var len := d.length()
		if len < min_d:
			p = c + (d / len if len > 0.001 else (from - c).normalized()) * min_d
	p.x = clampf(p.x, WORLD.position.x + r, WORLD.end.x - r)
	p.y = clampf(p.y, WORLD.position.y + r, WORLD.end.y - r)
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


func enemy_hit_by_point(p: Vector2, r: float) -> Enemy:
	for e in enemies:
		if not e.dead and p.distance_to(e.position) <= r + Enemy.RADIUS:
			return e
	return null


func on_enemy_killed(enemy: Enemy) -> void:
	enemies.erase(enemy)
	GameState.kills += 1
	float_text(enemy.position + Vector2(0, -enemy.sprite.body_height - 40), "+%d XP" % enemy.xp_reward, Color(0.7, 0.85, 1))
	if _rng.randf() < 0.12:
		GameState.potions = mini(GameState.potions + 1, 9)
		toast("물약을 얻었습니다")
	# Corpses feed 물약 발견 · 아이템 발견 · 섬뜩한 수호물.
	if _rng.randf() < 0.3:
		corpses.append({"pos": enemy.position, "time": 30.0, "used": false})
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
		if _blocked(next, r) or not WORLD.grow(-r).has_point(next):
			break
		p = next
	return p


func _on_player_died() -> void:
	hud.show_death()
	await get_tree().create_timer(2.5).timeout
	player.revive(Vector2.ZERO)
	hud.hide_death()
	GameState.save_game()


func _add_effect(e: Effect) -> void:
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
	GameState.save_game()
	quit_requested.emit()

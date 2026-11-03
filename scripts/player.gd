class_name Player
extends Node2D
## Hero controller. 전사: 베기 + 회오리 베기(분노), 마법사: 화염탄 + 얼음 폭발(마나).

signal died

const RADIUS := 18.0

var game: Node
var sprite: ActorSprite
var atlas: ActorAtlas
var attack_atlas: ActorAtlas
var is_mage := false

var hp := 100.0
var max_hp := 100.0
var resource := 0.0
var resource_max := 100.0
var speed := 190.0
var facing := PI / 2.0
var move_input := Vector2.ZERO
var attack_held := false

var _run_distance := 0.0
var _attack_time := 0.0
var _attack_duration := 0.42
var _attack_cooldown := 0.0
var _attack_hit_done := false
var _skill_cooldown := 0.0
var _invulnerable := 0.0
var dead := false


func setup(g: Node) -> void:
	game = g
	var info := GameState.class_info()
	is_mage = GameState.hero_class == "mage"
	atlas = ActorAtlas.get_atlas(info["atlas"])
	attack_atlas = ActorAtlas.get_atlas(info["attack_atlas"])
	speed = info["speed"]
	resource_max = info["resource_max"]
	sprite = ActorSprite.new()
	sprite.body_height = 74.0
	add_child(sprite)
	refresh_stats(true)


func refresh_stats(full := false) -> void:
	max_hp = GameState.max_hp()
	if full:
		hp = max_hp
		resource = resource_max if is_mage else 0.0


func _process(delta: float) -> void:
	if dead:
		return
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_skill_cooldown = maxf(0.0, _skill_cooldown - delta)
	_invulnerable = maxf(0.0, _invulnerable - delta)
	if is_mage:
		resource = minf(resource_max, resource + 7.0 * delta)
	else:
		resource = maxf(0.0, resource - 2.0 * delta)
	hp = minf(max_hp, hp + max_hp * 0.006 * delta)

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move_input.length() > 0.05:
		input = move_input
	if input.length() > 1.0:
		input = input.normalized()

	if Input.is_action_pressed("attack") or attack_held:
		try_attack()

	var attacking := _attack_time > 0.0
	if attacking:
		_attack_time -= delta
		var progress := 1.0 - _attack_time / _attack_duration
		if not _attack_hit_done and progress >= 0.45:
			_attack_hit_done = true
			_resolve_basic_attack()
		sprite.set_frame(attack_atlas, attack_atlas.action_frame(facing, progress))
		# Slow drift while swinging keeps the combat readable.
		position = game.resolve_movement(position, position + input * speed * 0.25 * delta, RADIUS)
		return

	if input.length() > 0.05:
		facing = input.angle()
		var target := position + input * speed * delta
		var moved: Vector2 = game.resolve_movement(position, target, RADIUS)
		_run_distance += moved.distance_to(position)
		position = moved
		var phase := int(_run_distance / 16.0)
		sprite.set_frame(atlas, atlas.run_frame(facing, phase))
	else:
		sprite.set_frame(atlas, atlas.idle_frame(facing))


func _aim_at_nearest(range_limit: float) -> void:
	var target: Node2D = game.nearest_enemy(position, range_limit)
	if target:
		facing = (target.position - position).angle()


func try_attack() -> void:
	if dead or _attack_time > 0.0 or _attack_cooldown > 0.0:
		return
	if is_mage and resource < 4.0:
		return
	_aim_at_nearest(520.0 if is_mage else 160.0)
	_attack_duration = 0.46 if is_mage else 0.4
	_attack_time = _attack_duration
	_attack_cooldown = _attack_duration + 0.05
	_attack_hit_done = false
	if is_mage:
		resource -= 4.0


func _resolve_basic_attack() -> void:
	var power := GameState.attack_power()
	if is_mage:
		var dir := Vector2.from_angle(facing)
		game.spawn_fireball(position + dir * 8.0 + Vector2(0, -34), dir, power * 1.15)
		return
	var hits := 0
	for enemy in game.enemies_in_arc(position, facing, 105.0, deg_to_rad(70)):
		enemy.take_damage(power * randf_range(0.9, 1.1), self)
		hits += 1
	game.spawn_slash(position + Vector2(0, -28), facing, Color(1, 0.92, 0.7))
	if hits > 0:
		resource = minf(resource_max, resource + 7.0 + hits * 3.0)


func try_skill() -> void:
	if dead or _skill_cooldown > 0.0:
		return
	var power := GameState.attack_power()
	if is_mage:
		if resource < 28.0:
			game.toast("마나가 부족합니다")
			return
		resource -= 28.0
		_skill_cooldown = 1.2
		_attack_duration = 0.5
		_attack_time = _attack_duration
		_attack_hit_done = true
		game.spawn_nova(position, 190.0, Color(0.6, 0.85, 1.0))
		for enemy in game.enemies_in_radius(position, 190.0):
			enemy.take_damage(power * 1.8, self)
			enemy.slow(2.5)
	else:
		if resource < 30.0:
			game.toast("분노가 부족합니다")
			return
		resource -= 30.0
		_skill_cooldown = 0.8
		_attack_duration = 0.5
		_attack_time = _attack_duration
		_attack_hit_done = true
		game.spawn_nova(position, 150.0, Color(1.0, 0.78, 0.45))
		for enemy in game.enemies_in_radius(position, 150.0):
			enemy.take_damage(power * 2.1, self)


func use_potion() -> void:
	if dead or GameState.potions <= 0 or hp >= max_hp:
		return
	GameState.potions -= 1
	hp = minf(max_hp, hp + max_hp * 0.45)
	game.float_text(position + Vector2(0, -90), "+%d" % roundi(max_hp * 0.45), Color(0.5, 1, 0.55))


func take_damage(amount: float) -> void:
	if dead or _invulnerable > 0.0:
		return
	var dealt := maxf(1.0, amount - GameState.defense())
	hp -= dealt
	_invulnerable = 0.25
	sprite.flash = 1.0
	if not is_mage:
		resource = minf(resource_max, resource + 4.0)
	game.float_text(position + Vector2(0, -90), str(roundi(dealt)), Color(1, 0.4, 0.35))
	if hp <= 0.0:
		hp = 0.0
		dead = true
		sprite.tint = Color(1, 1, 1, 0.45)
		died.emit()


func revive(at: Vector2) -> void:
	dead = false
	position = at
	sprite.tint = Color.WHITE
	refresh_stats(true)
	_invulnerable = 2.0


func skill_ready_ratio() -> float:
	return 1.0 - clampf(_skill_cooldown / 1.2, 0.0, 1.0)

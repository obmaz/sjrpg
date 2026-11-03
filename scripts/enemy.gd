class_name Enemy
extends Node2D
## Monster AI (원본 enemy_catalog.dart 수치 기반): 추적 → 예고 → 공격 → 회복.

const KINDS := {
	"goblin": {"name": "고블린", "hp": 28.0, "speed": 105.0, "height": 62.0, "damage": 9.0, "xp": 9, "range": 58.0},
	"wolf": {"name": "늑대", "hp": 38.0, "speed": 135.0, "height": 55.0, "damage": 11.0, "xp": 12, "range": 62.0},
	"boar": {"name": "멧돼지", "hp": 46.0, "speed": 145.0, "height": 60.0, "damage": 13.0, "xp": 14, "range": 64.0},
	"skeleton": {"name": "해골 전사", "hp": 52.0, "speed": 105.0, "height": 66.0, "damage": 15.0, "xp": 18, "range": 66.0},
}

const RADIUS := 20.0

var game: Node
var kind := "goblin"
var display_name := ""
var hp := 10.0
var max_hp := 10.0
var speed := 100.0
var damage := 8.0
var xp_reward := 5
var attack_range := 60.0
var sprite: ActorSprite
var atlas: ActorAtlas
var facing := PI / 2.0
var dead := false

var _state := "idle"
var _timer := 0.0
var _walk_cycle := 0.0
var _slow_time := 0.0
var _freeze_time := 0.0
var _stun_time := 0.0
var _fear_time := 0.0
var _fear_from := Vector2.ZERO
var _taunt_time := 0.0
var _cry_time := 0.0
var _cry_value := 0.0
var _knockback := Vector2.ZERO
var _wander := Vector2.ZERO


func setup(g: Node, k: String, level: int) -> void:
	game = g
	kind = k
	var def: Dictionary = KINDS[k]
	display_name = def["name"]
	var scale_factor := 1.0 + (level - 1) * 0.22
	max_hp = def["hp"] * 2.2 * scale_factor
	hp = max_hp
	speed = def["speed"]
	damage = def["damage"] * (1.0 + (level - 1) * 0.15)
	xp_reward = int(def["xp"] * (1.0 + (level - 1) * 0.25))
	attack_range = def["range"]
	atlas = ActorAtlas.get_atlas(k)
	sprite = ActorSprite.new()
	sprite.body_height = def["height"]
	sprite.show_behind_parent = true
	add_child(sprite)
	facing = randf() * TAU
	sprite.set_frame(atlas, atlas.walk_frame(facing, 0.0))


func slow(duration: float) -> void:
	_slow_time = maxf(_slow_time, duration)


func freeze(duration: float) -> void:
	_freeze_time = maxf(_freeze_time, duration)
	_interrupt()


func stun(duration: float) -> void:
	_stun_time = maxf(_stun_time, duration)
	_interrupt()


func fear(duration: float, from: Vector2) -> void:
	_fear_time = maxf(_fear_time, duration)
	_fear_from = from
	_interrupt()


func taunt(duration: float) -> void:
	_taunt_time = maxf(_taunt_time, duration)
	_fear_time = 0.0
	_state = "chase"


func cry(duration: float, value: float) -> void:
	_cry_time = maxf(_cry_time, duration)
	_cry_value = maxf(_cry_value if _cry_time > 0.0 else 0.0, value)


func knock(from: Vector2, strength: float) -> void:
	_knockback = (position - from).normalized() * strength


func _interrupt() -> void:
	if _state == "windup" or _state == "recover":
		_state = "chase"


func _update_tint() -> void:
	if _freeze_time > 0.0:
		sprite.tint = Color(0.55, 0.8, 1.0)
	elif _slow_time > 0.0:
		sprite.tint = Color(0.72, 0.88, 1.0)
	elif _fear_time > 0.0:
		sprite.tint = Color(0.8, 0.7, 1.0)
	elif _cry_time > 0.0:
		sprite.tint = Color(1.0, 0.8, 0.7)
	else:
		sprite.tint = Color.WHITE


func take_damage(amount: float, source: Node2D) -> void:
	if dead:
		return
	if _cry_time > 0.0:
		amount *= 1.0 + _cry_value
	hp -= amount
	sprite.flash = 1.0
	game.float_text(position + Vector2(0, -sprite.body_height - 20), str(roundi(amount)), Color(1, 0.95, 0.6))
	if source and _knockback.length() < 160.0:
		_knockback = (position - source.position).normalized() * 160.0
	if _state == "idle":
		_state = "chase"
	if hp <= 0.0:
		_die()


func _die() -> void:
	dead = true
	game.on_enemy_killed(self)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	if dead:
		return
	var player: Player = game.player
	var rate := 0.5 if _slow_time > 0.0 else 1.0
	_slow_time = maxf(0.0, _slow_time - delta)
	_freeze_time = maxf(0.0, _freeze_time - delta)
	_stun_time = maxf(0.0, _stun_time - delta)
	_fear_time = maxf(0.0, _fear_time - delta)
	_taunt_time = maxf(0.0, _taunt_time - delta)
	_cry_time = maxf(0.0, _cry_time - delta)
	_update_tint()
	if _knockback.length() > 1.0:
		position = game.resolve_movement(position, position + _knockback * delta, RADIUS, true)
		_knockback = _knockback.move_toward(Vector2.ZERO, 900.0 * delta)
	if _freeze_time > 0.0 or _stun_time > 0.0:
		return
	if _fear_time > 0.0:
		_step((position - _fear_from).normalized(), delta * rate)
		return

	var to_player := player.position - position
	var dist := to_player.length()
	match _state:
		"idle":
			_timer -= delta
			if _timer <= 0.0:
				_timer = randf_range(1.5, 3.5)
				_wander = Vector2.from_angle(randf() * TAU) * (0.0 if randf() < 0.4 else 0.4)
			if _wander != Vector2.ZERO:
				_step(_wander, delta * rate)
			else:
				sprite.set_frame(atlas, atlas.walk_frame(facing, 0.0))
			if not player.dead and dist < 340.0:
				_state = "chase"
		"chase":
			if player.dead or (dist > 700.0 and _taunt_time <= 0.0):
				_state = "idle"
			elif dist <= attack_range:
				_state = "windup"
				_timer = 0.55 / rate
				facing = to_player.angle()
			else:
				_step(to_player.normalized() + game.separation(self) * 0.6, delta * rate)
		"windup":
			_timer -= delta
			var progress := 1.0 - _timer / (0.55 / rate)
			sprite.set_frame(atlas, atlas.attack_frame(facing, progress * 0.6))
			if _timer <= 0.0:
				if not player.dead and position.distance_to(player.position) <= attack_range + 22.0:
					var mult := 1.0
					if _taunt_time > 0.0:
						mult *= 0.7
					if _cry_time > 0.0:
						mult *= 0.75
					player.take_damage(damage * mult * randf_range(0.85, 1.15), self)
				_state = "recover"
				_timer = 0.7 / rate
		"recover":
			_timer -= delta
			var progress := 1.0 - _timer / (0.7 / rate)
			sprite.set_frame(atlas, atlas.attack_frame(facing, 0.6 + progress * 0.4))
			if _timer <= 0.0:
				_state = "chase"


func _step(direction: Vector2, delta: float) -> void:
	if direction.length() < 0.01:
		return
	var dir := direction.normalized() * minf(1.0, direction.length())
	facing = dir.angle()
	var target := position + dir * speed * delta
	var moved: Vector2 = game.resolve_movement(position, target, RADIUS, true)
	_walk_cycle += moved.distance_to(position) / 70.0
	position = moved
	sprite.set_frame(atlas, atlas.walk_frame(facing, _walk_cycle))


func _draw() -> void:
	if dead or hp >= max_hp:
		return
	var w := 56.0
	var y := -sprite.body_height - 14.0
	draw_rect(Rect2(-w / 2 - 1, y - 1, w + 2, 8), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-w / 2, y, w * clampf(hp / max_hp, 0, 1), 6), Color(0.85, 0.2, 0.18))


func _physics_process(_delta: float) -> void:
	queue_redraw()

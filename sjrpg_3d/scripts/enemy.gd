class_name Enemy
extends Node2D
## Monster AI (원본 enemy_catalog.dart 수치 기반): 추적 → 예고 → 공격 → 회복.

const KINDS := {
	"goblin": {"name": "고블린", "hp": 28.0, "speed": 105.0, "height": 62.0, "damage": 9.0, "xp": 9, "range": 58.0},
	"wolf": {"name": "늑대", "hp": 38.0, "speed": 135.0, "height": 55.0, "damage": 11.0, "xp": 12, "range": 62.0},
	"boar": {"name": "멧돼지", "hp": 46.0, "speed": 145.0, "height": 60.0, "damage": 13.0, "xp": 14, "range": 64.0},
	"skeleton": {"name": "해골 전사", "hp": 52.0, "speed": 105.0, "height": 66.0, "damage": 15.0, "xp": 18, "range": 66.0},
	# 숲의 파수꾼 (원본: 기본 체력 1800 × 0.8 × 2, 골렘 원화).
	"golem": {"name": "숲의 파수꾼", "hp": 3600.0, "speed": 92.0, "height": 150.0, "damage": 22.0, "xp": 600, "range": 150.0},
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
## 보호 의뢰의 습격자 / 보스.
var is_threat := false
var is_boss := false
var encounter_id := ""
var spawn_level := 1
var encounter_spawn_frame := -1
## Cave enemies idle within their room; zero keeps the field's free roaming behavior.
var patrol_center := Vector2.ZERO
var patrol_radius := 0.0

var _state := "idle"
var _hitstop := GameTempo.ContactStop.new()
## JUICE #1: tier of the most recent confirmed hit (HitTier); presentation only.
var last_hit_tier := HitTier.LIGHT
## JUICE #13: a pale "recent loss" segment trails the health bar, then drains after a short hold.
const TELEGRAPH_COLOR := Color(1.0, 0.82, 0.25)
const GHOST_HOLD := 0.35
const GHOST_DRAIN := 1.2  # fractions of max health per second
var ghost_hp := 0.0
var _ghost_hold := 0.0
var _timer := 0.0
var _windup_duration := 0.55
var _recover_duration := 0.7
var _recover_visual_duration := 0.28
var _walk_cycle := 0.0
var _recoil := Vector2.ZERO
var _recoil_direction := Vector2.ZERO
var _recoil_size := 0.0
var _recoil_age := 1.0
var _recoil_started := false
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
var _boss_attacks := 0


func setup(g: Node, k: String, level: int) -> void:
	game = g
	spawn_level = level
	kind = k
	var def: Dictionary = KINDS[k]
	display_name = def["name"]
	var scale_factor := 1.0 + (level - 1) * 0.22
	max_hp = def["hp"] * 0.8 * scale_factor
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


func force_chase() -> void:
	_state = "chase"


func _ready() -> void:
	SpatialCombat3D.register_actor(game, self, RADIUS, true)


func make_boss() -> void:
	is_boss = true
	max_hp = ForestBalance.BOSS_HP
	hp = max_hp
	damage = ForestBalance.BOSS_DAMAGE
	attack_range = 150.0
	_state = "chase"


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
		queue_redraw()


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


func take_damage(amount: float, source: Node2D, visual_source: Node2D = null) -> void:
	if dead or amount <= 0.0:
		return
	if not encounter_id.is_empty() and encounter_spawn_frame == Engine.get_process_frames():
		return  # A summon cannot be killed by the same resolved contact that created it.
	if _cry_time > 0.0:
		amount *= 1.0 + _cry_value
	ghost_hp = maxf(ghost_hp, hp)  # JUICE #13: remember the health shown before this hit
	_ghost_hold = GHOST_HOLD
	hp -= amount
	queue_redraw()
	# JUICE #1: one tier drives every presentation below; "heavy" keeps its original meaning.
	var tier := HitTier.of(amount, max_hp, hp <= 0.0)
	last_hit_tier = tier
	var heavy := HitTier.is_heavy(tier)
	# Zone ticks have elemental visuals without acquiring direct-hit knockback or weapon effects.
	var impact_source: Node2D = visual_source if is_instance_valid(visual_source) else source
	var impact := Effect.spawn_impact(game, position + Vector2(0, -sprite.body_height * 0.55), impact_source, heavy)
	impact.spatial_floor_height = SpatialCombat3D.floor_at(game, position)
	game.combat_feedback(position, 0.8 if heavy else 0.32, false)
	if is_instance_valid(impact_source) and not Prefs.reduce_motion:
		_recoil_direction = Effect.contact_direction(impact_source, position)
		_recoil_size = HitTier.KILL_RECOIL if tier == HitTier.KILL else (8.0 if heavy else 5.0)  # JUICE #5
		_recoil_age = 0.0
		_recoil_started = false
		_recoil = _recoil_direction * _recoil_size
		sprite.position = _recoil
	_hitstop.trigger(0.055 if heavy else 0.040)
	sprite.hold_contact(0.065 if heavy else 0.045)
	if source is Player:
		source.confirm_melee_contact(heavy, tier == HitTier.KILL)
	if GameState.has_gift("frost") and source != null and source is Player:
		slow(0.67)
	SoundFx.play_hit(tier, Effect.contact_element(impact_source))  # JUICE #11, #12
	Prefs.pulse("hit")
	sprite.trigger_squash(HitTier.squash(tier))  # JUICE #4
	if tier >= HitTier.HEAVY:
		game.zoom_punch(HitTier.zoom_punch(tier), position)  # JUICE #14
	# JUICE #5: a killing blow flashes white and throws off a small burst ring instead of the elemental tint.
	if tier == HitTier.KILL:
		sprite.trigger_flash(Color.WHITE)
		if not Prefs.reduce_motion:
			game.spawn_nova(position, 56.0, Effect.contact_flash_color(impact_source), true)
	else:
		sprite.trigger_flash(Effect.contact_flash_color(impact_source))
	# JUICE #2: size, colour and a scale pop follow the tier.
	game.float_text(position + Vector2(0, -sprite.body_height - 20), HudArt.stat(amount), HitTier.number_color(tier), self, HitTier.number_size(tier), tier >= HitTier.MEDIUM)
	# JUICE #3: heavier hits push further; a stronger skill knockback already in progress is kept.
	var push := HitTier.knockback(tier, is_boss)
	if source and _knockback.length() < push:
		_knockback = (position - source.position).normalized() * push
	if _state == "idle":
		_state = "chase"
	if hp <= 0.0:
		_die()


## JUICE #13: real-time, so a hit-stop does not freeze the trailing segment. Reduced motion shows no trail.
func _update_ghost(delta: float) -> void:
	if ghost_hp <= hp:
		ghost_hp = hp
		return
	if Prefs.reduce_motion:
		ghost_hp = hp
		queue_redraw()
		return
	_ghost_hold = maxf(0.0, _ghost_hold - delta)
	if _ghost_hold <= 0.0:
		ghost_hp = maxf(hp, ghost_hp - max_hp * GHOST_DRAIN * delta)
	queue_redraw()


func _die() -> void:
	if dead:
		return
	dead = true
	_hitstop.clear()
	queue_redraw()
	sprite.clear_contact_hold()
	game.on_enemy_killed(self)
	var tween := create_tween()
	# JUICE #5: a touch longer than before so the white flash and recoil are seen; unchanged for reduced motion.
	tween.tween_property(sprite, "modulate:a", 0.0, HitTier.DEFAULT_FADE if Prefs.reduce_motion else HitTier.KILL_FADE)
	tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	if is_boss and _state == "windup":
		queue_redraw()
	_recoil_age += delta if _recoil_started else minf(delta, 0.012)
	_recoil_started = true
	# A short damped return gives contact weight without changing the actor's collision position.
	_recoil = _recoil_direction * _recoil_size * exp(-18.0 * _recoil_age) * cos(24.0 * _recoil_age) if not Prefs.reduce_motion and _recoil_age < 0.26 else Vector2.ZERO
	sprite.position = _recoil
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
	_update_ghost(delta)
	delta = _hitstop.consume(delta)
	if delta <= 0.0:
		return
	if _knockback.length() > 1.0:
		position = SpatialCombat3D.move_actor(game, self, position + _knockback * delta, RADIUS, true)
		_knockback = _knockback.move_toward(Vector2.ZERO, 900.0 * delta)
	if _freeze_time > 0.0 or _stun_time > 0.0:
		return
	if _fear_time > 0.0:
		_step((position - _fear_from).normalized(), delta * rate)
		return

	var to_player := player.position - position
	var dist := to_player.length()
	# 도발 중에는 영웅을 우선하고, 종료 후 가까운 조사관/영웅을 다시 고릅니다.
	var guard := false
	if is_threat and game.quest_runtime.defender_active():
		var to_def: Vector2 = game.quest_runtime.defender_position() - position
		if player.dead or (_taunt_time <= 0.0 and to_def.length() < dist):
			to_player = to_def
			dist = to_def.length()
			guard = true
	match _state:
		"idle":
			_timer -= delta
			if _timer <= 0.0:
				_timer = GameTempo.duration(randf_range(1.5, 3.5))
				_wander = Vector2.from_angle(randf() * TAU) * (0.0 if randf() < 0.4 else 0.4)
			var wander := _wander
			if patrol_radius > 0.0 and (position + wander * GameTempo.speed(speed) * delta * rate).distance_to(patrol_center) > patrol_radius:
				wander = (patrol_center - position).normalized() * 0.4
			if wander != Vector2.ZERO:
				_step(wander, delta * rate)
			else:
				sprite.set_frame(atlas, atlas.walk_frame(facing, 0.0))
			if not player.dead and dist < 340.0:
				_state = "chase"
		"chase":
			if (player.dead and not guard) or (dist > 700.0 and _taunt_time <= 0.0 and not is_threat):
				_state = "idle"
			elif dist <= attack_range and game.can_melee_reach(position, position + to_player):
				_state = "windup"
				# JUICE #9: ordinary enemies get a brief warning flash so the swing can be read and dodged.
				# Bosses already show their danger ring; the colour differs from hit and hurt flashes.
				if not is_boss:
					sprite.trigger_flash(TELEGRAPH_COLOR, 0.55)
				_windup_duration = GameTempo.duration((1.0 if is_boss else 0.55) / rate)
				_timer = _windup_duration
				if is_boss:
					queue_redraw()
				facing = to_player.angle()
			else:
				_step(to_player.normalized() + game.separation(self) * 0.6, delta * rate)
		"windup":
			_timer -= delta
			var progress := 1.0 - _timer / _windup_duration
			sprite.set_frame(atlas, atlas.attack_frame(facing, progress * 0.6))
			if _timer <= 0.0:
				var mult := 1.0
				if _taunt_time > 0.0:
					mult *= 0.7
				if _cry_time > 0.0:
					mult *= 0.75
				var hit_range := attack_range + (60.0 if is_boss else 22.0)
				if guard:
					if dist <= hit_range and game.can_melee_reach(position, position + to_player):
						game.quest_runtime.damage_defender(damage * mult * randf_range(0.85, 1.15))
				elif not player.dead and attack_distance(player.position) <= hit_range and game.can_melee_reach(position, player.position):
					player.take_damage(damage * mult * randf_range(0.85, 1.15), self)
				if is_boss:
					_boss_attacks += 1
					game.spawn_nova(position, attack_range + 60.0, Color(1.0, 0.6, 0.3))
					SoundFx.play("impact")
					# JUICE #10: the slam lands on the ground even when the hero dodges it.
					game.combat_feedback(position, 1.0)
				_state = "recover"
				_recover_duration = GameTempo.duration((1.2 if is_boss else 0.7) / rate)
				_recover_visual_duration = GameTempo.duration((0.4 if is_boss else 0.28) / rate)
				_timer = _recover_duration
		"recover":
			_timer -= delta
			# Complete the authored return promptly, then hold its neutral last pose.
			# Both clocks use the shared action tempo; bosses retain their longer pause.
			var progress := clampf((_recover_duration - _timer) / _recover_visual_duration, 0.0, 1.0)
			sprite.set_frame(atlas, atlas.attack_frame(facing, 0.6 + progress * 0.4))
			if _timer <= 0.0:
				_state = "chase"


func _step(direction: Vector2, delta: float) -> void:
	if direction.length() < 0.01:
		return
	var dir := direction.normalized() * minf(1.0, direction.length())
	facing = dir.angle()
	var target := position + dir * GameTempo.speed(speed) * delta
	var from := position
	var moved: Vector2 = SpatialCombat3D.move_actor(game, self, target, RADIUS, true)
	_walk_cycle += moved.distance_to(from) / 70.0
	position = moved
	sprite.set_frame(atlas, atlas.walk_frame(facing, _walk_cycle))


## The boss ring is an ellipse on screen; its hit test must use the same shape.
func attack_distance(target: Vector2) -> float:
	var delta := target - position
	if is_boss:
		delta.y /= 0.55
	return delta.length()


func _draw() -> void:
	if is_boss and _state == "windup" and not dead:
		# Danger ring: where the slam will land.
		var t := clampf(1.0 - _timer / _windup_duration, 0.0, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
		draw_circle(Vector2.ZERO, attack_range + 60.0, Color(1, 0.2, 0.1, 0.12 + 0.2 * t))
		draw_arc(Vector2.ZERO, attack_range + 60.0, 0, TAU, 48, Color(1, 0.35, 0.2, 0.9), 4.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if dead or hp >= max_hp:
		return
	var w := 120.0 if is_boss else 56.0
	var y := -sprite.body_height - 14.0
	draw_rect(Rect2(-w / 2 - 1, y - 1, w + 2, 8), Color(0, 0, 0, 0.7))
	if ghost_hp > hp and not Prefs.reduce_motion:
		draw_rect(Rect2(-w / 2, y, w * clampf(ghost_hp / max_hp, 0, 1), 6), Color(1.0, 0.86, 0.72, 0.9))
	draw_rect(Rect2(-w / 2, y, w * clampf(hp / max_hp, 0, 1), 6), Color(0.85, 0.2, 0.18))

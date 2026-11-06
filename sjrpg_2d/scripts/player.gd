class_name Player
extends Node2D
## Hero controller. Every combat skill from the skill tree is cast through `cast_slot`.

signal died
signal open_skills_requested

const RADIUS := 18.0
const ROLL_TIME := 0.32 / GameTempo.RATE
const ROLL_DISTANCE := 170.0

var game: Node
var sprite: ActorSprite
var atlas: ActorAtlas
var attack_atlas: ActorAtlas
var is_mage := false
var impact_color := SkillDefs.STEEL

var hp := 100.0
var max_hp := 100.0
var resource := 0.0
var resource_max := 100.0
var base_speed := 190.0
var facing := PI / 2.0
var move_input := Vector2.ZERO
var move_target := Vector2.ZERO
var has_move_target := false
## Slots held down on touch / keyboard (index 0 = main).
var held_slots := {}

var buffs := {}  # name -> {"time": float, "value": float, ...}
var cooldowns := {}  # skill id -> seconds left
var frenzy_stacks := 0
var dead := false

var _run_distance := 0.0
var _blaze_distance := 0.0
var _storm_timer := 0.0
var _attack_time := 0.0
var _attack_duration := 0.42
var _attack_melee := false
var _resolving_melee_contact := false
var _pending: Callable
var _action_serial := 0
var _release_pending := false
var _release_sound := ""
var _invulnerable := 0.0
var _roll_time := 0.0
var _hitstop := GameTempo.ContactStop.new()
var _roll_dir := Vector2.ZERO
var _roll_cooldown := 0.0
var _frenzy_timer := 0.0


func setup(g: Node) -> void:
	game = g
	var info := GameState.class_info()
	is_mage = GameState.hero_class == "mage"
	atlas = ActorAtlas.get_atlas(info["atlas"])
	attack_atlas = ActorAtlas.get_atlas(info["attack_atlas"])
	base_speed = info["speed"]
	sprite = ActorSprite.new()
	sprite.body_height = 84.0
	add_child(sprite)
	refresh_stats(true)


# ───────────────────────── stats ─────────────────────────

func passive(stat: String) -> float:
	var best := 0.0
	var total := 0.0
	for skill in GameState.skills():
		var d := SkillDefs.get_def(skill["id"])
		if d.get("type") != "passive" or d["stat"] != stat:
			continue
		var r := GameState.effective_rank(skill["id"])
		if r <= 0:
			continue
		var v: float = d["value"] + d["value_growth"] * (r - 1)
		best = maxf(best, v)
		total += v
	# Weapon masteries do not stack: the strongest one applies to the weapon in hand.
	return best if stat == "weapon" else total


func buff_value(name: String) -> float:
	return float(buffs[name]["value"]) if buffs.has(name) else 0.0


func refresh_stats(full := false) -> void:
	var orders := buff_value("orders")
	max_hp = GameState.max_hp() * (1.0 + orders)
	resource_max = GameState.max_resource() * (1.0 + orders)
	if full:
		hp = max_hp
		resource = minf(float(GameState.class_info()["resource_start"]) * (1.0 + buff_value("orders")), resource_max)
	hp = minf(hp, max_hp)
	resource = minf(resource, resource_max)


func defense() -> float:
	if buffs.has("berserk"):
		return 0.0
	var mult := 1.0 + passive("armor") + buff_value("shout") + buff_value("armor") + buff_value("guard")
	return GameState.defense() * mult


func speed() -> float:
	var s := base_speed * (1.0 + passive("speed"))
	s *= 1.0 + buff_value("sprint")
	s *= 1.0 + frenzy_stacks * 0.08
	return GameTempo.speed(s)


func damage_for(id: String, mult: float) -> float:
	var d := SkillDefs.get_def(id)
	var power := GameState.attack_power() * mult
	var element: String = d.get("element", "")
	if element != "":
		power *= 1.0 + passive(element)
	elif d.get("throw", false):
		power *= 1.0 + passive("throw")
	elif not is_mage:
		power *= 1.0 + passive("weapon")
	return power * randf_range(0.9, 1.1)


# ───────────────────────── loop ─────────────────────────

func _process(delta: float) -> void:
	if dead:
		return
	_tick_timers(delta)
	var regen := 7.0 * (1.0 + passive("regen"))
	if is_mage:
		resource = minf(resource_max, resource + regen * delta)
	else:
		resource = maxf(0.0, resource - 2.0 * delta)
	hp = minf(max_hp, hp + max_hp * 0.006 * delta)

	delta = _hitstop.consume(delta)
	if delta <= 0.0:
		return

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move_input.length() > 0.05:
		input = move_input
	if input.length() > 0.05:
		clear_move_target()
	elif has_move_target:
		var direction := move_target - position
		if direction.length() <= 3.0:
			clear_move_target()
		else:
			input = direction.normalized()
	if input.length() > 1.0:
		input = input.normalized()

	if _roll_time > 0.0:
		var roll_delta := minf(delta, _roll_time)
		_roll_time -= roll_delta
		position = game.move_actor(position, position + _roll_dir * ROLL_DISTANCE / ROLL_TIME * roll_delta, RADIUS)
		sprite.set_frame(atlas, atlas.run_frame(facing, int(_roll_time * 40.0)))
		return

	if Input.is_action_pressed("attack"):
		cast_slot(0, true)
	for index in held_slots.keys():
		if held_slots[index]:
			cast_slot(index, true)

	if _attack_time > 0.0:
		_attack_time -= delta
		var progress := 1.0 - _attack_time / _attack_duration
		# Set the actual contact pose before damage callbacks request a presentation hold.
		sprite.set_frame(attack_atlas, attack_atlas.action_frame(facing, progress))
		if _pending.is_valid() and progress >= 0.45:
			var action := _pending
			_pending = Callable()
			_resolving_melee_contact = _attack_melee
			action.call()
			if not dead and not _release_sound.is_empty():
				SoundFx.play(_release_sound)
			_release_sound = ""
			if _release_pending and not dead:
				Effect.spawn_release(game, self, impact_color)
			_release_pending = false
			_resolving_melee_contact = false
		_move(input * speed() * 0.25 * (0.0 if _hitstop.remaining > 0.0 else delta))
		return

	if input.length() > 0.05:
		facing = input.angle()
		var from := position
		_move(input * speed() * delta)
		var step := position.distance_to(from)
		_run_distance += step
		_drop_blaze(step)
		sprite.set_frame(atlas, atlas.run_frame(facing, int(_run_distance / 16.0)))
	else:
		sprite.set_frame(atlas, atlas.idle_frame(facing))


func set_move_target(at: Vector2) -> void:
	if not dead:
		move_target = at
		has_move_target = true


func clear_move_target() -> void:
	has_move_target = false


## Point movement stops at the first obstruction; keyboard/touch retain normal wall sliding.
func _move(offset: Vector2) -> void:
	if has_move_target and offset.length() > 0.0:
		offset = (move_target - position).limit_length(offset.length())
	var desired := position + offset
	position = game.move_actor(position, desired, RADIUS)
	if has_move_target and (position.distance_to(desired) > 0.5 or position.distance_to(move_target) <= 3.0):
		clear_move_target()


func _tick_timers(delta: float) -> void:
	_invulnerable = maxf(0.0, _invulnerable - delta)
	_roll_cooldown = maxf(0.0, _roll_cooldown - delta)
	for id in cooldowns.keys():
		cooldowns[id] = maxf(0.0, cooldowns[id] - delta)
	var expired := []
	for name in buffs:
		buffs[name]["time"] -= delta
		if buffs[name]["time"] <= 0.0:
			expired.append(name)
	for name in expired:
		buffs.erase(name)
		if name == "orders":
			refresh_stats()
		elif name == "command":
			GameState.bonus_ranks = 0
	if frenzy_stacks > 0:
		_frenzy_timer -= delta
		if _frenzy_timer <= 0.0:
			frenzy_stacks = 0
	if buffs.has("storm"):
		_storm_timer -= delta
		if _storm_timer <= 0.0:
			_storm_timer = 1.6
			var target: Enemy = game.nearest_enemy(position, 320.0)
			if target:
				var d := SkillDefs.get_def("thunderStorm")
				target.take_damage(damage_for("thunderStorm", SkillDefs.scaled(d["mult"], d["growth"], int(buffs["storm"]["rank"]))), self)
				game.spawn_bolt_strike(target.position)


func _drop_blaze(step: float) -> void:
	if not buffs.has("blaze"):
		return
	_blaze_distance += step
	if _blaze_distance >= 38.0:
		_blaze_distance = 0.0
		var d := SkillDefs.get_def("blaze")
		game.spawn_zone({"pos": position, "radius": 34.0, "duration": 3.0, "tick": 0.3,
			"damage": damage_for("blaze", SkillDefs.scaled(d["mult"], d["growth"], int(buffs["blaze"]["rank"]))),
			"color": SkillDefs.FIRE})


# ───────────────────────── casting ─────────────────────────

func slot_cooldown_ratio(index: int) -> float:
	var id: String = GameState.slots[index]
	if id == "":
		return 1.0
	var total := SkillDefs.cooldown(GameState.skill(id))
	if total <= 0.0:
		return 1.0
	return 1.0 - clampf(cooldowns.get(id, 0.0) / total, 0.0, 1.0)


## Returns true when the skill was cast. `repeat` is set for held buttons.
func cast_slot(index: int, repeat := false) -> bool:
	if dead or _roll_time > 0.0:
		return false
	var id: String = GameState.slots[index]
	if id == "":
		if not repeat:
			open_skills_requested.emit()
		return false
	var s := GameState.skill(id)
	var d := SkillDefs.get_def(id)
	var rank := GameState.effective_rank(id)
	if rank <= 0 or d.is_empty():
		return false
	# Held buttons only repeat attacks, never buffs or movement.
	if repeat and d["type"] in ["buff", "leap", "blink", "corpse"]:
		return false
	if _attack_time > 0.0 or cooldowns.get(id, 0.0) > 0.0:
		# The skill button already shows readiness; repeated taps must not queue notices.
		return false
	var cost := SkillDefs.cost(s, rank)
	if resource < cost:
		if not repeat:
			game.toast("%s이(가) 부족합니다" % GameState.class_info()["resource"])
		return false
	var action := _prepare(id, d, rank)
	if not action.is_valid():
		return false
	resource -= cost
	var reuse := SkillDefs.cooldown(s)
	if reuse > 0.0:
		cooldowns[id] = reuse
	_attack_melee = d["type"] in ["melee", "spin", "shadow"]
	_attack_duration = GameTempo.duration((0.4 if _attack_melee else 0.46) / (1.0 + frenzy_stacks * 0.08))
	if id in ["cleave", "sorceressAttack"]:
		_attack_duration = float(weapon_melee()["tempo"])
	_attack_time = _attack_duration
	_pending = action
	_action_serial += 1
	_release_pending = is_mage and d["type"] in ["proj", "orb", "beam", "cone"]
	_cast_feedback(d)
	return true


func _cast_feedback(d: Dictionary) -> void:
	if is_mage and str(d.get("element", "")) in ["fire", "cold", "lightning"] and d["type"] != "melee":
		Effect.spawn_cast(game, self, d.get("color", SkillDefs.LIGHT))
	var sound := "slash"
	match str(d.get("element", "")):
		"fire":
			sound = "fire"
		"cold":
			sound = "ice"
		"lightning":
			sound = "lightning"
		_:
			if d["type"] in ["buff", "corpse"] or d.has("cry") or d.has("fear") or d.has("taunt") or (d["type"] == "nova" and d.has("stun")):
				sound = "warcry"
			elif d["type"] == "blink":
				sound = "dodge"
	if is_mage and str(d.get("element", "")) in ["fire", "cold", "lightning"]:
		_release_sound = sound
		SoundFx.play("prepare")
	else:
		_release_sound = ""
		SoundFx.play(sound)
	Prefs.pulse("skill")


func try_roll() -> void:
	if dead or _roll_time > 0.0 or _roll_cooldown > 0.0:
		return
	var dir := move_input if move_input.length() > 0.1 else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir.length() < 0.1:
		dir = Vector2.from_angle(facing)
	_action_serial += 1
	_release_pending = false
	_release_sound = ""
	_hitstop.clear()
	Effect.spawn_dodge_echo(game, self)
	_roll_dir = dir.normalized()
	facing = _roll_dir.angle()
	_roll_time = ROLL_TIME
	sprite.clear_contact_hold()
	SoundFx.play("dodge")
	Prefs.pulse("dodge")
	_roll_cooldown = GameTempo.duration(0.9)
	_invulnerable = ROLL_TIME + GameTempo.duration(0.05)
	_attack_time = 0.0
	_pending = Callable()


## Only the current contact callback may hold the swing; passive/reflected damage also names this player.
func confirm_melee_contact(heavy: bool) -> void:
	if not dead and _resolving_melee_contact:
		_hitstop.trigger(0.050 if heavy else 0.035)
		sprite.hold_contact(0.060 if heavy else 0.040)


func _aim(range_limit: float) -> Enemy:
	var target: Enemy = game.nearest_enemy(position, range_limit)
	if target:
		facing = (target.position - position).angle()
	else:
		var prop: Node2D = game.nearest_attackable_prop(position, range_limit)
		if prop != null:
			facing = (prop.position - position).angle()
	return target


func _gain_rage(hits: int) -> void:
	if not is_mage and hits > 0:
		resource = minf(resource_max, resource + 5.0 + hits * 3.0)


## Builds the effect that fires at the swing's impact frame.
func _prepare(id: String, d: Dictionary, rank: int) -> Callable:
	impact_color = d.get("color", SkillDefs.STEEL)
	var power := SkillDefs.scaled(d.get("mult", 1.0), d.get("growth", 0.0), rank)
	match d["type"]:
		"melee":
			_aim(170.0 if id != "cleave" else float(weapon_melee()["range"]) + 60.0)
			return func(): _melee(id, d, rank, power)
		"spin":
			return func(): _spin(id, d, power)
		"shadow":
			if _aim(d["range"]) == null:
				game.toast("가까운 적이 없습니다")
				return Callable()
			return func(): _shadow(id, d, power)
		"leap":
			return _prepare_leap(id, d, rank, power)
		"blink":
			var dist: float = d["distance"] + d["dist_growth"] * (rank - 1)
			var dir := move_input if move_input.length() > 0.1 else Input.get_vector("move_left", "move_right", "move_up", "move_down")
			if dir.length() > 0.1:
				facing = dir.angle()
			return func():
				var from := position
				position = game.find_open_point(position, Vector2.from_angle(facing), dist, RADIUS)
				game.spawn_nova(from, 50.0, SkillDefs.LIGHT, true)
				game.spawn_nova(position, 60.0, SkillDefs.LIGHT, true)
		"proj":
			_aim(560.0)
			return func(): _projectiles(id, d, rank, power)
		"orb":
			_aim(560.0)
			return func():
				game.spawn_orb(position + Vector2(0, -34), Vector2.from_angle(facing), d, damage_for(id, power), self)
		"beam":
			_aim(600.0)
			return func():
				var lo := SkillDefs.scaled(d["mult_min"], d["growth"], rank)
				var hi := SkillDefs.scaled(d["mult_max"], d["growth"], rank)
				game.spawn_beam(position, facing, d["length"], damage_for(id, randf_range(lo, hi)), d["color"], self)
		"chain":
			var first := _aim(d["range"])
			if first == null:
				var stone: EncounterStone = game.nearest_ready_stone(position, d["range"])
				if stone != null:
					var stone_ref: WeakRef = weakref(stone)
					return func():
						var contact := stone_ref.get_ref() as EncounterStone
						if is_instance_valid(contact) and position.distance_to(contact.position) <= float(d["range"]):
							var travel: Vector2 = contact.position - position
							game.spawn_beam(position, travel.angle(), travel.length() + 35.0, damage_for(id, power), d["color"], self)
				game.toast("사거리 안에 적이 없습니다")
				return Callable()
			# Capture a WeakRef, not the Enemy: the VM validates strong lambda captures before entering the body.
			var anchor: WeakRef = weakref(first)
			return func():
				var jumps := int(d["jumps"] + d["jump_growth"] * (rank - 1))
				var captured_target: Enemy = anchor.get_ref() as Enemy
				var target: Enemy
				if is_instance_valid(captured_target) and not captured_target.dead and position.distance_to(captured_target.position) <= float(d["range"]):
					target = captured_target
				else:
					target = game.nearest_enemy(position, d["range"])
				if target != null:
					game.chain_lightning(position, target, jumps, d["radius"], damage_for(id, power), self)
		"cone":
			_aim(d["range"] + 40.0)
			return func():
				var hits: Array = game.enemies_in_arc(position, facing, d["range"], deg_to_rad(d["arc"]))
				game.break_chests_in_arc(position, facing, d["range"], deg_to_rad(d["arc"]), self)
				for e in hits:
					e.take_damage(damage_for(id, power), self)
				game.spawn_cone(position + Vector2(0, -30), facing, d["range"], d["color"])
		"nova":
			return func(): _nova(id, d, rank, power)
		"zone":
			var target := _aim(480.0)
			var at := target.position if target else position + Vector2.from_angle(facing) * 200.0
			return func(): _zone(id, d, rank, power, at)
		"summon":
			return func():
				var dur: float = d["duration"]
				game.spawn_hydra(position + Vector2.from_angle(facing) * 60.0, dur, d["rate"], d["range"], damage_for(id, power), self)
		"buff":
			return func(): _buff(id, d, rank)
		"corpse":
			var corpse = game.nearest_corpse(position, 170.0)
			if corpse == null:
				game.toast("가까운 시체가 없습니다")
				return Callable()
			return func(): _corpse(d, rank, corpse)
	return Callable()


## 착용 무기의 사거리 · 타격 호 · 공격 간격 (원본 GearDef.range / meleeHalfAngle / tempo).
func weapon_melee() -> Dictionary:
	var weapon: Gear = GameState.equipped.get("weapon")
	return weapon.melee_profile(frenzy_stacks) if weapon != null else {"range": 68.0, "arc": 1.25, "tempo": GameTempo.duration(0.4)}


func _melee(id: String, d: Dictionary, rank: int, power: float) -> void:
	if id in ["cleave", "sorceressAttack"]:
		var wm := weapon_melee()
		d = d.duplicate()
		d["range"] = wm["range"]
		d["arc"] = rad_to_deg(wm["arc"])
	var hits_total := 0
	var swings := int(d.get("hits", 1))
	var enchant := buff_value("enchant") if id == "sorceressAttack" else 0.0
	for swing in swings:
		var hits: Array = game.enemies_in_arc(position, facing, d["range"], deg_to_rad(d["arc"]), true)
		for e in hits:
			e.take_damage(damage_for(id, power) * (1.0 + enchant), self)
			if d.has("knock"):
				e.knock(position, d["knock"])
			if d.has("stun"):
				e.stun(d["stun"] + d.get("stun_growth", 0.0) * (rank - 1))
		hits_total += hits.size()
		game.break_chests_in_arc(position, facing, d["range"], deg_to_rad(d["arc"]), self, true)
		game.spawn_slash(position + Vector2(0, -28), facing + (0.25 if swing == 1 else 0.0), SkillDefs.FIRE if enchant > 0.0 else SkillDefs.STEEL, float(d["range"]), deg_to_rad(d["arc"]))
	_gain_rage(hits_total)
	if d.get("frenzy", false) and hits_total > 0:
		frenzy_stacks = mini(frenzy_stacks + 1, 5)
		_frenzy_timer = 3.0
	if d.has("self_buff"):
		buffs[d["self_buff"]] = {"time": d["buff_time"], "value": d["buff_value"]}


func _spin(id: String, d: Dictionary, power: float) -> void:
	var ticks := int(d["ticks"])
	var serial := _action_serial
	game.spawn_reference_fx("spin", position, float(d["radius"]), self, (ticks - 1) * 0.12 + 0.22)
	for i in ticks:
		get_tree().create_timer(i * 0.12, false).timeout.connect(func():
			if dead or serial != _action_serial:
				return
			_resolving_melee_contact = true
			var hits: Array = game.enemies_in_radius(position, d["radius"], true)
			game.break_chests_in_radius(position, d["radius"], self, true)
			for e in hits:
				e.take_damage(damage_for(id, power), self)
			_resolving_melee_contact = false
			_gain_rage(hits.size()))


func _shadow(id: String, d: Dictionary, power: float) -> void:
	var visited := []
	var contacts := 0
	for i in int(d["targets"]):
		var next: Enemy = null
		var best: float = d["range"]
		for e in game.enemies_in_radius(position, d["range"]):
			if not game.can_melee_reach(position, e.position):
				continue
			if visited.has(e):
				continue
			var dist := position.distance_to(e.position)
			if dist < best:
				best = dist
				next = e
		if next == null:
			break
		visited.append(next)
		var from := position
		position = game.find_open_point(position, (next.position - position).normalized(), maxf(0.0, best - 40.0), RADIUS)
		facing = (next.position - position).angle()
		game.spawn_trail(from, position, Color(0.6, 0.7, 1.0))
		if game.can_melee_reach(position, next.position):
			next.take_damage(damage_for(id, power), self)
			contacts += 1
		game.spawn_slash(position + Vector2(0, -28), facing, Color(0.7, 0.8, 1.0))
	_gain_rage(contacts)
	if contacts >= 3:
		if GameState.has_gift("comboFury"):
			resource = minf(resource_max, resource + 6.0)
			game.float_text(position + Vector2(0, -100), "연격의 격정", Color(1, 0.7, 0.4))
		if GameState.has_gift("comboGuard"):
			buffs["combo_guard"] = {"time": 0.75, "value": 0.25}
			game.float_text(position + Vector2(0, -100), "연격의 수호", Color(0.6, 0.8, 1))


func _prepare_leap(id: String, d: Dictionary, rank: int, power: float) -> Callable:
	var dist: float = d["distance"] + d.get("dist_growth", 0.0) * (rank - 1)
	var target: Enemy = null
	if d.get("to_enemy", false):
		target = _aim(dist)
		if target == null:
			game.toast("도약할 적이 없습니다")
			return Callable()
	else:
		var dir := move_input if move_input.length() > 0.1 else Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if dir.length() > 0.1:
			facing = dir.angle()
	var anchor: WeakRef = weakref(target) if target != null else null
	return func():
		var current: Enemy = anchor.get_ref() as Enemy if anchor != null else null
		if d.get("to_enemy", false) and (not is_instance_valid(current) or current.dead):
			return
		var from := position
		var reach := dist
		if is_instance_valid(current):
			reach = minf(dist, maxf(0.0, position.distance_to(current.position) - 36.0))
		position = game.find_open_point(position, Vector2.from_angle(facing), reach, RADIUS)
		game.spawn_trail(from, position, SkillDefs.STEEL)
		if id == "leapAttack":
			game.spawn_reference_fx("slam", position, float(d["radius"]), self)
		else:
			game.spawn_nova(position, d["radius"], SkillDefs.STEEL, true)
		_invulnerable = maxf(_invulnerable, 0.2)
		var hits: Array = game.enemies_in_radius(position, d["radius"], true)
		if d.has("mult"):
			game.break_chests_in_radius(position, d["radius"], self, true)
		var previous_contact := _resolving_melee_contact
		_resolving_melee_contact = d.has("mult")
		for e in hits:
			if d.has("mult"):
				e.take_damage(damage_for(id, power), self)
			if d.has("knock"):
				e.knock(position, d["knock"])
		_resolving_melee_contact = previous_contact
		_gain_rage(hits.size())


func _projectiles(id: String, d: Dictionary, rank: int, power: float) -> void:
	var count := mini(int(d.get("count", 1) + d.get("count_growth", 0.0) * (rank - 1)), int(d.get("max_count", 99)))
	var spread := deg_to_rad(d.get("spread", 0.0))
	for i in count:
		var offset := 0.0 if count == 1 else lerpf(-spread / 2.0, spread / 2.0, float(i) / (count - 1))
		var dir := Vector2.from_angle(facing + offset)
		game.spawn_projectile({
			"pos": position + dir * 8.0 + Vector2(0, -34), "dir": dir, "speed": d["speed"],
			"damage": damage_for(id, power), "color": d["color"], "explode": d.get("explode", 0.0),
			"slow": d.get("slow", 0.0), "freeze": d.get("freeze", 0.0) + d.get("freeze_growth", 0.0) * (rank - 1),
			"knock": d.get("knock", 0.0), "wiggle": d.get("wiggle", false), "throw": d.get("throw", false),
			"visual": "bolt" if id in ["iceBolt", "iceBlast", "glacialSpike", "chargedBolt"] else "",
		}, self)


func _nova(id: String, d: Dictionary, rank: int, power: float) -> void:
	var radius: float = d["radius"] + d.get("radius_growth", 0.0) * (rank - 1)
	if id == "frostNova":
		game.spawn_reference_fx("frost", position, radius, self, 0.5)
	else:
		game.spawn_nova(position, radius, d["color"])
	if d.has("mult") or d.has("pct"):
		game.break_chests_in_radius(position, radius, self)
	var hits: Array = game.enemies_in_radius(position, radius)
	for e in hits:
		if d.has("mult"):
			e.take_damage(damage_for(id, power), self)
		if d.has("pct"):
			e.take_damage(maxf(1.0, e.hp * d["pct"]), self)
		if d.has("slow"):
			e.slow(d["slow"])
		if d.has("stun"):
			e.stun(d["stun"])
		if d.has("fear"):
			e.fear(d["fear"] + d.get("fear_growth", 0.0) * (rank - 1), position)
		if d.has("taunt"):
			e.taunt(d["taunt"])
		if d.has("cry"):
			e.cry(d["cry"], d["cry_value"] + d["cry_growth"] * (rank - 1))
	if d.has("mult"):
		_gain_rage(hits.size())


func _zone(id: String, d: Dictionary, rank: int, power: float, at: Vector2) -> void:
	var z := {"pos": at, "radius": d["radius"], "duration": d["duration"], "tick": d["tick"],
		"damage": damage_for(id, power), "color": d["color"], "slow": d.get("slow", 0.0),
		"shards": d.get("shards", false), "delay": d.get("delay", 0.0), "visual": "meteor" if id == "meteor" else ""}
	if d.has("impact"):
		z["impact"] = damage_for(id, SkillDefs.scaled(d["impact"], d["growth"], rank))
		z["damage"] = damage_for(id, d["mult"])
	if d.get("wall", false):
		z["wall"] = facing + PI / 2.0
	game.spawn_zone(z)


func _buff(id: String, d: Dictionary, rank: int) -> void:
	var dur: float = d["duration"] + d.get("dur_growth", 0.0) * (rank - 1)
	var v: float = d.get("value", 0.0) + d.get("value_growth", 0.0) * (rank - 1)
	var name: String = d["buff"]
	if name == "sprint":
		dur *= 1.0 + passive("stamina")
	buffs[name] = {"time": dur, "value": v, "rank": rank, "id": id}
	if name == "armor":
		buffs[name]["kind"] = d["armor"]
	var color := SkillDefs.SHOUT if not is_mage else SkillDefs.COLD
	match name:
		"orders":
			var hp_ratio := hp / max_hp
			refresh_stats()
			hp = max_hp * hp_ratio
		"command":
			GameState.bonus_ranks = 1
		"storm":
			_storm_timer = 0.3
			color = SkillDefs.LIGHT
		"blaze", "enchant":
			color = SkillDefs.FIRE
		"shield":
			color = Color(0.7, 0.6, 1.0)
	game.spawn_nova(position, 90.0, color, true)
	game.toast(GameState.skill(id)["name"])


func _corpse(d: Dictionary, rank: int, corpse: Dictionary) -> void:
	if not game.corpse_available(corpse):
		return
	corpse["used"] = true
	var chance: float = minf(d.get("chance", 1.0) + d.get("chance_growth", 0.0) * (rank - 1), float(d.get("chance_cap", 1.0)))
	match d["reward"]:
		"potion":
			if randf() < chance:
				if randf() < 0.5:
					GameState.potions += 1
					game.float_text(corpse["pos"] + Vector2(0, -30), "탐색 성공\n생명 물약 +1", Color(0.62, 0.85, 0.69))
				else:
					GameState.mana_potions += 1
					game.float_text(corpse["pos"] + Vector2(0, -30), "탐색 성공\n%s 물약 +1" % GameState.class_info()["resource"], Color(0.6, 0.79, 0.93))
			else:
				game.float_text(corpse["pos"] + Vector2(0, -30), "아무것도 없음", Color(0.8, 0.8, 0.8))
		"item":
			if randf() < chance:
				var bonus := 6 + GameState.level * 3
				game.grant_xp(bonus)
				game.float_text(corpse["pos"] + Vector2(0, -30), "탐색 성공\n전리품 +%d XP" % bonus, Color(0.91, 0.78, 0.49))
			else:
				game.float_text(corpse["pos"] + Vector2(0, -30), "아무것도 없음", Color(0.8, 0.8, 0.8))
		"ward":
			game.spawn_ward(corpse["pos"], d["duration"] + d["dur_growth"] * (rank - 1), d["radius"])
	game.remove_corpse(corpse)


## 치유 물약: flat +55 (원본 CombatBalance.potionHealing), shown ×100.
func use_potion() -> void:
	if dead or GameState.potions <= 0 or hp >= max_hp:
		return
	var restored := minf(55.0, max_hp - hp)
	GameState.potions -= 1
	hp = minf(max_hp, hp + 55.0)
	game.float_text(position + Vector2(0, -80), "+%s 생명" % HudArt.stat(restored), Color(1.0, 0.71, 0.63))


## 마나/분노 물약: flat +60 (원본 potionEnergy), shown ×10.
func use_mana_potion() -> void:
	if dead or GameState.mana_potions <= 0 or resource >= resource_max:
		return
	var restored := minf(60.0, resource_max - resource)
	GameState.mana_potions -= 1
	resource = minf(resource_max, resource + 60.0)
	game.float_text(position + Vector2(0, -80), "+%s %s" % [HudArt.res(restored), GameState.class_info()["resource"]], Color(0.62, 0.87, 1.0))


func take_damage(amount: float, attacker: Node2D = null) -> void:
	if dead or _invulnerable > 0.0:
		return
	var armor := defense()
	var dealt := maxf(1.0, amount * (1.0 - armor / (armor + 30.0))) * (1.0 - minf(0.5, passive("resist")))
	if GameState.has_gift("guardian"):
		dealt *= 0.92
	if buffs.has("combo_guard"):
		dealt *= 0.75
	if buffs.has("shield") and resource > 0.0:
		var absorbed := minf(dealt * buff_value("shield"), resource / 1.5)
		resource -= absorbed * 1.5
		dealt -= absorbed
	hp -= dealt
	if dealt > 0.0:
		_hitstop.trigger(0.035)
		Effect.spawn_impact(game, position + Vector2(0, -sprite.body_height * 0.55), attacker, dealt >= max_hp * 0.15)
		game.combat_feedback(position, clampf(0.4 + dealt / max_hp, 0.4, 1.0), true)
	SoundFx.play("hurt")
	Prefs.pulse("hurt")
	_invulnerable = 0.25
	sprite.trigger_flash(Color(1.0, 0.45, 0.4))
	if not is_mage:
		resource = minf(resource_max, resource + 4.0)
	game.float_text(position + Vector2(0, -90), HudArt.stat(dealt), Color(1, 0.4, 0.35))
	if attacker and is_instance_valid(attacker) and buffs.has("armor"):
		_armor_retaliate(attacker)
	if hp <= 0.0:
		hp = 0.0
		dead = true
		_cancel_actions()
		buffs.clear()
		GameState.bonus_ranks = 0
		sprite.tint = Color(1, 1, 1, 0.45)
		died.emit()


func _armor_retaliate(attacker: Node2D) -> void:
	var b: Dictionary = buffs["armor"]
	var rank := int(b["rank"])
	match b["kind"]:
		"frozen":
			attacker.freeze(1.0 + 0.05 * rank)
		"shiver":
			attacker.take_damage(GameState.attack_power() * (0.6 + 0.06 * rank) * (1.0 + passive("cold")), self)
			attacker.slow(2.0)
		"chilling":
			var dir := (attacker.position - position).normalized()
			game.spawn_projectile({"pos": position + Vector2(0, -34), "dir": dir, "speed": 600.0,
				"damage": GameState.attack_power() * (0.7 + 0.07 * rank) * (1.0 + passive("cold")),
				"color": SkillDefs.COLD, "slow": 2.0}, self)


## Death and resurrection cannot preserve a delayed skill target or old movement input.
func _cancel_actions() -> void:
	_hitstop.clear()
	_action_serial += 1
	_pending = Callable()
	_attack_time = 0.0
	_attack_melee = false
	_resolving_melee_contact = false
	_release_pending = false
	_release_sound = ""
	_roll_time = 0.0
	_roll_dir = Vector2.ZERO
	held_slots.clear()
	move_input = Vector2.ZERO
	clear_move_target()
	sprite.clear_contact_hold()


func revive(at: Vector2) -> void:
	_cancel_actions()
	sprite.clear_flash()
	dead = false
	sprite.clear_contact_hold()
	position = at
	sprite.tint = Color.WHITE
	frenzy_stacks = 0
	cooldowns.clear()
	refresh_stats(true)
	resource = resource_max
	_invulnerable = 3.0

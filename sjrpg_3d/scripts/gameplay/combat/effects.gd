class_name Effect
extends Node2D
## Drawn combat effects. Kinds: slash, nova, proj, zone, orb, beam, chain, cone,
## trail, strike, hydra, ward, text.

const GROUND_Y := 0.577350269
const GROUP := "world_effects"

var kind := ""
var color := Color.WHITE
var life := 0.4
var age := 0.0
var angle := 0.0
var radius := 100.0
var velocity := Vector2.ZERO
var damage := 0.0
var game: Node
var owner_node: Node2D
var text := ""
## JUICE #2: damage numbers scale with the hit tier. 22 is the original size every other text keeps.
var font_size := 22
var pop := false
var points: PackedVector2Array = PackedVector2Array()
var params := {}
## Native trajectory centre/floor, in metres. INF means the backend was not available.
var spatial_height := INF
var spatial_floor_height := INF

var _impact_started := false
var _tick_timer := 0.0
var _hit := {}  # enemies already hit (piercing)
var _text_target: WeakRef
var _text_target_id := 0
var _text_offset := Vector2.ZERO
var _text_anchor := Vector2.ZERO
var _text_rise := 0.0
var _text_ground := Vector2.INF
const TEXT_STREAM_GAP := 4.0
const TEXT_STREAM_MAX_RISE := 240.0
const TEXT_STAGGER_SECONDS := 0.04
const TEXT_STAGGER_MAX := 0.20


## Monster damage uses its own vertical stream; rewards retain nearby free placement.
## Every amount stays individual, and all text shares the existing 64-effect budget.
func place_text(peers: Array, damage_target: Node2D = null) -> void:
	var anchor := position
	var lines := text.split("\n")
	var width := 0.0
	for line in lines:
		width = maxf(width, UiKit.BOLD_FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	params["text_size"] = Vector2(width, UiKit.BOLD_FONT.get_height(font_size) * lines.size())
	if is_instance_valid(damage_target):
		_text_target = weakref(damage_target)
		_text_target_id = damage_target.get_instance_id()
		_text_offset = position - damage_target.position
		_text_anchor = position
		_stagger_damage_text(peers, damage_target.get_parent())
		_place_damage_stream(peers)
		return
	var offsets := [Vector2.ZERO, Vector2(-96, 0), Vector2(96, 0),
		Vector2(0, -40), Vector2(-96, -40), Vector2(96, -40),
		Vector2(0, -80), Vector2(-96, -80), Vector2(96, -80)]
	for offset: Vector2 in offsets:
		position = anchor + offset
		var occupied := false
		for peer in peers:
			if is_instance_valid(peer) and not peer.is_queued_for_deletion() and peer.kind == "text" and text_bounds().intersects(peer.text_bounds()):
				occupied = true
				break
		if not occupied:
			return
	position = anchor
	for peer in peers:
		if is_instance_valid(peer) and not peer.is_queued_for_deletion() and peer.kind == "text" and text_bounds().intersects(peer.text_bounds()):
			peer.queue_free()


## 피해는 즉시 처리한다. 음수 나이는 숫자 표시만 늦추고 일시정지도 함께 따른다.
## 밀집 타격은 대기 중인 숫자의 간격만 압축해 마지막 숫자가 한꺼번에 몰리지 않게 한다.
func _stagger_damage_text(peers: Array, scope: Node) -> void:
	var delay := 0.0
	var first_gap := 0.0
	var waiting: Array[Effect] = []
	for peer in peers:
		if not is_instance_valid(peer) or peer.is_queued_for_deletion() or peer.kind != "text" or peer._text_target_id == 0 or peer.get_parent() != scope:
			continue
		delay = maxf(delay, TEXT_STAGGER_SECONDS - peer.age)
		if peer.age < 0.0:
			waiting.append(peer)
		else:
			first_gap = maxf(first_gap, TEXT_STAGGER_SECONDS - peer.age)
	if delay <= TEXT_STAGGER_MAX + 0.000001:
		age = -minf(delay, TEXT_STAGGER_MAX)
		return
	waiting.append(self)
	for index in waiting.size():
		var scheduled := -lerpf(first_gap, TEXT_STAGGER_MAX, float(index) / (waiting.size() - 1))
		# 후속 타격은 앞선 숫자를 앞당길 수만 있다. 이미 기다린 시간을 다시 늘리지 않는다.
		waiting[index].age = scheduled if waiting[index] == self else maxf(waiting[index].age, scheduled)


## Newest hit stays by the target; preceding hits move up in their original order.
## Push only when needed for the actual outlined font height, then retire the oldest
## rows at a fixed height rather than growing a tower during dense multi-hit attacks.
func _place_damage_stream(peers: Array) -> void:
	var below: Effect = self
	for index in range(peers.size() - 1, -1, -1):
		var peer = peers[index]
		if not is_instance_valid(peer) or peer.is_queued_for_deletion() or peer.kind != "text" or peer._text_target_id != _text_target_id:
			continue
		peer._sync_text_position()
		var needed: float = peer.text_bounds().end.y - below.text_bounds().position.y + TEXT_STREAM_GAP
		peer._text_rise += maxf(0.0, needed)
		if peer._text_rise > TEXT_STREAM_MAX_RISE:
			peer.queue_free()
			continue
		peer._sync_text_position()
		below = peer


## Weak targets never keep a dying monster alive. Its last anchor survives removal.
func has_actor_text_anchor() -> bool:
	return _text_target_id != 0


## 보상/회복은 기존 자유 배치와 즉시 표시를 유지하며 생성 당시의 바닥만 별도로 보존한다.
func anchor_text_ground(point: Vector2) -> Effect:
	_text_ground = point
	return self


func has_text_ground_anchor() -> bool:
	return has_actor_text_anchor() or _text_ground.is_finite()


## 대상 제거 뒤에도 마지막 접점을 보존한다. 화면 위 여백을 다른 바닥 좌표로 읽지 않는다.
func text_ground_point() -> Vector2:
	if has_actor_text_anchor():
		return _text_anchor - _text_offset
	return _text_ground if _text_ground.is_finite() else position


func text_actor() -> Node2D:
	if _text_target == null:
		return null
	var actor := _text_target.get_ref() as Node2D
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor.get_parent() != get_parent():
		return null
	return null if actor is Enemy and actor.dead else actor


func _sync_text_position() -> void:
	if _text_target == null:
		return
	var target := text_actor()
	if target != null:
		_text_anchor = target.position + _text_offset
	position = _text_anchor - Vector2(0, _text_rise)


## Match the centered glyphs and their outline, rather than the 120px drawing box.
func text_bounds() -> Rect2:
	var measured: Vector2 = params.get("text_size", Vector2(120, UiKit.BOLD_FONT.get_height(font_size)))
	var size := measured + Vector2(12, 12)
	return Rect2(position + Vector2(-size.x * 0.5, -UiKit.BOLD_FONT.get_ascent(font_size) - 6.0), size)


static var _impact_material: CanvasItemMaterial


static func _glow_material() -> CanvasItemMaterial:
	if _impact_material == null:
		_impact_material = CanvasItemMaterial.new()
		_impact_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _impact_material


static func _element_cell(tint: Color) -> int:
	if tint.is_equal_approx(SkillDefs.FIRE):
		return 1
	if tint.is_equal_approx(SkillDefs.LIGHT):
		return 2
	if tint.is_equal_approx(SkillDefs.COLD):
		return 3
	return 0


## JUICE #12: element of a contact source (0 none/steel, 1 fire, 2 lightning, 3 cold), shared by art and sound.
static func contact_element(source: Node2D) -> int:
	var tint := Color.WHITE
	if source is Effect:
		tint = source.color
	elif source is Player:
		tint = source.impact_color
	return _element_cell(tint)


## Successful elemental casts light the forward hand; this has no hitbox or gameplay clock.
static func spawn_cast(world_game: Node, caster: Player, tint: Color) -> Effect:
	var cast := Effect.new()
	cast.kind = "cast"
	cast.owner_node = caster
	cast.life = GameTempo.duration(0.30)
	cast.color = tint
	cast.params["cell"] = _element_cell(tint)
	cast.params["action_serial"] = caster._action_serial
	cast.z_index = 5
	cast.material = _glow_material()
	cast.position = caster.position + cast_hand_offset(caster.facing, caster.sprite.body_height)
	world_game._add_effect(cast)
	return cast


## A compact directional release confirms the actual deferred callback, not merely a button press.
static func spawn_release(world_game: Node, caster: Player, tint: Color) -> Effect:
	var release := Effect.new()
	release.kind = "release"
	release.life = 0.14
	release.position = caster.position + cast_hand_offset(caster.facing, caster.sprite.body_height)
	release.velocity = Vector2.from_angle(caster.facing) * (0.0 if Prefs.reduce_motion else 70.0)
	release.params["cell"] = _element_cell(tint)
	release.material = _glow_material()
	release.z_index = 6
	world_game._add_effect(release)
	return release


static func spawn_dodge_echo(world_game: Node, caster: Player) -> Effect:
	if Prefs.reduce_motion:
		return null
	var echo := Effect.new()
	echo.kind = "dodge_echo"
	echo.position = caster.position
	echo.life = GameTempo.duration(0.15)
	echo.params = {"atlas": caster.sprite.atlas, "frame": caster.sprite.frame, "height": caster.sprite.body_height}
	echo.z_index = caster.z_index
	world_game._add_effect(echo)
	return echo


static func cast_hand_offset(facing: float, body_height: float) -> Vector2:
	var forward := Vector2.from_angle(facing)
	return Vector2(forward.x * body_height * 0.25, -body_height * 0.55 + forward.y * body_height * 0.11)


func _init() -> void:
	add_to_group(GROUP)


## Presenters read effects every frame; the group avoids walking every tree, rock
## and plant that shares the world node. Order matches the world's child order.
static func in_world(world: Node) -> Array[Effect]:
	var result: Array[Effect] = []
	if not is_instance_valid(world) or not world.is_inside_tree():
		return result
	for node in world.get_tree().get_nodes_in_group(GROUP):
		if node.get_parent() == world:
			result.append(node as Effect)
	return result


func _ready() -> void:
	if SpatialCombat3D.world(game) != null:
		var at := _ground() if kind in ["proj", "orb"] else position
		spatial_floor_height = SpatialCombat3D.floor_at(game, at)
		if kind in ["proj", "orb"]:
			spatial_height = float(params.get("spatial_height", SpatialCombat3D.launch_height(game, at, owner_node)))
			if is_inf(spatial_height):
				spatial_height = SpatialCombat3D.launch_height(game, at, owner_node)
			spatial_floor_height = spatial_height - SpatialCombat3D.PROJECTILE_LIFT
	if kind in ["proj", "orb"]:
		velocity *= GameTempo.RATE
		life = GameTempo.duration(life)
	if kind in ["nova", "slash", "orb", "skill_fx"] or (kind == "proj" and not params.get("throw", false)) or (kind == "zone" and params.get("visual", "") == "meteor"):
		material = _glow_material()


## Projectile velocity gives the contact direction; stationary zones use their actual owner.
static func contact_direction(source: Node2D, target: Vector2) -> Vector2:
	if source == null:
		return Vector2.ZERO
	if source is Effect:
		if source.velocity.length_squared() > 1.0:
			return source.velocity.normalized()
		if is_instance_valid(source.owner_node):
			return (target - source.owner_node.position).normalized()
	return (target - source.position).normalized()


static func contact_flash_color(source: Node2D) -> Color:
	var tint := SkillDefs.STEEL
	if source is Effect:
		tint = source.color
	elif source is Player:
		tint = source.impact_color
	match _element_cell(tint):
		1: return Color(1.0, 0.72, 0.36)
		2: return Color(0.77, 0.75, 1.0)
		3: return Color(0.50, 0.85, 1.0)
	return Color(1.0, 0.90, 0.65)


## Generated contact art is cosmetic and shares the existing effect budget, never collision/damage.
static func spawn_impact(world_game: Node, at: Vector2, source: Node2D, heavy := false) -> Effect:
	var impact := Effect.new()
	impact.kind = "impact"
	impact.position = at
	impact.radius = 140.0 if heavy else 100.0
	impact.life = 0.28 if heavy else 0.22
	impact.z_index = 6
	impact.params["cell"] = contact_element(source)
	WorldLighting.pulse(at, contact_flash_color(source), heavy)
	if source != null:
		impact.angle = contact_direction(source, at).angle()
	impact.material = _glow_material()
	world_game._add_effect(impact)
	return impact


func _process(delta: float) -> void:
	var previous_age := age
	var active_delta := minf(delta, maxf(0.0, life - age))
	# A slow frame must not discard a new cosmetic impact before its first render.
	# Only the first update is bounded; headless/offscreen effects still expire normally.
	if kind in ["impact", "cast", "release", "dodge_echo", "slash", "nova", "skill_fx"] and not _impact_started:
		age += minf(delta, life * 0.2)
		_impact_started = true
	else:
		age += delta
	if kind == "text":
		active_delta = maxf(0.0, minf(age, life) - maxf(previous_age, 0.0))
	match kind:
		"skill_fx":
			if params.get("visual", "") == "spin":
				var caster := owner_node as Player
				if not is_instance_valid(caster) or caster.dead or caster._action_serial != int(params["action_serial"]):
					queue_free()
					return
				position = caster.position
				z_index = caster.z_index
		"release":
			position += velocity * active_delta
		"cast":
			var caster := owner_node as Player
			if not is_instance_valid(caster) or caster.dead or caster._roll_time > 0.0 or int(params.get("action_serial", -1)) != caster._action_serial:
				queue_free()
				return
			position = caster.position + cast_hand_offset(caster.facing, caster.sprite.body_height)
		"proj":
			_update_projectile(active_delta)
		"orb":
			_update_orb(active_delta)
		"zone":
			_update_zone(delta)
		"hydra":
			_update_hydra(delta)
		"ward":
			_update_ward(delta)
		"text":
			if _text_target_id != 0:
				if not Prefs.reduce_motion:
					_text_rise += 42.0 * active_delta
				_sync_text_position()
				if _text_rise > TEXT_STREAM_MAX_RISE:
					queue_free()
			elif not Prefs.reduce_motion:
				position.y -= 42.0 * active_delta
	if is_queued_for_deletion():
		return
	if age >= life:
		if kind == "orb":
			_orb_burst()
		queue_free()
		return
	if is_visible_in_tree():
		queue_redraw()


# ───────── behaviour ─────────

func _ground() -> Vector2:
	# Projectiles fly at chest height; collisions use the ground point below.
	return position + Vector2(0, 34)


func native_position() -> Vector3:
	if not is_inf(spatial_height):
		return WorldSpace3D.projected_to_world(_ground(), spatial_height)
	return WorldSpace3D.projected_to_world(position, 0.0 if is_inf(spatial_floor_height) else spatial_floor_height)


## Ordered continuous circle contacts prevent tunneling and do not let an already-hit front enemy hide others.
func _projectile_contacts(start: Vector2, finish: Vector2) -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	var travel := finish - start
	var distance_squared := travel.length_squared()
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or _hit.has(enemy):
			continue
		var contact_radius: float = 26.0 + enemy.radius
		if SpatialCombat3D.world(game) != null:
			if enemy.position.distance_to(Geometry2D.get_closest_point_to_segment(enemy.position, start, finish)) > contact_radius * 1.3:
				continue
			var native_fraction := SpatialCombat3D.target_fraction(game, start, finish, spatial_height, enemy)
			if native_fraction <= 1.0:
				contacts.append({"enemy": enemy, "fraction": native_fraction})
			continue
		var offset: Vector2 = start - enemy.position
		var c := offset.length_squared() - contact_radius * contact_radius
		var fraction := 0.0
		if c > 0.0:
			if distance_squared < 0.0001:
				continue
			var projection := offset.dot(travel)
			var discriminant := projection * projection - distance_squared * c
			if discriminant < 0.0:
				continue
			fraction = (-projection - sqrt(discriminant)) / distance_squared
			if fraction < 0.0 or fraction > 1.0:
				continue
		contacts.append({"enemy": enemy, "fraction": fraction})
	if owner_node is Player and game.encounters != null:
		for contact in game.encounters.projectile_contacts(start, finish, spatial_height):
			if SpatialCombat3D.world(game) != null and is_inf(SpatialCombat3D.target_fraction(game, start, finish, spatial_height, contact["enemy"], 0.0, 26.0)):
				continue
			if not _hit.has(contact["enemy"]):
				contacts.append(contact)
	contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["fraction"]) < float(b["fraction"]))
	return contacts


func _update_projectile(delta: float) -> void:
	if delta <= 0.0:
		return
	var dir := velocity.normalized()
	if params.get("wiggle", false):
		dir = dir.rotated(sin(minf(age, life) * GameTempo.RATE * 18.0 + params.get("seed", 0.0)) * 0.6)
	var start := _ground()
	var travel_end := start + dir * velocity.length() * delta
	var wall := 1.0
	if SpatialCombat3D.world(game) != null:
		if is_inf(spatial_height):
			spatial_height = SpatialCombat3D.launch_height(game, start, owner_node)
			spatial_floor_height = spatial_height - SpatialCombat3D.PROJECTILE_LIFT
		wall = SpatialCombat3D.wall_fraction(game, start, travel_end, spatial_height)
	var finish := start.lerp(travel_end, wall)
	var contacts: Array[Dictionary] = []
	for contact in _projectile_contacts(start, travel_end):
		if float(contact["fraction"]) <= wall:
			contacts.append(contact)
	var piercing: bool = params.get("pierce", false)
	if not piercing and not contacts.is_empty():
		finish = start.lerp(travel_end, float(contacts[0]["fraction"]))
	# Chest interaction follows the same bounded path, never past a blocking first contact.
	_break_projectile_chests(start, finish)
	for contact in contacts:
		var target: Node2D = contact["enemy"]
		if target is EncounterStone:
			position = start.lerp(travel_end, float(contact["fraction"])) - Vector2(0, 34)
			_hit[target] = true
			var blast := float(params.get("explode", 0.0))
			if blast > 0.0:
				# Resolve existing explosion victims before activating the stone: killing its
				# last defender must not turn this same contact into a fresh summon.
				for enemy in _area_targets(_ground(), blast):
					if not _hit.has(enemy):
						_hit[enemy] = true
						_apply(enemy, damage)
				game.spawn_nova(_ground(), blast, color, true)
			target.take_damage(damage, self)
			if not piercing:
				queue_free()
				return
			continue
		var hit := target as Enemy
		if not is_instance_valid(hit) or hit.dead or _hit.has(hit):
			continue
		position = start.lerp(travel_end, float(contact["fraction"])) - Vector2(0, 34)
		_hit[hit] = true
		if float(params.get("explode", 0.0)) > 0.0:
			var victims: Array = _area_targets(_ground(), params["explode"])
			if not victims.has(hit):
				victims.append(hit)
			for enemy in victims:
				if enemy != hit and _hit.has(enemy):
					continue
				_hit[enemy] = true
				_apply(enemy, damage)
			game.spawn_nova(_ground(), params["explode"], color, true)
		else:
			_apply(hit, damage)
			game.spawn_nova(_ground(), 40.0, color, true)
		if not piercing:
			queue_free()
			return
	position = finish - Vector2(0, 34)
	if wall < 1.0:
		var impact := Effect.spawn_impact(game, position, self)
		impact.spatial_height = spatial_height
		impact.spatial_floor_height = spatial_floor_height
		queue_free()


func _break_projectile_chests(start: Vector2, finish: Vector2) -> void:
	if SpatialCombat3D.world(game) == null:
		var steps := maxi(1, ceili(start.distance_to(finish) / 22.0))
		for step in range(steps + 1):
			game.break_chests_at(start.lerp(finish, float(step) / steps), 22.0, owner_node, false)
		return
	for chest: Chest in game.chests:
		if chest.dead:
			continue
		var fraction := SpatialCombat3D.target_fraction(game, start, finish, spatial_height, chest, 22.0, Chest.COLLISION_RADIUS)
		if fraction <= 1.0 and SpatialCombat3D.line_clear(game, start, chest.position, spatial_floor_height):
			chest.take_damage(1.0, owner_node)


func _area_targets(center: Vector2, reach: float) -> Array:
	if SpatialCombat3D.world(game) == null:
		return game.enemies_in_radius(center, reach)
	var out: Array[Enemy] = []
	for enemy: Enemy in game.enemies:
		if not enemy.dead and center.distance_to(enemy.position) <= reach + enemy.radius and SpatialCombat3D.area_reaches(game, center, enemy.position, reach + enemy.radius, spatial_floor_height):
			out.append(enemy)
	return out


func _apply(e: Enemy, amount: float) -> void:
	var before := e.hp
	e.take_damage(amount, self)
	if e.hp < before and owner_node is Player:
		RunBuild.contact(owner_node, e, str(params.get("run_skill_id", "")), int(params.get("run_action_serial", -1)), params.get("run_contact_mods", {}))
	if float(params.get("slow", 0.0)) > 0.0:
		e.slow(params["slow"])
	if float(params.get("freeze", 0.0)) > 0.0:
		e.freeze(params["freeze"])
	if float(params.get("knock", 0.0)) > 0.0:
		e.knock(position - velocity, params["knock"])


func _update_orb(delta: float) -> void:
	var start := _ground()
	var finish := start + velocity * delta
	var wall := 1.0
	if SpatialCombat3D.world(game) != null:
		if is_inf(spatial_height):
			spatial_height = SpatialCombat3D.launch_height(game, start, owner_node)
			spatial_floor_height = spatial_height - SpatialCombat3D.PROJECTILE_LIFT
		wall = SpatialCombat3D.wall_fraction(game, start, finish, spatial_height)
	position = start.lerp(finish, wall) - Vector2(0, 34)
	if wall < 1.0:
		_orb_burst()
		queue_free()
		return
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = GameTempo.duration(0.09)
		var dir := Vector2.from_angle(age * GameTempo.RATE * 9.0)
		game.spawn_projectile({"pos": position, "dir": dir, "speed": 420.0, "damage": damage,
			"color": color, "slow": 1.5, "life": 0.6, "spatial_height": spatial_height}, owner_node)


func _orb_burst() -> void:
	for i in 12:
		game.spawn_projectile({"pos": position, "dir": Vector2.from_angle(TAU * i / 12.0), "speed": 460.0,
			"damage": damage, "color": color, "slow": 1.5, "life": 0.5, "spatial_height": spatial_height}, owner_node)


func _update_zone(delta: float) -> void:
	var delay := float(params.get("delay", 0.0))
	if age < delay:
		return
	if delay > 0.0 and not params.get("impacted", false):
		params["impacted"] = true
		for e in _area_targets(position, radius):
			e.take_damage(params.get("impact", damage), self)
		if params.get("visual", "") == "meteor":
			game.spawn_reference_fx("meteor", position, radius * 1.2, owner_node, 0.48)
		else:
			game.spawn_nova(position, radius * 1.2, color)
	_tick_timer -= delta
	if _tick_timer > 0.0:
		return
	_tick_timer = float(params.get("tick", 0.3))
	game.break_chests_in_radius(position, radius, owner_node)
	for e in _zone_targets():
		e.take_damage(damage, null, self)
		if float(params.get("slow", 0.0)) > 0.0:
			e.slow(params["slow"])


func _zone_targets() -> Array:
	if params.has("wall"):
		var out := []
		var axis := Vector2.from_angle(params["wall"])
		for e in _area_targets(position, radius + 10.0):
			var d: Vector2 = e.position - position
			if absf(d.dot(axis.orthogonal())) < 26.0:
				out.append(e)
		return out
	return _area_targets(position, radius)


func _update_hydra(delta: float) -> void:
	_tick_timer -= delta
	if _tick_timer > 0.0:
		return
	var target: Node2D = game.nearest_enemy(position, params["range"])
	if target == null:
		target = game.nearest_attackable_prop(position, params["range"])
	if target == null:
		return
	_tick_timer = float(params["rate"])
	var dir := (target.position - position).normalized()
	game.spawn_projectile({"pos": position + Vector2(0, -40), "dir": dir, "speed": 600.0,
		"damage": damage, "color": SkillDefs.FIRE,
		"spatial_height": spatial_floor_height + SpatialCombat3D.PROJECTILE_LIFT}, owner_node)


func _update_ward(delta: float) -> void:
	_tick_timer -= delta
	if _tick_timer > 0.0:
		return
	_tick_timer = 0.5
	for e in _area_targets(position, radius):
		e.fear(1.0, position)


# ───────── drawing ─────────

## Reduced motion keeps one authored pose while the effect's real lifetime still runs.
func visual_phase() -> float:
	return 1.0 / 3.0 if Prefs.reduce_motion else clampf(age / life, 0.0, 1.0)


func _draw() -> void:
	if kind == "text" and age < 0.0:
		return
	var t := age / life
	match kind:
		"skill_fx":
			var key: String = params["visual"]
			var alpha := 0.35 if Prefs.reduce_motion else (0.58 if key == "frost" else 0.78)
			var fade := 1.0 - smoothstep(0.6, 1.0, clampf(t, 0.0, 1.0))
			# Native sheet already contains the projected ground plane and upright shards.
			var width := radius * (1.4 if key == "frost" else 2.0)
			ReferenceFxArt.draw(self, key, visual_phase(), ReferenceFxArt.rect(key, width), Color(1, 1, 1, alpha * fade))
		"release":
			_draw_generated_glow(Vector2.ZERO, 38.0 if Prefs.reduce_motion else 42.0 + 8.0 * t, int(params["cell"]), (0.32 if Prefs.reduce_motion else 0.7) * (1.0 - t), visual_phase())
		"dodge_echo":
			if Prefs.reduce_motion:
				return
			var atlas: ActorAtlas = params["atlas"]
			var frame: int = params["frame"]
			if atlas == null or frame >= atlas.regions.size():
				return
			var factor: float = float(params["height"]) / atlas.ref_height
			var region := atlas.regions[frame]
			draw_texture_rect_region(atlas.texture, Rect2(-atlas.anchors[frame] * factor, region.size * factor), region, Color(0.65, 0.8, 1.0, 0.22 * (1.0 - t)))
		"cast":
			var fade := pow(1.0 - clampf(t, 0.0, 1.0), 0.7)
			var strength := 0.45 if Prefs.reduce_motion else 0.72
			var preparation := 1.0 / 3.0 if Prefs.reduce_motion else lerpf(0.08, 0.28, clampf(t, 0.0, 1.0))
			_draw_generated_glow(Vector2.ZERO, 38.0, int(params["cell"]), fade * strength, preparation)
			# Small separated glints preserve the silhouette and floor underneath the hand.
			for index in 6:
				var phase := 0.4 if Prefs.reduce_motion else t
				var direction := Vector2.from_angle(index * 2.39996)
				var at := direction * lerpf(7.0, 29.0, phase)
				at.y *= 0.6
				var glint := Color(0.72, 0.9, 1.0, fade * strength) if index % 2 == 0 else Color(1.0, 0.84, 0.47, fade * strength)
				draw_line(at - Vector2(2.2, 0), at + Vector2(2.2, 0), glint, 1.0, true)
				draw_line(at - Vector2(0, 2.2), at + Vector2(0, 2.2), glint, 1.0, true)
		"impact":
			# Compact bright contact, quick expansion, then a quieter tail rather than a soft uniform puff.
			var fade := pow(1.0 - clampf((t - 0.10) / 0.90, 0.0, 1.0), 1.6)
			var growth := 0.86 if Prefs.reduce_motion else lerpf(0.64, 1.16, ease(t, 0.3))
			var diameter := radius * growth
			draw_set_transform(Vector2.ZERO, 0.0 if Prefs.reduce_motion else angle, Vector2.ONE)
			PresentationArt.draw_impact(self, int(params["cell"]), visual_phase(), Rect2(Vector2.ONE * -diameter * 0.5, Vector2.ONE * diameter), Color(1, 1, 1, fade * (0.58 if Prefs.reduce_motion else 0.95)))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"slash":
			draw_set_transform(Vector2.ZERO, angle, Vector2.ONE)
			var rect := ReferenceFxArt.rect("slash", radius * 1.7)
			var sweep := clampf(float(params.get("arc", 1.2)) / 1.2, 0.45, 1.2)
			rect.position.y *= sweep
			rect.size.y *= sweep
			ReferenceFxArt.draw(self, "slash", visual_phase(), rect, Color(1, 1, 1, (0.48 if Prefs.reduce_motion else 0.85) * (1.0 - 0.4 * t)))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"nova":
			var r := radius if Prefs.reduce_motion else radius * (0.25 + 0.75 * ease(t, 0.4))
			var element := _element_cell(color)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, GROUND_Y))
			PresentationArt.draw_impact(self, element, visual_phase(), Rect2(Vector2.ONE * -r, Vector2.ONE * r * 2.0), Color(1, 1, 1, (0.08 if element == 0 else 0.24) * (1.0 - t)))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_ellipse_ring(r, Color(color, 0.4 * (1.0 - t)), 1.4)
		"proj":
			if params.get("throw", false):
				draw_set_transform(Vector2.ZERO, age * 25.0, Vector2.ONE)
				draw_rect(Rect2(-12, -3, 24, 6), Color(0.8, 0.8, 0.85))
				draw_rect(Rect2(6, -8, 8, 16), Color(0.7, 0.72, 0.78))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			elif params.get("visual", "") == "bolt":
				draw_set_transform(Vector2.ZERO, velocity.angle(), Vector2.ONE)
				ReferenceFxArt.draw(self, "bolt", 1.0 / 3.0 if Prefs.reduce_motion else 0.32 + 0.06 * sin(age * 20.0), ReferenceFxArt.rect("bolt", 110.0), Color(1, 1, 1, 0.65 if Prefs.reduce_motion else 0.9))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				var flicker := 1.0 if Prefs.reduce_motion else 1.0 + 0.08 * sin(age * 30.0)
				var cell := _element_cell(color)
				_draw_generated_glow(Vector2.ZERO, 44.0 * flicker, cell, 0.9)
				draw_circle(Vector2.ZERO, 2.8, Color(1, 1, 0.95, 0.9))
				var tail := -velocity.normalized()
				for i in 3:
					_draw_generated_glow(tail * (11.0 + i * 11.0), 25.0 - i * 5.0, cell, 0.22 - i * 0.06)
		"orb":
			var element := _element_cell(color)
			_draw_generated_glow(Vector2.ZERO, 52.0, element, 0.85)
			for i in 3:
				var phase := 0.0 if Prefs.reduce_motion else age * 2.5
				var dir := Vector2.from_angle(phase + TAU * i / 3.0)
				_draw_generated_glow(dir * 14.0, 10.0, element, 0.4, 2.0 / 3.0)
		"zone":
			var delay := float(params.get("delay", 0.0))
			var fade := clampf((life - age) / 0.5, 0.0, 1.0)
			if params.get("visual", "") == "meteor":
				if age < delay:
					_ellipse_ring(radius, Color(color, 0.65), 1.8)
					var fall := Vector2(160, -360) * (1.0 - age / delay)
					if Prefs.reduce_motion:
						fall = Vector2(0, -36)
					for index in 3:
						_draw_generated_glow(fall + Vector2(12, -28) * index, 42.0 - index * 9.0, 1, 0.8 - index * 0.2)
				else:
					# Quiet embers retain the continuing damage-zone cue after the one-shot impact.
					_ellipse_ring(radius, Color(color, 0.25 * fade), 1.0)
					for index in 5:
						var ember := Vector2.from_angle(index * 2.39996) * radius * 0.6
						ember.y *= GROUND_Y
						_draw_generated_glow(ember, 17.0, 1, 0.2 * fade)
			elif age < delay:
				# Meteor warning circle and falling rock.
				_ellipse_ring(radius, Color(color, 0.8), 3.0)
				var k := age / delay
				draw_circle(Vector2(0, -420.0 * (1.0 - k)), 18.0, Color(1, 0.6, 0.2))
				draw_circle(Vector2(0, -420.0 * (1.0 - k)), 10.0, Color(1, 0.95, 0.7))
			elif params.has("wall"):
				var axis := Vector2.from_angle(params["wall"])
				for i in 9:
					var p := axis * lerpf(-radius, radius, i / 8.0)
					var h := 26.0 + 12.0 * sin(age * 12.0 + i)
					draw_line(p, p + Vector2(0, -h), Color(color, 0.85 * fade), 10.0)
					draw_circle(p + Vector2(0, -h), 6.0, Color(1, 0.9, 0.5, 0.8 * fade))
			else:
				_ellipse_fill(radius, Color(color, 0.22 * fade))
				_ellipse_ring(radius, Color(color, 0.6 * fade), 3.0)
				if params.get("shards", false):
					for i in 5:
						var a2 := fmod(age * 3.0 + i * 0.37, 1.0)
						var p2 := Vector2.from_angle(i * 2.4 + floor(age * 3.0 + i * 0.37) * 1.7) * radius * 0.7
						p2.y *= 0.55
						draw_line(p2 + Vector2(0, -160.0 * (1.0 - a2)), p2 + Vector2(0, -160.0 * (1.0 - a2) + 22.0), Color(1, 1, 1, 0.9 * fade), 3.0)
		"beam", "chain", "strike":
			var a3 := 1.0 - t
			if points.size() >= 2:
				draw_polyline(points, Color(color, 0.45 * a3), 9.0, true)
				draw_polyline(points, Color(1, 1, 1, 0.95 * a3), 3.0, true)
		"cone":
			var a4 := 1.0 - t
			var poly := PackedVector2Array([Vector2.ZERO])
			for i in 9:
				poly.append(Vector2.from_angle(angle + lerpf(-0.5, 0.5, i / 8.0)) * radius * (0.4 + 0.6 * t))
			draw_colored_polygon(poly, Color(color, 0.45 * a4))
		"trail":
			if points.size() >= 2:
				draw_line(points[0], points[1], Color(color, 0.5 * (1.0 - t)), 14.0 * (1.0 - t) + 2.0)
		"hydra":
			var fade2 := clampf((life - age) / 0.5, 0.0, 1.0)
			_ellipse_fill(24.0, Color(0.3, 0.1, 0.05, 0.5 * fade2))
			for i in 3:
				var base := Vector2((i - 1) * 12.0, 0)
				var head := base + Vector2((i - 1) * 10.0, -44.0 + sin(age * 5.0 + i) * 4.0)
				draw_line(base, head, Color(0.9, 0.35, 0.12, fade2), 8.0)
				draw_circle(head, 7.0, Color(1, 0.55, 0.2, fade2))
		"ward":
			var fade3 := clampf((life - age) / 0.5, 0.0, 1.0)
			_ellipse_ring(radius, Color(0.6, 0.4, 0.9, 0.25 * fade3), 2.0)
			draw_line(Vector2.ZERO, Vector2(0, -60), Color(0.45, 0.35, 0.3, fade3), 6.0)
			draw_circle(Vector2(0, -66), 10.0, Color(0.85, 0.85, 0.75, fade3))
			draw_circle(Vector2(-4, -68), 2.5, Color(0.1, 0, 0.1, fade3))
			draw_circle(Vector2(4, -68), 2.5, Color(0.1, 0, 0.1, fade3))
		"text":
			var a2 := clampf(2.0 - t * 2.0, 0.0, 1.0)
			var measured: Vector2 = params.get("text_size", Vector2(120, 22))
			var text_width := maxf(120.0, measured.x)
			var baseline := Vector2(-text_width * 0.5, 0)
			# JUICE #2: a brief scale pop about the number anchor; skipped for reduced motion.
			var pop_scale := text_pop_scale(age) if pop and not Prefs.reduce_motion else 1.0
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * pop_scale)
			for line in text.split("\n"):
				draw_string_outline(UiKit.BOLD_FONT, baseline, line, HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size, 5, Color(0, 0, 0, a2))
				draw_string(UiKit.BOLD_FONT, baseline, line, HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size, Color(color, a2))
				baseline.y += UiKit.BOLD_FONT.get_height(font_size)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## JUICE #2: 1.4x at contact easing to 1.0 over POP_SECONDS.
const POP_SECONDS := 0.08
const POP_START := 1.4


static func text_pop_scale(elapsed: float) -> float:
	return lerpf(POP_START, 1.0, clampf(elapsed / POP_SECONDS, 0.0, 1.0))


func _draw_generated_glow(at: Vector2, diameter: float, cell: int, alpha: float, phase := 1.0 / 3.0) -> void:
	PresentationArt.draw_impact(self, cell, phase, Rect2(at - Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter), Color(1, 1, 1, alpha))


func _ellipse_fill(r: float, c: Color) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, GROUND_Y))
	draw_circle(Vector2.ZERO, r, c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ellipse_ring(r: float, c: Color, width: float) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, GROUND_Y))
	draw_arc(Vector2.ZERO, r, 0, TAU, 48, c, width, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

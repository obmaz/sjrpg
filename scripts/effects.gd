class_name Effect
extends Node2D
## Drawn combat effects. Kinds: slash, nova, proj, zone, orb, beam, chain, cone,
## trail, strike, hydra, ward, text.

const GROUND_Y := 0.577350269

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
var points: PackedVector2Array = PackedVector2Array()
var params := {}

var _impact_started := false
var _tick_timer := 0.0
var _hit := {}  # enemies already hit (piercing)


## Keep individual amounts readable without a queue, amount merging, or an expanding stack.
## Nine nearby positions are enough for ordinary rapid hits; saturation replaces only
## older text intersecting the new label. All text still shares the 64-effect budget.
func place_text(peers: Array) -> void:
	var anchor := position
	var lines := text.split("\n")
	var width := 0.0
	for line in lines:
		width = maxf(width, UiKit.BOLD_FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x)
	params["text_size"] = Vector2(width, UiKit.BOLD_FONT.get_height(22) * lines.size())
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


## Match the centered glyphs and their outline, rather than the 120px drawing box.
func text_bounds() -> Rect2:
	var measured: Vector2 = params.get("text_size", Vector2(120, UiKit.BOLD_FONT.get_height(22)))
	var size := measured + Vector2(12, 12)
	return Rect2(position + Vector2(-size.x * 0.5, -UiKit.BOLD_FONT.get_ascent(22) - 6.0), size)


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


func _ready() -> void:
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
	var tint := Color.WHITE
	if source is Effect:
		tint = source.color
	elif source is Player:
		tint = source.impact_color
	impact.params["cell"] = _element_cell(tint)
	WorldLighting.pulse(at, contact_flash_color(source), heavy)
	if source != null:
		impact.angle = contact_direction(source, at).angle()
	impact.material = _glow_material()
	world_game._add_effect(impact)
	return impact


func _process(delta: float) -> void:
	var active_delta := minf(delta, maxf(0.0, life - age))
	# A slow frame must not discard a new cosmetic impact before its first render.
	# Only the first update is bounded; headless/offscreen effects still expire normally.
	if kind in ["impact", "cast", "release", "dodge_echo", "slash", "nova", "skill_fx"] and not _impact_started:
		age += minf(delta, life * 0.2)
		_impact_started = true
	else:
		age += delta
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
			_update_orb(delta)
		"zone":
			_update_zone(delta)
		"hydra":
			_update_hydra(delta)
		"ward":
			_update_ward(delta)
		"text":
			if not Prefs.reduce_motion:
				position.y -= 42.0 * delta
	if is_queued_for_deletion():
		return
	if age >= life:
		if kind == "orb":
			_orb_burst()
		queue_free()
		return
	queue_redraw()


# ───────── behaviour ─────────

func _ground() -> Vector2:
	# Projectiles fly at chest height; collisions use the ground point below.
	return position + Vector2(0, 34)


## Ordered continuous circle contacts prevent tunneling and do not let an already-hit front enemy hide others.
func _projectile_contacts(start: Vector2, finish: Vector2) -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	var travel := finish - start
	var distance_squared := travel.length_squared()
	var contact_radius := 26.0 + Enemy.RADIUS
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or _hit.has(enemy):
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
		for contact in game.encounters.projectile_contacts(start, finish):
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
	var finish := start + dir * velocity.length() * delta
	var contacts := _projectile_contacts(start, finish)
	var piercing: bool = params.get("pierce", false)
	if not piercing and not contacts.is_empty():
		finish = start.lerp(finish, float(contacts[0]["fraction"]))
	# Chest interaction follows the same bounded path, never past a blocking first contact.
	var steps := maxi(1, ceili(start.distance_to(finish) / 22.0))
	for step in range(steps + 1):
		game.break_chests_at(start.lerp(finish, float(step) / steps), 22.0, owner_node, false)
	var travel_end := start + dir * velocity.length() * delta
	for contact in contacts:
		var target: Node2D = contact["enemy"]
		if target is EncounterStone:
			position = start.lerp(travel_end, float(contact["fraction"])) - Vector2(0, 34)
			_hit[target] = true
			var blast := float(params.get("explode", 0.0))
			if blast > 0.0:
				# Resolve existing explosion victims before activating the stone: killing its
				# last defender must not turn this same contact into a fresh summon.
				for enemy in game.enemies_in_radius(_ground(), blast):
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
			var victims: Array = game.enemies_in_radius(_ground(), params["explode"])
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


func _apply(e: Enemy, amount: float) -> void:
	e.take_damage(amount, self)
	if float(params.get("slow", 0.0)) > 0.0:
		e.slow(params["slow"])
	if float(params.get("freeze", 0.0)) > 0.0:
		e.freeze(params["freeze"])
	if float(params.get("knock", 0.0)) > 0.0:
		e.knock(position - velocity, params["knock"])


func _update_orb(delta: float) -> void:
	position += velocity * delta
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = GameTempo.duration(0.09)
		var dir := Vector2.from_angle(age * GameTempo.RATE * 9.0)
		game.spawn_projectile({"pos": position, "dir": dir, "speed": 420.0, "damage": damage,
			"color": color, "slow": 1.5, "life": 0.6}, owner_node)


func _orb_burst() -> void:
	for i in 12:
		game.spawn_projectile({"pos": position, "dir": Vector2.from_angle(TAU * i / 12.0), "speed": 460.0,
			"damage": damage, "color": color, "slow": 1.5, "life": 0.5}, owner_node)


func _update_zone(delta: float) -> void:
	var delay := float(params.get("delay", 0.0))
	if age < delay:
		return
	if delay > 0.0 and not params.get("impacted", false):
		params["impacted"] = true
		for e in game.enemies_in_radius(position, radius):
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
		for e in game.enemies_in_radius(position, radius + 10.0):
			var d: Vector2 = e.position - position
			if absf(d.dot(axis.orthogonal())) < 26.0:
				out.append(e)
		return out
	return game.enemies_in_radius(position, radius)


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
		"damage": damage, "color": SkillDefs.FIRE}, owner_node)


func _update_ward(delta: float) -> void:
	_tick_timer -= delta
	if _tick_timer > 0.0:
		return
	_tick_timer = 0.5
	for e in game.enemies_in_radius(position, radius):
		e.fear(1.0, position)


# ───────── drawing ─────────

## Reduced motion keeps one authored pose while the effect's real lifetime still runs.
func visual_phase() -> float:
	return 1.0 / 3.0 if Prefs.reduce_motion else clampf(age / life, 0.0, 1.0)


func _draw() -> void:
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
			for line in text.split("\n"):
				draw_string_outline(UiKit.BOLD_FONT, baseline, line, HORIZONTAL_ALIGNMENT_CENTER, text_width, 22, 5, Color(0, 0, 0, a2))
				draw_string(UiKit.BOLD_FONT, baseline, line, HORIZONTAL_ALIGNMENT_CENTER, text_width, 22, Color(color, a2))
				baseline.y += UiKit.BOLD_FONT.get_height(22)


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

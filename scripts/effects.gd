class_name Effect
extends Node2D
## Drawn combat effects. Kinds: slash, nova, proj, zone, orb, beam, chain, cone,
## trail, strike, hydra, ward, text.

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

var _tick_timer := 0.0
var _hit := {}  # enemies already hit (piercing)


func _process(delta: float) -> void:
	age += delta
	match kind:
		"proj":
			_update_projectile(delta)
		"orb":
			_update_orb(delta)
		"zone":
			_update_zone(delta)
		"hydra":
			_update_hydra(delta)
		"ward":
			_update_ward(delta)
		"text":
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


func _update_projectile(delta: float) -> void:
	var dir := velocity.normalized()
	if params.get("wiggle", false):
		dir = dir.rotated(sin(age * 18.0 + params.get("seed", 0.0)) * 0.6)
	position += dir * velocity.length() * delta
	game.break_chests_at(_ground(), 22.0, owner_node)
	var hit: Enemy = game.enemy_hit_by_point(_ground(), 26.0)
	if hit == null or _hit.has(hit):
		return
	_hit[hit] = true
	if float(params.get("explode", 0.0)) > 0.0:
		for e in game.enemies_in_radius(_ground(), params["explode"]):
			_apply(e, damage)
		game.spawn_nova(_ground(), params["explode"], color, true)
	else:
		_apply(hit, damage)
		game.spawn_nova(_ground(), 40.0, color, true)
	if not params.get("pierce", false):
		queue_free()


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
		_tick_timer = 0.09
		var dir := Vector2.from_angle(age * 9.0)
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
		game.spawn_nova(position, radius * 1.2, color)
	_tick_timer -= delta
	if _tick_timer > 0.0:
		return
	_tick_timer = float(params.get("tick", 0.3))
	game.break_chests_in_radius(position, radius, owner_node)
	for e in _zone_targets():
		e.take_damage(damage, null)
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
	var target: Enemy = game.nearest_enemy(position, params["range"])
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

func _draw() -> void:
	var t := age / life
	match kind:
		"slash":
			var a := 1.0 - t
			for i in 3:
				draw_arc(Vector2.ZERO, 70.0 + i * 9.0, angle - 1.1, angle + 1.1, 18,
					Color(color, a * (0.9 - i * 0.25)), 7.0 - i * 2.0, true)
		"nova":
			var r := radius * (0.25 + 0.75 * ease(t, 0.4))
			_ellipse_fill(r, Color(color, 0.18 * (1.0 - t)))
			_ellipse_ring(r, Color(color, 0.9 * (1.0 - t)), 6.0)
		"proj":
			if params.get("throw", false):
				draw_set_transform(Vector2.ZERO, age * 25.0, Vector2.ONE)
				draw_rect(Rect2(-12, -3, 24, 6), Color(0.8, 0.8, 0.85))
				draw_rect(Rect2(6, -8, 8, 16), Color(0.7, 0.72, 0.78))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				var flicker := 1.0 + 0.15 * sin(age * 40.0)
				draw_circle(Vector2.ZERO, 15.0 * flicker, Color(color, 0.35))
				draw_circle(Vector2.ZERO, 9.0 * flicker, Color(color, 0.9))
				draw_circle(Vector2.ZERO, 4.5, Color(1, 1, 0.95))
				var tail := -velocity.normalized()
				for i in 4:
					draw_circle(tail * (10.0 + i * 9.0), 7.0 - i * 1.4, Color(color, 0.45 - i * 0.1))
		"orb":
			draw_circle(Vector2.ZERO, 22.0, Color(color, 0.35))
			draw_circle(Vector2.ZERO, 13.0, Color(color, 0.9))
			for i in 6:
				var dir := Vector2.from_angle(age * 9.0 + TAU * i / 6.0)
				draw_line(dir * 8.0, dir * 26.0, Color(1, 1, 1, 0.7), 2.0)
		"zone":
			var delay := float(params.get("delay", 0.0))
			var fade := clampf((life - age) / 0.5, 0.0, 1.0)
			if age < delay:
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
			draw_string_outline(UiKit.BOLD_FONT, Vector2(-60, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 120, 22, 5, Color(0, 0, 0, a2))
			draw_string(UiKit.BOLD_FONT, Vector2(-60, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 120, 22, Color(color, a2))


func _ellipse_fill(r: float, c: Color) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, r, c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ellipse_ring(r: float, c: Color, width: float) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	draw_arc(Vector2.ZERO, r, 0, TAU, 48, c, width, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

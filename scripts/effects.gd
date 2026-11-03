class_name Effect
extends Node2D
## Lightweight drawn effects: slash arcs, nova rings, fireballs and floating numbers.

var kind := ""
var color := Color.WHITE
var life := 0.4
var age := 0.0
var angle := 0.0
var radius := 100.0
var velocity := Vector2.ZERO
var damage := 0.0
var game: Node
var text := ""


func _process(delta: float) -> void:
	age += delta
	if kind == "fireball":
		position += velocity * delta
		var hit: Node2D = game.enemy_hit_by_point(position + Vector2(0, 34), 30.0)
		if hit:
			hit.take_damage(damage, self)
			game.spawn_nova(position + Vector2(0, 34), 60.0, Color(1, 0.55, 0.2), true)
			queue_free()
			return
	elif kind == "text":
		position.y -= 42.0 * delta
	if age >= life:
		queue_free()
		return
	queue_redraw()


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
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
			draw_circle(Vector2.ZERO, r, Color(color, 0.18 * (1.0 - t)))
			draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(color, 0.9 * (1.0 - t)), 6.0, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"fireball":
			var flicker := 1.0 + 0.15 * sin(age * 40.0)
			draw_circle(Vector2.ZERO, 16.0 * flicker, Color(1, 0.45, 0.1, 0.35))
			draw_circle(Vector2.ZERO, 10.0 * flicker, Color(1, 0.7, 0.25, 0.9))
			draw_circle(Vector2.ZERO, 5.0, Color(1, 1, 0.8))
			var tail := -velocity.normalized()
			for i in 4:
				draw_circle(tail * (10.0 + i * 9.0), 8.0 - i * 1.6, Color(1, 0.5, 0.15, 0.5 - i * 0.1))
		"text":
			var a2 := clampf(2.0 - t * 2.0, 0.0, 1.0)
			draw_string_outline(UiKit.BOLD_FONT, Vector2(-40, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 80, 22, 5, Color(0, 0, 0, a2))
			draw_string(UiKit.BOLD_FONT, Vector2(-40, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 80, 22, Color(color, a2))

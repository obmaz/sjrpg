class_name ActorSprite
extends Node2D
## Draws one atlas frame with its feet anchor at the node origin.

var atlas: ActorAtlas
var frame := 0
var body_height := 64.0
var flash := 0.0
var tint := Color.WHITE
var shadow := true
## Presentation only: simulation, attacks and movement continue during this brief contact pose.
var contact_hold := 0.0
var _contact_started := false
var _contact_recovery := 0.0


func set_frame(a: ActorAtlas, index: int) -> void:
	# A new action/atlas must win immediately (roll, run, revive), never inherit an old hit pose.
	if a != atlas:
		clear_contact_hold()
	elif contact_hold > 0.0 and not Prefs.reduce_motion:
		return
	if a != atlas or index != frame:
		atlas = a
		frame = index
		queue_redraw()


func hold_contact(duration: float) -> void:
	if Prefs.reduce_motion:
		clear_contact_hold()
		return
	if _contact_recovery > 0.0:
		return
	contact_hold = maxf(contact_hold, clampf(duration, 0.0, 0.065))
	_contact_started = false
	_contact_recovery = 0.10  # Rapid damage ticks must not pin an actor's presentation indefinitely.


func clear_contact_hold() -> void:
	contact_hold = 0.0
	_contact_started = false
	_contact_recovery = 0.0


func _process(delta: float) -> void:
	_contact_recovery = maxf(0.0, _contact_recovery - delta)
	if Prefs.reduce_motion:
		clear_contact_hold()
	elif contact_hold > 0.0:
		# Retain one contact frame even when the first browser frame is slow, then expire normally.
		contact_hold = maxf(0.0, contact_hold - (minf(delta, 0.012) if not _contact_started else delta))
		_contact_started = true
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 4.0)
		queue_redraw()


func _draw() -> void:
	if shadow:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.42))
		draw_circle(Vector2.ZERO, body_height * 0.36, Color(0, 0, 0, 0.28))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if atlas == null or atlas.texture == null or frame >= atlas.regions.size():
		return
	var scale_factor := body_height / atlas.ref_height
	var region := atlas.regions[frame]
	var dest := Rect2(-atlas.anchors[frame] * scale_factor, region.size * scale_factor)
	var color := tint
	if flash > 0.0:
		color = tint.lerp(Color(1.0, 0.45, 0.4, tint.a), flash)
	draw_texture_rect_region(atlas.texture, dest, region, color)

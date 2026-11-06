class_name ActorSprite
extends Node2D
## Draws one atlas frame with its feet anchor at the node origin.

var atlas: ActorAtlas
var frame := 0
var body_height := 64.0
var flash := 0.0
var flash_tint := Color(1.0, 0.45, 0.4)
var _flash_presented := false
var _flash_overlay: FlashOverlay
const FLASH_SHADER := preload("res://scripts/hit_flash.gdshader")
var tint := Color.WHITE
var shadow := true
## Presentation only: simulation, attacks and movement continue during this brief contact pose.
var contact_hold := 0.0
var _contact_started := false
var _contact_recovery := 0.0


func _ready() -> void:
	add_to_group("daylight_bodies")


func set_frame(a: ActorAtlas, index: int) -> void:
	# A new action/atlas must win immediately (roll, run, revive), never inherit an old hit pose.
	if a != atlas:
		clear_contact_hold()
	elif contact_hold > 0.0 and not Prefs.reduce_motion:
		return
	if a != atlas or index != frame:
		atlas = a
		frame = index
		_sync_flash_overlay()
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


## A short first presentation survives slow browser frames without extending rapid-hit flashes forever.
func trigger_flash(color: Color) -> void:
	if flash <= 0.0:
		_flash_presented = false
	flash_tint = color
	flash = 0.35 if Prefs.reduce_motion else 1.0
	_sync_flash_overlay()
	queue_redraw()


func clear_flash() -> void:
	flash = 0.0
	_flash_presented = false
	_sync_flash_overlay()
	queue_redraw()


func _process(delta: float) -> void:
	_contact_recovery = maxf(0.0, _contact_recovery - delta)
	if Prefs.reduce_motion:
		flash = minf(flash, 0.35)
		clear_contact_hold()
	elif contact_hold > 0.0:
		# Retain one contact frame even when the first browser frame is slow, then expire normally.
		contact_hold = maxf(0.0, contact_hold - (minf(delta, 0.012) if not _contact_started else delta))
		_contact_started = true
	if flash > 0.0:
		var flash_delta := minf(delta, 0.012) if not _flash_presented and not Prefs.reduce_motion else delta
		flash = maxf(0.0, flash - flash_delta * 4.0)
		_flash_presented = true
		_sync_flash_overlay()
		queue_redraw()


func _draw() -> void:
	if shadow:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.42))
		draw_circle(Vector2.ZERO, body_height * 0.36, Color(0, 0, 0, 0.28))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if atlas == null or atlas.texture == null or frame < 0 or frame >= atlas.regions.size():
		return
	var scale_factor := body_height / atlas.ref_height
	var region := atlas.regions[frame]
	var dest := Rect2(-atlas.anchors[frame] * scale_factor, region.size * scale_factor)
	draw_texture_rect_region(atlas.texture, dest, region, tint * WorldLighting.color_at(global_position))
	_sync_flash_overlay()


## A separate child material brightens the body silhouette without modifying base tint or its ground shadow.
func _sync_flash_overlay() -> void:
	if flash <= 0.0 or atlas == null or atlas.texture == null or frame < 0 or frame >= atlas.regions.size():
		if _flash_overlay != null:
			_flash_overlay.hide()
		return
	if _flash_overlay == null:
		_flash_overlay = FlashOverlay.new()
		var created_material := ShaderMaterial.new()
		created_material.shader = FLASH_SHADER
		_flash_overlay.material = created_material
		add_child(_flash_overlay)
	var scale_factor := body_height / atlas.ref_height
	_flash_overlay.texture = atlas.texture
	_flash_overlay.region = atlas.regions[frame]
	_flash_overlay.destination = Rect2(-atlas.anchors[frame] * scale_factor, _flash_overlay.region.size * scale_factor)
	var overlay_material := _flash_overlay.material as ShaderMaterial
	overlay_material.set_shader_parameter("flash_color", flash_tint.lerp(Color.WHITE, 0.35))
	overlay_material.set_shader_parameter("flash_strength", 0.65 * minf(flash, 0.35 if Prefs.reduce_motion else 1.0))
	_flash_overlay.show()
	_flash_overlay.queue_redraw()


class FlashOverlay:
	extends Node2D
	var texture: Texture2D
	var region := Rect2()
	var destination := Rect2()

	func _draw() -> void:
		if texture != null:
			draw_texture_rect_region(texture, destination, region)

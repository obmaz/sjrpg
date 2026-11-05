class_name CanopyShade
extends Node2D
## Ground-only billboard shadow from the actual tree atlas alpha, never a tile overlay.
## A 2D tree has no recoverable 3D crown volume: apparent height is projected along
## a shared screen-world sun direction. This is an approximation for flat town trees.
## The receiver must share the caster's canvas/viewport; raised terrain is not sampled.

const MAX_TOWN_CASTERS := 6
const GROUND_Z := -8  # Above paving (-9), below all world objects/raised yards (0+).
const SHADER_CODE := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D canopy_alpha : filter_linear, repeat_disable;
uniform vec4 atlas_region;
uniform vec2 atlas_texel;
uniform float opacity = 0.11;
uniform bool economy = false;
varying float vertex_alpha;
void vertex() { vertex_alpha = COLOR.a; }
float silhouette(vec2 uv) {
	if (uv.x < atlas_region.x || uv.y < atlas_region.y ||
		uv.x > atlas_region.x + atlas_region.z || uv.y > atlas_region.y + atlas_region.w) {
		return 0.0;
	}
	return texture(canopy_alpha, uv).a;
}
void fragment() {
	vec2 d = atlas_texel * 4.0;
	float a = silhouette(UV) * 4.0;
	a += silhouette(UV + vec2(d.x, 0.0)) + silhouette(UV - vec2(d.x, 0.0));
	a += silhouette(UV + vec2(0.0, d.y)) + silhouette(UV - vec2(0.0, d.y));
	float weight = 8.0;
	if (!economy) {
		a += 0.5 * (silhouette(UV + d) + silhouette(UV - d));
		a += 0.5 * (silhouette(UV + vec2(d.x, -d.y)) + silhouette(UV + vec2(-d.x, d.y)));
		weight = 10.0;
	}
	// RGB comes from the common light model; the silhouette/leaf holes are source alpha only.
	COLOR = vec4(0.08, 0.10, 0.10, a / weight * opacity * vertex_alpha);
}
"""

static var _shader: Shader
var caster: IsoSprite
var sun_direction := Vector2(0.72, 0.48)
var cast_length := 0.68
var opacity := 0.11
var refresh_count := 0
var _source := Rect2()
var _foot := Vector2.ZERO
var _texture: Texture2D
var _initialized := false
var _last_caster := Transform2D.IDENTITY
var _last_receiver := Transform2D.IDENTITY
var _last_k := -1.0
var _last_flip := false
var _last_gvs := 1.0
var _last_gvk := 0.0
var _last_light := Vector2.ZERO
var _last_length := -1.0
var _last_alpha := -1.0
var _last_economy := false


static func attach(source: IsoSprite, receiver: Node2D) -> CanopyShade:
	if not is_instance_valid(source) or not is_instance_valid(receiver) or source.texture == null:
		return null
	# Existing tree art is affine. A structural texture warp needs its own projected
	# mesh; refusing it avoids a shadow that disagrees with the visible caster.
	if source.def.has("warp") or source.get_viewport() != receiver.get_viewport():
		return null
	var count := 0
	for child in receiver.get_children():
		if child is CanopyShade and not child.is_queued_for_deletion():
			if child.caster == source:
				return child
			count += 1
	if count >= MAX_TOWN_CASTERS:
		return null
	var shade := CanopyShade.new()
	shade.caster = source
	receiver.add_child(shade)
	return shade


func _ready() -> void:
	z_as_relative = false
	z_index = GROUND_Z
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	var ink := ShaderMaterial.new()
	ink.shader = _shader
	material = ink
	refresh()


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	if not is_instance_valid(caster) or caster.is_queued_for_deletion():
		queue_free()
		return
	visible = caster.is_visible_in_tree()
	var receiver := get_parent() as Node2D
	if receiver == null or material == null:
		return
	var src: Array = caster.def["source"]
	var foot: Array = caster.def["foot"]
	var source_rect := Rect2(src[0], src[1], src[2], src[3])
	var contact := Vector2(foot[0], foot[1])
	var caster_pose := caster.global_transform
	var receiver_pose := receiver.global_transform
	if absf(receiver_pose.determinant()) < 0.000001:
		visible = false
		return
	var gvs: float = caster.def.get("gvs", 1.0)
	var gvk: float = caster.def.get("gvk", 0.0)
	var alpha := clampf(opacity, 0.0, 0.18) * caster.modulate.a * caster.self_modulate.a * caster.modulate_color.a
	if _initialized and caster_pose == _last_caster and receiver_pose == _last_receiver and caster.k == _last_k and caster.flip == _last_flip and gvs == _last_gvs and gvk == _last_gvk and sun_direction == _last_light and cast_length == _last_length and source_rect == _source and contact == _foot and caster.texture == _texture and alpha == _last_alpha and Prefs.low_resolution == _last_economy:
		return
	_source = source_rect
	_foot = contact
	_texture = caster.texture
	_last_caster = caster_pose
	_last_receiver = receiver_pose
	_last_k = caster.k
	_last_flip = caster.flip
	_last_gvs = gvs
	_last_gvk = gvk
	_last_light = sun_direction
	_last_length = cast_length
	_last_alpha = alpha
	_last_economy = Prefs.low_resolution
	_initialized = true
	var light := sun_direction.normalized() if sun_direction.length_squared() > 0.001 else Vector2(0.83205, 0.5547)
	# Match the painted lateral width/flip. Its upward apparent height becomes
	# ground displacement away from the light; the source foot maps exactly to zero.
	var x_axis := caster_pose.x * caster.k * (-1.0 if caster.flip else 1.0) + caster_pose.y * caster.k * gvk
	var height_per_pixel := caster_pose.y.length() * caster.k * absf(gvs)
	var y_axis := -light * height_per_pixel * clampf(cast_length, 0.1, 1.2)
	var projection := Transform2D(x_axis, y_axis, caster_pose.origin)
	transform = receiver_pose.affine_inverse() * projection
	var ink := material as ShaderMaterial
	var atlas_size := _texture.get_size()
	ink.set_shader_parameter("canopy_alpha", _texture)
	ink.set_shader_parameter("atlas_region", Vector4(_source.position.x / atlas_size.x, _source.position.y / atlas_size.y, _source.size.x / atlas_size.x, _source.size.y / atlas_size.y))
	ink.set_shader_parameter("atlas_texel", Vector2.ONE / atlas_size)
	ink.set_shader_parameter("opacity", alpha)
	ink.set_shader_parameter("economy", Prefs.low_resolution)
	refresh_count += 1
	queue_redraw()


func projected_point(atlas_pixel: Vector2) -> Vector2:
	return global_transform * (atlas_pixel - _foot)


func _draw() -> void:
	if _texture != null:
		draw_texture_rect_region(_texture, Rect2(_source.position - _foot, _source.size), _source)

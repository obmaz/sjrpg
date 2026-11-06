class_name WorldLighting
extends RefCounted
## Shared source-preserving daylight. Ground, scenery and actor feet use one model;
## effects/UI retain their own materials, and the hidden forest contributes no cave tint.

const SHADER := preload("res://scripts/world_daylight.gdshader")
const AMBIENT := Vector3(0.58, 0.66, 0.72)
const DIRECT := Vector3(0.58, 0.44, 0.27)

static var _material: ShaderMaterial
static var _materials: Array[WeakRef] = []
static var _openings := PackedVector2Array()
static var _forest: WeakRef
static var _requested := true
static var _applied := false


static func configure(openings: PackedVector2Array, forest_root: Node2D = null) -> void:
	_openings = openings.duplicate()
	_forest = weakref(forest_root) if forest_root != null else null
	if forest_root != null and not forest_root.visibility_changed.is_connected(_sync_materials):
		forest_root.visibility_changed.connect(_sync_materials)
	_requested = true
	_prune()
	for handle in _materials:
		var ink := handle.get_ref() as ShaderMaterial
		if ink != null:
			_bind_openings(ink)
	_sync_materials()


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		register_material(_material)
	return _material


## An amount of zero is still an unshaded material. Never assign this material
## to cave receivers: they need their ordinary canvas light pass for lanterns.
static func belongs_to_forest(item: Node) -> bool:
	var ancestor := item
	while ancestor != null:
		if ancestor.is_in_group("forest_daylight"):
			return true
		ancestor = ancestor.get_parent()
	return false


static func register_material(ink: ShaderMaterial) -> void:
	_prune()
	for handle in _materials:
		if handle.get_ref() == ink:
			return
	_materials.append(weakref(ink))
	_bind_openings(ink)
	ink.set_shader_parameter("daylight_amount", 1.0 if is_enabled() else 0.0)


static func _prune() -> void:
	_materials = _materials.filter(func(handle: WeakRef) -> bool: return handle.get_ref() != null)


static func _bind_openings(ink: ShaderMaterial) -> void:
	if _openings.size() >= 2:
		ink.set_shader_parameter("opening_a", _openings[0])
		ink.set_shader_parameter("opening_b", _openings[1])


static func is_enabled() -> bool:
	if not _requested or _openings.size() < 2:
		return false
	if _forest != null:
		var root := _forest.get_ref() as Node2D
		return root != null and root.is_visible_in_tree()
	return true


static func set_enabled(value: bool) -> void:
	if _requested == value:
		return
	_requested = value
	_sync_materials()


static func _sync_materials() -> void:
	_applied = is_enabled()
	_prune()
	for handle in _materials:
		var ink := handle.get_ref() as ShaderMaterial
		if ink != null:
			ink.set_shader_parameter("daylight_amount", 1.0 if _applied else 0.0)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		for item in tree.get_nodes_in_group("daylight_bodies"):
			(item as CanvasItem).queue_redraw()


## CPU equivalent for actor/NPC body texture tint. Labels, contact flash and shadow
## are separate draws and remain readable. Sampling feet keeps tall bodies coherent.
static func color_at(position: Vector2) -> Color:
	if not is_enabled():
		return Color.WHITE
	var a := _opening(position, _openings[0], Vector2(425.0, 246.5))
	var b := _opening(position, _openings[1], Vector2(1100.0, 638.0))
	var sun := 1.0 - (1.0 - a) * (1.0 - b)
	var rgb := AMBIENT + DIRECT * sun
	return Color(rgb.x, rgb.y, rgb.z, 1.0)


static func _opening(position: Vector2, center: Vector2, radius: Vector2) -> float:
	var r := clampf(((position - center) / radius).length(), 0.0, 1.0)
	var phase := r * 0.5 + r * r * 0.5
	return 1.0 - smoothstep(0.0, 1.0, phase)

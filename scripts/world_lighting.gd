class_name WorldLighting
extends RefCounted
## Shared source-preserving daylight. Ground, scenery and actor feet use one model;
## effects/UI retain their own materials, and the hidden forest contributes no cave tint.

const SHADER := preload("res://scripts/world_daylight.gdshader")
const AMBIENT := Vector3(0.58, 0.66, 0.72)
const DIRECT := Vector3(0.58, 0.44, 0.27)
const CONTACT_LIMIT := 2
const CONTACT_MATERIAL_LIMIT := 128
const CONTACT_SHADER_LIMIT := 16
const CONTACT_GROUND_Y := 0.577350269
const CONTACT_LIGHT_PARAMS := [&"contact_light_a", &"contact_light_b"]
const CONTACT_COLOR_PARAMS := [&"contact_color_a", &"contact_color_b"]

static var _material: ShaderMaterial
static var _materials: Array[WeakRef] = []
static var _openings := PackedVector2Array()
static var _forest: WeakRef
static var _requested := true
static var _applied := false
static var _contact_materials: Array[WeakRef] = []
static var _contacts: Array[ContactPulse] = []
static var _contact_sync_queued := false
static var _contact_shaders: Array[ContactShader] = []
static var _contact_states: Dictionary = {}


class ContactShader:
	extends RefCounted
	var base: WeakRef
	var active: Shader


class ContactMaterial:
	extends RefCounted
	var material: WeakRef
	# Dynamic ground shaders would be released while every receiver uses active.
	# Retain their base only while the weakly referenced receiver remains alive.
	var base: Shader
	var active: Shader


class ContactPulse:
	extends RefCounted
	var position := Vector2.ZERO
	var color := Vector3.ONE
	var radius := 145.0
	var strength := 0.28
	var duration := 0.16
	var age := 0.0
	var presented := false


static func configure(openings: PackedVector2Array, forest_root: Node2D = null, contact_materials: Array[ShaderMaterial] = []) -> void:
	_contacts.clear()
	_openings = openings.duplicate()
	_forest = weakref(forest_root) if forest_root != null else null
	if forest_root != null and not forest_root.visibility_changed.is_connected(_sync_materials):
		forest_root.visibility_changed.connect(_sync_materials)
	_requested = true
	_prune()
	for ink in contact_materials:
		register_contact_material(ink)
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
	register_contact_material(ink)


static func _prune() -> void:
	_materials = _materials.filter(func(handle: WeakRef) -> bool: return handle.get_ref() != null)
	_contact_materials = _contact_materials.filter(func(handle: WeakRef) -> bool: return handle.get_ref() != null)
	for key in _contact_states.keys():
		var state: ContactMaterial = _contact_states[key]
		if state.material.get_ref() == null:
			_contact_states.erase(key)
	_contact_shaders = _contact_shaders.filter(func(pair: ContactShader) -> bool: return pair.base.get_ref() != null)


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
	if not _applied:
		_contacts.clear()
	_prune()
	for handle in _materials:
		var ink := handle.get_ref() as ShaderMaterial
		if ink != null:
			ink.set_shader_parameter("daylight_amount", 1.0 if _applied else 0.0)
	_publish_contacts()


static func _redraw_bodies() -> void:
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
	var rgb := AMBIENT + DIRECT * sun + _contact_at(position)
	return Color(rgb.x, rgb.y, rgb.z, 1.0)


static func _opening(position: Vector2, center: Vector2, radius: Vector2) -> float:
	var r := clampf(((position - center) / radius).length(), 0.0, 1.0)
	var phase := r * 0.5 + r * r * 0.5
	return 1.0 - smoothstep(0.0, 1.0, phase)


## Ground clones use the same contact uniforms but keep their own daylight switch.
## Weak references and a fixed live limit cannot retain previous scene materials.
static func register_contact_material(ink: ShaderMaterial) -> void:
	_prune()
	for handle in _contact_materials:
		if handle.get_ref() == ink:
			return
	if _contact_materials.size() >= CONTACT_MATERIAL_LIMIT:
		# An unregistered receiver cannot follow expiry, so it must never retain a pulse.
		_bind_contacts(ink, false)
		return
	var active_shader := _prepare_contact_shader(ink.shader)
	if active_shader == null:
		_bind_contacts(ink, false)
		return
	var state := ContactMaterial.new()
	state.material = weakref(ink)
	state.base = ink.shader
	state.active = active_shader
	_contact_states[ink.get_instance_id()] = state
	_contact_materials.append(weakref(ink))
	_bind_contacts(ink)


## Compile-time variants keep the idle fragment path free of contact arithmetic.
## Preparation/metadata parsing happens at registration, never in the hit callback.
static func _prepare_contact_shader(base: Shader) -> Shader:
	if base == null:
		return null
	for pair in _contact_shaders:
		if pair.base.get_ref() == base:
			return pair.active
	if _contact_shaders.size() >= CONTACT_SHADER_LIMIT or not base.code.contains("world_daylight.gdshaderinc"):
		return null
	var active := Shader.new()
	active.code = base.code.replace("shader_type canvas_item;", "shader_type canvas_item;\n#define WORLD_CONTACT_LIGHTS")
	# Ask the renderer to prepare/validate the variant's uniform metadata now.
	active.get_shader_uniform_list()
	var pair := ContactShader.new()
	pair.base = weakref(base)
	pair.active = active
	_contact_shaders.append(pair)
	return active


static func _use_contact_shader(ink: ShaderMaterial, enabled: bool) -> void:
	var state: ContactMaterial = _contact_states.get(ink.get_instance_id())
	if state == null:
		return
	var target := state.active if enabled else state.base
	if ink.shader == target:
		return
	# Keep the SAME material resource. Save all assignable uniforms, including
	# defaults/null textures; arbitrary ground masks, water phase and gate state
	# must survive both directions of a shader switch.
	var values := {}
	for property in ink.get_property_list():
		var path: String = property["name"]
		if path.begins_with("shader_parameter/"):
			var uniform := StringName(path.trim_prefix("shader_parameter/"))
			values[uniform] = ink.get_shader_parameter(uniform)
	ink.shader = target
	for uniform in values:
		ink.set_shader_parameter(uniform, values[uniform])


## Called only by confirmed contact artwork. No new hitbox, damage or light node.
static func pulse(position: Vector2, tint: Color, heavy := false) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if not is_enabled() or (tree != null and tree.paused):
		return
	var strength := 0.4 if heavy else 0.28
	var selected: ContactPulse
	for contact in _contacts:
		if contact.position.distance_squared_to(position) < 36.0 * 36.0:
			selected = contact
			break
	if selected == null:
		if _contacts.size() < CONTACT_LIMIT:
			selected = ContactPulse.new()
			_contacts.append(selected)
		else:
			selected = _contacts[0] if _contact_strength(_contacts[0]) <= _contact_strength(_contacts[1]) else _contacts[1]
		selected.position = position
		selected.age = 0.0
		selected.presented = false
		selected.strength = strength
		selected.duration = 0.22 if heavy else 0.16
		selected.radius = 185.0 if heavy else 145.0
		selected.color = Vector3(tint.r, tint.g, tint.b).clamp(Vector3.ZERO, Vector3.ONE)
	elif strength >= selected.strength:
		selected.strength = strength
		selected.duration = maxf(selected.duration, 0.22 if heavy else 0.16)
		selected.radius = maxf(selected.radius, 185.0 if heavy else 145.0)
		selected.color = Vector3(tint.r, tint.g, tint.b).clamp(Vector3.ZERO, Vector3.ONE)
	_queue_contact_sync()


## The ordinary game clock pauses with the tree. Preserve one first presentation
## on slow browsers, then let contacts expire even if rendering never occurs.
static func advance(delta: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if _contacts.is_empty() or (tree != null and tree.paused):
		return
	if not is_enabled():
		_contacts.clear()
	else:
		for contact in _contacts:
			contact.age += minf(maxf(delta, 0.0), 0.012) if not contact.presented else maxf(delta, 0.0)
			contact.presented = true
		_contacts = _contacts.filter(func(contact: ContactPulse) -> bool: return contact.age < contact.duration)
	_queue_contact_sync()


static func _contact_strength(contact: ContactPulse) -> float:
	var phase := clampf(contact.age / contact.duration, 0.0, 1.0)
	return contact.strength * (1.0 - phase) * (1.0 - phase) * (0.4 if Prefs.reduce_motion else 1.0)


static func _contact_at(position: Vector2) -> Vector3:
	var result := Vector3.ZERO
	for contact in _contacts:
		var radius := Vector2(contact.radius, contact.radius * CONTACT_GROUND_Y)
		var falloff := maxf(0.0, 1.0 - ((position - contact.position) / radius).length())
		result += contact.color * _contact_strength(contact) * falloff * falloff
	return result.clamp(Vector3.ZERO, Vector3.ONE * 0.55)


static func _queue_contact_sync() -> void:
	if _contact_sync_queued:
		return
	_contact_sync_queued = true
	_publish_contacts.call_deferred()


## Settings can change while the game clock is paused. Refresh energy, not age.
static func refresh_contacts() -> void:
	if not _contacts.is_empty():
		_queue_contact_sync()


static func _publish_contacts() -> void:
	_contact_sync_queued = false
	_prune()
	for handle in _contact_materials:
		var ink := handle.get_ref() as ShaderMaterial
		if ink != null:
			_bind_contacts(ink)
	_redraw_bodies()


static func _bind_contacts(ink: ShaderMaterial, allowed := true) -> void:
	var active := allowed and is_enabled()
	_use_contact_shader(ink, active and not _contacts.is_empty())
	for index in CONTACT_LIMIT:
		var light := Vector4.ZERO
		var tint := Vector3.ZERO
		if active and index < _contacts.size():
			var contact := _contacts[index]
			light = Vector4(contact.position.x, contact.position.y, contact.radius, _contact_strength(contact))
			tint = contact.color
		ink.set_shader_parameter(CONTACT_LIGHT_PARAMS[index], light)
		ink.set_shader_parameter(CONTACT_COLOR_PARAMS[index], tint)

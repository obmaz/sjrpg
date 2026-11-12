class_name CombatEffects3D
extends RefCounted
## Missing generic projectile pictures only. Source effects retain all rules and clocks.
const MAX_PROJECTILES := 32
static var _shader: Shader
var _renderer: Node
var _atlas: Texture2D
var _entries := {}

func setup(presenter: Node) -> CombatEffects3D:
	_renderer = presenter
	_atlas = load("res://" + str(PresentationArt.data()["impact"]["path"]))
	if _shader == null:
		_shader = Shader.new()
		# Spatial shots use real depth, unlike the authored overlay-style skill cards.
		_shader.code = WorldRenderer3D.CARD_CODE.replace("blend_mix", "blend_add")
	return self

static func supports(source: Effect) -> bool:
	return source.kind == "proj" and not bool(source.params.get("throw", false)) and str(source.params.get("visual", "")).is_empty()

func sync() -> void:
	var current := {}
	var children: Array[Effect] = Effect.in_world(_renderer.game.world)
	# A bounded recent-shot picture cannot remove any gameplay projectile.
	for index in range(children.size() - 1, -1, -1):
		var source := children[index]
		if not is_instance_valid(source) or source.is_queued_for_deletion() or not supports(source) or source.age >= source.life:
			continue
		var at := source.native_position()
		if not at.is_finite():
			continue
		var id := source.get_instance_id()
		current[id] = true
		if not _entries.has(id):
			_entries[id] = _create(source)
		_update(_entries[id], source, at)
		if current.size() >= MAX_PROJECTILES:
			break
	for id in _entries.keys():
		if not current.has(id):
			var root: Node3D = _entries[id]["root"]
			root.hide()
			root.queue_free()
			_entries.erase(id)

func _create(source: Effect) -> Dictionary:
	var root := Node3D.new()
	root.name = "NativeGenericProjectile"
	_renderer.stage.add_child(root)
	var cards: Array[MeshInstance3D] = []
	var cell := Effect._element_cell(source.color)
	for label in ["Body", "Tail"]:
		var card: MeshInstance3D = _renderer._new_card(_atlas, PresentationArt.impact_frame(cell, 1), false)
		(card.material_override as ShaderMaterial).shader = _shader
		card.name = label
		card.reparent(root, false)
		cards.append(card)
	return {"root": root, "body": cards[0], "tail": cards[1], "source": weakref(source), "last": source.native_position(), "last_age": source.age, "previous": source.native_position(), "previous_age": source.age, "direction": Vector3.ZERO, "cell": cell}

func _update(entry: Dictionary, source: Effect, at: Vector3) -> void:
	entry["previous"] = entry["last"]
	entry["previous_age"] = entry["last_age"]
	entry["last_age"] = source.age
	var movement: Vector3 = at - entry["last"]
	if movement.length_squared() > 0.00000001:
		entry["direction"] = movement.normalized()
	elif (Vector3(entry["direction"])).is_zero_approx():
		entry["direction"] = WorldRenderer3D.ground_position(source.velocity).normalized()
	entry["last"] = at
	var body: MeshInstance3D = entry["body"]
	var tail: MeshInstance3D = entry["tail"]
	var cell := Effect._element_cell(source.color)
	entry["cell"] = cell
	_renderer._set_card_frame(body, _atlas, PresentationArt.impact_frame(cell, 1))
	_renderer._set_card_frame(tail, _atlas, PresentationArt.impact_frame(cell, 1))
	var flicker := 1.0 if Prefs.reduce_motion else 1.0 + 0.08 * sin(source.age * 30.0)
	var width := 44.0 * flicker
	_renderer._place_card(body, source.position, Rect2(Vector2.ONE * -width * 0.5, Vector2.ONE * width), 0.0, at)
	(body.material_override as ShaderMaterial).set_shader_parameter("tint", Color(1, 1, 1, 0.65 if Prefs.reduce_motion else 0.9))
	var direction: Vector3 = entry["direction"]
	var speed := WorldRenderer3D.ground_position(source.velocity).length()
	var distance := minf(maxf(source.age, 0.0) * speed, 0.32)
	tail.visible = not Prefs.reduce_motion and distance > 0.001 and not direction.is_zero_approx()
	if tail.visible:
		var screen_direction: Vector2 = _renderer.camera.unproject_position(at + direction) - _renderer.camera.unproject_position(at)
		var tail_at := at - direction * distance
		_renderer._place_card(tail, source.position, Rect2(Vector2(-16, -8), Vector2(32, 16)), screen_direction.angle(), tail_at)
		(tail.material_override as ShaderMaterial).set_shader_parameter("tint", Color(1, 1, 1, 0.24))

func snapshot() -> Dictionary:
	var sources := []
	for entry: Dictionary in _entries.values():
		var source: Effect = (entry["source"] as WeakRef).get_ref()
		if not is_instance_valid(source):
			continue
		var body: MeshInstance3D = entry["body"]
		var at := source.native_position()
		var screen: Vector2 = _renderer.camera.unproject_position(at)
		var previous: Vector3 = entry["previous"]
		sources.append({"id": source.get_instance_id(), "age": source.age, "life": source.life, "position": [at.x, at.y, at.z], "previous_position": [previous.x, previous.y, previous.z], "previous_age": entry["previous_age"], "screen": [screen.x, screen.y], "width": (body.mesh as QuadMesh).size.x * body.global_transform.basis.x.length(), "position_error": body.global_position.distance_to(at), "cell": entry["cell"], "tail": (entry["tail"] as MeshInstance3D).visible})
	return {"count": _entries.size(), "paused": _renderer.get_tree().paused, "reduce_motion": Prefs.reduce_motion, "sources": sources}

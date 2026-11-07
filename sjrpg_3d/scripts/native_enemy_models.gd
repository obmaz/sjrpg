class_name NativeEnemyModels
extends RefCounted
## Articulated volume models. Gameplay owns motion, attack and corpse clocks.
const KINDS := ["goblin", "wolf", "boar", "skeleton", "golem"]
var preview: Node
var entries := {}
static var _meshes := {}
static var _rig_meshes := {}

func setup(presenter: Node) -> NativeEnemyModels:
	preview = presenter
	return self

static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material

static func _part(parent: Node3D, shape: String, at: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var key := shape + str(dimensions)
	if not _meshes.has(key):
		var mesh: PrimitiveMesh
		if shape == "box":
			var box := BoxMesh.new()
			box.size = dimensions
			mesh = box
		elif shape == "cone":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = dimensions.x * 0.5
			cone.height = dimensions.y
			cone.radial_segments = 7
			mesh = cone
		else:
			var sphere := SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 1.0
			sphere.radial_segments = 10
			sphere.rings = 5
			mesh = sphere
		_meshes[key] = mesh
	var node := MeshInstance3D.new()
	node.mesh = _meshes[key]
	node.material_override = material
	parent.add_child(node)
	node.position = at
	if shape == "round":
		node.scale = dimensions
	return node

static func _pivot(parent: Node3D, at: Vector3) -> Node3D:
	var node := Node3D.new()
	parent.add_child(node)
	node.position = at
	return node

static func build(kind: String) -> Dictionary:
	var root := Node3D.new()
	root.name = "Native_" + kind
	var bone := _material(Color("b2aa88"))
	var hide := _material(Color("504c40"))
	var iron := _material(Color("4c5252"))
	var cloth := _material(Color("3a4852"))
	var skin := _material(Color("687751"))
	match kind:
		"skeleton": skin = bone
		"golem": skin = _material(Color("747665"))
		"wolf": skin = _material(Color("66685f"))
		"boar": skin = _material(Color("615243"))
	var materials: Array[StandardMaterial3D] = [skin, hide, iron, cloth, bone]
	var legs: Array[Node3D] = []
	var arms: Array[Node3D] = []
	var quadruped := kind in ["wolf", "boar"]
	var torso := _pivot(root, Vector3.ZERO)
	if quadruped:
		_part(torso, "round", Vector3(0, 0.66, 0), Vector3(0.55, 0.54, 1.02), skin)
		_part(torso, "round", Vector3(0, 0.74, 0.53), Vector3(0.42, 0.45, 0.46), skin)
		_part(torso, "round", Vector3(0, 0.66, 0.81), Vector3(0.28, 0.22, 0.32), hide)
		for side in [-1.0, 1.0]:
			_part(torso, "cone", Vector3(side * 0.15, 1.0, 0.49), Vector3(0.15, 0.28, 0.15), skin)
			for depth in [-0.22, 0.22]:
				var leg := _pivot(root, Vector3(side * 0.20, 0.57, depth))
				_part(leg, "round", Vector3(0, -0.23, 0), Vector3(0.14, 0.49, 0.15), skin)
				_part(leg, "round", Vector3(0, -0.49, 0.06), Vector3(0.18, 0.13, 0.27), hide)
				legs.append(leg)
			if kind == "boar":
				var tusk := _part(torso, "cone", Vector3(side * 0.18, 0.72, 0.84), Vector3(0.09, 0.22, 0.09), bone)
				tusk.rotation.x = -0.6
		var tail := _part(torso, "round", Vector3(0, 0.73, -0.66), Vector3(0.15, 0.18, 0.58 if kind == "wolf" else 0.18), skin)
		tail.rotation.x = -0.35
		if kind == "boar":
			for index in 6:
				_part(torso, "cone", Vector3(0, 0.98, -0.40 + index * 0.13), Vector3(0.10, 0.17, 0.10), hide)
	else:
		var wide := 1.45 if kind == "golem" else 1.0
		_part(torso, "round", Vector3(0, 1.03, 0), Vector3(0.54 * wide, 0.68, 0.32 * wide), skin if kind in ["skeleton", "golem"] else cloth)
		_part(torso, "round", Vector3(0, 1.49, 0), Vector3(0.31 * wide, 0.34, 0.32), skin)
		_part(torso, "box", Vector3(0, 1.47, 0.15), Vector3(0.22, 0.09, 0.05), hide)
		for side in [-1.0, 1.0]:
			_part(torso, "round", Vector3(side * 0.075, 1.52, 0.15), Vector3(0.05, 0.055, 0.045), hide)
			var leg := _pivot(root, Vector3(side * (0.12 if kind == "golem" else 0.15), 0.76, 0))
			_part(leg, "round", Vector3(0, -0.33, 0), Vector3(0.17 if kind == "golem" else 0.18, 0.66, 0.19), skin if kind == "skeleton" else hide)
			_part(leg, "round", Vector3(0, -0.69, 0.07), Vector3(0.18 if kind == "golem" else 0.23, 0.14, 0.35), hide)
			legs.append(leg)
			var arm := _pivot(torso, Vector3(side * 0.32 * wide, 1.25, 0))
			_part(arm, "round", Vector3(side * 0.04, -0.25, 0), Vector3(0.19 * wide, 0.55, 0.21), skin)
			_part(arm, "round", Vector3(side * 0.04, -0.54, 0), Vector3(0.17 * wide, 0.18, 0.18), skin)
			arms.append(arm)
			if kind == "goblin":
				var ear := _part(torso, "cone", Vector3(side * 0.22, 1.5, 0), Vector3(0.15, 0.31, 0.15), skin)
				ear.rotation.z = side * -1.1
			if kind == "skeleton":
				_part(arm, "round", Vector3(0, -0.02, 0), Vector3(0.27, 0.22, 0.28), iron)
		if kind in ["goblin", "skeleton"]:
			_part(arms[0], "box", Vector3(0, -0.47, 0.32), Vector3(0.08, 0.07, 0.70), iron)
			_part(arms[0], "box", Vector3(0, -0.47, 0.02), Vector3(0.30, 0.08, 0.06), bone)
			_part(arms[1], "round", Vector3(-0.04, -0.29, 0.15), Vector3(0.46, 0.59, 0.13), hide)
		if kind == "skeleton":
			for index in 4:
				_part(torso, "round", Vector3(0, 1.22 - index * 0.09, 0.09), Vector3(0.43 - index * 0.035, 0.045, 0.24), bone)
		if kind == "golem":
			for side in [-1.0, 1.0]:
				var rock := _part(torso, "box", Vector3(side * 0.40, 1.25, 0), Vector3(0.43, 0.39, 0.43), skin)
				rock.rotation.z = side * 0.25
			_part(torso, "round", Vector3(0, 1.04, 0.26), Vector3(0.16, 0.22, 0.07), cloth)
	_batch(kind, [torso] + legs + arms, materials)
	var base_colors: Array[Color] = []
	for material in materials:
		base_colors.append(material.albedo_color)
	return {"root": root, "torso": torso, "legs": legs, "arms": arms, "materials": materials, "colors": base_colors, "kind": kind, "base_height": 1.14 if quadruped else 1.72}

static func tint(model: Dictionary, color: Color, flash: float, flash_color: Color, alpha: float) -> void:
	var materials: Array = model["materials"]
	var colors: Array = model["colors"]
	for index in materials.size():
		var material := materials[index] as StandardMaterial3D
		var ink: Color = colors[index] * color
		ink = ink.lerp(flash_color, clampf(flash, 0.0, 0.65))
		ink.a = alpha
		material.albedo_color = ink
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 0.999 else BaseMaterial3D.TRANSPARENCY_DISABLED

static func pose(model: Dictionary, facing: float, cycle: float, attack: float, dead := false) -> void:
	var root: Node3D = model["root"]
	var direction := Iso.unproject(Vector2.from_angle(facing)).normalized()
	root.rotation.y = atan2(direction.x, direction.y)
	var legs: Array = model["legs"]
	for index in legs.size():
		var limb := legs[index] as Node3D
		limb.rotation.x = sin(cycle * TAU + (PI if index % 2 else 0.0)) * 0.48
	var arms: Array = model["arms"]
	for index in arms.size():
		var limb := arms[index] as Node3D
		limb.rotation.x = -sin(cycle * TAU + index * PI) * 0.26 - sin(attack * PI) * (1.7 if index == 0 else 0.4)
	var torso: Node3D = model["torso"]
	torso.rotation.x = -sin(attack * PI) * 0.20
	if dead:
		root.rotation.z = PI * 0.5
		torso.rotation.x = 0.0

func sync() -> void:
	var live := {}
	var candidates: Array = preview.game.enemies.duplicate()
	for entry: Dictionary in entries.values():
		var fading: Node = entry["owner"].get_ref()
		if is_instance_valid(fading) and not candidates.has(fading):
			candidates.append(fading)
	for candidate in candidates:
		if not is_instance_valid(candidate):
			continue
		var enemy := candidate as Enemy
		if enemy == null or enemy.is_queued_for_deletion():
			continue
		var id := enemy.get_instance_id()
		live[id] = true
		if not entries.has(id):
			var model := build(enemy.kind)
			model["owner"] = weakref(enemy)
			preview.stage.add_child(model["root"])
			entries[id] = model
		var model: Dictionary = entries[id]
		var root: Node3D = model["root"]
		var size := enemy.sprite.body_height / (Ortho3DPreview.GROUND_PER_METER * Iso.S) / float(model["base_height"])
		# JUICE #4: the 3D body follows the sprite's contact squash (feet stay planted at the root origin).
		var squash := enemy.sprite.squash_scale()
		root.scale = Vector3(size * squash.x, size * squash.y, size * squash.x)
		root.position = preview.actor_foot(enemy) + Ortho3DPreview.ground_position(enemy.sprite.position)
		root.visible = enemy.get_parent() == preview.game.world and enemy.sprite.visible
		var attack := 0.0
		if enemy._state == "windup":
			attack = 0.6 * clampf(1.0 - enemy._timer / enemy._windup_duration, 0.0, 1.0)
		elif enemy._state == "recover":
			attack = 0.6 + 0.4 * clampf((enemy._recover_duration - enemy._timer) / enemy._recover_visual_duration, 0.0, 1.0)
		var cycle := enemy._walk_cycle if enemy._state == "chase" or (enemy._state == "idle" and enemy._wander != Vector2.ZERO) else 0.0
		pose(model, enemy.facing, cycle, attack)
		tint(model, enemy.sprite.tint, enemy.sprite.flash, enemy.sprite.flash_tint, enemy.sprite.modulate.a * enemy.sprite.self_modulate.a)
	for id in entries.keys():
		if not live.has(id):
			(entries[id]["root"] as Node3D).queue_free()
			entries.erase(id)

func snapshot() -> Dictionary:
	return {"count": entries.size(), "kinds": KINDS, "volume": true}

static func place_corpse(presenter: Node, model: Dictionary, corpse: Dictionary) -> void:
	var root: Node3D = model["root"]
	var ratio := float(corpse.get("height", 62.0)) / (Ortho3DPreview.GROUND_PER_METER * Iso.S) / float(model["base_height"])
	root.scale = Vector3.ONE * ratio
	pose(model, float(corpse.get("facing", 0.0)), 0.0, 0.0, true)
	# Rest the whole rotated mesh on the real floor, not the old picture's square.
	var minimum := 0.0
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var local := root.global_transform.affine_inverse() * mesh.global_transform
		for index in 8:
			minimum = minf(minimum, (root.basis * (local * mesh.get_aabb().get_endpoint(index))).y)
	var at: Vector2 = corpse.get("pos", Vector2.ZERO)
	root.position = Ortho3DPreview.ground_position(at, presenter.surface_height(at) - minimum + 0.012)
	var opacity := CorpseArt.opacity(float(corpse.get("time", 0.0)), float(corpse.get("lifetime", 30.0)))
	root.visible = not bool(corpse.get("used", false)) and opacity > 0.0
	tint(model, Color.WHITE, 0.0, Color.WHITE, opacity)

static func _batch(kind: String, pivots: Array, materials: Array) -> void:
	# Merge authored pieces by joint and material; joints remain independently posed.
	for index in pivots.size():
		var pivot := pivots[index] as Node3D
		var groups := {}
		for child in pivot.get_children():
			var mesh := child as MeshInstance3D
			if mesh == null:
				continue
			var slot := materials.find(mesh.material_override)
			if not groups.has(slot):
				groups[slot] = []
			groups[slot].append(mesh)
		for slot in groups:
			var key := kind + "/" + str(index) + "/" + str(slot)
			if not _rig_meshes.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				for child: MeshInstance3D in groups[slot]:
					tool.append_from(child.mesh, 0, child.transform)
				_rig_meshes[key] = tool.commit()
			var merged := MeshInstance3D.new()
			merged.mesh = _rig_meshes[key]
			merged.material_override = materials[slot]
			pivot.add_child(merged)
			for child: MeshInstance3D in groups[slot]:
				child.free()

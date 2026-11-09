class_name NativeEnemyModels
extends RefCounted
## Articulated volume models. Gameplay owns motion, attack and corpse clocks.
const KINDS := ["goblin", "wolf", "boar", "skeleton", "golem"]
var preview: Node
var entries := {}
static var _rig_meshes := {}
static var _rest_bounds_by_kind := {}
## Immutable geometry/transform recipes contain no live Node or actor material references.
static var _recipes: Dictionary = {}
static var _recipe_hits := 0
static var _source_builds := 0
static var _surface_forms_built := 0

func setup(presenter: Node) -> NativeEnemyModels:
	preview = presenter
	return self

static func _material(color: Color, surface := "leather") -> StandardMaterial3D:
	# Independent uniform state per actor; generated surface textures remain shared.
	var result := NativeActorMaterials.material(surface, color).duplicate() as StandardMaterial3D
	result.set_meta("anatomy_surface", surface)
	return result

static func _pivot(parent: Node3D, at: Vector3) -> Node3D:
	var node := Node3D.new()
	parent.add_child(node)
	node.position = at
	return node

static func build(kind: String) -> Dictionary:
	if _recipes.has(kind):
		_recipe_hits += 1
		return _instantiate_recipe(_recipes[kind])
	_source_builds += 1
	var root: Node3D = Node3D.new()
	root.name = "Native_" + kind
	var bone: StandardMaterial3D = _material(Color("b7ae91"), "bone")
	var hide: StandardMaterial3D = _material(Color("514332"), "leather")
	var iron: StandardMaterial3D = _material(Color("454c4d"), "iron")
	var cloth: StandardMaterial3D = _material(Color("3b4545"), "cloth")
	var skin: StandardMaterial3D = _material(Color("697353"), "skin")
	var shadow: StandardMaterial3D = _material(Color("1f2520"), "leather")
	match kind:
		"skeleton": skin = bone
		"golem": skin = _material(Color("777a6b"), "rock")
		"wolf": skin = _material(Color("666c66"), "fur")
		"boar": skin = _material(Color("675643"), "fur")
	var surface_path: String = "beast_fur" if kind in ["wolf", "boar"] else ("grave_bone" if kind == "skeleton" else ("scar_skin" if kind == "goblin" else "rock_iron"))
	skin.albedo_texture = load("res://assets/art/preview3d/" + surface_path + ".webp")
	if kind == "golem":
		skin.albedo_color = Color(0.95, 1.0, 1.03)
	var eye: StandardMaterial3D = _material(Color("be693c"), "iron")
	eye.roughness = 0.28
	var materials: Array[StandardMaterial3D] = [skin, hide, iron, cloth, bone, shadow, eye]
	var legs: Array[Node3D] = []
	var arms: Array[Node3D] = []
	var quadruped: bool = kind in ["wolf", "boar"]
	var torso: Node3D = _pivot(root, Vector3.ZERO)
	if quadruped:
		var boar: bool = kind == "boar"
		# Long lean ribcage and high withers for wolf; heavy short barrel for boar.
		var body: MeshInstance3D = _form(torso, Vector3(0, 0.64, -0.40), [
			[-0.42, 0.12, 0.15, 0.0, 0.0], [-0.23, 0.23 if boar else 0.19, 0.27 if boar else 0.20, 0.0, 0.0],
			[0.21, 0.28 if boar else 0.22, 0.32 if boar else 0.27, 0.0, 0.03],
			[0.44, 0.21 if boar else 0.18, 0.25, 0.0, 0.0]], skin, 10, 0.035)
		body.rotation.x = PI * 0.5
		body.position.z = 0.0
		# Layered shoulder/chest planes, angular jaw, tapered skull and cheek.
		_form(torso, Vector3(0, 0, 0.28), [[0.45, 0.12, 0.13, 0.0, 0.0], [0.70, 0.25 if boar else 0.21, 0.22, 0.0, 0.0], [0.91, 0.18, 0.16, 0.0, 0.03]], skin, 8)
		var skull: MeshInstance3D = _form(torso, Vector3(0, 0.77, 0.49), [[-0.18, 0.13, 0.13, 0.0, 0.0], [-0.03, 0.20 if boar else 0.16, 0.20, 0.0, 0.0], [0.18, 0.15, 0.17, 0.0, -0.01], [0.24, 0.09, 0.10, 0.0, -0.03]], skin, 8)
		skull.rotation.x = -0.20
		_bone(torso, Vector3(0, 0.75, 0.58), Vector3(0, 0.63 if boar else 0.74, 0.88 if boar else 1.01), Vector2(0.12, 0.12), Vector2(0.10 if boar else 0.055, 0.075), skin, 7)
		_bone(torso, Vector3(-0.06, 0.64, 0.65), Vector3(0, 0.60 if boar else 0.68, 0.86 if boar else 0.98), Vector2(0.06, 0.045), Vector2(0.065, 0.027), hide, 6)
		_rock(torso, Vector3(0, 0.64 if boar else 0.75, 0.90 if boar else 1.035), Vector3(0.18 if boar else 0.11, 0.10, 0.075), shadow, 0)
		for side: float in [-1.0, 1.0]:
			var ear: MeshInstance3D = _form(torso, Vector3(side * 0.13, 0.96, 0.48), [[0.0, 0.09, 0.055, 0.0, 0.0], [0.11, 0.055, 0.035, side * 0.03, -0.03], [0.19 if not boar else 0.12, 0.004, 0.004, side * 0.02, -0.04]], skin, 4)
			ear.rotation.z = -side * (0.28 if not boar else 0.65)
			_bone(torso, Vector3(side * 0.13, 0.85, 0.65), Vector3(side * 0.18, 0.86, 0.56), Vector2(0.025, 0.018), Vector2(0.025, 0.018), shadow)
			_rock(torso, Vector3(side * 0.145, 0.85, 0.66), Vector3(0.035, 0.020, 0.035), eye, 0)
			for depth: float in [-0.22, 0.22]:
				var rear: bool = depth < 0.0
				var leg: Node3D = _pivot(root, Vector3(side * 0.18, 0.58, depth))
				var knee: Vector3 = Vector3(side * 0.015, -0.25, -0.09 if rear else 0.055)
				var hock: Vector3 = Vector3(0, -0.44, -0.025 if rear else 0.025)
				_bone(leg, Vector3.ZERO, knee, Vector2(0.09 if rear else 0.07, 0.09), Vector2(0.05, 0.055), skin)
				_bone(leg, knee, hock, Vector2(0.047, 0.05), Vector2(0.033, 0.035), skin)
				if boar:
					for toe: float in [-1.0, 1.0]:
						_form(leg, Vector3(toe * 0.027, -0.53, 0.045), [[-0.05, 0.025, 0.07, 0.0, 0.0], [0.055, 0.031, 0.055, 0.0, -0.01]], shadow, 5)
				else:
					_form(leg, Vector3(0, -0.53, 0.055), [[-0.05, 0.055, 0.095, 0.0, 0.0], [0.05, 0.065, 0.072, 0.0, -0.02]], skin, 7)
					for toe: float in [-1.0, 0.0, 1.0]:
						_bone(leg, Vector3(toe * 0.033, -0.55, 0.12), Vector3(toe * 0.033, -0.55, 0.155), Vector2(0.009, 0.012), Vector2(0.003, 0.003), bone)
				legs.append(leg)
			# 실제 곡면 주둥이 아래로 드러나는 위/아래 송곳니.
			if not boar:
				for tooth_z: float in [0.78, 0.90]:
					_bone(torso, Vector3(side * 0.075, 0.735, tooth_z), Vector3(side * 0.07, 0.665, tooth_z + 0.015), Vector2(0.018, 0.018), Vector2(0.002, 0.002), bone, 6)
			if boar:
				_bone(torso, Vector3(side * 0.14, 0.63, 0.79), Vector3(side * 0.22, 0.72, 0.88), Vector2(0.034, 0.03), Vector2(0.025, 0.022), bone)
				_bone(torso, Vector3(side * 0.22, 0.72, 0.88), Vector3(side * 0.21, 0.84, 0.85), Vector2(0.025, 0.022), Vector2(0.002, 0.002), bone)
		if boar:
			# A low broken bristle ridge, not dinosaur plates.
			for index: int in 10:
				_rock(torso, Vector3(0.015 * sin(index * 2.0), 0.94 + 0.035 * sin(index * 0.4), -0.35 + index * 0.075), Vector3(0.12, 0.075, 0.14), hide, index)
			_bone(torso, Vector3(0, 0.76, -0.44), Vector3(0.08, 0.70, -0.58), Vector2(0.025, 0.025), Vector2(0.012, 0.012), hide)
		else:
			_bone(torso, Vector3(0, 0.77, -0.42), Vector3(0, 0.62, -0.78), Vector2(0.09, 0.09), Vector2(0.075, 0.07), skin)
			_bone(torso, Vector3(0, 0.62, -0.78), Vector3(0.04, 0.44, -1.02), Vector2(0.075, 0.07), Vector2(0.008, 0.008), skin)
			for side: float in [-1.0, 1.0]:
				_bone(torso, Vector3(side * 0.16, 0.82, 0.36), Vector3(side * 0.25, 0.65, 0.21), Vector2(0.06, 0.04), Vector2(0.003, 0.003), skin)
	else:
		if kind == "skeleton":
			# Empty chest: paired curved ribs attach to a visible spine and sternum.
			_bone(torso, Vector3(0, 0.82, -0.07), Vector3(0, 1.36, -0.07), Vector2(0.035, 0.035), Vector2(0.035, 0.035), bone)
			_bone(torso, Vector3(0, 1.02, 0.13), Vector3(0, 1.27, 0.13), Vector2(0.022, 0.022), Vector2(0.03, 0.03), bone)
			for level: int in 5:
				var y: float = 1.26 - level * 0.075
				var width: float = 0.22 - absf(level - 1.0) * 0.025
				for side: float in [-1.0, 1.0]:
					var a: Vector3 = Vector3(0, y + 0.01, -0.07)
					var b: Vector3 = Vector3(side * width, y, 0.0)
					var c: Vector3 = Vector3(side * width * 0.74, y - 0.025, 0.135)
					var d: Vector3 = Vector3(side * 0.025, y - 0.035, 0.15)
					_bone(torso, a, b, Vector2(0.018, 0.02), Vector2(0.018, 0.02), bone, 6)
					_bone(torso, b, c, Vector2(0.018, 0.02), Vector2(0.016, 0.018), bone, 6)
					_bone(torso, c, d, Vector2(0.016, 0.018), Vector2(0.013, 0.015), bone, 6)
			for side: float in [-1.0, 1.0]:
				_bone(torso, Vector3(side * 0.07, 0.82, -0.05), Vector3(side * 0.19, 0.84, 0.035), Vector2(0.06, 0.04), Vector2(0.055, 0.035), bone)
				_bone(torso, Vector3(side * 0.19, 0.84, 0.035), Vector3(side * 0.07, 0.76, 0.09), Vector2(0.055, 0.035), Vector2(0.025, 0.025), bone)
			_form(torso, Vector3(0, 1.38, 0), [[0.0, 0.09, 0.095, 0.0, -0.02], [0.10, 0.14, 0.12, 0.0, -0.04], [0.25, 0.125, 0.11, 0.0, -0.04], [0.30, 0.06, 0.055, 0.0, -0.04]], bone, 9)
			_bone(torso, Vector3(-0.09, 1.40, 0.06), Vector3(0.09, 1.40, 0.06), Vector2(0.025, 0.035), Vector2(0.025, 0.035), bone)
			for side: float in [-1.0, 1.0]:
				_rock(torso, Vector3(side * 0.064, 1.55, 0.09), Vector3(0.095, 0.075, 0.026), shadow, 1)
				_rock(torso, Vector3(side * 0.064, 1.55, 0.108), Vector3(0.022, 0.017, 0.012), eye, 0)
				_bone(torso, Vector3(side * 0.12, 1.60, 0.11), Vector3(side * 0.025, 1.60, 0.14), Vector2(0.022, 0.023), Vector2(0.025, 0.022), bone)
				_bone(torso, Vector3(side * 0.13, 1.49, 0.10), Vector3(side * 0.07, 1.47, 0.13), Vector2(0.020, 0.022), Vector2(0.022, 0.02), bone)
				_bone(torso, Vector3(side * 0.10, 1.40, 0.06), Vector3(side * 0.115, 1.50, 0.015), Vector2(0.018, 0.025), Vector2(0.02, 0.022), bone)
				_bone(torso, Vector3(side * 0.02, 1.46, 0.11), Vector3(side * 0.10, 1.46, 0.07), Vector2(0.016, 0.02), Vector2(0.018, 0.02), bone)
			_rock(torso, Vector3(0, 1.49, 0.132), Vector3(0.04, 0.065, 0.02), shadow, 0)
			for tooth: int in 6:
				_bone(torso, Vector3(-0.066 + tooth * 0.026, 1.43, 0.112), Vector3(-0.066 + tooth * 0.026, 1.405, 0.116), Vector2(0.008, 0.01), Vector2(0.007, 0.007), bone, 4)
		elif kind == "golem":
			# Offset irregular slabs separated by real dark fissures, no perfect cubes.
			_rock(torso, Vector3(0, 0.91, 0), Vector3(0.52, 0.35, 0.39), shadow, 0)
			_rock(torso, Vector3(-0.18, 1.14, 0), Vector3(0.48, 0.49, 0.43), skin, 2)
			_rock(torso, Vector3(0.20, 1.19, -0.025), Vector3(0.47, 0.43, 0.43), skin, 5)
			_rock(torso, Vector3(0.02, 0.92, 0.13), Vector3(0.44, 0.32, 0.29), skin, 3)
			_rock(torso, Vector3(0.01, 1.49, 0.015), Vector3(0.39, 0.40, 0.36), skin, 7)
			for side: float in [-1.0, 1.0]:
				_rock(torso, Vector3(side * 0.08, 1.52, 0.183), Vector3(0.085, 0.025, 0.025), eye, 0)
				_rock(torso, Vector3(side * 0.43, 1.27, 0), Vector3(0.39, 0.38, 0.43), skin, int(side) + 5)
				_rock(torso, Vector3(side * 0.17, 1.13, 0.235), Vector3(0.14, 0.29, 0.035), hide, 2)
		else:
			_form(torso, Vector3.ZERO, [[0.73, 0.22, 0.15, 0.0, 0.0], [0.88, 0.20, 0.14, 0.0, 0.0], [1.15, 0.26, 0.16, 0.0, -0.01], [1.31, 0.17, 0.12, 0.0, 0.0]], cloth, 9)
			for side: float in [-1.0, 1.0]:
				var skirt: MeshInstance3D = _form(torso, Vector3(side * 0.10, 0.74, 0.09), [[-0.10, 0.085, 0.022, 0.0, 0.02], [0.13, 0.08, 0.025, 0.0, 0.0]], hide, 5)
				skirt.rotation.z = side * 0.13
			_form(torso, Vector3(0, 1.38, 0), [[-0.06, 0.08, 0.09, 0.0, 0.04], [0.04, 0.14, 0.13, 0.0, 0.03], [0.19, 0.16, 0.13, 0.0, 0.0], [0.29, 0.095, 0.09, 0.0, -0.025]], skin, 9)
			_rock(torso, Vector3(0, 1.48, 0.19), Vector3(0.09, 0.16, 0.14), skin, 0)
			_bone(torso, Vector3(-0.075, 1.40, 0.12), Vector3(0.075, 1.40, 0.12), Vector2(0.02, 0.014), Vector2(0.02, 0.014), shadow, 4)
			for side: float in [-1.0, 1.0]:
				_rock(torso, Vector3(side * 0.085, 1.54, 0.13), Vector3(0.08, 0.045, 0.035), shadow, 1)
				_rock(torso, Vector3(side * 0.080, 1.542, 0.151), Vector3(0.027, 0.018, 0.014), eye, 0)
				var brow: MeshInstance3D = _rock(torso, Vector3(side * 0.083, 1.58, 0.14), Vector3(0.12, 0.04, 0.055), skin, 0)
				brow.rotation.z = side * -0.20
				var ear: MeshInstance3D = _form(torso, Vector3(side * 0.15, 1.52, 0), [[-0.035, 0.06, 0.045, 0.0, 0.0], [0.08, 0.055, 0.025, side * 0.09, -0.01], [0.13, 0.002, 0.003, side * 0.15, -0.04]], skin, 4)
				ear.rotation.z = -side * 0.3
			_strap(torso, Vector3(-0.19, 1.28, 0.13), Vector3(0.17, 0.87, 0.155), 0.035, hide)
			_bone(torso, Vector3(-0.20, 0.88, 0.15), Vector3(0.20, 0.88, 0.15), Vector2(0.035, 0.018), Vector2(0.035, 0.018), hide, 4)
			_rock(torso, Vector3(0, 0.88, 0.18), Vector3(0.085, 0.07, 0.025), iron, 0)
		for side: float in [-1.0, 1.0]:
			var leg: Node3D = _pivot(root, Vector3(side * (0.12 if kind == "golem" else 0.15), 0.76, 0))
			var arm: Node3D = _pivot(torso, Vector3(side * (0.43 if kind == "golem" else 0.28), 1.25, 0))
			if kind == "golem":
				_rock(leg, Vector3(0, -0.18, 0), Vector3(0.25, 0.35, 0.27), skin, 2)
				_rock(leg, Vector3(0, -0.46, 0.01), Vector3(0.22, 0.29, 0.25), skin, 4)
				_rock(leg, Vector3(0, -0.68, 0.08), Vector3(0.22, 0.16, 0.36), skin, 1)
				_rock(arm, Vector3(side * 0.02, -0.20, 0), Vector3(0.28, 0.34, 0.28), skin, 2)
				_rock(arm, Vector3(side * 0.04, -0.47, 0.04), Vector3(0.30, 0.25, 0.31), skin, 4)
				for finger: int in 3:
					_rock(arm, Vector3(-0.09 + finger * 0.085, -0.61, 0.09), Vector3(0.075, 0.14, 0.12), skin, finger)
			elif kind == "skeleton":
				for depth: float in [-0.018, 0.018]:
					_bone(leg, Vector3(depth, -0.01, 0), Vector3(depth, -0.34, 0.025), Vector2(0.025, 0.027), Vector2(0.022, 0.023), bone)
					_bone(leg, Vector3(depth, -0.38, 0.025), Vector3(depth, -0.65, 0), Vector2(0.020, 0.025), Vector2(0.018, 0.02), bone)
				_rock(leg, Vector3(0, -0.35, 0.03), Vector3(0.085, 0.075, 0.08), bone, 0)
				_bone(leg, Vector3(0, -0.65, 0), Vector3(0, -0.735, 0.03), Vector2(0.02, 0.023), Vector2(0.015, 0.018), bone)
				for toe: int in 3:
					_bone(leg, Vector3(-0.04 + toe * 0.04, -0.735, 0), Vector3(-0.04 + toe * 0.04, -0.745, 0.17), Vector2(0.014, 0.017), Vector2(0.009, 0.012), bone)
				_bone(arm, Vector3.ZERO, Vector3(side * 0.03, -0.24, 0), Vector2(0.04, 0.04), Vector2(0.025, 0.03), bone)
				for depth: float in [-0.02, 0.02]:
					_bone(arm, Vector3(depth, -0.27, 0), Vector3(depth, -0.49, 0.02), Vector2(0.018, 0.025), Vector2(0.017, 0.02), bone)
				_rock(arm, Vector3(0, -0.54, 0.03), Vector3(0.10, 0.11, 0.065), bone, 0)
				_rock(arm, Vector3(0, 0.01, 0), Vector3(0.21, 0.16, 0.24), iron, 1)
			else:
				_bone(leg, Vector3.ZERO, Vector3(0, -0.34, 0.03), Vector2(0.085, 0.085), Vector2(0.06, 0.065), cloth)
				_bone(leg, Vector3(0, -0.33, 0.03), Vector3(0, -0.64, 0), Vector2(0.065, 0.07), Vector2(0.05, 0.055), hide)
				_form(leg, Vector3(0, -0.70, 0.06), [[-0.06, 0.085, 0.13, 0.0, 0.025], [0.07, 0.07, 0.10, 0.0, 0.0]], hide, 7)
				_bone(arm, Vector3.ZERO, Vector3(side * 0.04, -0.26, 0.02), Vector2(0.09, 0.08), Vector2(0.06, 0.06), skin)
				_bone(arm, Vector3(side * 0.04, -0.27, 0.02), Vector3(side * 0.04, -0.51, 0.04), Vector2(0.055, 0.06), Vector2(0.04, 0.045), skin)
				_rock(arm, Vector3(side * 0.04, -0.54, 0.07), Vector3(0.10, 0.12, 0.10), skin, 0)
				_rock(arm, Vector3(0, -0.04, 0), Vector3(0.22, 0.19, 0.23), hide, 1)
			legs.append(leg)
			arms.append(arm)
		if kind in ["goblin", "skeleton"]:
			_weapon(arms[0], iron, hide)
			_shield(arms[1], hide, iron)
	_batch(kind, [torso] + legs + arms, materials)
	if not _rest_bounds_by_kind.has(kind):
		_rest_bounds_by_kind[kind] = rest_bounds(root)
	var rest: AABB = _rest_bounds_by_kind[kind]
	# Bake the actual lowest resting vertex to the foot and measure the full exterior.
	for child: Node3D in root.get_children():
		child.position.y -= rest.position.y
	var base_colors: Array[Color] = []
	for material in materials:
		base_colors.append(material.albedo_color)
	var model: Dictionary = {"root": root, "torso": torso, "legs": legs, "arms": arms, "materials": materials, "colors": base_colors, "kind": kind, "base_height": rest.size.y, "leg_origins": legs.map(func(leg: Node3D): return leg.position)}
	_recipes[kind] = _capture_recipe(model)
	return model


## Capture the already-authored, foot-aligned rig once. Shared meshes stay immutable.
static func _recipe_node(node: Node3D, parent_index: int, nodes: Array[Dictionary], indices: Dictionary, materials: Array) -> void:
	var index: int = nodes.size()
	indices[node.get_instance_id()] = index
	var record: Dictionary = {"parent": parent_index, "transform": node.transform}
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		record["mesh"] = instance.mesh
		record["material"] = materials.find(instance.material_override)
		record["shadow"] = instance.cast_shadow
	nodes.append(record)
	for child: Node in node.get_children():
		_recipe_node(child as Node3D, index, nodes, indices, materials)


static func _capture_recipe(model: Dictionary) -> Dictionary:
	var nodes: Array[Dictionary] = []
	var indices: Dictionary = {}
	var materials: Array = model["materials"]
	_recipe_node(model["root"], -1, nodes, indices, materials)
	var palette: Array[Dictionary] = []
	for material: StandardMaterial3D in materials:
		palette.append({"surface": str(material.get_meta("actor_surface_kind")), "color": material.albedo_color,
			"alias": materials.find(material)})
	var legs: Array[int] = []
	var arms: Array[int] = []
	for node: Node3D in model["legs"]:
		legs.append(int(indices[node.get_instance_id()]))
	for node: Node3D in model["arms"]:
		arms.append(int(indices[node.get_instance_id()]))
	return {"nodes": nodes, "palette": palette, "torso": int(indices[(model["torso"] as Node3D).get_instance_id()]),
		"legs": legs, "arms": arms, "kind": model["kind"], "base_height": model["base_height"],
		"leg_origins": (model["leg_origins"] as Array).duplicate()}


## A cache hit creates only actor-owned joints/instances/material uniforms.
## It never builds SurfaceTools, primitive meshes, normals, or temporary geometry.
static func _instantiate_recipe(recipe: Dictionary) -> Dictionary:
	var materials: Array[StandardMaterial3D] = []
	var colors: Array[Color] = []
	for descriptor: Dictionary in recipe["palette"]:
		var color: Color = descriptor["color"]
		var alias: int = int(descriptor["alias"])
		materials.append(materials[alias] if alias < materials.size() else _material(color, str(descriptor["surface"])))
		colors.append(color)
	var built: Array[Node3D] = []
	for record: Dictionary in recipe["nodes"]:
		var node: Node3D
		if record.has("mesh"):
			var instance := MeshInstance3D.new()
			instance.mesh = record["mesh"]
			instance.material_override = materials[int(record["material"])]
			instance.cast_shadow = int(record["shadow"])
			node = instance
		else:
			node = Node3D.new()
		node.transform = record["transform"]
		var parent_index: int = int(record["parent"])
		if parent_index >= 0:
			built[parent_index].add_child(node)
		built.append(node)
	var root: Node3D = built[0]
	root.name = "Native_" + str(recipe["kind"])
	var legs: Array[Node3D] = []
	var arms: Array[Node3D] = []
	for index: int in recipe["legs"]:
		legs.append(built[index])
	for index: int in recipe["arms"]:
		arms.append(built[index])
	return {"root": root, "torso": built[int(recipe["torso"])], "legs": legs, "arms": arms,
		"materials": materials, "colors": colors, "kind": recipe["kind"], "base_height": recipe["base_height"],
		"leg_origins": (recipe["leg_origins"] as Array).duplicate()}


static func cache_stats() -> Dictionary:
	return {"recipes": _recipes.size(), "hits": _recipe_hits, "source_builds": _source_builds,
		"surface_forms": _surface_forms_built}

static func tint(model: Dictionary, color: Color, flash: float, flash_color: Color, alpha: float) -> void:
	var materials: Array = model["materials"]
	var colors: Array = model["colors"]
	for index in materials.size():
		var material := materials[index] as StandardMaterial3D
		var ink: Color = colors[index] * color
		ink = ink.lerp(flash_color, clampf(flash, 0.0, 0.65))
		ink.a = alpha
		# GLES3 queues a uniform update even when the assigned value is unchanged.
		if material.albedo_color != ink:
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
		var origin: Vector3 = model["leg_origins"][index]
		limb.position.y = origin.y * cos(limb.rotation.x)
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
		if enemy == null or enemy.is_queued_for_deletion() or NativeEnemySprites3D.supports(enemy):
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
	var at: Vector2 = corpse.get("pos", Vector2.ZERO)
	var facing: float = float(corpse.get("facing", 0.0))
	var height: float = float(corpse.get("height", 62.0))
	# Query the current floor every time: moved corpses or changed terrain invalidate placement.
	var floor_height: float = presenter.surface_height(at)
	var key: Array = [at, facing, height, floor_height]
	if model.get("_corpse_placement_key", []) != key:
		var ratio: float = height / (Ortho3DPreview.GROUND_PER_METER * Iso.S) / float(model["base_height"])
		root.scale = Vector3.ONE * ratio
		pose(model, facing, 0.0, 0.0, true)
		# Rest the whole rotated mesh on the real floor, not the old picture's square.
		var minimum := 0.0
		for child in root.find_children("*", "MeshInstance3D", true, false):
			var mesh := child as MeshInstance3D
			var local := root.global_transform.affine_inverse() * mesh.global_transform
			for index in 8:
				minimum = minf(minimum, (root.basis * (local * mesh.get_aabb().get_endpoint(index))).y)
		root.position = Ortho3DPreview.ground_position(at, floor_height - minimum + 0.012)
		model["_corpse_placement_key"] = key
		model["_corpse_placement_updates"] = int(model.get("_corpse_placement_updates", 0)) + 1
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


static func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Godot front faces use clockwise winding; generate_normals follows it.
	for point: Vector3 in [a, c, b]:
		tool.set_uv(Vector2(point.x, point.y))
		tool.add_vertex(point)

static func _form(parent: Node3D, at: Vector3, rows: Array, material: Material, facets := 8, irregular := 0.0) -> MeshInstance3D:
	_surface_forms_built += 1
	# Authored horizontal sections, not scaled capsule primitives. Triangles have
	# skin/털/뼈에는 연속 법선, 철물과 바위에는 면 법선을 사용한다.
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var surface: String = str(material.get_meta("anatomy_surface", ""))
	var organic: bool = surface in ["skin", "fur", "bone"]
	# 연속 법선은 근육·주둥이·뼈의 곡률을 살리고 철물·바위는 선명하게 남긴다.
	# 큰 근육과 두개골의 단면 끝을 둥글게 닫는다. 넓은 평면 뚜껑이
	# 어깨·이마에서 드러나지 않도록 기존 높이 안에서 끝단을 수축한다.
	if organic and surface != "bone" and facets >= 8 and rows.size() >= 3:
		var first: Array = rows[0].duplicate()
		var lower: Array = rows[0].duplicate()
		var upper: Array = rows.back().duplicate()
		var last: Array = rows.back().duplicate()
		lower[0] = lerpf(float(rows[0][0]), float(rows[1][0]), 0.25)
		upper[0] = lerpf(float(rows.back()[0]), float(rows[rows.size() - 2][0]), 0.25)
		for component: int in [1, 2]:
			first[component] = float(first[component]) * 0.08
			last[component] = float(last[component]) * 0.08
		var rounded: Array = [first, lower]
		for level: int in range(1, rows.size() - 1):
			rounded.append(rows[level])
		rounded.append_array([upper, last])
		rows = rounded
	if organic:
		irregular = minf(irregular, 0.004)
		facets = maxi(facets, 8 if surface == "bone" else 16)
	if organic and surface != "bone":
		var curved: Array = []
		for level: int in rows.size() - 1:
			var first: Array = rows[level]
			var last: Array = rows[level + 1]
			curved.append(first)
			var mid: Array = []
			for component: int in 5:
				var a: float = float(first[component])
				var b: float = float(last[component])
				var before: float = float(rows[maxi(0, level - 1)][component])
				var after: float = float(rows[mini(rows.size() - 1, level + 2)][component])
				var value: float = (9.0 * (a + b) - before - after) / 16.0
				mid.append((a + b) * 0.5 if component == 0 else clampf(value, minf(a, b), maxf(a, b)))
			curved.append(mid)
		curved.append(rows.back())
		rows = curved
	tool.set_smooth_group(0 if organic else -1)
	var rings: Array[PackedVector3Array] = []
	for row_index: int in rows.size():
		var row: Array = rows[row_index]
		var ring: PackedVector3Array = PackedVector3Array()
		for index: int in facets:
			var angle: float = TAU * float(index) / facets + PI / facets
			var variation: float = 1.0 + irregular * sin(float(index * 7 + row_index * 3))
			ring.append(Vector3(float(row[3]) + cos(angle) * float(row[1]) * variation, float(row[0]), float(row[4]) + sin(angle) * float(row[2]) * variation))
		rings.append(ring)
	for level: int in rings.size() - 1:
		for index: int in facets:
			var next: int = (index + 1) % facets
			_tri(tool, rings[level][index], rings[level + 1][index], rings[level + 1][next])
			_tri(tool, rings[level][index], rings[level + 1][next], rings[level][next])
	tool.set_smooth_group(-1)
	var bottom: Vector3 = Vector3(float(rows[0][3]), float(rows[0][0]), float(rows[0][4]))
	var last: Array = rows.back()
	var top: Vector3 = Vector3(float(last[3]), float(last[0]), float(last[4]))
	for index: int in facets:
		var next: int = (index + 1) % facets
		_tri(tool, bottom, rings[0][index], rings[0][next])
		_tri(tool, top, rings.back()[next], rings.back()[index])
	tool.generate_normals()
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = tool.commit()
	node.material_override = material
	parent.add_child(node)
	node.position = at
	return node

static func _bone(parent: Node3D, a: Vector3, b: Vector3, first: Vector2, last: Vector2, material: Material, facets := 7) -> MeshInstance3D:
	var length: float = a.distance_to(b)
	var node: MeshInstance3D = _form(parent, (a + b) * 0.5, [
		[-length * 0.5, first.x, first.y, 0.0, 0.0],
		[-length * 0.33, first.x * 0.76, first.y * 0.80, 0.0, 0.0],
		[length * 0.30, last.x * 0.80, last.y * 0.78, 0.0, 0.0],
		[length * 0.5, last.x, last.y, 0.0, 0.0]], material, facets)
	if length > 0.0001:
		node.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	return node

static func _rock(parent: Node3D, at: Vector3, size: Vector3, material: Material, seed_value: int) -> MeshInstance3D:
	var organic: bool = str(material.get_meta("anatomy_surface", "")) in ["skin", "fur", "bone"]
	var end_radius: float = 0.035 if organic else 0.30
	var node: MeshInstance3D = _form(parent, at, [
		[-0.5 * size.y, end_radius * size.x, end_radius * size.z, -0.04 * size.x, 0.0],
		[-0.29 * size.y, 0.51 * size.x, 0.49 * size.z, 0.0, 0.0],
		[0.19 * size.y, 0.47 * size.x, 0.52 * size.z, 0.02 * size.x, -0.04 * size.z],
		[0.5 * size.y, end_radius * size.x, end_radius * size.z, -0.06 * size.x, 0.02 * size.z]], material, 7, 0.12)
	node.rotation = Vector3(0.06 * sin(seed_value), 0.19 * seed_value, 0.08 * cos(seed_value))
	return node

static func _strap(parent: Node3D, a: Vector3, b: Vector3, width: float, material: Material) -> void:
	_bone(parent, a, b, Vector2(width, 0.012), Vector2(width, 0.012), material, 4)

static func _shield(parent: Node3D, wood: Material, iron: Material) -> void:
	# Five separate weathered boards, a reinforced rim and crossed rear braces.
	for index: int in 5:
		var x: float = -0.16 + index * 0.08
		_form(parent, Vector3(x - 0.04, -0.29, 0.15), [[-0.29 + absf(x) * 0.18, 0.046, 0.025, 0.0, 0.0], [0.22, 0.046, 0.025, 0.0, 0.0], [0.29 - absf(x) * 0.18, 0.038, 0.025, 0.0, 0.0]], wood, 4)
	_bone(parent, Vector3(-0.27, -0.53, 0.17), Vector3(0.19, -0.53, 0.17), Vector2(0.023, 0.018), Vector2(0.023, 0.018), iron)
	_bone(parent, Vector3(-0.27, -0.05, 0.17), Vector3(0.19, -0.05, 0.17), Vector2(0.023, 0.018), Vector2(0.023, 0.018), iron)
	_rock(parent, Vector3(-0.04, -0.29, 0.20), Vector3(0.12, 0.12, 0.05), iron, 0)

static func _weapon(parent: Node3D, iron: Material, wood: Material) -> void:
	_bone(parent, Vector3(0, -0.47, -0.09), Vector3(0, -0.47, 0.17), Vector2(0.035, 0.028), Vector2(0.03, 0.028), wood)
	var blade: MeshInstance3D = _form(parent, Vector3(0, -0.47, 0.18), [[0.0, 0.045, 0.018, 0.0, 0.0], [0.47, 0.032, 0.014, 0.018, 0.0], [0.58, 0.003, 0.003, 0.0, 0.0]], iron, 4)
	blade.rotation.x = PI * 0.5
	_bone(parent, Vector3(-0.13, -0.47, 0.17), Vector3(0.13, -0.47, 0.17), Vector2(0.025, 0.02), Vector2(0.025, 0.02), iron)

static func rest_bounds(root: Node3D) -> AABB:
	# Pure local transforms also work before the model enters a SceneTree.
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		var transform: Transform3D = instance.transform
		var parent: Node = instance.get_parent()
		while parent != root:
			transform = (parent as Node3D).transform * transform
			parent = parent.get_parent()
		for surface: int in instance.mesh.get_surface_count():
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				var point: Vector3 = transform * vertex
				minimum = minimum.min(point)
				maximum = maximum.max(point)
	return AABB(minimum, maximum - minimum)

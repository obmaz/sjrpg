class_name NativeWarrior3D
extends Node3D
## Articulated native warrior. Source movement distance and action progress are
## the only pose clocks, so contact stop/pause never accumulate presentation time.
var torso: Node3D
var legs: Array[Node3D] = []
var arms: Array[Node3D] = []
var meshes: Array[MeshInstance3D] = []
var last_pose := {}
var weapon: Node3D
var _last_distance := -1.0
var _flash: ShaderMaterial
static var _inks: Dictionary = {}


static func _ink(key: String) -> StandardMaterial3D:
	if not _inks.has(key):
		var colors := {"steel": Color("626b6a"), "cloth": Color("35463f"), "leather": Color("43352a"), "skin": Color("ad886b"), "hair": Color("342d26"), "bronze": Color("998057")}
		var material := StandardMaterial3D.new()
		material.albedo_color = colors[key]
		material.roughness = 0.56 if key == "steel" else 0.88
		material.metallic = 0.45 if key in ["steel", "bronze"] else 0.0
		_inks[key] = material
	return _inks[key]


func _piece(parent: Node3D, key: String, at: Vector3, size: Vector3, rounded := false) -> MeshInstance3D:
	var shape: PrimitiveMesh
	if rounded:
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 12
		sphere.rings = 6
		shape = sphere
	else:
		shape = BoxMesh.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.material_override = _ink(key)
	parent.add_child(mesh)
	mesh.position = at
	# Bake dimensions into the actual mesh arrays, not the runtime actor root.
	var arrays := shape.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var normal_basis := Basis.from_scale(size).inverse().transposed()
	for index in points.size():
		points[index] *= size
		normals[index] = (normal_basis * normals[index]).normalized()
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	var baked := ArrayMesh.new()
	baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.mesh = baked
	meshes.append(mesh)
	return mesh


func build() -> NativeWarrior3D:
	name = "NativeWarrior"
	torso = Node3D.new()
	add_child(torso)
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.12, 0.88, 0)
		torso.add_child(hip)
		legs.append(hip)
		_piece(hip, "leather", Vector3(0, -0.35, 0), Vector3(0.17, 0.68, 0.19), true)
		_piece(hip, "steel", Vector3(0, -0.40, 0.10), Vector3(0.18, 0.26, 0.07))
		_piece(hip, "leather", Vector3(0, -0.80, 0.06), Vector3(0.19, 0.16, 0.32))
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * 0.30, 1.37, 0)
		torso.add_child(shoulder)
		arms.append(shoulder)
		_piece(shoulder, "leather", Vector3(0, -0.24, 0), Vector3(0.16, 0.50, 0.18), true)
		_piece(shoulder, "steel", Vector3(0, -0.04, 0), Vector3(0.25, 0.17, 0.30), true)
		_piece(shoulder, "steel", Vector3(0, -0.40, 0.02), Vector3(0.17, 0.19, 0.19))
		_piece(shoulder, "leather", Vector3(0, -0.54, 0.02), Vector3(0.13, 0.13, 0.15), true)
	_piece(torso, "leather", Vector3(0, 1.13, 0), Vector3(0.48, 0.61, 0.32), true)
	_piece(torso, "steel", Vector3(0, 1.24, 0.125), Vector3(0.43, 0.40, 0.13), true)
	_piece(torso, "cloth", Vector3(0, 1.10, -0.195), Vector3(0.48, 0.69, 0.065))
	_piece(torso, "bronze", Vector3(0, 0.99, 0.182), Vector3(0.09, 0.07, 0.035))
	_piece(torso, "skin", Vector3(0, 1.48, 0), Vector3(0.13, 0.14, 0.13), true)
	_piece(torso, "skin", Vector3(0, 1.64, 0.01), Vector3(0.23, 0.28, 0.22), true)
	_piece(torso, "skin", Vector3(0, 1.65, 0.125), Vector3(0.045, 0.07, 0.05))
	for side in [-1.0, 1.0]:
		_piece(torso, "hair", Vector3(side * 0.047, 1.675, 0.116), Vector3(0.032, 0.013, 0.014))
	_piece(torso, "hair", Vector3(0, 1.74, -0.02), Vector3(0.25, 0.15, 0.23), true)
	_piece(torso, "hair", Vector3(0, 1.555, 0.10), Vector3(0.17, 0.13, 0.07), true)
	weapon = Node3D.new()
	weapon.name = "Sword"
	weapon.position = Vector3(0, -0.54, 0.05)
	arms[1].add_child(weapon)
	_piece(weapon, "leather", Vector3(0, 0, 0), Vector3(0.045, 0.045, 0.18))
	_piece(weapon, "bronze", Vector3(0, 0, 0.11), Vector3(0.22, 0.04, 0.04))
	_piece(weapon, "steel", Vector3(0, 0, 0.55), Vector3(0.065, 0.025, 0.84))
	var shader := Shader.new()
	shader.code = Ortho3DPreview.ACTOR_FLASH_CODE
	_flash = ShaderMaterial.new()
	_flash.shader = shader
	return self


func sync(player: Player) -> void:
	_flash.set_shader_parameter("flash_color", player.sprite.flash_tint.lerp(Color.WHITE, 0.35))
	_flash.set_shader_parameter("flash_strength", player.sprite.flash * 0.65)
	for mesh in meshes:
		mesh.material_overlay = _flash if player.sprite.flash > 0.0 else null
	if (is_inside_tree() and get_tree().paused) or player._hitstop.remaining > 0.0:
		return
	var moving := player._run_distance != _last_distance
	_last_distance = player._run_distance
	var phase := player._run_distance / 23.0
	var swing := sin(phase) * 0.55 if moving else 0.0
	if Prefs.reduce_motion:
		swing *= 0.45
	for index in 2:
		legs[index].rotation.x = swing * (-1.0 if index == 0 else 1.0)
		arms[index].rotation.x = swing * (0.6 if index == 0 else -0.6) + (0.45 if index == 1 else 0.0)
		arms[index].rotation.z = -0.06 if index == 0 else 0.06
		arms[index].rotation.y = 0.0
	torso.rotation = Vector3.ZERO
	var progress := 0.0
	if player._attack_time > 0.0:
		progress = clampf(1.0 - player._attack_time / player._attack_duration, 0, 1)
		var strike := smoothstep(0.18, 0.55, progress)
		arms[1].rotation.x = lerpf(-1.30, 0.75, strike)
		arms[1].rotation.y = lerpf(-0.7, 0.8, strike)
		torso.rotation.y = sin(progress * PI) * 0.18
	if player._roll_time > 0.0:
		torso.rotation.x = -0.75
	if player.dead:
		torso.rotation.x = PI * 0.5
		torso.position.y = 0.25
	else:
		torso.position.y = 0.0
	weapon.visible = not player.dead
	last_pose = {"walk_distance": player._run_distance, "attack_progress": progress, "dead": player.dead, "parts": meshes.size()}


func review_snapshot() -> Dictionary:
	return last_pose.duplicate()

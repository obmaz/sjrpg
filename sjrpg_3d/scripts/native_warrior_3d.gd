class_name NativeWarrior3D
extends Node3D
## Adult anatomical lofts and forged plate profiles, sharing the resident face
## family and painted atlas. Joint poses still observe the original Player clocks.
var torso: Node3D
var legs: Array[Node3D] = []
var arms: Array[Node3D] = []
var meshes: Array[MeshInstance3D] = []
var last_pose := {}
var weapon: Node3D
var _last_distance := -1.0
var _flash: ShaderMaterial


func _part(parent: Node3D, key: String, geometry: Mesh, at := Vector3.ZERO, rotation := Vector3.ZERO) -> MeshInstance3D:
	var colors := {"iron": Color("b7c5c2"), "cloth": Color("66796a"), "leather": Color("937858"), "skin": Color("efc6a0"), "hair": Color("514638"), "bronze": Color("cfab68")}
	var group := "iron" if key in ["iron", "bronze"] else "skin" if key in ["skin", "hair"] else key
	var arrays := geometry.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var painted := PackedColorArray()
	painted.resize(vertices.size())
	painted.fill(colors[key])
	arrays[Mesh.ARRAY_COLOR] = painted
	var model := ArrayMesh.new()
	model.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.mesh = model
	instance.material_override = NativeActorMaterials.material(group)
	instance.set_meta("actor_material", group)
	parent.add_child(instance)
	instance.position = at
	instance.rotation = rotation
	meshes.append(instance)
	return instance


func _loft(parent: Node3D, key: String, rings: Array[Vector4], at := Vector3.ZERO, folds := 0.0, start := 0.0, span := TAU, thickness := 0.0) -> MeshInstance3D:
	return _part(parent, key, NativeActorShapes.loft(rings, 16, folds, start, span, thickness), at)


func _round(parent: Node3D, key: String, at: Vector3, size: Vector3) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var arrays := sphere.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var normal_basis := Basis.from_scale(size).inverse().transposed()
	for index in points.size():
		points[index] *= size
		normals[index] = (normal_basis * normals[index]).normalized()
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	var model := ArrayMesh.new()
	model.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_part(parent, key, model, at)


func _batch() -> void:
	var groups := {}
	for mesh in meshes:
		var parent := mesh.get_parent() as Node3D
		var id := parent.get_instance_id()
		if not groups.has(id):
			groups[id] = {"parent": parent, "surfaces": {}}
		var surfaces: Dictionary = groups[id]["surfaces"]
		var kind: String = mesh.get_meta("actor_material")
		if not surfaces.has(kind):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			surfaces[kind] = tool
		var tool: SurfaceTool = surfaces[kind]
		tool.append_from(mesh.mesh, 0, mesh.transform)
		parent.remove_child(mesh)
		mesh.free()
	meshes.clear()
	for entry: Dictionary in groups.values():
		var model := ArrayMesh.new()
		var surfaces: Dictionary = entry["surfaces"]
		for kind: String in surfaces:
			var tool: SurfaceTool = surfaces[kind]
			tool.commit(model)
			model.surface_set_material(model.get_surface_count() - 1, NativeActorMaterials.material(kind))
		var instance := MeshInstance3D.new()
		instance.mesh = model
		(entry["parent"] as Node3D).add_child(instance)
		meshes.append(instance)


func build() -> NativeWarrior3D:
	name = "NativeWarrior"
	torso = Node3D.new()
	add_child(torso)
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.115, 0.88, 0)
		torso.add_child(hip)
		legs.append(hip)
		_loft(hip, "leather", [Vector4(-0.65, 0.068, 0.075, 0), Vector4(-0.43, 0.078, 0.083, 0), Vector4(-0.30, 0.071, 0.08, 0.025), Vector4(-0.12, 0.10, 0.10, 0), Vector4(0.04, 0.105, 0.10, 0)], Vector3.ZERO, 0.004)
		_part(hip, "leather", NativeActorShapes.boot(), Vector3(0, -0.88, 0))
		_loft(hip, "iron", [Vector4(-0.62, 0.071, 0.084, 0.012), Vector4(-0.42, 0.086, 0.105, 0.02), Vector4(-0.28, 0.080, 0.09, 0.025)], Vector3.ZERO, 0.0, 0, PI, 0.018)
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * 0.285, 1.37, 0)
		torso.add_child(shoulder)
		arms.append(shoulder)
		_part(shoulder, "leather", NativeActorShapes.sleeve(0.48, 0.083), Vector3.ZERO)
		_loft(shoulder, "iron", [Vector4(-0.11, 0.12, 0.16, 0), Vector4(-0.025, 0.148, 0.177, 0), Vector4(0.065, 0.12, 0.15, 0), Vector4(0.095, 0.065, 0.095, 0)])
		_loft(shoulder, "iron", [Vector4(-0.18, 0.112, 0.14, 0), Vector4(-0.13, 0.131, 0.16, 0), Vector4(-0.10, 0.119, 0.145, 0)])
		_loft(shoulder, "iron", [Vector4(-0.48, 0.065, 0.073, 0.045), Vector4(-0.32, 0.086, 0.098, 0.03), Vector4(-0.26, 0.077, 0.086, 0.02)])
		_loft(shoulder, "bronze", [Vector4(-0.47, 0.071, 0.078, 0.044), Vector4(-0.445, 0.072, 0.079, 0.044)])
		_round(shoulder, "skin", Vector3(0, -0.54, 0.05), Vector3(0.112, 0.145, 0.10))
	_part(torso, "cloth", NativeActorShapes.chest())
	for arc in [0.0, PI * 0.54]:
		_loft(torso, "cloth", [Vector4(0.62, 0.245, 0.17, 0), Vector4(0.82, 0.215, 0.15, 0), Vector4(1.0, 0.195, 0.14, 0)], Vector3.ZERO, 0.010, arc, PI * 0.46, 0.018)
	_loft(torso, "iron", [Vector4(1.01, 0.194, 0.153, 0.01), Vector4(1.14, 0.234, 0.188, 0.01), Vector4(1.29, 0.262, 0.176, 0), Vector4(1.39, 0.186, 0.116, 0)], Vector3.ZERO, 0, 0, PI, 0.025)
	_loft(torso, "iron", [Vector4(1.02, 0.193, 0.151, -0.01), Vector4(1.22, 0.240, 0.175, 0), Vector4(1.37, 0.195, 0.122, 0)], Vector3.ZERO, 0, PI, PI, 0.022)
	# Back cloak is an open-front curved cloth shell with hem folds and finite
	# thickness; it never presents a rectangular box seen from the side.
	_loft(torso, "cloth", [Vector4(0.43, 0.34, 0.25, -0.02), Vector4(0.76, 0.30, 0.23, -0.02), Vector4(1.16, 0.28, 0.21, -0.015), Vector4(1.41, 0.255, 0.17, 0)], Vector3.ZERO, 0.018, PI, PI, 0.022)
	_loft(torso, "leather", [Vector4(0.94, 0.203, 0.165, 0), Vector4(1.005, 0.203, 0.165, 0)])
	_round(torso, "bronze", Vector3(0, 0.975, 0.174), Vector3(0.072, 0.068, 0.024))
	for side in [-1.0, 1.0]:
		_round(torso, "bronze", Vector3(side * 0.14, 1.345, 0.145), Vector3(0.056, 0.056, 0.024))
	_loft(torso, "skin", [Vector4(1.36, 0.065, 0.06, 0.02), Vector4(1.55, 0.064, 0.06, 0.025)])
	_loft(torso, "leather", [Vector4(1.36, 0.10, 0.085, 0), Vector4(1.45, 0.085, 0.073, 0)], Vector3.ZERO, 0, PI * 0.05, PI * 1.90, 0.018)
	var face := {}
	NativeResidents3D._face(face, 1.50, false, false, "rowen")
	for category: String in face:
		var tool: SurfaceTool = face[category]
		var face_mesh := tool.commit()
		var instance := MeshInstance3D.new()
		instance.mesh = face_mesh
		instance.set_meta("actor_material", category)
		torso.add_child(instance)
		meshes.append(instance)
	_loft(torso, "hair", [Vector4(1.49, 0.052, 0.063, 0.026), Vector4(1.53, 0.080, 0.077, 0.017), Vector4(1.555, 0.083, 0.080, 0.014)])
	weapon = Node3D.new()
	weapon.name = "Sword"
	weapon.position = Vector3(0, -0.54, 0.05)
	arms[1].add_child(weapon)
	_part(weapon, "leather", NativeActorShapes.loft([Vector4(-0.08, 0.023, 0.023, 0), Vector4(0.08, 0.023, 0.023, 0)], 12), Vector3.ZERO, Vector3(PI * 0.5, 0, 0))
	_part(weapon, "iron", NativeActorShapes.blade(), Vector3(0, 0, 0.12), Vector3(PI * 0.5, 0, 0))
	_round(weapon, "bronze", Vector3(0, 0, 0.105), Vector3(0.22, 0.045, 0.055))
	_round(weapon, "bronze", Vector3(0, 0, -0.09), Vector3(0.055, 0.055, 0.055))
	_batch()
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

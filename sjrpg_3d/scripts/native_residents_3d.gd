class_name NativeResidents3D
extends RefCounted
## Eight resident identities use closed, surface-batched volumes in native metres.
## Rendering only: original Villager, quests and SpatialWorld3D remain authoritative.
const IDS := ["merchant", "smith", "stable", "elder", "mira", "elin", "noah", "rowen"]
const COATS := ["493e31", "393b39", "4a4934", "454b53", "3c4e50", "444a55", "454f3d", "354550"]
static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}
var preview: Node
var entries: Dictionary = {}


func setup(presenter: Node) -> NativeResidents3D:
	preview = presenter
	sync()
	return self


static func _material(key: String, color: Color, metal := false) -> StandardMaterial3D:
	if not _materials.has(key):
		var ink := StandardMaterial3D.new()
		ink.albedo_color = color
		ink.roughness = 0.57 if metal else 0.91
		ink.metallic = 0.35 if metal else 0.0
		ink.vertex_color_use_as_albedo = true
		_materials[key] = ink
	return _materials[key]


static func _part(buckets: Dictionary, key: String, mesh: Mesh, at: Vector3, stretch := Vector3.ONE, angle := 0.0) -> void:
	var palette := {"leather": Color("493a2b"), "trouser": Color("333938"), "skin": Color("aa8569"), "hair": Color("34302b"), "bronze": Color("92754a"), "iron": Color("4b5150"), "ivory": Color("bdb8a5"), "wood": Color("65513b"), "olive": Color("65704c")}
	var color: Color = palette.get(key, Color.WHITE)
	if key.begins_with("cloth"):
		color = Color(COATS[int(key.trim_prefix("cloth"))])
	var group := "metal" if key in ["bronze", "iron"] else "leather" if key == "leather" else "matte"
	if not buckets.has(group):
		var fresh := SurfaceTool.new()
		fresh.begin(Mesh.PRIMITIVE_TRIANGLES)
		buckets[group] = fresh
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	colors.resize(vertices.size())
	colors.fill(color)
	arrays[Mesh.ARRAY_COLOR] = colors
	var colored := ArrayMesh.new()
	colored.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var tool: SurfaceTool = buckets[group]
	var basis := Basis(Vector3.UP, angle).scaled(stretch)
	tool.append_from(colored, 0, Transform3D(basis, at))


static func _box(buckets: Dictionary, key: String, at: Vector3, dimensions: Vector3, angle := 0.0) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	_part(buckets, key, mesh, at, Vector3.ONE, angle)


static func _round(buckets: Dictionary, key: String, at: Vector3, radius: float, height: float, stretch := Vector3.ONE) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 6
	_part(buckets, key, mesh, at, stretch)


static func _cone(buckets: Dictionary, key: String, at: Vector3, bottom: float, top: float, height: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = 12
	_part(buckets, key, mesh, at)


static func build(identity: String) -> ArrayMesh:
	if _meshes.has(identity):
		return _meshes[identity]
	var index := IDS.find(identity)
	if index < 0:
		return null
	var buckets := {}
	var stout := identity in ["smith", "merchant", "elder"]
	var robe := identity in ["elder", "elin", "noah"]
	var breadth := 1.14 if stout else 1.0
	# Sole is exactly Y=0. Head top1.78m gives the established112px silhouette.
	for side in [-1.0, 1.0]:
		_box(buckets, "leather", Vector3(side * 0.11, 0.075, 0.045), Vector3(0.17, 0.15, 0.31))
		_cone(buckets, "trouser", Vector3(side * 0.11, 0.44, 0), 0.085, 0.095, 0.63)
		_round(buckets, "cloth" + str(index), Vector3(side * 0.29 * breadth, 1.20, 0.0), 0.09, 0.46)
		_round(buckets, "skin", Vector3(side * 0.30 * breadth, 0.94, 0.035), 0.066, 0.16)
	_cone(buckets, "cloth" + str(index), Vector3(0, 0.83 if robe else 0.91, 0), 0.29 if robe else 0.22 * breadth, 0.22 * breadth, 0.90 if robe else 0.66)
	_round(buckets, "cloth" + str(index), Vector3(0, 1.23, 0), 0.25, 0.49, Vector3(breadth, 1, 0.69))
	_box(buckets, "leather", Vector3(0, 0.99, 0), Vector3(0.47 * breadth, 0.065, 0.34))
	_box(buckets, "bronze", Vector3(0, 0.99, 0.182), Vector3(0.075, 0.063, 0.028))
	_cone(buckets, "skin", Vector3(0, 1.46, 0), 0.065, 0.065, 0.16)
	_round(buckets, "skin", Vector3(0, 1.615, 0.01), 0.115, 0.255, Vector3(0.92, 1, 0.92))
	_box(buckets, "skin", Vector3(0, 1.615, 0.123), Vector3(0.038, 0.07, 0.047))
	for side in [-1.0, 1.0]:
		_box(buckets, "hair", Vector3(side * 0.047, 1.655, 0.110), Vector3(0.033, 0.012, 0.012))
	_round(buckets, "hair", Vector3(0, 1.705, -0.015), 0.12, 0.15)
	# Each role has a different construction, not just a clothing hue.
	match identity:
		"merchant":
			_box(buckets, "leather", Vector3(0.20, 1.06, 0.20), Vector3(0.17, 0.22, 0.10))
			_cone(buckets, "cloth0", Vector3(0, 1.75, 0), 0.16, 0.10, 0.10)
		"smith":
			_box(buckets, "leather", Vector3(0, 0.98, 0.19), Vector3(0.34, 0.66, 0.035))
			_box(buckets, "leather", Vector3(0.32, 0.93, 0.10), Vector3(0.035, 0.34, 0.035))
			_box(buckets, "iron", Vector3(0.32, 1.11, 0.10), Vector3(0.18, 0.09, 0.08))
		"stable":
			_box(buckets, "leather", Vector3(0, 1.22, -0.17), Vector3(0.37, 0.48, 0.12))
			_box(buckets, "bronze", Vector3(-0.22, 1.02, 0.19), Vector3(0.045, 0.21, 0.045))
		"elder":
			_round(buckets, "ivory", Vector3(0, 1.52, 0.10), 0.09, 0.21)
			_box(buckets, "wood", Vector3(0.36, 0.82, 0.03), Vector3(0.045, 1.64, 0.045))
			_round(buckets, "bronze", Vector3(0.36, 1.66, 0.03), 0.06, 0.10)
		"mira":
			_box(buckets, "leather", Vector3(0, 1.16, -0.23), Vector3(0.39, 0.49, 0.23))
			_box(buckets, "ivory", Vector3(0, 1.40, -0.24), Vector3(0.42, 0.12, 0.25))
		"elin":
			_cone(buckets, "ivory", Vector3(0, 1.61, -0.035), 0.18, 0.13, 0.35)
			# Restore a clear face in front of the veil.
			_round(buckets, "skin", Vector3(0, 1.62, 0.085), 0.097, 0.22, Vector3(0.95, 1, 0.75))
			_box(buckets, "ivory", Vector3(0, 1.20, 0.19), Vector3(0.18, 0.34, 0.025))
		"noah":
			_cone(buckets, "cloth6", Vector3(0, 1.73, -0.03), 0.18, 0.04, 0.22)
			_box(buckets, "wood", Vector3(0.23, 0.91, 0.18), Vector3(0.16, 0.22, 0.15))
			for side in [-1.0, 1.0]:
				_round(buckets, "olive", Vector3(0.23 + side * 0.04, 1.06, 0.18), 0.05, 0.18)
		"rowen":
			_box(buckets, "leather", Vector3(0, 1.17, -0.20), Vector3(0.31, 0.40, 0.16))
			_box(buckets, "ivory", Vector3(0.27, 0.97, 0.16), Vector3(0.12, 0.21, 0.08))
			_box(buckets, "iron", Vector3(-0.18, 1.30, 0.02), Vector3(0.20, 0.10, 0.26))
	var result := ArrayMesh.new()
	for key: String in buckets:
		var tool: SurfaceTool = buckets[key]
		tool.commit(result)
		result.surface_set_material(result.get_surface_count() - 1, _material(key, Color.WHITE, key == "metal"))
	_meshes[identity] = result
	return result


func sync() -> void:
	for id in entries.keys():
		var owner: Villager = entries[id]["owner"].get_ref()
		if not is_instance_valid(owner) or owner.is_queued_for_deletion():
			entries[id]["node"].queue_free()
			entries.erase(id)
	for candidate in preview.game.village.npc_nodes.values():
		var resident := candidate as Villager
		if not is_instance_valid(resident) or resident.is_queued_for_deletion():
			continue
		var id := resident.get_instance_id()
		if not entries.has(id):
			var instance := MeshInstance3D.new()
			instance.name = "NativeResident_" + NpcArt.identity(resident.display_name)
			instance.mesh = build(NpcArt.identity(resident.display_name))
			preview.stage.add_child(instance)
			entries[id] = {"owner": weakref(resident), "node": instance}
		var model: MeshInstance3D = entries[id]["node"]
		model.visible = resident.visible and resident.get_parent() == preview.game.world and not preview.game.dungeon.active
		model.position = preview.actor_foot(resident)
		var direction := Ortho3DPreview.ground_position(Vector2.from_angle(resident.facing))
		model.rotation.y = atan2(direction.x, direction.z)
		# Overlay is original resident damage state, never a new effect clock.
		if resident._hurt_flash > 0.0:
			if not entries[id].has("flash"):
				var shader := Shader.new()
				shader.code = Ortho3DPreview.ACTOR_FLASH_CODE
				var flash := ShaderMaterial.new()
				flash.shader = shader
				entries[id]["flash"] = flash
			var flash: ShaderMaterial = entries[id]["flash"]
			flash.set_shader_parameter("flash_color", Color(1.0, 0.64, 0.59))
			flash.set_shader_parameter("flash_strength", resident._hurt_flash * 0.65)
			model.material_overlay = flash
		else:
			model.material_overlay = null


func review_snapshot() -> Dictionary:
	var identities := []
	var visible := 0
	for entry: Dictionary in entries.values():
		var node: MeshInstance3D = entry["node"]
		if node.visible:
			visible += 1
		identities.append(node.name)
	return {"mapped": IDS, "instances": entries.size(), "visible": visible, "identities": identities, "camera_facing_cards": 0}

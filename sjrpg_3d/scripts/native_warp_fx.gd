class_name NativeWarpFx
extends RefCounted
## 플레이어 전체의 원본 재질은 보존하고 전용 알파 사본과 재사용하는 작은 빛 기둥만 표시한다.
var preview: Node
var root: Node3D
var rings: Array[MeshInstance3D] = []
var motes: MultiMeshInstance3D
var slots: Array[Dictionary] = []
var _materials := {}
var _meshes: Array[Dictionary] = []
var _was_active := false


func setup(presenter: Node) -> NativeWarpFx:
	preview = presenter
	_create()
	return self


func _ink() -> StandardMaterial3D:
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ink.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ink.vertex_color_use_as_albedo = true
	ink.albedo_color = Color(.45, .87, 1, .7)
	return ink


func _create() -> void:
	root = Node3D.new()
	root.name = "WarpTravelLight"
	root.visible = false
	preview.stage.add_child(root)
	var mesh := TorusMesh.new()
	mesh.inner_radius = .72
	mesh.outer_radius = .76
	mesh.rings = 32
	mesh.ring_segments = 4
	for index in 3:
		var ring := MeshInstance3D.new()
		ring.mesh = mesh
		ring.material_override = _ink()
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ring)
		rings.append(ring)
	motes = MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	var sphere := SphereMesh.new()
	sphere.radius = .035
	sphere.height = .07
	sphere.radial_segments = 6
	sphere.rings = 3
	multimesh.mesh = sphere
	multimesh.instance_count = 12
	motes.multimesh = multimesh
	motes.material_override = _ink()
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(motes)
	for child in preview.actor.find_children("*", "MeshInstance3D", true, false):
		var actor_mesh := child as MeshInstance3D
		_meshes.append({"mesh": actor_mesh, "shadow": actor_mesh.cast_shadow})
		if actor_mesh.material_override != null:
			_add_slot(actor_mesh, -1, actor_mesh.material_override, actor_mesh.material_override)
		else:
			for surface in actor_mesh.mesh.get_surface_count():
				_add_slot(
					actor_mesh,
					surface,
					actor_mesh.get_active_material(surface),
					actor_mesh.get_surface_override_material(surface)
				)


func _add_slot(mesh: MeshInstance3D, surface: int, source: Material, original: Material) -> void:
	assert(source is StandardMaterial3D, "워프하는 배우 표면은 StandardMaterial3D 계약을 따릅니다.")
	var key := source.get_instance_id()
	if not _materials.has(key):
		var fade := source.duplicate() as StandardMaterial3D
		fade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials[key] = {"fade": fade, "color": (source as StandardMaterial3D).albedo_color}
	slots.append(
		{"mesh": mesh, "surface": surface, "original": original, "material": _materials[key]}
	)


func sync() -> void:
	var travel: WarpTravel = preview.game.exploration.transition
	if not travel.active and not _was_active:
		return
	if root == null:
		_create()
	root.visible = travel.active
	for slot in slots:
		var material: Material = slot["material"]["fade"] if travel.active else slot["original"]
		var mesh: MeshInstance3D = slot["mesh"]
		if int(slot["surface"]) < 0:
			mesh.material_override = material
		else:
			mesh.set_surface_override_material(int(slot["surface"]), material)
	for entry in _meshes:
		var mesh: MeshInstance3D = entry["mesh"]
		mesh.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if travel.active else entry["shadow"]
		)
		if travel.active:
			mesh.material_overlay = null
	for material: Dictionary in _materials.values():
		var ink: Color = material["color"]
		ink.a *= travel.opacity()
		(material["fade"] as StandardMaterial3D).albedo_color = ink
	_was_active = travel.active
	if not travel.active:
		return
	root.position = preview.actor_foot(preview.game.player)
	var departure := not travel.transferred
	var phase := clampf(
		(
			travel.age / WarpTravel.OUT
			if departure
			else (travel.age - WarpTravel.OUT) / (WarpTravel.DURATION - WarpTravel.OUT)
		),
		0.0,
		1.0
	)
	var strength := sin(phase * PI) * (.45 if Prefs.reduce_motion else .8)
	for index in rings.size():
		var ring := rings[index]
		var spread := 1.0 if Prefs.reduce_motion else lerpf(.72, 1.20, phase)
		ring.scale = Vector3(spread, 1, spread)
		ring.position.y = .04 + index * (.54 if Prefs.reduce_motion else phase * .8)
		(ring.material_override as StandardMaterial3D).albedo_color = Color(
			.42, .84, 1, strength * (1.0 - index * .18)
		)
	for index in 12:
		var angle := TAU * index / 12.0
		var height := .25 + (index % 4) * .32 + (0.0 if Prefs.reduce_motion else phase * .6)
		motes.multimesh.set_instance_transform(
			index, Transform3D(Basis.IDENTITY, Vector3(cos(angle) * .58, height, sin(angle) * .58))
		)
		motes.multimesh.set_instance_color(index, Color(.65, .94, 1, strength))


func warm_up() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var samples: Array = []
	for slot in slots:
		samples.append(
			{"mesh": (slot["mesh"] as MeshInstance3D).mesh, "ink": slot["material"]["fade"]}
		)
	for ring in rings:
		samples.append({"mesh": ring.mesh, "ink": ring.material_override})
	samples.append({"mesh": motes.multimesh.mesh, "ink": motes.material_override})
	await NativeOcclusionWarmup.draw(preview, samples)

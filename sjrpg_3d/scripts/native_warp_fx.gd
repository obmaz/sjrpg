class_name NativeWarpFx
extends RefCounted
## 전환 시계에 맞춰 배우 표시 헬퍼와 재사용하는 작은 빛 기둥을 동기화한다.
var preview: Node
var root: Node3D
var rings: Array[MeshInstance3D] = []
var motes: MultiMeshInstance3D
var fade := ActorWarpFade.new()
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
	fade.prepare(preview.actor)


func sync() -> void:
	var travel: WarpTravel = preview.game.exploration.transition
	if not travel.active and not _was_active:
		return
	if root == null:
		_create()
	root.visible = travel.active
	fade.sync(preview.actor, travel.active, travel.opacity())
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
	var samples := fade.warmup_samples()
	for ring in rings:
		samples.append({"mesh": ring.mesh, "ink": ring.material_override})
	samples.append({"mesh": motes.multimesh.mesh, "ink": motes.material_override})
	await NativeOcclusionWarmup.draw(preview, samples)

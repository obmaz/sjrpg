class_name NativeCaveLanterns3D
extends RefCounted
## Legacy "lantern" source ownership is retained; the native picture is a wood/iron torch.
## Four shared batches cover all ten torches. Fire reads the existing cave light clock.
const FLAME_BASE := 0.44


static func build(preview: Node, parent: Node3D, sources: Array) -> Dictionary:
	var root := Node3D.new()
	root.name = "NativeCaveLanterns"
	parent.add_child(root)
	var owned := {}
	var anchors := PackedVector3Array()
	for source in sources:
		if not source is IsoSprite or str(source.get_meta("cave_role", "")) != "lantern":
			continue
		owned[source.get_instance_id()] = true
		anchors.append(Ortho3DPreview.ground_position(source.global_position, 0.0))
	var timber := SurfaceTool.new()
	timber.begin(Mesh.PRIMITIVE_TRIANGLES)
	var handle := CylinderMesh.new()
	handle.bottom_radius = 0.022
	handle.top_radius = 0.042
	handle.height = 0.44
	handle.radial_segments = 8
	handle.rings = 1
	timber.append_from(handle, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0.22, 0)))
	var iron := SurfaceTool.new()
	iron.begin(Mesh.PRIMITIVE_TRIANGLES)
	_ring(iron, 0.29, 0.035, 0.048, 0.048, 0.011)
	_ring(iron, 0.36, 0.12, 0.047, 0.086, 0.013)
	var outer := _flame(0.11, 0.46, 0.065)
	var core := _flame(0.052, 0.30, -0.018)
	var batches := {
		"wood": _batch(root, "TorchWood", timber.commit(), preview._materials["wood"], anchors, true),
		"iron": _batch(root, "TorchIron", iron.commit(), preview._materials["iron"], anchors, true),
		"outer": _batch(root, "TorchFlame", outer, _fire_material(Color("c85818"), Color("f17b24"), 0.5), anchors, false),
		"core": _batch(root, "TorchCore", core, _fire_material(Color("f3cf8d"), Color("ffd584"), 0.6), anchors, false)
	}
	var report := {"owned_source_ids": owned, "root": root, "count": owned.size(),
		"anchors": anchors, "batches": batches, "visual_key": [],
		"outer_transforms": [], "core_transforms": [], "style": "torch"}
	root.set_meta("native_lantern_report", report)
	sync(parent, 0.0)
	return report


## Called from Ortho3DEnvironment.sync with its authoritative light clock.
## No TIME shader, process callback, extra light, particle system or shadow pass.
static func sync(parent: Node3D, clock: float) -> void:
	if not is_instance_valid(parent) or not parent.is_visible_in_tree():
		return
	var root := parent.get_node_or_null("NativeCaveLanterns") as Node3D
	if root == null:
		return
	var report: Dictionary = root.get_meta("native_lantern_report")
	var key: Array = [0.0 if Prefs.reduce_motion else clock, Prefs.reduce_motion]
	if report["visual_key"] == key:
		return
	var anchors: PackedVector3Array = report["anchors"]
	var batches: Dictionary = report["batches"]
	var outer: Array[Transform3D] = []
	var core: Array[Transform3D] = []
	for index in anchors.size():
		var transform := _fire_transform(anchors[index], clock, index, Prefs.reduce_motion)
		var centre := transform
		# The pale inner tongue remains a small real volume, visible on the front
		# of the orange flame from the fixed 45-degree quarter-view camera.
		centre.origin += Vector3(0.048, 0.0, 0.048)
		(batches["outer"] as MultiMeshInstance3D).multimesh.set_instance_transform(index, transform)
		(batches["core"] as MultiMeshInstance3D).multimesh.set_instance_transform(index, centre)
		outer.append(transform)
		core.append(centre)
	report["outer_transforms"] = outer
	report["core_transforms"] = core
	report["visual_key"] = key


static func _fire_transform(at: Vector3, clock: float, index: int, still: bool) -> Transform3D:
	var phase := clock * 5.3 + index * 1.73
	var width := 1.0 if still else 0.95 + sin(phase * 1.31) * 0.06
	var height := 1.0 if still else 0.97 + sin(phase) * 0.08
	var lean := 0.0 if still else sin(phase * 0.83) * 0.07
	var basis := Basis(Vector3.FORWARD, lean) * Basis.from_scale(Vector3(width, height, width))
	return Transform3D(basis, at + Vector3.UP * FLAME_BASE)


static func _batch(parent: Node3D, label: String, mesh: Mesh, material: Material, anchors: PackedVector3Array, shadows: bool) -> MultiMeshInstance3D:
	var shared := MultiMesh.new()
	shared.transform_format = MultiMesh.TRANSFORM_3D
	shared.mesh = mesh
	shared.instance_count = anchors.size()
	for index in anchors.size():
		shared.set_instance_transform(index, Transform3D(Basis.IDENTITY, anchors[index]))
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = shared
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


static func _fire_material(tint: Color, glow: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = glow
	material.emission_energy_multiplier = energy
	material.roughness = 0.9
	return material


static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	var reverse := normal.dot(outward) > 0.0
	if not reverse:
		normal = -normal
	# Godot's front faces are clockwise; all normals face outside the volume.
	var ordered: Array[Vector3] = [a, c, b] if reverse else [a, b, c]
	for point: Vector3 in ordered:
		tool.set_normal(normal)
		tool.set_uv(Vector2(point.x, point.y))
		tool.add_vertex(point)


static func _ring(tool: SurfaceTool, bottom: float, height: float, lower: float, upper: float, thickness: float) -> void:
	var rings: Array[PackedVector3Array] = []
	for section: Vector3 in [Vector3(lower, bottom, 0), Vector3(upper, bottom + height, 0),
			Vector3(lower - thickness, bottom, 0), Vector3(upper - thickness, bottom + height, 0)]:
		var ring := PackedVector3Array()
		for index in 8:
			var angle := TAU * index / 8.0
			ring.append(Vector3(cos(angle) * section.x, section.y, sin(angle) * section.x))
		rings.append(ring)
	for index in 8:
		var next := (index + 1) % 8
		var direction := Vector3(cos(TAU * (index + 0.5) / 8.0), 0, sin(TAU * (index + 0.5) / 8.0))
		_quad(tool, rings[0][index], rings[1][index], rings[1][next], rings[0][next], direction)
		_quad(tool, rings[2][index], rings[2][next], rings[3][next], rings[3][index], -direction)
		_quad(tool, rings[1][index], rings[3][index], rings[3][next], rings[1][next], Vector3.UP)
		_quad(tool, rings[0][index], rings[0][next], rings[2][next], rings[2][index], Vector3.DOWN)


static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	_triangle(tool, a, b, c, outward)
	_triangle(tool, a, c, d, outward)


static func _flame(radius: float, height: float, bend: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for section: Vector3 in [Vector3(radius * 0.48, 0.0, 0.0), Vector3(radius, height * 0.32, -bend * 0.25),
			Vector3(radius * 0.48, height * 0.71, bend * 0.42)]:
		var ring := PackedVector3Array()
		for index in 6:
			var angle := TAU * index / 6.0
			ring.append(Vector3(cos(angle) * section.x + section.z, section.y, sin(angle) * section.x))
		rings.append(ring)
	var tip := Vector3(bend, height, -radius * 0.12)
	for index in 6:
		var next := (index + 1) % 6
		var outward := Vector3(cos(TAU * (index + 0.5) / 6.0), 0.2, sin(TAU * (index + 0.5) / 6.0))
		for level in 2:
			_triangle(tool, rings[level][index], rings[level + 1][index], rings[level + 1][next], outward)
			_triangle(tool, rings[level][index], rings[level + 1][next], rings[level][next], outward)
		_triangle(tool, rings[0][index], Vector3.ZERO, rings[0][next], Vector3.DOWN)
		_triangle(tool, rings[2][index], tip, rings[2][next], outward)
	return tool.commit()

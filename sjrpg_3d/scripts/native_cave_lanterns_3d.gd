class_name NativeCaveLanterns3D
extends RefCounted
## One static mesh per authored lamp; existing cave lights retain their original clock.
static func build(preview: Node, parent: Node3D, sources: Array) -> Dictionary:
	var root := Node3D.new()
	root.name = "NativeCaveLanterns"
	parent.add_child(root)
	var frame := SurfaceTool.new()
	frame.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Reuse primitive mesh faces to keep real normals and closed volumes.
	for y in [0.055, 0.66]:
		_box(frame, Vector3(0, y, 0), Vector3(0.34, 0.07, 0.34))
	for x in [-0.13, 0.13]:
		for z in [-0.13, 0.13]:
			_box(frame, Vector3(x, 0.36, z), Vector3(0.028, 0.55, 0.028))
	_box(frame, Vector3(0, 0.73, 0), Vector3(0.16, 0.05, 0.07))
	_box(frame, Vector3(-0.067, 0.79, 0), Vector3(0.026, 0.14, 0.026))
	_box(frame, Vector3(0.067, 0.79, 0), Vector3(0.026, 0.14, 0.026))
	_box(frame, Vector3(0, 0.86, 0), Vector3(0.16, 0.026, 0.026))
	var frame_mesh := frame.commit()
	var glass := BoxMesh.new()
	glass.size = Vector3(0.23, 0.48, 0.23)
	var warm := StandardMaterial3D.new()
	warm.albedo_color = Color("c68a3d")
	warm.emission_enabled = true
	warm.emission = Color("c4822e")
	warm.emission_energy_multiplier = 0.85
	warm.roughness = 0.55
	var owned := {}
	for source in sources:
		if not source is IsoSprite or str(source.get_meta("cave_role", "")) != "lantern":
			continue
		var group := Node3D.new()
		group.name = "Lantern%d" % owned.size()
		group.position = Ortho3DPreview.ground_position(source.global_position, 0.0)
		parent.add_child(group)
		group.reparent(root, true)
		var cage := MeshInstance3D.new()
		cage.mesh = frame_mesh
		cage.material_override = preview._materials["iron"]
		group.add_child(cage)
		var glow := MeshInstance3D.new()
		glow.mesh = glass
		glow.material_override = warm
		glow.position.y = 0.36
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(glow)
		owned[source.get_instance_id()] = true
	var report := {"owned_source_ids": owned, "root": root, "count": owned.size()}
	root.set_meta("native_lantern_report", report)
	return report

static func _box(tool: SurfaceTool, centre: Vector3, dimensions: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var faces := mesh.get_faces()
	for index in range(0, faces.size(), 3):
		var a := faces[index] + centre
		var b := faces[index + 1] + centre
		var c := faces[index + 2] + centre
		var normal := (b - a).cross(c - a).normalized()
		if normal.dot((a + b + c) / 3.0 - centre) < 0.0:
			normal = -normal
		for point in [a, b, c]:
			tool.set_normal(normal)
			tool.add_vertex(point)

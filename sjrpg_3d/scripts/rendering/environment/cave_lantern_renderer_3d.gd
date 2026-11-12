class_name CaveLanternRenderer3D
extends RefCounted
## Legacy lantern ownership is retained; actual rock triangles own wall-sconce placement.
## Four shared batches cover ten larger torches; the existing cave clock drives fire.
const SCALE := 1.7
const MOUNT_HEIGHT := 1.55
const TORCH_DEPTH := 0.32
const HANDLE_BOTTOM := -0.25
const FLAME_BASE := 0.44 * SCALE + HANDLE_BOTTOM


static func build(renderer: Node, parent: Node3D, sources: Array) -> Dictionary:
	var root := Node3D.new()
	root.name = "NativeCaveLanterns"
	parent.add_child(root)
	var owned := {}
	var anchors := PackedVector3Array()
	var mounts: Array[Transform3D] = []
	var contacts: Array[Dictionary] = []
	var lights := PackedVector3Array()
	var rock: Dictionary = parent.get_meta("native_cave_rock", {})
	var profiles: Array = rock.get("profiles", [])
	for source in sources:
		if not source is IsoSprite or str(source.get_meta("cave_role", "")) != "lantern":
			continue
		var anchor := WorldSpace3D.projected_to_world(source.global_position, DungeonRelief.at(source.global_position))
		var mount := _wall_mount(anchor, profiles)
		if mount.is_empty():
			push_error("Cave torch has no supporting rendered wall")
			continue
		var transform: Transform3D = mount["transform"]
		mount["source_id"] = source.get_instance_id()
		owned[source.get_instance_id()] = true
		anchors.append(anchor)
		mounts.append(transform)
		contacts.append(mount)
		lights.append(transform * Vector3(0, FLAME_BASE + 0.24, TORCH_DEPTH + 0.10))
	var outer := _flame(0.11 * SCALE, 0.46 * SCALE, 0.065 * SCALE)
	var core := _flame(0.052 * SCALE, 0.30 * SCALE, -0.018 * SCALE)
	var batches := {
		"wood": _batch(root, "TorchWood", ModelSceneLibrary.mesh("environment/wall_torch", "wood"), renderer._materials["wood"], mounts, true),
		"iron": _batch(root, "TorchIron", ModelSceneLibrary.mesh("environment/wall_torch", "iron"), renderer._materials["iron"], mounts, true),
		"outer": _batch(root, "TorchFlame", outer, _fire_material(Color("c85818"), Color("f17b24"), 0.5), mounts, false),
		"core": _batch(root, "TorchCore", core, _fire_material(Color("f3cf8d"), Color("ffd584"), 0.6), mounts, false)
	}
	var report := {"owned_source_ids": owned, "root": root, "count": owned.size(),
		"anchors": anchors, "mount_transforms": mounts, "wall_contacts": contacts,
		"light_positions": lights, "batches": batches, "visual_key": [],
		"outer_transforms": [], "core_transforms": [], "style": "torch", "mounting": "wall", "scale": SCALE}
	root.set_meta("native_lantern_report", report)
	sync(parent, 0.0)
	return report


## Ray tests use the very same inner-face triangles as the rendered rock.
## Front cutaways are deliberately excluded: a tall flame must have a supporting wall.
static func _wall_mount(anchor: Vector3, profiles: Array) -> Dictionary:
	var best := {}
	var distance := INF
	var origin := Vector3(anchor.x, anchor.y + MOUNT_HEIGHT, anchor.z)
	for profile: Dictionary in profiles:
		if float(profile["height"]) < CaveWallGeometry3D.CHAMBER_HEIGHT:
			continue
		var outward: Vector2 = profile["outward"]
		var ray := Vector3(outward.x, 0, outward.y)
		var sections: Array = profile.get("sections", [])
		for station in range(sections.size() - 1):
			var a: PackedVector3Array = sections[station]
			var b: PackedVector3Array = sections[station + 1]
			for face in 4:
				for triangle: Array in [[a[face], b[face], b[face + 1]], [a[face], b[face + 1], a[face + 1]]]:
					var hit: Variant = Geometry3D.ray_intersects_triangle(origin, ray, triangle[0], triangle[1], triangle[2])
					if not hit is Vector3:
						continue
					var point: Vector3 = hit
					var gap := point.distance_squared_to(origin)
					if gap >= distance:
						continue
					var normal: Vector3 = (triangle[1] - triangle[0]).cross(triangle[2] - triangle[0]).normalized()
					if normal.dot(ray) > 0.0:
						normal = -normal
					var right := Vector3.UP.cross(normal).normalized()
					var up := normal.cross(right).normalized()
					distance = gap
					best = {"transform": Transform3D(Basis(right, up, normal), point),
						"triangle": triangle, "inward": normal, "source_origin": origin,
						"wall_outward": ray, "wall_height": profile["height"]}
	return best


## No extra process callback, particle system, light or shadow pass.
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
	var mounts: Array = report["mount_transforms"]
	var batches: Dictionary = report["batches"]
	var outer: Array[Transform3D] = []
	var core: Array[Transform3D] = []
	for index in mounts.size():
		var mount: Transform3D = mounts[index]
		var transform := _fire_transform(mount, clock, index, Prefs.reduce_motion)
		var centre := transform
		# Keep the opaque pale core on the camera-facing shell at the larger scale.
		centre.origin += Vector3(0.048, 0.0, 0.048) * SCALE
		(batches["outer"] as MultiMeshInstance3D).multimesh.set_instance_transform(index, transform)
		(batches["core"] as MultiMeshInstance3D).multimesh.set_instance_transform(index, centre)
		outer.append(transform)
		core.append(centre)
	report["outer_transforms"] = outer
	report["core_transforms"] = core
	report["visual_key"] = key


static func _fire_transform(mount: Transform3D, clock: float, index: int, still: bool) -> Transform3D:
	var phase := clock * 5.3 + index * 1.73
	var width := 1.0 if still else 0.95 + sin(phase * 1.31) * 0.06
	var height := 1.0 if still else 0.97 + sin(phase) * 0.08
	var lean := 0.0 if still else sin(phase * 0.83) * 0.07
	var basis := mount.basis * Basis(Vector3.FORWARD, lean) * Basis.from_scale(Vector3(width, height, width))
	return Transform3D(basis, mount * Vector3(0, FLAME_BASE, TORCH_DEPTH))


static func _batch(parent: Node3D, label: String, mesh: Mesh, material: Material, mounts: Array[Transform3D], shadows: bool) -> MultiMeshInstance3D:
	var shared := MultiMesh.new()
	shared.transform_format = MultiMesh.TRANSFORM_3D
	shared.mesh = mesh
	shared.instance_count = mounts.size()
	for index in mounts.size():
		shared.set_instance_transform(index, mounts[index])
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
	var ordered: Array = [a, c, b] if reverse else [a, b, c]
	for point: Vector3 in ordered:
		tool.set_normal(normal)
		tool.set_uv(Vector2(point.x, point.y))
		tool.add_vertex(point)


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

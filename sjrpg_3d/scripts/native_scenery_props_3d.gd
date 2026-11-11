class_name NativeSceneryProps3D
extends RefCounted
## Exact authored definitions/roles, never atlas-wide ownership or name guessing.

static func role_of(source: IsoSprite, village: Village) -> String:
	var role := str(source.get_meta("cave_role", ""))
	if role in ["arch", "boulder", "crystal"]:
		return role
	if source.def == village.data["sprites"]["rock"]:
		return "boulder"
	if source.def == DungeonArt.data()["frames"]["entrance"]:
		return "entrance"
	return ""

static func _face(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, centre: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.dot((a + b + c + d) * 0.25 - centre) < 0:
		normal = -normal
	NativeLandmarks3D._tri(tool, a, b, c, normal)
	NativeLandmarks3D._tri(tool, a, c, d, normal)

static func _box(tool: SurfaceTool, origin: Vector3, size: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	var faces := box.get_faces()
	for i in range(0, faces.size(), 3):
		var a := faces[i] + origin
		var b := faces[i + 1] + origin
		var c := faces[i + 2] + origin
		var normal := (b - a).cross(c - a).normalized()
		if normal.dot((a + b + c) / 3.0 - origin) < 0:
			normal = -normal
		NativeLandmarks3D._tri(tool, a, b, c, normal)

static func arch_mesh(clear_width: float, height: float, thickness := 0.36, depth := 0.62) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radius := clear_width * 0.5
	var spring := maxf(1.85, height - (radius + thickness) * 0.85)
	_box(tool, Vector3(-radius - thickness * 0.5, spring * 0.5, 0), Vector3(thickness, spring, depth))
	_box(tool, Vector3(radius + thickness * 0.5, spring * 0.5, 0), Vector3(thickness, spring, depth))
	for i in 12:
		var a := PI * i / 12.0
		var b := PI * (i + 1) / 12.0
		var inner_a := Vector3(cos(a) * radius, spring + sin(a) * radius * 0.85, 0)
		var inner_b := Vector3(cos(b) * radius, spring + sin(b) * radius * 0.85, 0)
		var outer_a := Vector3(cos(a) * (radius + thickness), spring + sin(a) * (radius + thickness) * 0.85, 0)
		var outer_b := Vector3(cos(b) * (radius + thickness), spring + sin(b) * (radius + thickness) * 0.85, 0)
		var front := Vector3.BACK * depth * 0.5
		var back := -front
		var centre := (inner_a + inner_b + outer_a + outer_b) * 0.25
		_face(tool, inner_a + front, inner_b + front, outer_b + front, outer_a + front, centre)
		_face(tool, inner_b + back, inner_a + back, outer_a + back, outer_b + back, centre)
		_face(tool, inner_a + back, inner_b + back, inner_b + front, inner_a + front, centre)
		_face(tool, outer_b + back, outer_a + back, outer_a + front, outer_b + front, centre)
		_face(tool, inner_a + back, inner_a + front, outer_a + front, outer_a + back, centre)
		_face(tool, inner_b + front, inner_b + back, outer_b + back, outer_b + front, centre)
	return tool.commit()

static func _rock_mesh(radius: float, height: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var primitive := SphereMesh.new()
	primitive.radius = 1
	primitive.height = 2
	primitive.radial_segments = 10
	primitive.rings = 4
	var faces := primitive.get_faces()
	for part in 3:
		var scale := Vector3(radius * (0.72 if part == 0 else 0.44), height * (0.5 if part == 0 else 0.29), radius * (0.64 if part == 0 else 0.42))
		var centre := Vector3(0 if part == 0 else radius * (0.48 if part == 1 else -0.44), scale.y * 0.88, radius * (0.12 if part == 1 else -0.12))
		for i in range(0, faces.size(), 3):
			var a := faces[i] * scale + centre
			var b := faces[i + 1] * scale + centre
			var c := faces[i + 2] * scale + centre
			var normal := (b - a).cross(c - a).normalized()
			if normal.dot((a + b + c) / 3.0 - centre) < 0:
				normal = -normal
			NativeLandmarks3D._tri(tool, a, b, c, normal)
	return tool.commit()

static func _crystal_mesh(height: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for stem in 3:
		var radius := height * (0.13 if stem == 0 else 0.09)
		var centre := Vector3((stem - 1) * height * 0.15, 0, stem * height * 0.06)
		var top := centre + Vector3.UP * height * (1.0 if stem == 0 else 0.68)
		for i in 6:
			var a := centre + Vector3(cos(TAU * i / 6), 0, sin(TAU * i / 6)) * radius
			var b := centre + Vector3(cos(TAU * (i + 1) / 6), 0, sin(TAU * (i + 1) / 6)) * radius
			var high_a := a + Vector3.UP * top.y * 0.72
			var high_b := b + Vector3.UP * top.y * 0.72
			_face(tool, a, b, high_b, high_a, centre + Vector3.UP * top.y * 0.5)
			var normal := (high_b - high_a).cross(top - high_a).normalized()
			if normal.dot((top + high_a + high_b) / 3.0 - centre - Vector3.UP * top.y * 0.5) < 0:
				normal = -normal
			NativeLandmarks3D._tri(tool, high_a, high_b, top, normal)
			NativeLandmarks3D._tri(tool, centre, b, a, Vector3.DOWN)
	return tool.commit()

static func build(preview: Node, parent: Node3D, world: Node2D, cave: bool, excluded: Dictionary = {}) -> Dictionary:
	var root := Node3D.new()
	root.name = "NativeCaveScenery" if cave else "NativeFieldScenery"
	parent.add_child(root)
	var stone := StandardMaterial3D.new()
	stone.albedo_texture = load("res://assets/art/village/rock.webp")
	stone.uv1_triplanar = true
	stone.uv1_world_triplanar = true
	stone.uv1_scale = Vector3.ONE / 2.56
	stone.roughness = 0.95
	# 위치에서 선택하는 공유 표면: 재접속이나 카메라 회전에도 바뀌지 않는다.
	var stone_variants: Array[StandardMaterial3D] = [stone]
	for surface: String in ["rock_lichen", "rock_iron"]:
		var variant := stone.duplicate() as StandardMaterial3D
		variant.albedo_texture = load("res://assets/art/preview3d/" + surface + ".webp")
		stone_variants.append(variant)
	var crystal := StandardMaterial3D.new()
	crystal.albedo_color = Color("648889")
	crystal.roughness = 0.42
	crystal.metallic = 0.14
	var owned := {}
	var entries: Array[Dictionary] = []
	for child in world.get_children():
		if not child is IsoSprite or excluded.has(child.get_instance_id()) or child.clip != Vector2.ZERO or not child.visible:
			continue
		var source := child as IsoSprite
		var role := role_of(source, preview.game.village)
		if role.is_empty():
			continue
		var at := Ortho3DPreview.ground_position(source.global_position, preview.surface_height(source.global_position))
		var height := float(source.def["height"]) * source.k / SpatialWorld3D.VERTICAL
		var basis := Basis.IDENTITY
		var mesh: ArrayMesh
		var opening := 0.0
		if role == "arch":
			var corners: Array = source.def["opening"]
			var left := source.atlas_point(Vector2(corners[0][0], corners[0][1]))
			var right := source.atlas_point(Vector2(corners[1][0], corners[1][1]))
			var a := Ortho3DPreview.ground_position(left)
			var b := Ortho3DPreview.ground_position(right)
			at = (a + b) * 0.5
			at.y = preview.surface_height((left+right)*.5)
			var axis := (b - a).normalized()
			basis = Basis(axis, Vector3.UP, axis.cross(Vector3.UP))
			opening = a.distance_to(b)
			mesh = arch_mesh(opening, height)
		elif role == "entrance":
			# 열려 있는 바닥 홈과 양옆/후면의 실제 암반을 공용 설계로 배치한다.
			var cave_frame := NativeCavePlan.frame(source.global_position + NativeCavePlan.ENTRY_OFFSET)
			at = cave_frame.origin
			basis = cave_frame.basis
			opening = NativeCavePlan.OPENING_WIDTH
			mesh = NativeCaveEntrance3D.mesh(NativeCavePlan.HILL_HEIGHT, SpatialWorld3D.radius_metres(NativeCavePlan.SOURCE_RADIUS))
		elif role == "crystal":
			mesh = _crystal_mesh(height)
		else:
			var radius := 0.55
			for circle: Array in preview.game.village.circles:
				var point: Vector2 = circle[0]
				if point.distance_squared_to(source.global_position) < 0.001:
					radius = SpatialWorld3D.radius_metres(float(circle[1]))
					break
			mesh = _rock_mesh(radius, minf(height, 2.2))
		if mesh == null:
			continue
		var node := MeshInstance3D.new()
		node.name = "Native_" + role + "_" + str(entries.size())
		NativePlayerOcclusion.mark_object(node)
		node.mesh = mesh
		var variant_index: int = posmod(roundi(at.x * 7.0 + at.z * 11.0), stone_variants.size())
		node.material_override = crystal if role == "crystal" else stone_variants[variant_index]
		if role == "entrance":
			var hill := ShaderMaterial.new()
			hill.shader = load("res://assets/models/environment/cave_entrance/surface.gdshader")
			hill.set_shader_parameter("stone", load("res://assets/models/environment/cave_entrance/albedo.png"))
			hill.set_shader_parameter("grass", load("res://assets/art/forest/grass.webp"))
			hill.set_shader_parameter("earth", load("res://assets/art/forest/earth.webp"))
			node.material_override = hill
		node.transform = Transform3D(basis, at)
		root.add_child(node)
		owned[source.get_instance_id()] = true
		entries.append({"source_id": source.get_instance_id(), "role": role, "source_foot": source.global_position, "transform": node.transform, "clear_width": opening, "mesh": mesh})
	var report := {"owned_source_ids": owned, "entries": entries, "root": root}
	root.set_meta("native_scenery_report", report)
	return report

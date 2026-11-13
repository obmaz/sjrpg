class_name SceneryRenderer3D
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
	LandmarkRenderer3D._tri(tool, a, b, c, normal)
	LandmarkRenderer3D._tri(tool, a, c, d, normal)

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
		LandmarkRenderer3D._tri(tool, a, b, c, normal)

## 동굴의 실제 통과 폭은 보존하고, 얇은 완성 석조 문틀 대신 두꺼운 암반 지지부를 만든다.
static func _arch_column(tool: SurfaceTool, side: float, radius: float, spring: float, thickness: float, depth: float) -> void:
	var previous: Array[Vector3] = []
	var first: Array[Vector3] = []
	var centre := Vector3(side * (radius + thickness * .5), spring * .5, 0)
	for station in 4:
		var height: float = [0.0, .32, spring * .58, spring][station]
		var width: float = thickness * [1.18, 1.05, 1.26, 1.0][station]
		# 방 경계에서30/65m 바깥에 놓이므로 아래 기둥은 기존 보행면에 침범하지 않는다.
		var half_depth: float = minf(.44, depth * [0.57, 0.49, 0.55, 0.50][station])
		var inner := side * radius
		var outer := side * (radius + width)
		var section: Array[Vector3] = [Vector3(inner, height, -half_depth), Vector3(outer, height, -half_depth), Vector3(outer, height, half_depth), Vector3(inner, height, half_depth)]
		if first.is_empty():
			first = section
		if not previous.is_empty():
			for face in 4:
				var next := (face + 1) % 4
				_face(tool, previous[face], previous[next], section[next], section[face], centre)
		previous = section
	_face(tool, first[0], first[3], first[2], first[1], centre)
	_face(tool, previous[0], previous[1], previous[2], previous[3], centre)


static func arch_mesh(clear_width: float, height: float, thickness := 0.58, depth := 1.12) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radius := clear_width * .5
	var spring := maxf(1.85, height - (radius + thickness) * .85)
	for side: float in [-1.0, 1.0]:
		_arch_column(tool, side, radius, spring, thickness, depth)
	for i in 12:
		var a := PI * i / 12.0
		var b := PI * (i + 1) / 12.0
		var inner_a := Vector3(cos(a) * radius, spring + sin(a) * radius * .85, 0)
		var inner_b := Vector3(cos(b) * radius, spring + sin(b) * radius * .85, 0)
		var width_a := thickness * (.98 + .16 * sin(a * 3.0 + .3))
		var width_b := thickness * (.98 + .16 * sin(b * 3.0 + .3))
		var outer_a := Vector3(cos(a) * (radius + width_a), spring + sin(a) * (radius + width_a) * .85, 0)
		var outer_b := Vector3(cos(b) * (radius + width_b), spring + sin(b) * (radius + width_b) * .85, 0)
		var over_a := smoothstep(0.0, .55, sin(a))
		var over_b := smoothstep(0.0, .55, sin(b))
		var front_a := Vector3.BACK * lerpf(.44, depth * (.50 + .10 * sin(a * 4.0)), over_a)
		var front_b := Vector3.BACK * lerpf(.44, depth * (.50 + .10 * sin(b * 4.0)), over_b)
		var back_a := -Vector3.BACK * lerpf(.44, depth * (.50 + .08 * sin(a * 3.0 + .5)), over_a)
		var back_b := -Vector3.BACK * lerpf(.44, depth * (.50 + .08 * sin(b * 3.0 + .5)), over_b)
		var centre := (inner_a + inner_b + outer_a + outer_b) * .25
		_face(tool, inner_a + front_a, inner_b + front_b, outer_b + front_b, outer_a + front_a, centre)
		_face(tool, inner_b + back_b, inner_a + back_a, outer_a + back_a, outer_b + back_b, centre)
		_face(tool, inner_a + back_a, inner_b + back_b, inner_b + front_b, inner_a + front_a, centre)
		_face(tool, outer_b + back_b, outer_a + back_a, outer_a + front_a, outer_b + front_b, centre)
		_face(tool, inner_a + back_a, inner_a + front_a, outer_a + front_a, outer_a + back_a, centre)
		_face(tool, inner_b + front_b, inner_b + back_b, outer_b + back_b, outer_b + front_b, centre)
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
			LandmarkRenderer3D._tri(tool, a, b, c, normal)
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
			LandmarkRenderer3D._tri(tool, high_a, high_b, top, normal)
			LandmarkRenderer3D._tri(tool, centre, b, a, Vector3.DOWN)
	return tool.commit()

static func build(renderer: Node, parent: Node3D, world: Node2D, cave: bool, excluded: Dictionary = {}) -> Dictionary:
	var root := Node3D.new()
	root.name = "NativeCaveScenery" if cave else "NativeFieldScenery"
	parent.add_child(root)
	var stone := StandardMaterial3D.new()
	stone.albedo_texture = load("res://assets/materials/terrain/rock_base.webp")
	stone.uv1_triplanar = true
	stone.uv1_world_triplanar = true
	stone.uv1_scale = Vector3.ONE / 2.56
	stone.roughness = 0.95
	# 위치에서 선택하는 공유 표면: 재접속이나 카메라 회전에도 바뀌지 않는다.
	var stone_variants: Array[StandardMaterial3D] = [stone]
	for surface: String in ["rock_lichen", "rock_iron"]:
		var variant := stone.duplicate() as StandardMaterial3D
		variant.albedo_texture = load("res://assets/materials/shared/" + surface + ".webp")
		stone_variants.append(variant)
	var cave_rock: ShaderMaterial = NativeCaveSurfaces.material("wall", true) if cave else null
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
		var role := role_of(source, renderer.game.village)
		if role.is_empty():
			continue
		var at := WorldSpace3D.projected_to_world(source.global_position, renderer.surface_height(source.global_position))
		var height := float(source.def["height"]) * source.k / WorldSpace3D.VERTICAL_PIXELS_PER_METER
		var basis := Basis.IDENTITY
		var mesh: ArrayMesh
		var opening := 0.0
		if role == "arch":
			var corners: Array = source.def["opening"]
			var left := source.atlas_point(Vector2(corners[0][0], corners[0][1]))
			var right := source.atlas_point(Vector2(corners[1][0], corners[1][1]))
			var a := WorldSpace3D.projected_to_world(left)
			var b := WorldSpace3D.projected_to_world(right)
			at = (a + b) * 0.5
			at.y = renderer.surface_height((left+right)*.5)
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
			for circle: Array in renderer.game.village.circles:
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
		if role == "arch" and cave:
			node.material_override = cave_rock
		if role == "entrance":
			var hill := ShaderMaterial.new()
			hill.shader = load("res://assets/models/environment/cave_entrance/surface.gdshader")
			hill.set_shader_parameter("stone", load("res://assets/models/environment/cave_entrance/albedo.png"))
			hill.set_shader_parameter("grass", load("res://assets/materials/terrain/grass_base.webp"))
			hill.set_shader_parameter("earth", load("res://assets/sprites/forest/earth.webp"))
			node.material_override = hill
		node.transform = Transform3D(basis, at)
		root.add_child(node)
		owned[source.get_instance_id()] = true
		entries.append({"source_id": source.get_instance_id(), "role": role, "source_foot": source.global_position, "transform": node.transform, "clear_width": opening, "mesh": mesh})
	var report := {"owned_source_ids": owned, "entries": entries, "root": root}
	root.set_meta("native_scenery_report", report)
	return report

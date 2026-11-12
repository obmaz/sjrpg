class_name WaypointModelBuilder
extends RefCounted
const RADIUS := 1.55
const HEIGHT := 0.10
const CORNER := 1.01
const SHADER := preload("res://assets/models/environment/waypoint/surface.gdshader")


static func create(parent: Node3D, mote_mesh: Mesh, stone: Material) -> Dictionary:
	var root := Node3D.new()
	root.name = "NativeGroundWaypoint"
	parent.add_child(root)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in 64:
		var a := TAU * i / 64.0
		var b := TAU * (i + 1) / 64.0
		for p: Vector3 in [
			Vector3.ZERO, Vector3(cos(a), 0, sin(a)) * RADIUS, Vector3(cos(b), 0, sin(b)) * RADIUS
		]:
			tool.set_normal(Vector3.UP)
			tool.set_uv(Vector2(p.x, p.z) / (RADIUS * 2.0) + Vector2.ONE * 0.5)
			tool.add_vertex(p + Vector3.UP * (HEIGHT + 0.005))
	var fluid := ShaderMaterial.new()
	fluid.shader = SHADER
	fluid.set_shader_parameter(
		"albedo", load("res://assets/models/environment/waypoint/albedo.png")
	)
	var seal := MeshInstance3D.new()
	seal.name = "EngravedGroundSeal"
	seal.mesh = tool.commit()
	seal.material_override = fluid
	seal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	seal.set_meta("exclude_static_batch", true)
	root.add_child(seal)
	var edge := SurfaceTool.new()
	edge.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile := [
		Vector2(RADIUS + 0.10, 0.0), Vector2(RADIUS + 0.10, 0.035), Vector2(RADIUS, HEIGHT)
	]
	for ring: int in 2:
		for i: int in 64:
			var a := TAU * i / 64.0
			var b := TAU * (i + 1) / 64.0
			var lower: Vector2 = profile[ring]
			var upper: Vector2 = profile[ring + 1]
			SceneryRenderer3D._face(
				edge,
				Vector3(cos(a) * lower.x, lower.y, sin(a) * lower.x),
				Vector3(cos(b) * lower.x, lower.y, sin(b) * lower.x),
				Vector3(cos(b) * upper.x, upper.y, sin(b) * upper.x),
				Vector3(cos(a) * upper.x, upper.y, sin(a) * upper.x),
				Vector3.UP * HEIGHT * 0.5
			)
	var plinth := MeshInstance3D.new()
	plinth.name = "BeveledStonePlinth"
	plinth.mesh = edge.commit()
	var stone_ink := stone.duplicate() as StandardMaterial3D
	stone_ink.albedo_color = Color("424440")
	plinth.material_override = stone_ink
	root.add_child(plinth)
	var motes := MultiMeshInstance3D.new()
	motes.name = "WaypointSparks"
	motes.multimesh = MultiMesh.new()
	motes.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	motes.multimesh.use_colors = true
	motes.multimesh.mesh = mote_mesh
	motes.multimesh.instance_count = 4
	var flame := StandardMaterial3D.new()
	flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.albedo_color = Color("dcb36a")
	flame.emission_enabled = true
	flame.emission = Color("c18c47")
	flame.emission_energy_multiplier = 1.2
	motes.material_override = flame
	motes.visible = false
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	motes.set_meta("exclude_static_batch", true)
	root.add_child(motes)
	var lights: Array[OmniLight3D] = []
	for i: int in 4:
		var at := Vector3(
			CORNER * (-1.0 if i % 2 == 0 else 1.0), HEIGHT, CORNER * (-1.0 if i < 2 else 1.0)
		)
		var cup := MeshInstance3D.new()
		cup.name = "CornerSocket%d" % i
		var socket := CylinderMesh.new()
		socket.top_radius = 0.14
		socket.bottom_radius = 0.18
		socket.height = 0.09
		socket.radial_segments = 8
		cup.mesh = socket
		cup.material_override = stone_ink
		cup.position = at + Vector3.UP * 0.045
		root.add_child(cup)
		motes.multimesh.set_instance_transform(
			i, Transform3D(Basis.from_scale(Vector3(4, 7, 4)), at + Vector3.UP * 0.17)
		)
		var light := OmniLight3D.new()
		light.name = "CornerLight%d" % i
		light.position = at + Vector3.UP * 0.27
		light.light_color = Color("cfaa70")
		light.light_energy = 0.22
		light.omni_range = 1.25
		light.shadow_enabled = false
		light.visible = false
		root.add_child(light)
		lights.append(light)
	return {
		"root": root,
		"role": "waypoint",
		"fluid": fluid,
		"stone": stone_ink,
		"motes": motes,
		"lights": lights
	}

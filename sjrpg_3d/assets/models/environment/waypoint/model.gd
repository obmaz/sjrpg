class_name NativeWaypoint3D
extends RefCounted
const RADIUS := 1.55
const HEIGHT := 0.10
const CORNER := 1.01
const SHADER := preload("res://assets/models/environment/waypoint/surface.gdshader")


static func create(parent: Node3D, mote_mesh: Mesh, stone: Material) -> Dictionary:
	var root := NativePropAssets.create("environment/waypoint")
	root.name = "NativeGroundWaypoint"
	parent.add_child(root)
	var fluid := ShaderMaterial.new()
	fluid.shader = SHADER
	fluid.set_shader_parameter("albedo", load("res://assets/models/environment/waypoint/albedo.png"))
	(root.get_node("EngravedGroundSeal") as MeshInstance3D).material_override = fluid
	var stone_ink := stone.duplicate() as StandardMaterial3D
	stone_ink.albedo_color = Color("424440")
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		if node.name != "EngravedGroundSeal":
			(node as MeshInstance3D).material_override = stone_ink
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

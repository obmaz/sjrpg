class_name NativeWaypoint3D
extends RefCounted
const RADIUS := 1.55
const SHADER := preload("res://assets/models/environment/waypoint/surface.gdshader")

static func create(parent: Node3D, mote_mesh: Mesh) -> Dictionary:
	var root := Node3D.new()
	root.name = "NativeGroundWaypoint"
	parent.add_child(root)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in 64:
		var a := TAU*i/64.0
		var b := TAU*(i+1)/64.0
		for p: Vector3 in [Vector3.ZERO,Vector3(cos(a),0,sin(a))*RADIUS,Vector3(cos(b),0,sin(b))*RADIUS]:
			tool.set_normal(Vector3.UP)
			tool.set_uv(Vector2(p.x,p.z)/(RADIUS*2.0)+Vector2.ONE*0.5)
			tool.add_vertex(p+Vector3.UP*0.025)
	var fluid := ShaderMaterial.new()
	fluid.shader = SHADER
	fluid.set_shader_parameter("albedo",load("res://assets/models/environment/waypoint/albedo.png"))
	var seal := MeshInstance3D.new()
	seal.name = "EngravedGroundSeal"
	seal.mesh = tool.commit()
	seal.material_override = fluid
	seal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	seal.set_meta("exclude_static_batch",true)
	root.add_child(seal)
	var motes := MultiMeshInstance3D.new()
	motes.name = "WaypointSparks"
	motes.multimesh = MultiMesh.new()
	motes.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	motes.multimesh.use_colors = true
	motes.multimesh.mesh = mote_mesh
	motes.multimesh.instance_count = NativeTownProps3D.MOTE_COUNT
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	motes.set_meta("exclude_static_batch",true)
	root.add_child(motes)
	var light := OmniLight3D.new()
	light.name = "ActivationLight"
	light.position.y = 0.65
	light.light_color = Color(0.18,0.65,0.88)
	light.light_energy = 0.75
	light.omni_range = 3.1
	light.shadow_enabled = false
	root.add_child(light)
	return {"root":root,"role":"waypoint","fluid":fluid,"motes":motes,"light":light}

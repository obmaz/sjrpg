class_name TreeDamageGeometry3D
extends RefCounted
## 원래 GLB의 피벗·UV·줄기 기하를 공유하고 손상 표면만 다섯 패밀리로 캐시한다.

static var _meshes: Dictionary = {}
static var _inks: Dictionary = {}


static func mesh(variant: int, state: String) -> Mesh:
	var key := "%d:%s" % [variant, state]
	if _meshes.has(key):
		return _meshes[key]
	var source: Mesh = TreeGeometry3D.mesh_library()[variant]["mesh"]
	if state in ["ash", "felled"]:
		var stump := CylinderMesh.new()
		stump.top_radius = 0.16
		stump.bottom_radius = 0.28
		stump.height = 0.24 if state == "felled" else 0.10
		stump.radial_segments = 9
		stump.rings = 1
		stump.material = _ink(TreeGeometry3D._bark_material, state)
		# Geometry is based at zero, never re-fit a remnant to the former crown height.
		var surface := SurfaceTool.new()
		surface.append_from(stump, 0, Transform3D(Basis.IDENTITY, Vector3.UP * stump.height * 0.5))
		var result := surface.commit()
		result.surface_set_material(0, stump.material)
		_meshes[key] = result
		return result
	var result := ArrayMesh.new()
	for index in source.get_surface_count():
		var ink: StandardMaterial3D = source.surface_get_material(index)
		if state == "charred" and ink != TreeGeometry3D._bark_material:
			continue
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source.surface_get_arrays(index))
		result.surface_set_material(result.get_surface_count() - 1, _ink(ink, state))
	_meshes[key] = result
	return result


static func _ink(source: StandardMaterial3D, state: String) -> Material:
	var key := "%d:%s" % [source.get_instance_id(), state]
	if _inks.has(key):
		return _inks[key]
	if state == "frozen":
		var frost := ShaderMaterial.new()
		frost.shader = load("res://assets/materials/vegetation/tree_frost.gdshader")
		frost.set_shader_parameter("albedo_texture", source.albedo_texture)
		frost.set_shader_parameter("cutout", source != TreeGeometry3D._bark_material)
		frost.set_shader_parameter("cutout_threshold", source.alpha_scissor_threshold)
		_inks[key] = frost
		return frost
	var ink := source.duplicate() as StandardMaterial3D
	match state:
		"burning":
			ink.albedo_color = Color(0.55, 0.40, 0.25)
			ink.roughness = 1.0
		"charred", "ash":
			ink.albedo_color = Color(0.19, 0.18, 0.17)
			ink.roughness = 1.0
		_:
			ink.albedo_color = Color(0.75, 0.64, 0.46)
	_inks[key] = ink
	return ink

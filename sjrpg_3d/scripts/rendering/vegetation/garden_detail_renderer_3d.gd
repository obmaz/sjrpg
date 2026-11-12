class_name GardenDetailRenderer3D
extends RefCounted
## 고정된 곡면 잎과 실제 판석. 종류별 공유 메시를 배치해 전체 장면을 구성한다.
const ATLAS := "res://assets/materials/chapel_garden/foliage.png"
static var _leaf_meshes: Array[ArrayMesh] = []
static var _leaf_material: StandardMaterial3D


static func build(
	renderer: Node,
	stones: Array[Dictionary],
	placements: Array[Dictionary],
	root_name: String,
	report_key: String
) -> Dictionary:
	var root := Node3D.new()
	root.name = root_name
	renderer.stage.add_child(root)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles := 0
	for stone: Dictionary in stones:
		var faces := GardenPath3D.floor_faces([stone])
		for i in range(0, faces.size(), 3):
			var normal := (faces[i + 2] - faces[i]).cross(faces[i + 1] - faces[i]).normalized()
			for j in 3:
				var point := faces[i + j]
				tool.set_normal(normal)
				tool.set_color(stone["tint"])
				tool.set_uv(Vector2(point.x, point.z))
				tool.add_vertex(point)
		triangles += faces.size() / 3
	tool.index()
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/materials/chapel_garden/stone.gdshader")
	material.set_shader_parameter("atlas", load(NativeVillageSurfaces.ROOT + "masonry.png"))
	var paving := MeshInstance3D.new()
	paving.name = "IrregularFlagstones"
	paving.mesh = tool.commit()
	paving.material_override = material
	paving.set_meta("exclude_static_batch", true)
	root.add_child(paving)
	var meshes := _leaves()
	var instances := 0
	for kind in 4:
		var selected: Array[Dictionary] = []
		for plant: Dictionary in placements:
			if plant["kind"] == kind:
				selected.append(plant)
		if selected.is_empty():
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = meshes[kind]
		multi.instance_count = selected.size()
		for i in selected.size():
			var item: Dictionary = selected[i]
			multi.set_instance_transform(
				i,
				Transform3D(
					Basis(Vector3.UP, item["yaw"]).scaled(Vector3.ONE * float(item["scale"])),
					item["at"]
				)
			)
			multi.set_instance_color(i, Color(.64, .77, .61))
		var batch := MultiMeshInstance3D.new()
		batch.name = "Groundcover" + str(kind)
		batch.multimesh = multi
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(batch)
		instances += selected.size()
	var report := {
		"root": root,
		"paving": paving,
		"pavers": stones.size(),
		"paver_triangles": triangles,
		"plant_instances": instances,
		"plant_draws": root.get_child_count() - 1,
		"new_lights": 0
	}
	root.set_meta(report_key, report)
	return report


static func _leaves() -> Array[ArrayMesh]:
	if not _leaf_meshes.is_empty():
		return _leaf_meshes
	_leaf_material = StandardMaterial3D.new()
	_leaf_material.albedo_texture = load(ATLAS)
	_leaf_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_leaf_material.alpha_scissor_threshold = .35
	_leaf_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_leaf_material.vertex_color_use_as_albedo = true
	_leaf_material.backlight_enabled = true
	_leaf_material.backlight = Color(.10, .12, .06)
	_leaf_material.roughness = .96
	_leaf_material.metallic_specular = .12
	_leaf_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for kind in 4:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var fronds := 6 if kind < 2 else 3
		for leaf in fronds:
			var basis := Basis(Vector3.UP, TAU * leaf / fronds + kind * .4)
			for segment in 3:
				var a := float(segment) / 3.0
				var b := float(segment + 1) / 3.0
				var points: Array[Vector3] = []
				var coords: Array[Vector2] = []
				for corner: Vector2 in [Vector2(0, a), Vector2(1, a), Vector2(1, b), Vector2(0, b)]:
					var v := corner.y
					points.append(
						(
							basis
							* Vector3(
								(corner.x - .5) * .44,
								v * (.53 if kind < 2 else .48) - sin(v * PI) * .13,
								v * .44
							)
						)
					)
					var uv := Vector2(corner.x, 1.0 - v)
					coords.append((Vector2(kind % 2, kind / 2) + Vector2(.03, .03) + uv * .94) * .5)
				var normal := (points[1] - points[0]).cross(points[3] - points[0]).normalized()
				for i in [0, 2, 1, 0, 3, 2]:
					tool.set_normal(normal)
					tool.set_color(Color.WHITE)
					tool.set_uv(coords[i])
					tool.add_vertex(points[i])
		tool.index()
		var mesh := tool.commit()
		mesh.surface_set_material(0, _leaf_material)
		_leaf_meshes.append(mesh)
	return _leaf_meshes

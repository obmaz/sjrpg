extends Node
## 함정별 GLB를 독립 제작한다. 정적 철물은 합치고 상승 가시는 이름 있는 별도 메시로 둔다.
const ROOT := "res://assets/models/environment/traps/"
var _tools: Dictionary = {}
var _materials: Dictionary = {}


func _ready() -> void:
	var iron := StandardMaterial3D.new()
	iron.resource_name = "TrapIron"
	iron.albedo_color = Color(.17, .19, .19)
	iron.metallic = .65
	iron.roughness = .72
	var steel := StandardMaterial3D.new()
	steel.resource_name = "TrapSteel"
	steel.albedo_color = Color(.57, .60, .61)
	steel.metallic = .82
	steel.roughness = .36
	var stone := StandardMaterial3D.new()
	stone.resource_name = "TrapStone"
	stone.albedo_color = Color(.30, .31, .29)
	stone.roughness = .94
	_materials = {"BaseIron": iron, "Spikes": steel, "BaseStone": stone}
	var shared := NativeCaveSurfaces.material("wall")
	assert(ResourceSaver.save(shared, ROOT + "shared/stone.tres") == OK)
	_spikes()
	_vent()
	get_tree().quit()


func _box(size: Vector3, at: Vector3, role: String) -> void:
	var box := BoxMesh.new()
	box.size = size
	_append(box, Transform3D(Basis.IDENTITY, at), role)


func _append(mesh: Mesh, transform: Transform3D, role: String) -> void:
	if not _tools.has(role):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[role] = tool
	var tool: SurfaceTool = _tools[role]
	var data := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
	var count := indices.size() if not indices.is_empty() else vertices.size()
	for face in range(0, count, 3):
		var corners: Array[int] = []
		for offset in 3:
			corners.append(indices[face + offset] if not indices.is_empty() else face + offset)
		var a := transform * vertices[corners[0]]
		var b := transform * vertices[corners[1]]
		var c := transform * vertices[corners[2]]
		# 원뿔 끝의 반경0 캡은 눈에 보이지 않는 면을 추가하지 않는다.
		if (b - a).cross(c - a).length_squared() < .0000000001:
			continue
		for vertex in corners:
			var point := transform * vertices[vertex]
			var normal := transform.basis * normals[vertex]
			tool.set_normal(normal)
			tool.set_uv(
				(
					Vector2(point.x, point.z) / 2.6
					if absf(normal.y) > .5
					else Vector2(point.x + point.z, point.y) / 2.6
				)
			)
			tool.add_vertex(point)


func _spikes() -> void:
	_tools.clear()
	# 판의 윗면은 바닥에 매입된다. 얇은 돌/금속 홈이 가시의 위치를 계속 알려준다.
	_box(Vector3(1.78, .12, 1.98), Vector3(0, -.064, 0), "BaseStone")
	_box(Vector3(1.62, .008, 1.82), Vector3(0, .006, 0), "BaseIron")
	for x: float in [-.87, .87]:
		_box(Vector3(.08, .07, 1.98), Vector3(x, -.025, 0), "BaseIron")
	for z: float in [-.97, .97]:
		_box(Vector3(1.78, .07, .08), Vector3(0, -.025, z), "BaseIron")
	for index in 5:
		_box(Vector3(.045, .035, 1.72), Vector3(-.72 + index * .36, .002, 0), "BaseIron")
		_box(Vector3(1.46, .035, .045), Vector3(0, .002, -.84 + index * .42), "BaseIron")
	for x in 4:
		for z in 4:
			var spike := CylinderMesh.new()
			spike.bottom_radius = .068
			spike.top_radius = 0
			spike.height = 1.02
			spike.radial_segments = 8
			spike.rings = 1
			_append(
				spike,
				Transform3D(Basis.IDENTITY, Vector3(-.54 + x * .36, .51, -.63 + z * .42)),
				"Spikes"
			)
	for x: float in [-.78, .78]:
		for z: float in [-.88, .88]:
			var bolt := CylinderMesh.new()
			bolt.bottom_radius = .045
			bolt.top_radius = .045
			bolt.height = .018
			bolt.radial_segments = 6
			bolt.rings = 1
			_append(bolt, Transform3D(Basis.IDENTITY, Vector3(x, .022, z)), "BaseIron")
	_export("spikes", "Spikes")


func _vent() -> void:
	_tools.clear()
	for side: float in [-1, 1]:
		_box(Vector3(.23, .9, .30), Vector3(side * .34, .8, -.12), "BaseStone")
		_box(Vector3(.46, .23, .30), Vector3(0, .8 + side * .34, -.12), "BaseStone")
	var nozzle := CylinderMesh.new()
	nozzle.bottom_radius = .24
	nozzle.top_radius = .19
	nozzle.height = .40
	nozzle.radial_segments = 12
	nozzle.rings = 1
	nozzle.cap_top = false
	nozzle.cap_bottom = false
	_append(nozzle, Transform3D(Basis(Vector3.RIGHT, PI * .5), Vector3(0, .8, .02)), "BaseIron")
	var inner := CylinderMesh.new()
	inner.bottom_radius = .205
	inner.top_radius = .155
	inner.height = .40
	inner.radial_segments = 12
	inner.rings = 1
	inner.cap_top = false
	inner.cap_bottom = false
	inner.flip_faces = true
	_append(inner, Transform3D(Basis(Vector3.RIGHT, PI * .5), Vector3(0, .8, .02)), "BaseIron")
	var lip := TorusMesh.new()
	lip.inner_radius = .155
	lip.outer_radius = .19
	lip.rings = 12
	lip.ring_segments = 4
	_append(lip, Transform3D(Basis(Vector3.RIGHT, PI * .5), Vector3(0, .8, .22)), "BaseIron")
	for side: float in [-1, 1]:
		_box(Vector3(.035, .5, .045), Vector3(side * .1, .8, .235), "BaseIron")
	_export("flame_vent", "")


func _export(id: String, animated: String) -> void:
	var root := Node3D.new()
	root.name = "TrapModel"
	add_child(root)
	var triangles := 0
	for role: String in _tools:
		var tool: SurfaceTool = _tools[role]
		var mesh := tool.commit()
		var part := MeshInstance3D.new()
		part.name = role
		part.mesh = mesh
		part.material_override = _materials[role]
		root.add_child(part)
		triangles += mesh.get_faces().size() / 3
	var folder := ROOT + id + "/"
	DirAccess.make_dir_recursive_absolute(folder)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_scene(root, state) == OK)
	assert(document.write_to_filesystem(state, folder + "model.glb") == OK)
	var file := FileAccess.open(folder + "visual.tscn", FileAccess.WRITE)
	(
		file
		. store_string(
			(
				'[gd_scene load_steps=4 format=3]\n[ext_resource type="PackedScene" path="'
				+ folder
				+ 'model.glb" id="model"]\n[ext_resource type="Script" path="'
				+ ROOT
				+ 'shared/visual.gd" id="script"]\n[ext_resource type="Material" path="'
				+ ROOT
				+ 'shared/stone.tres" id="stone"]\n[node name="Trap" type="Node3D"]\nscript=ExtResource("script")\nstone=ExtResource("stone")\n[node name="Geometry" parent="." instance=ExtResource("model")]\n'
			)
		)
	)
	file.close()
	var record: Dictionary = {
		"id": id,
		"model": "model.glb",
		"scene": "visual.tscn",
		"units": "metres; +Y up; +Z firing direction; floor origin Y=0",
		"animated_node": animated,
		"triangles": triangles,
		"source": "tools/assets/dungeon/bake_traps.gd",
		"sourceSha256": FileAccess.get_sha256("res://tools/assets/dungeon/bake_traps.gd"),
		"modelSha256": FileAccess.get_sha256(folder + "model.glb"),
		"collision": "timed damage only; flush floor plate; no movement blocker",
		"material":
		"GLB metal PBR slots; scene binds shared generated cave rock without embedded texture copies"
	}
	file = FileAccess.open(folder + "asset.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "  ") + "\n")
	file.close()
	print("TRAP_MODEL ", id, " triangles=", triangles)
	root.free()

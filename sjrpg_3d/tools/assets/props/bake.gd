extends Node
## 고정 형상 제작 전용. 게임·NPC AI·보상·공격 시계를 시작하지 않는다.
const ROOT := "res://assets/models/"
const VEGETATION := ["dark_fir", "black_pine", "spire_cypress", "juniper", "thorn_bramble"]
var _selected := ""
var _exported := 0


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			_selected = argument.trim_prefix("--only=")
	if _wants("heroes/warrior"):
		_export("heroes/warrior", WarriorModelBuilder.new().build(), true)
	for id: String in ResidentModelBuilder.AUTHORED_IDS:
		if _wants("residents/" + id):
			var root := Node3D.new()
			_part(root, "Body", ResidentModelBuilder.build(id))
			_export("residents/" + id, root, true)
	if _wants("environment/encounter_stone") or _wants("environment/treasure_chest"):
		var models := EncounterModelBuilder.build()
		if _wants("environment/encounter_stone"):
			var root := Node3D.new()
			for key: String in ["stone", "glyph"]:
				_part(root, key, models[key])
			_export("environment/encounter_stone", root)
		if _wants("environment/treasure_chest"):
			var root := Node3D.new()
			for key: String in ["base", "splinters"]:
				_part(root, key, models[key])
			var lid := Node3D.new()
			lid.name = "ObservedConsumedLid"
			lid.position = EncounterModelBuilder.LID_PIVOT
			root.add_child(lid)
			_part(lid, "lid", models["lid"])
			_export("environment/treasure_chest", root)
	if _wants("environment/waypoint"):
		var parent := Node3D.new()
		var entry := WaypointModelBuilder.create(parent, SphereMesh.new(), StandardMaterial3D.new())
		var root: Node3D = entry["root"]
		for node: Node in root.get_children():
			if not node is MeshInstance3D:
				node.free()
		parent.remove_child(root)
		parent.free()
		_export("environment/waypoint", root)
	for index: int in VEGETATION.size():
		var id: String = "vegetation/" + VEGETATION[index]
		if _wants(id):
			var root := Node3D.new()
			_part(root, "Body", WildVegetationBuilder.make_mesh(index))
			_export(id, root)
	if _wants("environment/cave_entrance"):
		var root := Node3D.new()
		_part(
			root,
			"Body",
			NativeCaveSculptor.mesh(
				NativeCavePlan.HILL_HEIGHT,
				SpatialWorld3D.radius_metres(NativeCavePlan.SOURCE_RADIUS)
			)
		)
		_export("environment/cave_entrance", root)
	if _wants("environment/wall_torch"):
		var root := Node3D.new()
		var meshes := TorchModelBuilder.meshes()
		for key: String in meshes:
			_part(root, key, meshes[key])
		_export("environment/wall_torch", root)
	if _wants("environment/trail_sign"):
		var root := Node3D.new()
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: Dictionary in [
			{"at": Vector3(0, .75, 0), "size": Vector3(.16, 1.5, .16)},
			{"at": Vector3(0, 1.32, 0), "size": Vector3(1.6, .40, .14)}
		]:
			var box := BoxMesh.new()
			box.size = part["size"]
			tool.append_from(box, 0, Transform3D(Basis.IDENTITY, part["at"]))
		_part(root, "Board", tool.commit())
		_export("environment/trail_sign", root)
	assert(_exported > 0, "Unknown asset selector: " + _selected)
	print("PROP_BAKE_PASS ", _selected if not _selected.is_empty() else "all")
	get_tree().quit()


func _wants(id: String) -> bool:
	return _selected.is_empty() or _selected == id


func _part(parent: Node3D, id: String, mesh: Mesh) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = id
	part.mesh = mesh
	parent.add_child(part)
	return part


func _export(id: String, root: Node3D, actor := false) -> void:
	var folder := ROOT + id + "/"
	DirAccess.make_dir_recursive_absolute(folder)
	root.name = "Model"
	var roles := {}
	var flags := {}
	var metrics := {}
	var triangle_count := 0
	_exported += 1
	var unnamed := 0
	for node: Node in root.find_children("*", "Node", true, false):
		if str(node.name).begins_with("@"):
			node.name = "Part%03d" % unnamed
			unnamed += 1
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		var path := str(root.get_path_to(part))
		var slots := []
		var baked := ArrayMesh.new()
		for surface: int in part.mesh.get_surface_count():
			baked.add_surface_from_arrays(
				Mesh.PRIMITIVE_TRIANGLES, part.mesh.surface_get_arrays(surface)
			)
			baked.surface_set_material(surface, part.mesh.surface_get_material(surface))
			baked.surface_set_name(
				surface, part.mesh.surface_get_name(surface) if part.mesh is ArrayMesh else ""
			)
		for surface: int in baked.get_surface_count():
			var original := baked.surface_get_material(surface)
			var role: String = (
				original.get_meta("actor_surface_kind", "")
				if actor and original != null
				else baked.surface_get_name(surface)
			)
			if role.is_empty():
				role = (
					original.resource_name
					if original != null and not original.resource_name.is_empty()
					else str(part.name)
				)
			slots.append(role)
			var neutral := StandardMaterial3D.new()
			neutral.resource_name = role
			neutral.vertex_color_use_as_albedo = true
			baked.surface_set_material(surface, neutral)
			var arrays := baked.surface_get_arrays(surface)
			var indices: PackedInt32Array = (
				arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			)
			triangle_count += (
				(indices.size() if not indices.is_empty() else baked.surface_get_array_len(surface))
				/ 3
			)
		roles[path] = slots
		var metadata := {}
		for key: String in ["exclude_static_batch", "occlusion_dynamic"]:
			if part.has_meta(key):
				metadata[key] = part.get_meta(key)
		flags[path] = {"cast_shadow": part.cast_shadow, "metadata": metadata}
		var bounds := baked.get_aabb()
		metrics[path] = {
			"min": [bounds.position.x, bounds.position.y, bounds.position.z],
			"size": [bounds.size.x, bounds.size.y, bounds.size.z],
			"surfaces": slots.size()
		}
		part.mesh = baked
		part.material_override = null
	var layout := Resource.new()
	layout.set_meta("mesh_roles", roles)
	layout.set_meta("node_flags", flags)
	layout.set_meta("actor", actor)
	assert(ResourceSaver.save(layout, folder + "layout.tres") == OK)
	for node: Node in [root] + root.find_children("*", "Node", true, false):
		node.set_script(null)
		for key: StringName in node.get_meta_list():
			node.remove_meta(key)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_scene(root, state) == OK)
	assert(document.write_to_filesystem(state, folder + "model.glb") == OK)
	var importer := ConfigFile.new()
	if importer.load(folder + "model.glb.import") == OK:
		importer.set_value("params", "meshes/generate_lods", false)
		importer.set_value("params", "meshes/force_disable_compression", true)
		assert(importer.save(folder + "model.glb.import") == OK)
	var scene := "[gd_scene load_steps=4 format=3]\n\n"
	scene += '[ext_resource type="PackedScene" path="%smodel.glb" id="model"]\n' % folder
	scene += '[ext_resource type="Script" path="res://assets/models/shared/prop_visual.gd" id="visual"]\n'
	scene += '[ext_resource type="Resource" path="%slayout.tres" id="layout"]\n\n' % folder
	scene += '[node name="Model" instance=ExtResource("model")]\nscript = ExtResource("visual")\nlayout = ExtResource("layout")\n'
	var file := FileAccess.open(folder + "visual.tscn", FileAccess.WRITE)
	file.store_string(scene)
	file.close()
	var inputs := {}
	var sources: Array[String] = ["res://tools/assets/props/bake.gd"]
	if actor:
		sources.append_array(
			[
				"res://tools/assets/props/resident_builder.gd",
				"res://tools/assets/props/actor_shapes.gd",
				"res://scripts/rendering/materials/actor_surface_materials.gd"
			]
		)
		if id == "heroes/warrior":
			sources.append("res://tools/assets/props/warrior_builder.gd")
	elif id in ["environment/treasure_chest", "environment/encounter_stone"]:
		sources.append("res://tools/assets/props/encounter_builder.gd")
	elif id.begins_with("vegetation/"):
		sources.append("res://tools/assets/props/vegetation_builder.gd")
	elif id == "environment/waypoint":
		sources.append_array(
			[
				"res://tools/assets/props/waypoint_builder.gd",
				"res://scripts/rendering/environment/scenery_renderer_3d.gd",
				"res://scripts/rendering/environment/landmark_renderer_3d.gd"
			]
		)
	elif id == "environment/cave_entrance":
		sources.append_array(
			[
				"res://tools/assets/props/cave_builder.gd",
				"res://assets/models/environment/cave_entrance/plan.gd"
			]
		)
	elif id == "environment/wall_torch":
		sources.append_array(
			["res://tools/assets/props/torch_builder.gd", "res://scripts/rendering/environment/cave_lantern_renderer_3d.gd"]
		)
	for path: String in sources:
		inputs[path] = FileAccess.get_sha256(path)
	var proof := {
		"id": id,
		"units": "metres",
		"forward": "+Z",
		"pivot": "wall_mount" if id == "environment/wall_torch" else "ground",
		"inputs": inputs,
		"triangles": triangle_count,
		"meshes": metrics,
		"model_sha256": FileAccess.get_sha256(folder + "model.glb"),
		"scene_sha256": FileAccess.get_sha256(folder + "visual.tscn"),
		"layout_sha256": FileAccess.get_sha256(folder + "layout.tres")
	}
	file = FileAccess.open(folder + "geometry.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(proof, "\t") + "\n")
	file.close()
	root.free()
	print("PROP_ASSET ", id, " triangles=", triangle_count)

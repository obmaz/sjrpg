extends Node
## 현재 제작 기하를 GLB로 굽는다. 런타임은 이 도구나 builder에 의존하지 않는다.
const HouseBuilder := preload("res://tools/assets/architecture/house_builder.gd")
const ChapelBuilder := preload("res://tools/assets/architecture/chapel_builder.gd")
const FortressBuilder := preload("res://tools/assets/architecture/fortress_builder.gd")
const BridgeBuilder := preload("res://tools/assets/architecture/bridge_builder.gd")
const ROOT := "res://assets/models/architecture/"
const IDS := {"nw": "shop", "ne": "smith", "sw": "stable", "se": "home"}


class BakeWorld:
	extends Node2D
	var village: Village


var _materials := {}
var _material_ids := {}
var _mesh_roles := {}
var _node_flags := {}
var _used_names := {}


func _ready() -> void:
	# 운영 Game이나 기존 GLB를 열지 않는다. 모든 자산을 지워도 원본에서 복원할 수 있다.
	GameState.new_game("mage")
	var game := BakeWorld.new()
	game.village = Village.new()
	var ground := Node2D.new()
	var world := Node2D.new()
	game.add_child(ground)
	game.add_child(world)
	game.village.build(ground, world)
	var renderer := WorldRenderer3D.new()
	renderer.game = game
	renderer.stage = Node3D.new()
	add_child(renderer.stage)
	renderer._setup_materials()
	var selected := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			selected = argument.trim_prefix("--only=")
	assert(selected.is_empty() or selected in IDS.values() + ["chapel", "fortress", "bridge"])
	for key: String in IDS.keys() + ["chapel"]:
		var id: String = IDS.get(key, key)
		if not selected.is_empty() and selected != id:
			continue
		var bounds := renderer._building_bounds(key)
		var width := maxf(3.5, bounds.size.x)
		var depth := maxf(3.0, bounds.size.y)
		var root := Node3D.new()
		root.name = "Model"
		renderer.stage.add_child(root)
		var data: Dictionary
		if key == "chapel":
			data = ChapelBuilder.build(
				renderer, root, width, depth, 3.5 * ChapelPlan3D.SIZE_FACTOR
			)
		else:
			data = HouseBuilder.build(renderer, root, key, width, depth, 2.9)
		_export(
			id,
			root,
			data,
			Vector3(width, 3.5 * ChapelPlan3D.SIZE_FACTOR if key == "chapel" else 2.9, depth)
		)
		root.free()
	if selected.is_empty() or selected == "fortress":
		var fortress := FortressBuilder.new()
		fortress.renderer = renderer
		fortress._build()
		_export("fortress", fortress.root, fortress.report, Vector3.ZERO)
		fortress.root.free()
	if selected.is_empty() or selected == "bridge":
		var bridge: Node3D = BridgeBuilder.build(renderer, renderer.stage)
		bridge.transform = Transform3D.IDENTITY
		_export("bridge", bridge, bridge.get_meta("bridge_detail"), Vector3.ZERO)
		bridge.free()
	print("ARCHITECTURE_BAKE_PASS ", selected if not selected.is_empty() else "all")
	renderer.stage.free()
	renderer.free()
	game.free()
	get_tree().quit()


func _safe_names(root: Node) -> void:
	for child in root.get_children():
		child.set_meta("bake_name", str(child.name))
		if str(child.name).begins_with("@"):
			child.name = "Part" + str(child.get_index())
		var base := str(child.name)
		var index := 1
		while _used_names.has(str(child.name)):
			child.name = base + "__" + str(index)
			index += 1
		_used_names[str(child.name)] = true
		_safe_names(child)


func _collect(root: Node3D, node: Node) -> void:
	var path := str(root.get_path_to(node))
	var flags := {}
	for key in ["occlusion_dynamic", "exclude_static_batch"]:
		if node.has_meta(key):
			flags[key] = node.get_meta(key)
	if not flags.is_empty():
		_node_flags[path] = flags
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var role: String = node.get_meta("bake_name", str(node.name))
		for prefix: String in [
			"House_nw_",
			"House_ne_",
			"House_sw_",
			"House_se_",
			"ChapelDetail_",
			"Fortification_",
			"Leaf_"
		]:
			role = role.trim_prefix(prefix)
		var material := mesh.material_override
		assert(material != null)
		if _materials.has(role):
			assert(_materials[role] == material)
		_materials[role] = material
		_material_ids[material.get_instance_id()] = role
		_mesh_roles[path] = role
	for child in node.get_children():
		_collect(root, child)


func _encode(value: Variant, root: Node3D) -> Variant:
	if value is Material:
		assert(_material_ids.has(value.get_instance_id()))
		return {"$material": _material_ids[value.get_instance_id()]}
	if value is Node:
		return {"$node": str(root.get_path_to(value))}
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			result[key] = _encode(value[key], root)
		return result
	if value is Array:
		var result := []
		for item: Variant in value:
			result.append(_encode(item, root))
		return result
	return value


func _export(id: String, root: Node3D, data: Dictionary, dimensions: Vector3) -> void:
	var folder := ROOT + id + "/"
	DirAccess.make_dir_recursive_absolute(folder + "materials")
	_materials.clear()
	_material_ids.clear()
	_mesh_roles.clear()
	_node_flags.clear()
	_used_names.clear()
	_safe_names(root)
	_collect(root, root)
	var layout := Resource.new()
	layout.set_meta("report", _encode(data, root))
	layout.set_meta("mesh_roles", _mesh_roles.duplicate())
	layout.set_meta("node_flags", _node_flags.duplicate(true))
	layout.set_meta("source_dimensions", dimensions)
	assert(ResourceSaver.save(layout, folder + "layout.tres") == OK)
	var copy := root.duplicate() as Node3D
	var placeholders := {}
	for node: Node in [copy] + copy.find_children("*", "Node", true, false):
		for key in node.get_meta_list():
			node.remove_meta(key)
		if node is MeshInstance3D:
			var mesh := node as MeshInstance3D
			var role: String = _mesh_roles[str(copy.get_path_to(node))]
			# GLB는 중립 PBR 슬롯을 제공하고 실제 엔진 셰이더/공유 텍스처는 씬에 연결한다.
			if not placeholders.has(role):
				var placeholder := StandardMaterial3D.new()
				placeholder.resource_name = "Material_" + role
				placeholder.albedo_color = Color(.65, .63, .58)
				placeholder.roughness = .94
				placeholders[role] = placeholder
			mesh.material_override = placeholders[role]
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_scene(copy, state) == OK)
	assert(document.write_to_filesystem(state, folder + "model.glb") == OK)
	copy.free()
	var importer := ConfigFile.new()
	if importer.load(folder + "model.glb.import") == OK:
		# 기와 줄눈의 UV와 얇은 몰딩 법선을 원래 정밀도로 보존한다.
		importer.set_value("params", "meshes/generate_lods", false)
		importer.set_value("params", "meshes/force_disable_compression", true)
		assert(importer.save(folder + "model.glb.import") == OK)
	var scene := "[gd_scene load_steps=%d format=3]\n\n" % (_materials.size() + 4)
	scene += '[ext_resource type="Script" path="res://assets/models/architecture/shared/visual.gd" id="visual"]\n'
	scene += '[ext_resource type="PackedScene" path="%smodel.glb" id="model"]\n' % folder
	scene += '[ext_resource type="Resource" path="%slayout.tres" id="layout"]\n' % folder
	var bindings := []
	for role: String in _materials:
		var path := folder + "materials/" + role + ".tres"
		assert(ResourceSaver.save((_materials[role] as Material).duplicate(), path) == OK)
		scene += '[ext_resource type="Material" path="%s" id="%s"]\n' % [path, role]
		bindings.append('"%s": ExtResource("%s")' % [role, role])
	scene += (
		'\n[node name="%s" type="Node3D"]\nscript = ExtResource("visual")\n' % id.to_pascal_case()
	)
	scene += 'layout = ExtResource("layout")\nmaterials = {%s}\n' % ", ".join(bindings)
	scene += '\n[node name="Geometry" parent="." instance=ExtResource("model")]\n'
	var file := FileAccess.open(folder + "visual.tscn", FileAccess.WRITE)
	file.store_string(scene)
	file.close()
	var spec: Dictionary = (
		JSON.parse_string(FileAccess.get_file_as_string(folder + "asset.json"))
		if FileAccess.file_exists(folder + "asset.json")
		else {"schemaVersion": 1, "id": id, "kind": "model"}
	)
	spec["model"] = "model.glb"
	spec["scene"] = "visual.tscn"
	spec["layout"] = "layout.tres"
	spec["modelSchemaVersion"] = 1
	var manifest := FileAccess.open(folder + "asset.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify(spec, "  ", false) + "\n")
	manifest.close()
	_record(id, folder, data)
	print("ARCHITECTURE_GLB ", id, " meshes=", _mesh_roles.size(), " materials=", _materials.size())


func _record(id: String, folder: String, data: Dictionary) -> void:
	var builder := "house_builder.gd"
	if id in ["chapel", "fortress", "bridge"]:
		builder = id + "_builder.gd"
	var inputs := [
		"tools/assets/architecture/bake.gd",
		"tools/assets/architecture/" + builder,
		"tools/assets/architecture/medieval_details.gd",
		"assets/materials/village_craft/surfaces.gd",
		"scripts/core/iso.gd",
		"scripts/core/world_space_3d.gd",
		"scripts/world/village.gd",
		"scripts/world/geometry/town_plaza_plan_3d.gd",
		"scripts/world/forest_region.gd",
		"assets/data/village.json"
	]
	if id == "chapel":
		inputs.append("scripts/world/geometry/chapel_plan_3d.gd")
	elif id == "fortress":
		inputs.append("scripts/world/geometry/fortress_plan_3d.gd")
	elif id == "bridge":
		inputs.append_array(["scripts/world/geometry/bridge_plan_3d.gd", "scripts/rendering/environment/scenery_renderer_3d.gd"])
	else:
		inputs.append("assets/models/architecture/shared/house_plan.gd")
	var sources := []
	for path: String in inputs:
		sources.append({"path": path, "sha256": FileAccess.get_sha256("res://" + path)})
	var outputs := []
	for name in ["model.glb", "layout.tres", "visual.tscn", "asset.json"]:
		outputs.append({"path": name, "sha256": FileAccess.get_sha256(folder + name)})
	for role: String in _materials:
		var name := "materials/" + role + ".tres"
		outputs.append({"path": name, "sha256": FileAccess.get_sha256(folder + name)})
	var record := {
		"schemaVersion": 1,
		"id": id,
		"sourceType": "offline_native_mesh_bake",
		"inputs": sources,
		"outputs": outputs,
		"triangles": data["triangles"],
		"meshes": _mesh_roles.size(),
		"materialRoles": _materials.keys(),
		"units": "metres; +Y up; existing +Z front and foot datum",
		"materialPolicy":
		"GLB contains neutral PBR slots; visual.tscn binds original Godot shaders and shared textures without image copies.",
		"collisionPolicy":
		"existing Native plans and SpatialWorld3D own collision; visual asset contains no physics bodies"
	}
	var source := "res://assets/source/architecture/" + id + "/"
	DirAccess.make_dir_recursive_absolute(source)
	var file := FileAccess.open(source + "model-provenance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "  ", false) + "\n")

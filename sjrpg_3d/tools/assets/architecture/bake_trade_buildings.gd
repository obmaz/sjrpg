extends "res://tools/assets/architecture/bake.gd"
## 기존 일곱 GLB는 건드리지 않고 승인된 신규 전용 시설 두 채만 굽는다.
const TradeBuilder := preload("res://tools/assets/architecture/trade_building_builder.gd")


func _ready() -> void:
	var renderer := WorldRenderer3D.new()
	renderer._setup_materials()
	for id: String in TownPlazaPlan3D.SERVICES:
		var root := Node3D.new()
		root.name = "Model"
		add_child(root)
		var builder := TradeBuilder.new()
		var report: Dictionary = builder.make(renderer, root, id)
		_export(id, root, report, Vector3(8, 3.7, 8))
		root.free()
	renderer.free()
	print("TRADE_BUILDINGS_BAKE_PASS")
	get_tree().quit()


func _collect(root: Node3D, node: Node) -> void:
	# 노드 이름과 자산 파일 역할을 분리해 materials/stone.tres처럼 저장한다.
	if node is MeshInstance3D:
		var role := str(node.get_meta("bake_name", node.name))
		for id: String in TownPlazaPlan3D.SERVICES:
			role = role.trim_prefix("House_" + id + "_")
		node.set_meta("bake_name", role)
	super._collect(root, node)


func _record(id: String, folder: String, data: Dictionary) -> void:
	var inputs := []
	for path: String in [
		"tools/assets/architecture/bake.gd",
		"tools/assets/architecture/bake_trade_buildings.gd",
		"tools/assets/architecture/trade_building_builder.gd",
		"tools/assets/architecture/house_builder.gd",
		"tools/assets/architecture/medieval_details.gd",
		"scripts/world/geometry/town_plaza_plan_3d.gd",
		"assets/models/architecture/shared/house_plan.gd",
		"assets/materials/village_craft/surfaces.gd",
		"assets/materials/trade_workshops/albedo.png",
		"assets/source/architecture/trade_workshops/concept.png"
	]:
		inputs.append({"path": path, "sha256": FileAccess.get_sha256("res://" + path)})
	var outputs := []
	for name: String in ["model.glb", "layout.tres", "visual.tscn", "asset.json"]:
		outputs.append({"path": name, "sha256": FileAccess.get_sha256(folder + name)})
	for role: String in _materials:
		var name := "materials/" + role + ".tres"
		outputs.append({"path": name, "sha256": FileAccess.get_sha256(folder + name)})
	var record := {
		"schemaVersion": 1,
		"id": id,
		"sourceType": "approved_concept_native_mesh_bake",
		"inputs": inputs,
		"outputs": outputs,
		"triangles": data["triangles"],
		"meshes": _mesh_roles.size(),
		"materialRoles": _materials.keys(),
		"units": "metres; +Y up; +Z front; ground origin",
		"materialPolicy":
		"Shared village textures plus generated 4x4 workshop atlas. GLB neutral slots; Godot scene material bindings.",
		"collisionPolicy":
		"TownPlazaPlan3D blockers/posts shared with model and SpatialWorld3D; open smithy floor traversable"
	}
	var source := "res://assets/source/architecture/" + id + "/"
	DirAccess.make_dir_recursive_absolute(source)
	var file := FileAccess.open(source + "model-provenance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "  ", false) + "\n")

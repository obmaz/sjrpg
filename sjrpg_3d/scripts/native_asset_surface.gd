class_name NativeAssetSurface
extends RefCounted
## 개별 에셋 폴더만 수정해 교체하는 표면 계약. 전역 목록을 유지하지 않는다.
const ROOT := "res://assets/models/architecture/"


static func _spec(id: String) -> Dictionary:
	assert(id.is_valid_identifier(), "Invalid surface asset identifier")
	var spec: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(ROOT + id + "/asset.json")
	)
	assert(int(spec.get("schemaVersion", 0)) == 1 and spec.get("id") == id)
	assert(spec.get("kind") == "surface")
	return spec


static func roof_material(id: String) -> ShaderMaterial:
	var spec := _spec(id)
	var tint: Array = spec.get("roofTint", [1.0, 1.0, 1.0])
	var material := NativeVillageSurfaces.roof(
		int(spec["roofCell"]), Color(float(tint[0]), float(tint[1]), float(tint[2]))
	)
	var albedo: String = spec.get("roofAlbedo", "")
	if not albedo.is_empty():
		assert(not albedo.contains("/") and not albedo.contains(".."))
		material.set_shader_parameter("atlas", load(ROOT + id + "/" + albedo))
	return material


static func material(id: String, bounds: Vector3, cell := -1, gable_rise := 0.0) -> ShaderMaterial:
	var folder := ROOT + id + "/"
	var spec := _spec(id)
	var grid: Array = spec["atlasGrid"]
	assert(grid.size() == 2 and int(grid[0]) == 2 and int(grid[1]) == 2)
	var texture_path: String = spec["albedo"]
	assert(not texture_path.contains("/") and not texture_path.contains(".."))
	var result := ShaderMaterial.new()
	result.shader = preload("res://scripts/native_asset_surface.gdshader")
	result.set_shader_parameter("atlas", load(folder + texture_path))
	result.set_shader_parameter("extent", bounds.max(Vector3.ONE * 0.01))
	result.set_shader_parameter("gable_rise", gable_rise if spec.get("fullFacade", false) else 0.0)
	result.set_shader_parameter("tile", spec["mapping"] == "tile")
	result.set_shader_parameter("tile_metres", float(spec["tileMetres"]))
	result.set_shader_parameter("cell_override", cell)
	result.set_shader_parameter("roughness", float(spec["roughness"]))
	result.set_meta("asset_id", id)
	return result

class_name NativeFountainSurface
extends RefCounted
const ROOT := "res://assets/models/environment/fountain/"


static func material() -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = preload("res://assets/models/environment/fountain/surface.gdshader")
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "asset.json"))
	result.set_shader_parameter("atlas", load(ROOT + str(spec["albedo"])))
	return result


static func bind_water(fluid: ShaderMaterial) -> void:
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "asset.json"))
	var water: Dictionary = spec["legacyWater"]
	var rect: Array = water["regionPixels"]
	var size: Array = water["imagePixels"]
	fluid.set_shader_parameter("legacy_water", load(water["texture"]))
	fluid.set_shader_parameter(
		"water_region",
		Vector4(
			float(rect[0]) / size[0],
			float(rect[1]) / size[1],
			float(rect[2]) / size[0],
			float(rect[3]) / size[1]
		)
	)

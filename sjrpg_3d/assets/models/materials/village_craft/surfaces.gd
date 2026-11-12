class_name NativeVillageSurfaces
extends RefCounted
## 마을의 골조·계단·포장·기와가 공유하는 생성형 재료. 벽 한 면 원화와 분리한다.

const ROOT := "res://assets/models/materials/village_craft/"


static func masonry(cell := -1) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("surface.gdshader")
	material.set_shader_parameter("atlas", load(ROOT + "masonry.png"))
	material.set_shader_parameter("cell_override", cell)
	return material


static func roof(cell: int, tint := Color.WHITE) -> ShaderMaterial:
	assert(cell >= 0 and cell < 4)
	var material := ShaderMaterial.new()
	material.shader = preload("roof.gdshader")
	material.set_shader_parameter("atlas", load(ROOT + "roof.png"))
	material.set_shader_parameter("cell", cell)
	material.set_shader_parameter("tint", tint)
	return material


static func oak(triplanar := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(ROOT + "oak.png")
	# 따뜻함은 남기고 새 주황 목재보다 오래된 참나무 골조로 통일한다.
	material.albedo_color = Color("a79b88")
	material.roughness = 0.94
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_triplanar = triplanar
	material.uv1_scale = Vector3.ONE * (0.65 if triplanar else 1.0)
	return material

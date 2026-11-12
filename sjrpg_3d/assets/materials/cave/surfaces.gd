class_name NativeCaveSurfaces
extends RefCounted
## 바닥과 벽 각각6개의 공유 알베도만 연결한다. 배치·충돌·가림 소유권은 바꾸지 않는다.

const ROOT := "res://assets/materials/cave/"


static func material(kind: String, exposed := false) -> ShaderMaterial:
	assert(kind in ["floor", "wall"])
	var result := ShaderMaterial.new()
	result.resource_name = (
		"CaveWalkableFloor"
		if kind == "floor"
		else ("CaveOuterRock" if exposed else "CaveInnerWall")
	)
	result.shader = (
		load("res://assets/materials/cave/floor.gdshader")
		if kind == "floor"
		else preload("wall.gdshader")
	)
	for index in 6:
		result.set_shader_parameter(
			"surface_%d" % index, load(ROOT + kind + "/" + kind + "-%d.png" % index)
		)
	if kind == "wall":
		result.set_shader_parameter("exposed", exposed)
	return result

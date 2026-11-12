class_name ChapelRenderer3D
extends RefCounted
## 예배당 GLB를 배치한다. 계단/문/실제 FLOOR는 NativeChapelPlan이 소유한다.


static func build(
	_presenter: Node, root: Node3D, width: float, depth: float, height: float
) -> Dictionary:
	var visual := ArchitectureSceneLibrary.create("chapel")
	var dimensions: Vector3 = visual.layout.get_meta("source_dimensions")
	assert(
		dimensions.is_equal_approx(Vector3(width, height, depth)), "예배당 규격 변경 후 GLB를 다시 구워야 합니다."
	)
	root.add_child(visual)
	root.set_meta("chapel_detail", visual.report)
	return visual.report

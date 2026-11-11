extends TestCase


## 실제 타격 위상 전후의 관절 이동과 복귀를 확인한다.
func run() -> void:
	for kind: String in (
		NativeEnemyModels.KINDS.filter(func(k): return not NativeEnemyAssets.uses_asset(k))
		+ [NativeEnemyModels.CRAWLER]
	):
		var model := NativeEnemyModels.build(kind)
		var root: Node3D = model["root"]
		var torso: Node3D = model["torso"]
		NativeEnemyModels.pose(model, 0.7, 0.0, 0.0)
		var rest := torso.transform
		var arms: Array = model["arms"]
		var arm_rest: Transform3D = (
			arms[0].transform if not arms.is_empty() else Transform3D.IDENTITY
		)
		NativeEnemyModels.pose(model, 0.7, 0.0, 0.42)
		var prepared := torso.transform
		var arm_prepared: Transform3D = (
			arms[0].transform if not arms.is_empty() else Transform3D.IDENTITY
		)
		NativeEnemyModels.pose(model, 0.7, 0.0, 0.60)
		check(
			"attack moves the real body or weapon at impact " + kind,
			(
				not torso.transform.is_equal_approx(prepared)
				or (not arms.is_empty() and not arms[0].transform.is_equal_approx(arm_prepared))
			)
		)
		check("attack keeps the physical foot root fixed " + kind, root.position == Vector3.ZERO)
		NativeEnemyModels.pose(model, 0.7, 0.0, 1.0)
		check(
			"recovery returns body and weapon to rest " + kind,
			(
				torso.transform.is_equal_approx(rest)
				and (arms.is_empty() or arms[0].transform.is_equal_approx(arm_rest))
			)
		)
		root.free()

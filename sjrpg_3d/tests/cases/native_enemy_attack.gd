extends TestCase
## 실제 스킨 골격이 준비·타격·복귀를 따르며 피해 시점과 발 루트를 바꾸지 않는다.


func run() -> void:
	for kind: String in NativeEnemyModels.KINDS + [NativeEnemyModels.CRAWLER]:
		var model := NativeEnemyModels.build(kind)
		var visual: NativeEnemyVisual = model["visual"]
		add_child(visual)
		var bone := visual.skeleton.find_bone(visual.manifest["attack_bone"])
		check("authored attack marker exists " + kind, bone >= 0)
		NativeEnemyModels.pose(model, .7, 0, 0)
		visual.skeleton.force_update_all_bone_transforms()
		var rest := visual.skeleton.get_bone_global_pose(bone)
		NativeEnemyModels.pose(model, .7, 0, .42)
		visual.skeleton.force_update_all_bone_transforms()
		var prepared := visual.skeleton.get_bone_global_pose(bone)
		NativeEnemyModels.pose(model, .7, 0, .60)
		visual.skeleton.force_update_all_bone_transforms()
		var contact := visual.skeleton.get_bone_global_pose(bone)
		check(
			"real weapon/head/jaw changes at contact " + kind, not contact.is_equal_approx(prepared)
		)
		check(
			"source damage phase samples the clip contact time " + kind,
			is_equal_approx(
				visual.sample_time, float(visual.manifest["clips"]["attack"]["contact_time"])
			)
		)
		check("attack keeps the physical foot root fixed " + kind, visual.position == Vector3.ZERO)
		NativeEnemyModels.pose(model, .7, 0, 1.0)
		visual.skeleton.force_update_all_bone_transforms()
		check(
			"recovery returns the actual skeleton to idle " + kind,
			visual.skeleton.get_bone_global_pose(bone).is_equal_approx(rest)
		)
		visual.free()

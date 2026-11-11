extends Node
## 최종 GLB의 낮은 발이 뒤로 움직이는 구간에서 클립 한 번의 이동 거리(m)를 측정한다.
## 도구 씬으로 실행한다. -- --write를 붙인 경우에만 각 asset.json을 갱신한다.
const SAMPLE_HZ := 120.0
const CONTACT_HEIGHT_FRACTION := 0.25


func _ready() -> void:
	for kind: String in NativeEnemyModels.KINDS + [NativeEnemyModels.CRAWLER]:
		var model := NativeEnemyModels.build(kind)
		var visual: NativeEnemyVisual = model["visual"]
		add_child(visual)
		var measured := measure(visual)
		print("ENEMY_STRIDE ", kind, " ", JSON.stringify(measured))
		if "--write" in OS.get_cmdline_user_args():
			visual.manifest["locomotion"] = measured
			var file := FileAccess.open(visual.manifest_path, FileAccess.WRITE)
			file.store_string(JSON.stringify(visual.manifest, "  ", false) + "\n")
		visual.free()
	get_tree().quit()


static func measure(visual: NativeEnemyVisual) -> Dictionary:
	visual.prepare()
	var config: Dictionary = visual.manifest["locomotion"]
	var names: Array = config["contact_bones"]
	var duration: float = visual.manifest["clips"]["run"]["length"]
	# JSON 왕복의 미세한 길이 오차로 200프레임이 201로 바뀌지 않게 정수화한다.
	var steps := maxi(1, roundi(duration * SAMPLE_HZ))
	var tracks: Array[PackedVector3Array] = []
	for name: String in names:
		assert(visual.skeleton.find_bone(name) >= 0)
		tracks.append(PackedVector3Array())
	for frame in steps + 1:
		visual.sample("run", duration * frame / steps)
		visual.skeleton.force_update_all_bone_transforms()
		for index in names.size():
			var bone := visual.skeleton.find_bone(names[index])
			tracks[index].append(visual.skeleton.get_bone_global_pose(bone).origin)
	var distances := PackedFloat64Array()
	for track in tracks:
		var low := INF
		var high := -INF
		for point in track:
			low = minf(low, point.y)
			high = maxf(high, point.y)
		var contact := lerpf(low, high, CONTACT_HEIGHT_FRACTION)
		for index in steps:
			var a := track[index]
			var b := track[index + 1]
			# +Z가 전방이다. 도약/발 회수는 빼고, 접지 중 후방 속도의 중앙값을 쓴다.
			var per_clip := (a.z - b.z) * steps
			if (a.y + b.y) * 0.5 <= contact and per_clip > 0.05:
				distances.append(per_clip)
	assert(distances.size() >= 12)
	distances.sort()
	var middle := distances.size() / 2
	var stride := (distances[(distances.size() - 1) / 2] + distances[middle]) * 0.5
	return {
		"distance_per_clip_m": snappedf(stride, 0.0001),
		"contact_bones": names,
		"sample_hz": SAMPLE_HZ,
		"contact_height_fraction": CONTACT_HEIGHT_FRACTION,
		"contact_samples": distances.size(),
		"model_sha256": FileAccess.get_sha256(visual.manifest_path.get_base_dir() + "/model.glb")
	}

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
	# 한 클립의 평균 속도만 맞추면 접지 구간 안에서도 발이 미끄러진다.
	# 각 시점의 가장 낮은 지지발 후방 변위를 적분한 거리→클립 시각 표를 굽는다.
	var lows := PackedFloat64Array()
	var spans := PackedFloat64Array()
	for track in tracks:
		var low := INF
		var high := -INF
		for point in track:
			low = minf(low, point.y)
			high = maxf(high, point.y)
		lows.append(low)
		spans.append(maxf(.05, high - low))
	var speeds := PackedFloat64Array()
	var contacts := PackedFloat64Array()
	for index in steps:
		var lowest := INF
		var speed := NAN
		for foot in tracks.size():
			var a := tracks[foot][index]
			var b := tracks[foot][index + 1]
			var height := ((a.y + b.y) * .5 - lows[foot]) / spans[foot]
			var backward := (a.z - b.z) * steps
			if height < CONTACT_HEIGHT_FRACTION and backward > .05 and height < lowest:
				lowest = height
				speed = backward
		speeds.append(speed)
		if is_finite(speed):
			contacts.append(speed)
	assert(contacts.size() >= 12)
	contacts.sort()
	var median := contacts[contacts.size() / 2]
	# 도약 중에는 양쪽 접지 속도를 원형으로 보간한다. 접지 전환만 한 표본씩 부드럽게 한다.
	var filled := speeds.duplicate()
	for index in steps:
		if is_finite(speeds[index]):
			continue
		var previous := 1
		var next := 1
		while not is_finite(speeds[posmod(index - previous, steps)]):
			previous += 1
		while not is_finite(speeds[(index + next) % steps]):
			next += 1
		filled[index] = lerpf(
			speeds[posmod(index - previous, steps)],
			speeds[(index + next) % steps],
			float(previous) / (previous + next)
		)
	var cumulative := PackedFloat64Array([0.0])
	for index in steps:
		var speed := (
			(filled[posmod(index - 1, steps)] + 2 * filled[index] + filled[(index + 1) % steps])
			* .25
		)
		cumulative.append(cumulative[-1] + clampf(speed, median * .15, median * 4) / steps)
	var stride := cumulative[-1]
	var curve := []
	for distance in cumulative:
		curve.append(snappedf(distance / stride, .000001))
	return {
		"distance_per_clip_m": snappedf(stride, 0.0001),
		"distance_curve": curve,
		"method": "support_distance_v1",
		"contact_bones": names,
		"sample_hz": SAMPLE_HZ,
		"contact_height_fraction": CONTACT_HEIGHT_FRACTION,
		"contact_samples": contacts.size(),
		"model_sha256": FileAccess.get_sha256(visual.manifest_path.get_base_dir() + "/model.glb")
	}

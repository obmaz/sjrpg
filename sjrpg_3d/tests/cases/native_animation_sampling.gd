extends TestCase
## Compare real GLB bones and actual key evaluations against the previous double sample.

const CountedPlayer := preload("res://tests/fixtures/counted_animation_player.gd")


func _instrument(player: AnimationPlayer) -> void:
	player.set_script(CountedPlayer)
	player.clear_caches()
	player.set("processed_keys", 0)


func _legacy_sample(player: AnimationPlayer, clip: String, sample: float) -> void:
	if player.current_animation != clip:
		player.play(clip, 0.0)
	player.seek(sample, true)
	player.advance(0.0)


func _compare(label: String, actual: Node3D, reference: Node3D) -> void:
	var actual_bones: Skeleton3D = NativeResidents3D._find_skeleton(actual)
	var reference_bones: Skeleton3D = NativeResidents3D._find_skeleton(reference)
	if not check(label + " retains both complete imported skeletons", actual_bones != null and reference_bones != null):
		return
	check(label + " preserves all 65 bone poses", actual_bones.get_bone_count() == 65 and reference_bones.get_bone_count() == 65)
	var same := true
	for index in actual_bones.get_bone_count():
		same = same and actual_bones.get_bone_name(index) == reference_bones.get_bone_name(index)
		same = same and actual_bones.get_bone_pose(index).is_equal_approx(reference_bones.get_bone_pose(index))
	check(label + " matches the previous displayed pose on every bone", same)


func _check_work(label: String, actual: AnimationPlayer, reference: AnimationPlayer, stable: bool) -> void:
	var current: int = actual.get("processed_keys")
	var legacy: int = reference.get("processed_keys")
	check(label + " evaluates fewer real animation keys", current > 0 and legacy > current)
	if stable:
		check(label + " evaluates the same keys once instead of twice", legacy == current * 2)
	print("ANIMATION_SAMPLE_WORK " + JSON.stringify({"label": label, "single_keys": current, "legacy_keys": legacy}))


func run() -> void:
	var game := await make_game("mage")
	var preview: Ortho3DPreview = game.ortho_preview
	var motion: Ortho3DHeroMotion = preview._hero_motion
	game.process_mode = Node.PROCESS_MODE_DISABLED
	preview.set_process(false)
	var reference := (load(Ortho3DPreview.MAGE_PATH) as PackedScene).instantiate() as Node3D
	add_child(reference)
	var reference_player: AnimationPlayer = NativeResidents3D._find_animation(reference)
	Ortho3DHeroMotion.new().setup(reference_player, reference)
	_instrument(preview.animation)
	_instrument(reference_player)
	var player: Player = game.player
	player.sprite.clear_contact_hold()
	player._hitstop.clear()
	var origin := player.position
	var steps: Array[Vector4] = [
		Vector4(0.0, 0.0, 0.0, 0.0), Vector4(0.13, 0.0, 0.0, 0.0),
		Vector4(3.2, 0.0, 0.0, 0.0), Vector4(0.1, 32.0, 1.0, 0.0),
		Vector4(0.1, 64.0, 2.0, 0.0), Vector4(0.1, 127.9, 3.0, 0.0),
		Vector4(0.1, 128.1, 4.0, 0.0), Vector4(0.1, 128.1, 4.0, 0.9),
		Vector4(0.1, 128.1, 4.0, 0.5), Vector4(0.1, 128.1, 4.0, 0.1),
		Vector4(0.2, 128.1, 4.0, 0.0)]
	for index in steps.size():
		var step: Vector4 = steps[index]
		var old_clip := str(reference_player.current_animation)
		player.position = origin + Vector2(step.z, 0)
		player._run_distance = step.y
		player._attack_time = player._attack_duration * step.w
		preview.animation.set("processed_keys", 0)
		reference_player.set("processed_keys", 0)
		motion.sync(player, step.x)
		_legacy_sample(reference_player, motion.active_clip, motion.sample_time)
		_compare("mage step " + str(index), preview.actor, reference)
		_check_work("mage step " + str(index), preview.animation, reference_player, old_clip == motion.active_clip)
	reference.free()
	game.queue_free()
	await _frames(2)
	for identity: String in ["merchant", "mira"]:
		var actual: Node3D = NativeResidents3D.create(identity)
		var baseline: Node3D = NativeResidents3D.create(identity)
		add_child(actual)
		add_child(baseline)
		var actual_player: AnimationPlayer = NativeResidents3D.idle_player(actual)
		var baseline_player: AnimationPlayer = NativeResidents3D.idle_player(baseline)
		_instrument(actual_player)
		_instrument(baseline_player)
		var selected: String = str(actual.get_meta("resident_idle_clip"))
		var clip: Animation = actual_player.get_animation(selected)
		for source_time: float in [0.0, 0.11, 0.64, clip.length + 0.17]:
			var stable := baseline_player.current_animation == selected
			actual_player.set("processed_keys", 0)
			baseline_player.set("processed_keys", 0)
			var sample: Dictionary = NativeResidents3D.sample_idle(actual, source_time)
			_legacy_sample(baseline_player, selected, float(sample["sample_time"]))
			_compare(identity + " at " + str(source_time), actual, baseline)
			_check_work(identity + " at " + str(source_time), actual_player, baseline_player, stable)
		var before := int(actual_player.get("processed_keys"))
		NativeResidents3D.sample_idle(actual, clip.length + 0.17)
		check(identity + " still skips unchanged source-clock samples", int(actual_player.get("processed_keys")) == before)
		actual.free()
		baseline.free()

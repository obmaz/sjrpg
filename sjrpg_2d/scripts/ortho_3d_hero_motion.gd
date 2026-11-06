class_name Ortho3DHeroMotion
extends RefCounted
## Sample the native hero from simulation clocks. Manual seeks must never leave
## a crossfade waiting for advance(delta), or the previous pose stays fully mixed.

var active_clip := ""
var sample_time := 0.0
var pose_updates := 0
var run_distance := 0.0
var moving := false
var held := false
var _animation: AnimationPlayer
var _skeleton: Skeleton3D
var _clips := {}
var _bone_indices := {}
var _idle_clock := 0.0
var _last_position := Vector2.ZERO
var _last_run_distance := 0.0
var _has_source := false


func setup(animator: AnimationPlayer, model: Node = null) -> Ortho3DHeroMotion:
	_animation = animator
	if animator == null:
		return self
	_animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_animation.playback_default_blend_time = 0.0
	for key: String in ["idle", "run", "cast"]:
		for clip: StringName in _animation.get_animation_list():
			if str(clip).to_lower().contains(key):
				_clips[key] = str(clip)
				break
	var root: Node = model if model != null else animator.get_parent()
	_skeleton = _find_skeleton(root)
	if _skeleton != null:
		for bone_name: String in ["thigh_l", "calf_r", "Head"]:
			var index := _skeleton.find_bone(bone_name)
			if index >= 0:
				_bone_indices[bone_name] = index
	return self


func sync(player: Player, delta: float, paused := false) -> void:
	if not is_instance_valid(_animation) or not is_instance_valid(player):
		return
	run_distance = player._run_distance
	moving = _has_source and (player.position.distance_squared_to(_last_position) > 0.01 or absf(run_distance - _last_run_distance) > 0.001)
	held = paused or (player.is_inside_tree() and player.get_tree().paused) or player.sprite.contact_hold > 0.0 or player._hitstop.remaining > 0.0
	_remember(player)
	if held and pose_updates > 0:
		return
	var desired := "cast" if player._attack_time > 0.0 else ("run" if moving else "idle")
	var selected: String = str(_clips.get(desired, ""))
	if selected.is_empty():
		return
	var clip: Animation = _animation.get_animation(selected)
	if clip == null or clip.length <= 0.0:
		return
	if selected != active_clip:
		# A nonzero blend never finishes if every update only seeks. Explicitly
		# disable it instead of advancing a second, independent playback clock.
		_animation.play(selected, 0.0)
		active_clip = selected
	if desired == "cast":
		var progress := 1.0 - player._attack_time / maxf(player._attack_duration, 0.0001)
		sample_time = clampf(progress, 0.0, 1.0) * clip.length
	elif desired == "run":
		# Same eight-step128-world-unit stride as the authoritative sprite.
		sample_time = fposmod(run_distance / 128.0, 1.0) * clip.length
	else:
		# Imported idle is not necessarily looped. Keep breathing after its first
		# clip duration without resetting on standing turns or modifying the asset.
		_idle_clock = fposmod(_idle_clock + (0.0 if held else maxf(delta, 0.0)), clip.length)
		sample_time = _idle_clock
	_animation.seek(sample_time, true)
	_animation.advance(0.0)
	pose_updates += 1


func snapshot() -> Dictionary:
	return {"active_clip": active_clip, "sample_time": sample_time,
		"pose_updates": pose_updates, "run_distance": run_distance,
		"moving": moving, "held": held, "bones": bone_pose_sample()}


func bone_pose_sample() -> Dictionary:
	var sample := {}
	if not is_instance_valid(_skeleton):
		return sample
	for bone_name: String in _bone_indices:
		var rotation := _skeleton.get_bone_pose_rotation(int(_bone_indices[bone_name]))
		sample[bone_name] = [rotation.x, rotation.y, rotation.z, rotation.w]
	return sample


func _remember(player: Player) -> void:
	_last_position = player.position
	_last_run_distance = player._run_distance
	_has_source = true


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	if node != null:
		for child in node.get_children():
			var found := _find_skeleton(child)
			if found != null:
				return found
	return null

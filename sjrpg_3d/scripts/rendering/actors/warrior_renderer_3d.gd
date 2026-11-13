class_name WarriorRenderer3D
extends Node3D
## 성인 골격 GLB의 자세를 Player의 실제 이동·명중 시계로 샘플링한다.
var torso: Node3D
var skeleton: Skeleton3D
var meshes: Array[MeshInstance3D] = []
var weapon: Node3D
var last_pose: Dictionary = {}
var _motion: HeroAnimation3D
var _animator: AnimationPlayer
var _flash: ShaderMaterial
var _death_clip := ""
var _death_clock := 0.0
var _was_dead := false


func build() -> WarriorRenderer3D:
	name = "NativeWarrior"
	torso = ModelSceneLibrary.create("heroes/warrior")
	add_child(torso)
	skeleton = ModelTree3D.first_skeleton(torso)
	_animator = ModelTree3D.first_animation_player(torso)
	_motion = HeroAnimation3D.new().setup(_animator, torso)
	weapon = torso.find_child("Sword", true, false) as Node3D
	meshes = ModelTree3D.meshes_including_root(torso)
	for clip: StringName in _animator.get_animation_list():
		if str(clip).to_lower().contains("death"):
			_death_clip = str(clip)
	var shader := Shader.new()
	shader.code = WorldRenderer3D.ACTOR_FLASH_SHADER_SOURCE
	_flash = ShaderMaterial.new()
	_flash.shader = shader
	return self


func sync(player: Player, delta := 0.0) -> void:
	var overlay: Material = _flash if player.sprite.flash > 0.0 else null
	if overlay != null:
		_flash.set_shader_parameter("flash_color", player.sprite.flash_tint.lerp(Color.WHITE, 0.35))
		_flash.set_shader_parameter("flash_strength", player.sprite.flash * 0.65)
	for mesh: MeshInstance3D in meshes:
		if mesh.material_overlay != overlay:
			mesh.material_overlay = overlay
	if is_inside_tree() and get_tree().paused:
		return
	if player.dead:
		_was_dead = true
		torso.rotation = Vector3.ZERO
		# 전투 상태는 Player가 확정한다. 사망 이후의 표시 시간만 여기서 진행한다.
		_death_clock += maxf(delta, 0.0)
		if not _death_clip.is_empty():
			if _animator.current_animation != _death_clip:
				_animator.play(_death_clip, 0.0)
			var clip: Animation = _animator.get_animation(_death_clip)
			# 끝 이벤트가 자세를 해제하지 않도록 마지막 표시 샘플을 유지한다.
			_animator.seek(minf(_death_clock, maxf(0.0, clip.length - 0.001)), true)
	else:
		if _was_dead:
			# death를 직접 재생했으므로 부활 때 이전 idle/run 클립 캐시도 새로 맞춘다.
			_motion = HeroAnimation3D.new().setup(_animator, torso)
			_was_dead = false
		_death_clock = 0.0
		_motion.sync(player, delta)
		if not _motion.held:
			torso.rotation.x = -0.75 if player._roll_time > 0.0 else 0.0
	weapon.visible = not player.dead
	var progress := 0.0
	if not player.dead and player._attack_time > 0.0 and _motion.active_clip.to_lower().contains("cast"):
		var clip: Animation = _animator.get_animation(_motion.active_clip)
		progress = _motion.sample_time / clip.length
	var animation_state := _motion.snapshot()
	if player.dead:
		animation_state["active_clip"] = _death_clip
		animation_state["sample_time"] = _animator.current_animation_position
	last_pose = {
		"walk_distance": player._run_distance,
		"attack_progress": progress,
		"dead": player.dead,
		"parts": meshes.size(),
		"animation": animation_state,
		"death_time": _death_clock
	}


func joint_rotation(bone_name: String) -> Quaternion:
	var index := skeleton.find_bone(bone_name)
	return skeleton.get_bone_pose_rotation(index) if index >= 0 else Quaternion.IDENTITY


func review_snapshot() -> Dictionary:
	var snapshot := last_pose.duplicate(true)
	var animation_state: Dictionary = snapshot.get("animation", _motion.snapshot())
	# 마법사와 같은 최상위 애니메이션 진단 계약을 제공하며 전사 전용 값도 보존한다.
	snapshot.merge(animation_state, true)
	snapshot["bone_count"] = skeleton.get_bone_count()
	return snapshot

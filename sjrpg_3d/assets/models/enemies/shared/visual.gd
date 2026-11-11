class_name NativeEnemyVisual
extends Node3D
## GLB의 클립을 게임이 소유한 이동/공격 시각으로 샘플링한다. 물리나 피해는 만들지 않는다.
@export_file("*.json") var manifest_path: String
var manifest: Dictionary
var animator: AnimationPlayer
var skeleton: Skeleton3D
var meshes: Array[MeshInstance3D] = []
var materials: Array[StandardMaterial3D] = []
var colors: Array[Color] = []
var idle_clock := 0.0
var active_clip := ""
var sample_time := 0.0
var pose_updates := 0
var moving := false
var _prepared := false
@onready var hit_pivot: Node3D = $HitPivot


func _ready() -> void:
	prepare()
	sample("idle", 0.0)


func _collect(node: Node) -> void:
	if node is AnimationPlayer:
		animator = node
	elif node is Skeleton3D:
		skeleton = node
	elif node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		_collect(child)


func prepare() -> void:
	if _prepared:
		return
	manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	hit_pivot = get_node("HitPivot")
	_collect(hit_pivot)
	assert(animator != null and skeleton != null)
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animator.playback_default_blend_time = 0.0
	animator.autoplay = ""
	var cloned := {}
	for mesh in meshes:
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface) as StandardMaterial3D
			assert(source != null)
			var id := source.get_instance_id()
			if not cloned.has(id):
				var ink := source.duplicate() as StandardMaterial3D
				ink.roughness = .94
				cloned[id] = ink
				materials.append(ink)
				colors.append(ink.albedo_color)
			mesh.set_surface_override_material(surface, cloned[id])
	_prepared = true


func advance_idle(delta: float, held: bool) -> void:
	if not held:
		idle_clock += maxf(delta, 0.0)


func sample(clip: String, time: float) -> void:
	prepare()
	var name: String = manifest["clips"][clip]["name"]
	var next_time := clampf(time, 0.0, animator.get_animation(name).length)
	if active_clip == name and is_equal_approx(sample_time, next_time):
		return
	if active_clip != name:
		animator.play(name, 0.0)
		active_clip = name
	sample_time = next_time
	animator.seek(sample_time, true)
	pose_updates += 1


func pose(facing: float, cycle: float, attack: float, dead: bool) -> void:
	prepare()
	var direction := Iso.unproject(Vector2.from_angle(facing)).normalized()
	rotation = Vector3(0, atan2(direction.x, direction.y), 0)
	hit_pivot.transform = Transform3D.IDENTITY
	if dead:
		sample("death", float(manifest["clips"]["death"]["length"]))
		hit_pivot.position.y = -float(manifest["death_floor_m"])
	elif attack > 0.0001 and attack < 1.0:
		var clip: Dictionary = manifest["clips"]["attack"]
		var contact: float = clip["contact_time"]
		# 현재 실제 피해 판정은 준비가 끝나는 진행도 .60이다. 클립의 타격 순간을 여기에 맞춘다.
		var time := (
			attack / .60 * contact
			if attack <= .60
			else lerpf(contact, float(clip["length"]), (attack - .60) / .40)
		)
		sample("attack", time)
	elif moving or not is_zero_approx(cycle):
		sample("run", fposmod(cycle, 1.0) * float(manifest["clips"]["run"]["length"]))
	else:
		sample("idle", fposmod(idle_clock, float(manifest["clips"]["idle"]["length"])))


## 바인드 자세 AABB와 구별되는 실제 스킨 정점. 검수/죽은 자세 측정에서만 사용한다.
func posed_vertices() -> PackedVector3Array:
	prepare()
	skeleton.force_update_all_bone_transforms()
	var points := PackedVector3Array()
	for mesh in meshes:
		var skin := mesh.skin
		var skeleton_to_root := global_transform.affine_inverse() * skeleton.global_transform
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var influences: int = bones.size() / vertices.size()
			for index in vertices.size():
				var point := Vector3.ZERO
				for slot in influences:
					var offset := index * influences + slot
					var weight := weights[offset]
					if weight <= 0.0:
						continue
					var bind := bones[offset]
					var bone := skin.get_bind_bone(bind)
					if bone < 0:
						bone = skeleton.find_bone(skin.get_bind_name(bind))
					point += (
						(
							skeleton.get_bone_global_pose(bone)
							* skin.get_bind_pose(bind)
							* vertices[index]
						)
						* weight
					)
				points.append(skeleton_to_root * point)
	return points

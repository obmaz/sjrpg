class_name WarriorRenderer3D
extends Node3D
## Adult anatomical lofts and forged plate profiles, sharing the resident face
## family and painted atlas. Joint poses still observe the original Player clocks.
var torso: Node3D
var legs: Array[Node3D] = []
var arms: Array[Node3D] = []
var meshes: Array[MeshInstance3D] = []
var last_pose: Dictionary = {}
var weapon: Node3D
var _last_distance: float = -1.0
var _flash: ShaderMaterial
var _contact_serial := 0


func build() -> WarriorRenderer3D:
	name = "NativeWarrior"
	var model := ModelSceneLibrary.create("heroes/warrior")
	add_child(model)
	torso = model.get_node("Torso")
	for index: int in 2:
		legs.append(torso.get_node("Leg%d" % index))
		arms.append(torso.get_node("Arm%d" % index))
	weapon = arms[1].get_node("Sword")
	meshes = ResidentRenderer3D.descendant_meshes(model)
	var shader := Shader.new()
	shader.code = WorldRenderer3D.ACTOR_FLASH_CODE
	_flash = ShaderMaterial.new()
	_flash.shader = shader
	return self


func sync(player: Player) -> void:
	var overlay: Material = _flash if player.sprite.flash > 0.0 else null
	if overlay != null:
		_flash.set_shader_parameter("flash_color", player.sprite.flash_tint.lerp(Color.WHITE, 0.35))
		_flash.set_shader_parameter("flash_strength", player.sprite.flash * 0.65)
	for mesh: MeshInstance3D in meshes:
		if mesh.material_overlay != overlay:
			mesh.material_overlay = overlay
	if is_inside_tree() and get_tree().paused:
		return
	var contact := (
		player.contact_serial != _contact_serial
		and player.contact_action_serial == player._action_serial
		and player._attack_time > 0.0
	)
	_contact_serial = player.contact_serial
	if not contact and (player._hitstop.remaining > 0.0 or player.sprite.contact_hold > 0.0):
		return
	var moving: bool = player._run_distance != _last_distance
	_last_distance = player._run_distance
	var phase: float = player._run_distance / 23.0
	var swing: float = sin(phase) * 0.55 if moving else 0.0
	if Prefs.reduce_motion:
		swing *= 0.45
	for index: int in 2:
		legs[index].rotation.x = swing * (-1.0 if index == 0 else 1.0)
		arms[index].rotation.x = (
			swing * (0.6 if index == 0 else -0.6) + (0.45 if index == 1 else 0.0)
		)
		arms[index].rotation.z = -0.06 if index == 0 else 0.06
		arms[index].rotation.y = 0.0
	torso.rotation = Vector3.ZERO
	var progress: float = 0.0
	if player._attack_time > 0.0:
		progress = clampf(1.0 - player._attack_time / player._attack_duration, 0, 1)
		if contact:
			progress = Player.CONTACT_PROGRESS
		var prepare := smoothstep(0.0, 0.27, progress)
		var strike := smoothstep(0.28, Player.CONTACT_PROGRESS, progress)
		var recover := smoothstep(0.60, 1.0, progress)
		arms[1].rotation.x = lerpf(-1.55 * prepare, 0.90, strike) * (1.0 - recover)
		arms[1].rotation.y = lerpf(-0.85 * prepare, 0.95, strike) * (1.0 - recover)
		arms[1].rotation.z = -0.18 * sin(progress * PI)
		arms[0].rotation.x = -0.55 * sin(progress * PI)
		torso.rotation.y = lerpf(-0.28 * prepare, 0.30, strike) * (1.0 - recover)
		torso.rotation.x = 0.10 * strike * (1.0 - recover)
	if player._roll_time > 0.0:
		torso.rotation.x = -0.75
	if player.dead:
		torso.rotation.x = PI * 0.5
		torso.position.y = 0.25
	else:
		torso.position.y = 0.0
	weapon.visible = not player.dead
	last_pose = {
		"walk_distance": player._run_distance,
		"attack_progress": progress,
		"dead": player.dead,
		"parts": meshes.size()
	}


func review_snapshot() -> Dictionary:
	return last_pose.duplicate()

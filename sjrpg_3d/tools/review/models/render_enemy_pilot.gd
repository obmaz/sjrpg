extends Node3D
## 같은 카메라·광원에서 현재 몬스터 씬 또는 GLB 후보의 네 방향/동작을 검수한다.
var camera: Camera3D


func find_animator(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := find_animator(child)
		if found != null:
			return found
	return null


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("17231d")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(.57, .68, .77)
	env.environment.ambient_light_energy = .43
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1, .94, .82)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	add_child(sun)
	sun.rotation_degrees = Vector3(-47, -35, 0)
	var floor := MeshInstance3D.new()
	floor.mesh = PlaneMesh.new()
	(floor.mesh as PlaneMesh).size = Vector2.ONE * 12
	var ink := StandardMaterial3D.new()
	ink.albedo_color = Color("616450")
	ink.roughness = .95
	floor.material_override = ink
	add_child(floor)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.2
	camera.position = Vector3(6, 6.85, 6)
	add_child(camera)
	camera.look_at(Vector3(0, .85, 0))
	var output := ProjectSettings.globalize_path("res://../build/review/enemy-glb-pilot")
	DirAccess.make_dir_recursive_absolute(output)
	var kinds: Array = EnemyRenderer3D.KINDS + [EnemyRenderer3D.CRAWLER]
	var label := "after"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kinds="):
			kinds = Array(arg.trim_prefix("--kinds=").split(","))
		elif arg.begins_with("--label="):
			label = arg.trim_prefix("--label=")
	for kind: String in kinds:
		var height: float = Enemy.NATIVE_HEIGHT_METRES.get(
			kind, Enemy.NATIVE_HEIGHT_METRES["goblin"]
		)
		camera.size = height * 2.6
		camera.position = Vector3(8, 8 + height * .5, 8)
		camera.look_at(Vector3(0, height * .5, 0))
		for edition in (
			["candidate"] if "--candidate-only" in OS.get_cmdline_user_args() else [label]
		):
			var root: Node3D
			var model := {}
			var animator: AnimationPlayer
			if edition != "candidate":
				model = EnemyRenderer3D.build(kind)
				root = model["root"]
				root.scale = (Vector3.ONE * height / float(model["base_height"]))
			else:
				root = (
					(load("res://assets/models/enemies/%s/model.glb" % kind) as PackedScene)
					. instantiate()
				)
				animator = find_animator(root)
				animator.callback_mode_process = (
					AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				)
			add_child(root)
			for phase in ["idle", "run", "attack", "death"]:
				if edition != "candidate":
					EnemyRenderer3D.pose(
						model,
						0,
						.24 if phase == "run" else 0,
						.6 if phase == "attack" else 0,
						phase == "death"
					)
				else:
					animator.play(phase, 0)
					var time: float = .24 * animator.get_animation(phase).length
					if phase == "attack":
						time = float(
							(
								JSON
								. parse_string(
									FileAccess.get_file_as_string(
										"res://assets/models/enemies/%s/asset.json" % kind
									)
								)["clips"]["attack"]["contact_time"]
							)
						)
					if phase == "death":
						time = animator.get_animation(phase).length
					animator.seek(time, true)
				for yaw in [0, 90, 180, 270]:
					root.rotation_degrees = Vector3(0, yaw, 0)
					for frame in 3:
						await get_tree().process_frame
					await RenderingServer.frame_post_draw
					var file := "%s/%s-%s-%s-%d.png" % [output, kind, edition, phase, yaw]
					assert(get_viewport().get_texture().get_image().save_png(file) == OK)
			root.free()
	print("ENEMY_PILOT_RENDER_PASS views=", kinds.size() * 16)
	get_tree().quit()

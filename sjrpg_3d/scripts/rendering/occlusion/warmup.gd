class_name NativeOcclusionWarmup
extends RefCounted


## Compatibility는 투명 변형을 실제로 그려야 컴파일한다. 작은 별도 월드라 화면에 노출되지 않는다.
static func draw(renderer: WorldRenderer3D, samples: Array) -> int:
	var view := SubViewport.new()
	view.size = Vector2i(64, 64)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	renderer.add_child(view)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.0
	camera.position.z = 10.0
	view.add_child(camera)
	var sun := DirectionalLight3D.new()
	view.add_child(sun)
	var glow := OmniLight3D.new()
	glow.position.z = 3.0
	glow.omni_range = 15.0
	view.add_child(glow)
	for first in range(0, samples.size(), 16):
		var batch := Node3D.new()
		view.add_child(batch)
		for index in range(first, mini(first + 16, samples.size())):
			var sample: Dictionary = samples[index]
			var mesh := MeshInstance3D.new()
			mesh.mesh = sample["mesh"]
			mesh.material_override = sample["ink"]
			var box := mesh.mesh.get_aabb()
			var scale := 1.4 / maxf(0.01, maxf(box.size.x, maxf(box.size.y, box.size.z)))
			mesh.scale = Vector3.ONE * scale
			mesh.position = (
				Vector3((index % 4) * 2.0 - 3.0, 3.0 - floorf((index - first) / 4.0) * 2.0, 0.0)
				- box.get_center() * scale
			)
			batch.add_child(mesh)
		# 작은 뷰포트에서 각 투명 변형을 최소 한 프레임 실제로 그린다.
		await RenderingServer.frame_post_draw
		if not is_instance_valid(renderer) or renderer.is_queued_for_deletion():
			return 0
		batch.queue_free()
	view.queue_free()
	return samples.size()

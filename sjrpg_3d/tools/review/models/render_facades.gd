extends Node
## 실제 건물의 비교 렌더와 생성 입력용 정면 배치도를 만든다. 게임 진입점에는 연결하지 않는다.

const ASSETS := {"nw": "shop", "ne": "smith", "sw": "stable", "se": "home", "chapel": "chapel"}
var _review_root := ProjectSettings.globalize_path("res://").path_join("../build/review/facades/")
var _renderer: WorldRenderer3D
var _view: SubViewport
var _camera: Camera3D


func _ready() -> void:
	GameState.save_path = "user://tests/facade-review.json"
	GameState.new_game("mage")
	var game: Node = load("res://scripts/gameplay/game.gd").new()
	add_child(game)
	while not game.native_ready:
		await get_tree().process_frame
	_renderer = game.world_renderer
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_renderer.set_process(false)
	_renderer.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_view = SubViewport.new()
	_view.size = Vector2i(640, 640)
	_view.world_3d = World3D.new()
	_view.world_3d.environment = _renderer.stage.get_world_3d().environment
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_view.msaa_3d = Viewport.MSAA_2X
	add_child(_view)
	for light in _renderer.stage.get_children():
		if light is DirectionalLight3D:
			_view.add_child(light.duplicate())
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = 0.05
	_camera.far = 100.0
	_view.add_child(_camera)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	ground.position.y = -0.01
	ground.material_override = GroundRenderer3D.grass_material()
	_view.add_child(ground)
	var after := "--after" in OS.get_cmdline_user_args()
	var baseline := "--baseline" in OS.get_cmdline_user_args()
	var layouts_enabled := not after and "--no-layouts" not in OS.get_cmdline_user_args()
	var folder := _review_root + ("after/" if after else "before/")
	DirAccess.make_dir_recursive_absolute(folder)
	DirAccess.make_dir_recursive_absolute(_review_root + "layouts/")
	var layouts := {}
	for key: String in ASSETS:
		var id: String = ASSETS[key]
		var bounds := _renderer._building_bounds(key)
		var width := maxf(3.5, bounds.size.x)
		var depth := maxf(3.0, bounds.size.y)
		var root := Node3D.new()
		_view.add_child(root)
		var report: Dictionary
		var body_width := width - 0.40
		var body_depth := depth - 0.40
		var top: float
		var rise: float
		if key == "chapel":
			report = ChapelRenderer3D.build(
				_renderer, root, width, depth, 3.5 * ChapelPlan3D.SIZE_FACTOR
			)
			body_width = width
			body_depth = depth
			top = 3.5 * ChapelPlan3D.SIZE_FACTOR + 0.28
			rise = 2.4
		else:
			report = HouseRenderer3D.build(_renderer, root, key, width, depth, 2.9)
			top = report["eaves_height"]
			rise = report["roof_rise"]
		if baseline:
			var previous: Texture2D = load("res://build/facade-baseline/" + id + ".ctex")
			assert(previous != null, "Extract the prior PCK wall texture before comparing")
			for mesh: MeshInstance3D in report["meshes"]:
				var material := mesh.material_override as ShaderMaterial
				if material != null and material.get_meta("asset_id", "") == id:
					material.set_shader_parameter("atlas", previous)
					material.set_shader_parameter("gable_rise", 0.0)
		var box: AABB = report["bounds"]
		var target := box.get_center()
		_camera.position = target + Vector3.ONE * 30.0
		_camera.look_at(target, Vector3.UP)
		_camera.size = (
			maxf(
				(box.size.x + box.size.z) / sqrt(2.0),
				box.size.y * sqrt(2.0 / 3.0) + (box.size.x + box.size.z) / sqrt(6.0)
			)
			* 1.12
		)
		for yaw in [0, 90, 180, 270]:
			root.rotation.y = deg_to_rad(float(yaw))
			await _draw()
			_save(folder + id + "-" + str(yaw) + ".png")
		if layouts_enabled:
			ground.hide()
			root.rotation = Vector3.ZERO
			layouts[id] = {
				"width_m": body_width,
				"depth_m": body_depth,
				"eaves_m": top,
				"gable_rise_m": rise,
				"cell_order": ["front+Z", "right+X", "back-Z", "left-X"],
				"inset": 0.018
			}
			await _layout(root, id, body_width, body_depth, top, rise)
			ground.show()
		root.queue_free()
		await get_tree().process_frame
	if layouts_enabled:
		var file := FileAccess.open(_review_root + "layouts/layouts.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(layouts, "\t"))
	print("FACADE_REVIEW_PASS ", "after" if after else "before", " assets=5 views=20")
	get_tree().quit()


func _draw() -> void:
	for frame in 3:
		await RenderingServer.frame_post_draw


func _save(path: String) -> void:
	assert(_view.get_texture().get_image().save_png(path) == OK)


func _layout(root: Node3D, id: String, width: float, depth: float, top: float, rise: float) -> void:
	var state: Array[Dictionary] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		state.append({"node": mesh, "visible": mesh.visible, "material": mesh.material_override})
		var mesh_name := str(mesh.name)
		if mesh_name.ends_with("_slate"):
			mesh.hide()
		elif mesh_name.ends_with("_wall"):
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("c9c4b7")
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mesh.material_override = material
	var atlas := SubViewport.new()
	atlas.size = Vector2i(1280, 1280)
	atlas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(atlas)
	var background := ColorRect.new()
	background.color = Color("c9c4b7")
	background.size = Vector2(1280, 1280)
	atlas.add_child(background)
	for face in 4:
		var height := top + rise if face % 2 == 0 else top
		root.scale = Vector3(1.0 / width, 1.0 / height, 1.0 / depth)
		var direction: Vector3 = [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT][face]
		_camera.position = Vector3(0, 0.5, 0) + direction * 5.0
		_camera.look_at(Vector3(0, 0.5, 0), Vector3.UP)
		_camera.size = 1.0 / 0.964
		await _draw()
		var image := _view.get_texture().get_image()
		var tile := TextureRect.new()
		tile.texture = ImageTexture.create_from_image(image)
		tile.position = Vector2(face % 2, face / 2) * 640.0
		tile.size = Vector2(640, 640)
		atlas.add_child(tile)
	await _draw()
	assert(atlas.get_texture().get_image().save_png(_review_root + "layouts/" + id + ".png") == OK)
	atlas.queue_free()
	root.scale = Vector3.ONE
	for item in state:
		var node: MeshInstance3D = item["node"]
		node.visible = item["visible"]
		node.material_override = item["material"]

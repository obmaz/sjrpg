extends TestCase
## Native geometry/light proof and exact projection parity; this is not a migrated3D simulation test.


func _projection_error(game: Node, preview: Ortho3DPreview) -> float:
	var maximum := 0.0
	for offset in [Vector2.ZERO, Vector2(120, 0), Vector2(-70, 95)]:
		var point: Vector2 = game.player.position + offset
		var actual := preview.camera.unproject_position(Ortho3DPreview.ground_position(point))
		var expected: Vector2 = game.camera.get_canvas_transform() * point
		maximum = maxf(maximum, actual.distance_to(expected))
	return maximum


func run() -> void:
	var old_quality := Prefs.low_resolution
	var old_zoom := Prefs.world_zoom
	Prefs.set_low_resolution(false)
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	add_child(view)
	GameState.new_game("mage")
	var game := preload("res://scripts/game.gd").new()
	view.add_child(game)
	await _frames(3)
	game.set_process(false)
	game.encounters.set_process(false)
	check("native comparison has its verified skeletal actor asset", ResourceLoader.exists(Ortho3DPreview.MAGE_PATH))
	if not ResourceLoader.exists(Ortho3DPreview.MAGE_PATH):
		view.queue_free()
		await _frames(2)
		Prefs.set_low_resolution(old_quality)
		return
	var preview := Ortho3DPreview.new().setup(game)
	game.add_child(preview)
	await _frames(4)
	check("comparison hides only the field while keeping original HUD input", not game.field_root.visible and game.hud.visible and preview.display.mouse_filter == Control.MOUSE_FILTER_IGNORE and game.player.get_parent() == game.world)
	check("native mage has a real skeletal animation player", preview.actor != null and preview.animation != null and preview.animation.get_animation_list().size() >= 3)
	check("comparison uses native orthographic camera and real sun shadows", preview.camera.projection == Camera3D.PROJECTION_ORTHOGONAL and preview.sunlight.shadow_enabled and preview.sunlight.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL)
	var focus := Ortho3DPreview.ground_position(game.camera.get_screen_center_position())
	var focus_depth := preview.camera.global_position.distance_to(focus)
	check("orthographic shadow camera fits local ground and tall architecture", preview.camera.near < focus_depth - 20.0 and preview.camera.far > focus_depth and preview.camera.far - preview.camera.near < 100.0)
	var eye := preview.camera.global_transform.basis.z.normalized()
	check("camera is mathematically45azimuth and35.264elevation", absf(rad_to_deg(atan2(eye.x, eye.z)) - 45.0) < 0.001 and absf(rad_to_deg(asin(eye.y)) - 35.264389682754654) < 0.001)
	var ray := -preview.sunlight.global_transform.basis.z
	var projected_ray := Iso.project(Vector2(ray.x, ray.z)).normalized()
	check("native shadow direction matches the existing canopy sun", projected_ray.dot(Vector2(0.72, 0.48).normalized()) > 0.99999)
	var meshes := preview.stage.find_children("*", "MeshInstance3D", true, false)
	var native_geometry: int = preview._static_batch["boxes"]
	var installed := DisplayServer.get_name() != "headless"
	var batch_error := Ortho3DStaticBatch.corner_error(preview._static_batch, installed)
	check("static batching preserves all eight corners (CPU plan in Dummy, installed transforms with GPU)", batch_error < 0.0001 and int(preview._static_batch["groups"]) < native_geometry)
	for instance: MeshInstance3D in meshes:
		if instance.mesh is BoxMesh or instance.mesh is CylinderMesh or instance.mesh is PrismMesh:
			native_geometry += 1
	check("building and wall geometry is volumetric rather than facade cards", native_geometry > 40)
	for low in [false, true]:
		Prefs.set_low_resolution(low)
		await _frames(4)
		preview._sync_camera()
		check("native view remains above the old economy canvas and below HUD", preview._layer.layer > 0 and preview._layer.layer < game.hud.layer and preview.display.visible)
		check("native projection matches the actual2D viewport at both qualities", _projection_error(game, preview) < 1.0)
		check("economy mode removes native multisampling", preview.viewport.msaa_3d == (Viewport.MSAA_DISABLED if low else Viewport.MSAA_2X))
	get_tree().paused = true
	Prefs.set_world_zoom(1.5)
	await _frames(3)
	check("paused settings immediately update native zoom projection", _projection_error(game, preview) < 1.0)
	view.size = Vector2i(1280, 720)
	await _frames(3)
	check("paused device rotation preserves projection and display bounds", _projection_error(game, preview) < 1.0 and preview.display.size.is_equal_approx(Vector2(view.size)))
	Prefs.set_low_resolution(false)
	await _frames(3)
	check("paused quality switch preserves native projection", _projection_error(game, preview) < 1.0)
	get_tree().paused = false
	var old_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var enemy := Enemy.new()
	enemy.setup(game, "goblin", 1)
	enemy.position = game.player.position + Vector2(70, 0)
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	enemy.set_process(false)
	enemy.take_damage(2.0, game.player)
	# The real presenter synchronizes the hit camera before copying visual cards.
	preview._sync_camera()
	preview._sync_cards()
	var card: MeshInstance3D = preview._cards[enemy.get_instance_id()]["node"]
	var ink := card.material_override as ShaderMaterial
	var frame: Rect2 = enemy.sprite.atlas.regions[enemy.sprite.frame]
	var factor := enemy.sprite.body_height / enemy.sprite.atlas.ref_height
	var rect := Rect2(-enemy.sprite.atlas.anchors[enemy.sprite.frame] * factor, frame.size * factor)
	var center := preview.camera.unproject_position(card.position)
	var expected_center: Vector2 = game.camera.get_canvas_transform() * (enemy.position + enemy.sprite.position + rect.get_center())
	check("real hit preserves body flash and visual recoil", float(ink.get_shader_parameter("flash_strength")) > 0.0 and enemy.sprite.position.length() > 0.0 and center.distance_to(expected_center) < 1.0)
	enemy.take_damage(enemy.max_hp * 2.0, game.player)
	await get_tree().create_timer(0.09).timeout
	preview._sync_cards()
	var tint: Color = ink.get_shader_parameter("tint")
	check("dead enemy keeps its actual fade after leaving the live array", enemy.dead and not game.enemies.has(enemy) and tint.a > 0.0 and tint.a < 0.95 and is_equal_approx(tint.a, enemy.sprite.modulate.a))
	Prefs.reduce_motion = old_reduce
	var at: Vector2 = game.player.position + Vector2(24, -60)
	var visible := preview.camera.unproject_position(Ortho3DPreview.spatial_position(at, 0.9))
	var projected := preview.camera.unproject_position(Ortho3DPreview.ground_position(at))
	check("chest-height light does not double-apply its projected height", visible.distance_to(projected) < 0.01)
	var impact := Effect.spawn_impact(game, at, game.player)
	impact.set_process(false)
	preview._process(0.5)
	check("slow first update still presents the real confirmed impact light", preview.contact_light.visible and preview.contact_light.light_energy > 0.0 and preview.contact_light.position.y > 0.0 and not preview.contact_light.shadow_enabled)
	var light_energy := preview.contact_light.light_energy
	get_tree().paused = true
	await _frames(2)
	check("pause preserves native contact light and pose", preview.contact_light.light_energy == light_energy)
	get_tree().paused = false
	preview._process(1.0)
	check("native contact light expires even without another rendering frame", not preview.contact_light.visible)
	check("native preview preserves live town portals chests and resident headers", preview._affordances._art.size() >= game.village.portal_sprites.size() + game.chests.size() and preview._affordances._headers.size() == game.village.npc_nodes.size())
	var town_residents := ["상인", "대장장이", "탈것 상인", "촌장", "보급원 미라"]
	for label: String in town_residents:
		check("town resident has both original source and native body/header: " + label, game.village.npc_nodes.has(label))
		if game.village.npc_nodes.has(label):
			var resident: Villager = game.village.npc_nodes[label]
			check("town body and header are registered: " + label, preview._cards.has(resident.get_instance_id()) and preview._affordances._headers.has(resident.get_instance_id()))
	var town_position: Vector2 = game.player.position
	game.player.position = game.village.safe_zone[0] + Vector2(-10000, 0)
	preview._process(0.016)
	check("leaving the comparison restores authoritative2D obstacles", not preview.display.visible and game.field_root.visible and preview.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	game.player.position = town_position
	preview._process(0.016)
	check("returning to town restores the native view", preview.display.visible and not game.field_root.visible)
	game.player.position = game.dungeon.entry_point()
	check("comparison can enter the existing cave normally", game.dungeon.enter())
	preview._process(0.016)
	check("cave keeps its actual2D walls while native town is suspended", not preview.display.visible and not game.field_root.visible and game.dungeon._root.visible)
	game.dungeon.leave("")
	preview.queue_free()
	await _frames(2)
	check("removing the opt-in presenter restores the original field", game.field_root.visible)
	view.queue_free()
	await _frames(2)
	Prefs.set_low_resolution(old_quality)
	Prefs.set_world_zoom(old_zoom)

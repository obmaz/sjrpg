extends TestCase
## Native edition geometry/light proof, input projection and realm lifetime.


func _projection_error(game: Node, preview: Ortho3DPreview) -> float:
	var maximum := 0.0
	var focus_height: float = preview.surface_height(game.player.position)
	var screen_scale: Vector2 = game.get_viewport_rect().size / Vector2(preview.viewport.size)
	for offset in [Vector2.ZERO, Vector2(120, 0), Vector2(-70, 95)]:
		var point: Vector2 = game.player.position + offset
		var height: float = preview.surface_height(point)
		var actual := preview.camera.unproject_position(Ortho3DPreview.ground_position(point, height)) * screen_scale
		var expected: Vector2 = game.camera.get_canvas_transform() * point
		# The adapter stays full resolution. Native pixels are scaled for display,
		# and the real floor can differ from the elevated camera-focus plane.
		expected.y += (focus_height - height) * Ortho3DPreview.GROUND_PER_METER * Iso.S * game.camera.zoom.y
		maximum = maxf(maximum, actual.distance_to(expected))
	return maximum


func _town_affordances_hidden(game: Node, preview: Ortho3DPreview) -> bool:
	for entry: Dictionary in preview._affordances._headers.values():
		if (entry["root"] as Node3D).is_visible_in_tree():
			return false
	for portal: IsoSprite in game.village.portal_sprites.values():
		if preview._town_props.owns(portal):
			return false
		var entry: Dictionary = preview._affordances._art.get(portal.get_instance_id(), {})
		if not entry.is_empty() and (entry["node"] as MeshInstance3D).is_visible_in_tree():
			return false
	return true


func run() -> void:
	check("native edition saves are separate from the2D project", bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)) and str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")) == "sjrpg_3d")
	var old_quality := Prefs.low_resolution
	var old_zoom := Prefs.world_zoom
	Prefs.set_low_resolution(false)
	var view := SubViewport.new()
	view.size = Vector2i(720, 1280)
	add_child(view)
	GameState.delete_save()
	GameState.new_game("mage")
	var game := preload("res://scripts/game.gd").new()
	view.add_child(game)
	await _frames(3)
	game.set_process(false)
	game.encounters.set_process(false)
	check("native edition has its verified skeletal actor asset", ResourceLoader.exists(Ortho3DPreview.MAGE_PATH))
	if not ResourceLoader.exists(Ortho3DPreview.MAGE_PATH):
		view.queue_free()
		await _frames(2)
		Prefs.set_low_resolution(old_quality)
		return
	var preview: Ortho3DPreview = game.ortho_preview
	check("native presenter is created by the ordinary adventure lifecycle", preview != null)
	if preview == null:
		view.queue_free()
		await _frames(2)
		Prefs.set_low_resolution(old_quality)
		Prefs.set_world_zoom(old_zoom)
		return
	await _frames(4)
	check("native rendering culls original field drawing while keeping HUD input", game.field_root.visibility_layer == 0 and game.hud.visible and preview.display.mouse_filter == Control.MOUSE_FILTER_IGNORE and game.player.get_parent() == game.world)
	check("native simulation owns a persistent character body for the hero", is_instance_valid(game.spatial_world) and game.spatial_world.actor_bodies.get(game.player.get_instance_id()) is CharacterBody3D)
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
	var native_geometry: int = preview._static_batch["boxes"]
	var installed := DisplayServer.get_name() != "headless"
	var batch_error := Ortho3DStaticBatch.corner_error(preview._static_batch, installed)
	check("eligible static box batching preserves all eight corners (houses already merge their surfaces)", batch_error < 0.0001 and (native_geometry == 0 or int(preview._static_batch["groups"]) < native_geometry))
	var house_triangles := 0
	var houses_have_volume := preview._houses.size() == 4
	for house: Dictionary in preview._houses.values():
		var bounds: AABB = house["bounds"]
		house_triangles += int(house["triangles"])
		houses_have_volume = houses_have_volume and bounds.size.x > 3.0 and bounds.size.z > 2.5 and bounds.size.y > 4.0
	check("all four major houses use volumetric meshes rather than facade cards", houses_have_volume and house_triangles >= 24000 and preview._fortification.report["triangles"] > 1000)
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
	get_tree().paused = false
	await _frames(2)
	get_tree().paused = true
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
	check("dead enemy stays visible during its actual fade after leaving the live array", enemy.dead and not game.enemies.has(enemy) and card.visible and tint.a > 0.0 and tint.a < 0.95 and is_equal_approx(tint.a, enemy.sprite.modulate.a))
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
	var live_portals := true
	for source in game.village.portal_sprites.values():
		live_portals = live_portals and preview._town_props.owns(source) and not preview._affordances._art.has(source.get_instance_id())
	var live_chests := true
	for chest: Chest in game.chests:
		var fallback: Dictionary = preview._affordances._art.get(chest.body_sprite.get_instance_id(), {})
		var native: Dictionary = preview._encounter_props._entries.get(chest.get_instance_id(), {})
		if preview._encounter_props.owns(chest.body_sprite):
			live_chests = live_chests and fallback.is_empty() and not native.is_empty() and (native["root"] as Node3D).is_visible_in_tree() and (native["owner"] as WeakRef).get_ref() == chest
		else:
			live_chests = live_chests and native.is_empty() and not fallback.is_empty() and (fallback["node"] as MeshInstance3D).is_visible_in_tree()
	check("native preview preserves every live chest exactly once with portals and resident headers", live_portals and live_chests and preview._affordances._headers.size() == game.village.npc_nodes.size())
	var town_residents := ["상인", "대장장이", "탈것 상인", "촌장", "보급원 미라"]
	for label: String in town_residents:
		check("town resident has both original source and native body/header: " + label, game.village.npc_nodes.has(label))
		if game.village.npc_nodes.has(label):
			var resident: Villager = game.village.npc_nodes[label]
			check("town body and header are registered: " + label, preview._cards.has(resident.get_instance_id()) and preview._affordances._headers.has(resident.get_instance_id()))
	var town_position: Vector2 = game.player.position
	game.player.position = game.village.gate_points[0] + (game.village.gate_points[0] - game.village.spawn_point).normalized() * 450.0
	preview._process(0.016)
	check("leaving town keeps native rendering and the source field culled", preview.display.visible and preview._native_visible and game.field_root.visibility_layer == 0 and preview.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
	check("native forest remains visible in its own realm", preview._world_environment.forest.visible and preview._world_environment.report["scope"] == "forest")
	game.player.position = town_position
	preview._process(0.016)
	check("returning to town reuses the native world", game.ortho_preview == preview and preview.display.visible and game.field_root.visibility_layer == 0)
	game.player.position = game.dungeon.entry_point()
	check("native adventure can enter the existing cave encounter", game.dungeon.enter())
	await get_tree().physics_frame
	await get_tree().physics_frame
	preview._process(0.016)
	check("cave keeps native walls visible while the forest remains culled", preview.display.visible and preview._native_visible and game.field_root.visibility_layer == 0 and preview._world_environment.cave.visible and not preview._world_environment.forest.visible)
	check("town portals names and quest markers do not leak into the cave", _town_affordances_hidden(game, preview))
	game.dungeon.leave("")
	await get_tree().physics_frame
	await get_tree().physics_frame
	preview._process(0.016)
	check("cave return restores the native forest without replacing the presenter", game.ortho_preview == preview and preview._world_environment.forest.visible and not preview._world_environment.cave.visible and game.field_root.visibility_layer == 0)
	var native_stage: Node3D = preview.stage
	var spatial_world: Node = game.spatial_world
	var player_body: CharacterBody3D = game.spatial_world.actor_bodies[game.player.get_instance_id()]
	view.queue_free()
	await _frames(2)
	check("closing the native adventure frees its presenter physics world and hero body", not is_instance_valid(preview) and not is_instance_valid(native_stage) and not is_instance_valid(spatial_world) and not is_instance_valid(player_body))
	Prefs.set_low_resolution(old_quality)
	Prefs.set_world_zoom(old_zoom)

extends TestCase
## Native edition geometry/light proof, input projection and realm lifetime.


func _projection_error(game: Node, renderer: WorldRenderer3D) -> float:
	var maximum := 0.0
	var focus_height: float = renderer.surface_height(game.player.position)
	var screen_scale: Vector2 = game.get_viewport_rect().size / Vector2(renderer.viewport.size)
	for offset in [Vector2.ZERO, Vector2(120, 0), Vector2(-70, 95)]:
		var point: Vector2 = game.player.position + offset
		var height: float = renderer.surface_height(point)
		var actual := renderer.camera.unproject_position(WorldRenderer3D.ground_position(point, height)) * screen_scale
		var expected: Vector2 = game.camera.get_canvas_transform() * point
		# The adapter stays full resolution. Native pixels are scaled for display,
		# and the real floor can differ from the elevated camera-focus plane.
		expected.y += (focus_height - height) * WorldRenderer3D.GROUND_PER_METER * Iso.S * game.camera.zoom.y
		maximum = maxf(maximum, actual.distance_to(expected))
	return maximum


func _town_affordances_hidden(game: Node, renderer: WorldRenderer3D) -> bool:
	for entry: Dictionary in renderer._affordances._headers.values():
		if (entry["root"] as Node3D).is_visible_in_tree():
			return false
	for portal: IsoSprite in game.village.portal_sprites.values():
		if renderer._town_props.owns(portal):
			return false
		var entry: Dictionary = renderer._affordances._art.get(portal.get_instance_id(), {})
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
	var game := preload("res://scripts/gameplay/game.gd").new()
	view.add_child(game)
	await _frames(3)
	game.set_process(false)
	game.encounters.set_process(false)
	check("native edition has its verified skeletal actor asset", ResourceLoader.exists(WorldRenderer3D.MAGE_SCENE_PATH))
	if not ResourceLoader.exists(WorldRenderer3D.MAGE_SCENE_PATH):
		view.queue_free()
		await _frames(2)
		Prefs.set_low_resolution(old_quality)
		return
	var renderer: WorldRenderer3D = game.world_renderer
	check("native presenter is created by the ordinary adventure lifecycle", renderer != null)
	if renderer == null:
		view.queue_free()
		await _frames(2)
		Prefs.set_low_resolution(old_quality)
		Prefs.set_world_zoom(old_zoom)
		return
	await _frames(4)
	check("native rendering culls original field drawing while keeping HUD input", game.field_root.visibility_layer == 0 and game.hud.visible and renderer.display.mouse_filter == Control.MOUSE_FILTER_IGNORE and game.player.get_parent() == game.world)
	check("native simulation owns a persistent character body for the hero", is_instance_valid(game.spatial_world) and game.spatial_world.actor_bodies.get(game.player.get_instance_id()) is CharacterBody3D)
	check("native mage has a real skeletal animation player", renderer.actor != null and renderer.animation != null and renderer.animation.get_animation_list().size() >= 3)
	check("comparison uses native orthographic camera and real sun shadows", renderer.camera.projection == Camera3D.PROJECTION_ORTHOGONAL and renderer.sunlight.shadow_enabled and renderer.sunlight.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL)
	var focus := WorldRenderer3D.ground_position(game.camera.get_screen_center_position())
	var focus_depth := renderer.camera.global_position.distance_to(focus)
	check("orthographic shadow camera fits local ground and tall architecture", renderer.camera.near < focus_depth - 20.0 and renderer.camera.far > focus_depth and renderer.camera.far - renderer.camera.near < 100.0)
	var eye := renderer.camera.global_transform.basis.z.normalized()
	check("camera is mathematically45azimuth and35.264elevation", absf(rad_to_deg(atan2(eye.x, eye.z)) - 45.0) < 0.001 and absf(rad_to_deg(asin(eye.y)) - 35.264389682754654) < 0.001)
	var ray := -renderer.sunlight.global_transform.basis.z
	var projected_ray := Iso.project(Vector2(ray.x, ray.z)).normalized()
	check("native shadow direction matches the existing canopy sun", projected_ray.dot(Vector2(0.72, 0.48).normalized()) > 0.99999)
	var native_geometry: int = renderer._static_batch["boxes"]
	var installed := DisplayServer.get_name() != "headless"
	var batch_error := StaticMeshBatch3D.corner_error(renderer._static_batch, installed)
	check("eligible static box batching preserves all eight corners (houses already merge their surfaces)", batch_error < 0.0001 and (native_geometry == 0 or int(renderer._static_batch["groups"]) < native_geometry))
	var house_triangles := 0
	var houses_have_volume := renderer._houses.size() == 4
	for house: Dictionary in renderer._houses.values():
		var bounds: AABB = house["bounds"]
		house_triangles += int(house["triangles"])
		houses_have_volume = houses_have_volume and bounds.size.x > 3.0 and bounds.size.z > 2.5 and bounds.size.y > 4.0
	check("all four major houses use volumetric meshes rather than facade cards", houses_have_volume and house_triangles >= 24000 and renderer._fortification.report["triangles"] > 1000)
	for low in [false, true]:
		Prefs.set_low_resolution(low)
		await _frames(4)
		renderer._sync_camera()
		check("native view remains above the old economy canvas and below HUD", renderer._layer.layer > 0 and renderer._layer.layer < game.hud.layer and renderer.display.visible)
		check("native projection matches the actual2D viewport at both qualities", _projection_error(game, renderer) < 1.0)
		check("economy mode removes native multisampling", renderer.viewport.msaa_3d == (Viewport.MSAA_DISABLED if low else Viewport.MSAA_2X))
	get_tree().paused = true
	Prefs.set_world_zoom(1.5)
	await _frames(3)
	check("paused settings immediately update native zoom projection", _projection_error(game, renderer) < 1.0)
	view.size = Vector2i(1280, 720)
	await _frames(3)
	check("paused device rotation preserves projection and display bounds", _projection_error(game, renderer) < 1.0 and renderer.display.size.is_equal_approx(Vector2(view.size)))
	get_tree().paused = false
	await _frames(2)
	get_tree().paused = true
	Prefs.set_low_resolution(false)
	await _frames(3)
	check("paused quality switch preserves native projection", _projection_error(game, renderer) < 1.0)
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
	# The real presenter synchronizes the hit camera before observing native bodies.
	renderer._sync_camera()
	renderer._enemy_models.sync()
	var native_model: Dictionary = renderer._enemy_models.entries[enemy.get_instance_id()]
	var body: Node3D = native_model["root"]
	var ink := native_model["materials"][0] as StandardMaterial3D
	check("real native hit preserves body flash and visual recoil", enemy.sprite.flash > 0.0 and ink.albedo_color != native_model["colors"][0] and enemy.sprite.position.length() > 0.0 and body.position.is_equal_approx(renderer.actor_foot(enemy) + WorldRenderer3D.ground_position(enemy.sprite.position)))
	check("native enemy never retains duplicate fallback artwork", not renderer._cards.has(enemy.get_instance_id()))
	enemy.take_damage(enemy.max_hp * 2.0, game.player)
	await get_tree().create_timer(0.09).timeout
	renderer._enemy_models.sync()
	check("dead native body stays visible during actual fade after leaving live array", enemy.dead and not game.enemies.has(enemy) and body.visible and ink.albedo_color.a > 0.0 and ink.albedo_color.a < 0.95 and is_equal_approx(ink.albedo_color.a, enemy.sprite.modulate.a))
	# The game process is frozen by this fixture; advance its authoritative corpse clock.
	game._tick_corpses(0.09)
	renderer._world_environment._sync_corpses()
	var fallen: Dictionary = game.corpses.back()
	var source: Node = fallen["visual"]
	var corpse_model: Dictionary = renderer._world_environment._corpses[source.get_instance_id()]
	var corpse_root: Node3D = corpse_model["root"]
	check("native corpse observes original source opacity", corpse_root.visible and is_equal_approx((corpse_model["materials"][0] as StandardMaterial3D).albedo_color.a, CorpseArt.opacity(float(fallen["time"]), float(fallen["lifetime"]))))
	var saved_time: float = fallen["time"]
	fallen["time"] = 0.0
	renderer._world_environment._sync_corpses()
	check("expired native corpse no longer renders", not corpse_root.visible)
	fallen["time"] = saved_time
	renderer._world_environment._sync_corpses()
	Prefs.reduce_motion = old_reduce
	var at: Vector2 = game.player.position + Vector2(24, -60)
	var visible := renderer.camera.unproject_position(WorldRenderer3D.spatial_position(at, 0.9))
	var projected := renderer.camera.unproject_position(WorldRenderer3D.ground_position(at))
	check("chest-height light does not double-apply its projected height", visible.distance_to(projected) < 0.01)
	var impact := Effect.spawn_impact(game, at, game.player)
	impact.set_process(false)
	renderer._process(0.5)
	check("slow first update still presents the real confirmed impact light", renderer.contact_light.visible and renderer.contact_light.light_energy > 0.0 and renderer.contact_light.position.y > 0.0 and not renderer.contact_light.shadow_enabled)
	var light_energy := renderer.contact_light.light_energy
	get_tree().paused = true
	await _frames(2)
	check("pause preserves native contact light and pose", renderer.contact_light.light_energy == light_energy)
	get_tree().paused = false
	renderer._process(1.0)
	check("native contact light expires even without another rendering frame", not renderer.contact_light.visible)
	var live_portals := true
	for portal_source in game.village.portal_sprites.values():
		live_portals = live_portals and renderer._town_props.owns(portal_source) and not renderer._affordances._art.has(portal_source.get_instance_id())
	var live_chests := true
	for chest: Chest in game.chests:
		var fallback: Dictionary = renderer._affordances._art.get(chest.body_sprite.get_instance_id(), {})
		var native: Dictionary = renderer._encounter_props._entries.get(chest.get_instance_id(), {})
		if renderer._encounter_props.owns(chest.body_sprite):
			live_chests = live_chests and fallback.is_empty() and not native.is_empty() and (native["root"] as Node3D).is_visible_in_tree() and (native["owner"] as WeakRef).get_ref() == chest
		else:
			live_chests = live_chests and native.is_empty() and not fallback.is_empty() and (fallback["node"] as MeshInstance3D).is_visible_in_tree()
	check("native preview preserves every live chest exactly once with portals and resident headers", live_portals and live_chests and renderer._affordances._headers.size() == game.village.npc_nodes.size())
	var town_residents := ["상인", "대장장이", "탈것 상인", "촌장", "보급원 미라"]
	for label: String in town_residents:
		check("town resident has both original source and native body/header: " + label, game.village.npc_nodes.has(label))
		if game.village.npc_nodes.has(label):
			var resident: Villager = game.village.npc_nodes[label]
			check("town body and header are registered: " + label, renderer._native_residents.entries.has(resident.get_instance_id()) and not renderer._cards.has(resident.get_instance_id()) and renderer._affordances._headers.has(resident.get_instance_id()))
	# Resident native volumes retain each source foot and facing, rather than just
	# replacing a dictionary membership assertion with another renderer name.
	for entry: Dictionary in renderer._native_residents.entries.values():
		var resident: Villager = entry["owner"].get_ref()
		var model: Node3D = entry["node"]
		check("resident model follows native floor position", model.position.is_equal_approx(renderer.actor_foot(resident)))
		var bounds: AABB = ResidentRenderer3D.local_bounds(model)
		var meshes: Array[MeshInstance3D] = ResidentRenderer3D.descendant_meshes(model)
		var actual_volume: bool = not meshes.is_empty() and bounds.size.x > 0.4 and bounds.size.z > 0.2
		for part: MeshInstance3D in meshes:
			actual_volume = actual_volume and part.mesh != null and not part.mesh is QuadMesh
		check("resident retains real descendant body volume rather than a quad", actual_volume)
		if NpcArt.identity(resident.display_name) == "merchant":
			check("preview integration uses the imported merchant rather than a procedural substitute", str(entry["source"]) == "cc0_import" and entry["skeleton"] != null and entry["animation"] != null)
	var town_position: Vector2 = game.player.position
	game.player.position = game.village.gate_points[0] + (game.village.gate_points[0] - game.village.spawn_point).normalized() * 450.0
	renderer._process(0.016)
	check("leaving town keeps native rendering and the source field culled", renderer.display.visible and game.field_root.visibility_layer == 0 and renderer.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
	check("native forest remains visible in its own realm", renderer._world_environment.forest.visible and renderer._world_environment.report["scope"] == "forest")
	game.player.position = town_position
	renderer._process(0.016)
	check("returning to town reuses the native world", game.world_renderer == renderer and renderer.display.visible and game.field_root.visibility_layer == 0)
	game.player.position = game.dungeon.entry_point()
	check("native adventure can enter the existing cave encounter", game.dungeon.enter())
	await get_tree().physics_frame
	await get_tree().physics_frame
	renderer._process(0.016)
	check("cave keeps native walls visible while the forest remains culled", renderer.display.visible and game.field_root.visibility_layer == 0 and renderer._world_environment.cave.visible and not renderer._world_environment.forest.visible)
	check("town portals names and quest markers do not leak into the cave", _town_affordances_hidden(game, renderer))
	check("native resident bodies do not leak into cave realm", renderer._native_residents.review_snapshot()["visible"] == 0)
	game.dungeon.leave("")
	await get_tree().physics_frame
	await get_tree().physics_frame
	renderer._process(0.016)
	check("cave return restores the native forest without replacing the presenter", game.world_renderer == renderer and renderer._world_environment.forest.visible and not renderer._world_environment.cave.visible and game.field_root.visibility_layer == 0)
	var native_stage: Node3D = renderer.stage
	var spatial_world: Node = game.spatial_world
	var player_body: CharacterBody3D = game.spatial_world.actor_bodies[game.player.get_instance_id()]
	view.queue_free()
	await _frames(2)
	check("closing the native adventure frees its presenter physics world and hero body", not is_instance_valid(renderer) and not is_instance_valid(native_stage) and not is_instance_valid(spatial_world) and not is_instance_valid(player_body))
	Prefs.set_low_resolution(old_quality)
	Prefs.set_world_zoom(old_zoom)

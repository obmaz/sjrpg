extends TestCase


func run() -> void:
	var game := await make_game("mage")
	game.set_process(false)
	game.player.set_process(false)
	game.encounters.set_process(false)
	game.exploration.set_process(false)
	game.player.position = game.dungeon.entry_point()
	check("treasure fixture enters the cave", game.dungeon.enter())
	game.spatial_world.sync_scope()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var preview: Ortho3DPreview = game.ortho_preview
	preview.set_process(false)
	preview._world_environment.sync(0, true)
	var props: NativeEncounterProps3D = preview._encounter_props
	props.sync()
	var iron: Chest
	var gold: Chest
	var accessible := true
	for chest: Chest in game.chests:
		if chest.variant == "iron":
			iron = chest
		else:
			gold = chest
		var ground := Iso.unproject(chest.position)
		var approach := Iso.project(Vector2(ground.x, 0))
		var target := chest.position.move_toward(approach, 125)
		var result: Vector2 = game.resolve_movement(approach, target, Player.RADIUS)
		accessible = (
			accessible and result.distance_to(target) < 1.0 and props.owns(chest.body_sprite)
		)
	check(
		"five native treasure chests have a real clear side approach",
		game.chests.size() == 5 and accessible and iron != null and gold != null
	)
	var opened := GameState.opened_chests.duplicate()
	var enemy_count: int = game.enemies.size()
	var money := GameState.gold
	var potions := GameState.potions
	var bag := GameState.inventory.size()
	for hit in 3:
		iron.take_damage(999999, game.player)
	check(
		"iron endures three strong hits without paying rewards",
		not iron.dead and iron.hp == 1 and GameState.gold == money and GameState.potions == potions
	)
	iron.take_damage(1, game.player)
	check(
		"iron opens on fourth hit and pays supplies or money without enemies or gear",
		(
			iron.dead
			and GameState.gold > money
			and GameState.inventory.size() == bag
			and game.enemies.size() == enemy_count
		)
	)
	money = GameState.gold
	iron.take_damage(1, game.player)
	check("consumed iron cannot pay twice", GameState.gold == money)
	var gold_count := 0
	for chest: Chest in game.chests:
		if chest.variant != "gold":
			continue
		bag = GameState.inventory.size()
		chest.take_damage(1, game.player)
		var gear: Gear = GameState.inventory.back()
		check(
			"gold chest %d guarantees rare equipment and never ambushes" % chest.index,
			(
				chest.dead
				and GameState.inventory.size() == bag + 1
				and gear.rarity >= 2
				and game.enemies.size() == enemy_count
			)
		)
		gold_count += 1
	check(
		"cave treasure never overwrites persistent forest chest IDs",
		gold_count == 3 and GameState.opened_chests == opened
	)
	game.spatial_world.sync_scope()
	props.sync()
	await get_tree().physics_frame
	check(
		"opened cave chest releases its finite native blocker",
		not game.spatial_world.blocked(gold.position, 1)
	)
	_check_wall_ownership(game)
	game.dungeon.leave("")
	game.queue_free()
	await _frames(2)


func _check_wall_ownership(game: Node) -> void:
	var preview: Ortho3DPreview = game.ortho_preview
	var rock: Dictionary = preview._world_environment._cave_rock
	var owners := {}
	for wall: MeshInstance3D in rock["meshes"]:
		var owner := NativePlayerOcclusion.static_owner(wall)
		if owner != null:
			owners[owner.get_instance_id()] = true
	check(
		"each connected cave wall owns its entire inner and outer material independently",
		owners.size() == rock["meshes"].size() and owners.size() > 8
	)
	var fade: NativePlayerOcclusion = preview._occlusion
	var sample_found := false
	var unrelated_stays_solid := true
	var all_surfaces_match := true
	var samples := [
		Vector2(1125, -500), Vector2(2825, -500), Vector2(1125, 500), Vector2(2825, 500)
	]
	for room: Vector2 in DungeonLayout.ROOMS:
		samples.append(room + Vector2(180, 180))
	for sample: Vector2 in samples:
		game.spatial_world.teleport_source_actor(game.player, Iso.project(sample), Player.RADIUS)
		fade.sync(1.0)
		for wall: MeshInstance3D in rock["meshes"]:
			var key := "object:%s" % wall.get_instance_id()
			var wanted: bool = fade._fades.has(key) and fade._fades[key]["wanted"]
			if not wanted:
				unrelated_stays_solid = (
					unrelated_stays_solid
					and (not fade._fades.has(key) or fade._fades[key]["alpha"] == 1.0)
				)
			else:
				sample_found = true
				for surface in wall.mesh.get_surface_count():
					var ink := wall.get_surface_override_material(surface) as ShaderMaterial
					all_surfaces_match = (
						all_surfaces_match
						and ink != null
						and (
							absf(
								(
									float(ink.get_shader_parameter("occlusion_opacity"))
									- NativePlayerOcclusion.MIN_OPACITY
								)
							)
							< .001
						)
					)
	check(
		"actual player sightlines fade only occluding wall objects and keep other walls solid",
		sample_found and unrelated_stays_solid and all_surfaces_match,
		JSON.stringify(
			{"found": sample_found, "solid": unrelated_stays_solid, "surfaces": all_surfaces_match}
		)
	)
	preview._enemy_models.sync()
	var dynamic_models := true
	for model: Dictionary in preview._enemy_models.entries.values():
		for mesh: MeshInstance3D in (model["root"] as Node3D).find_children(
			"*", "MeshInstance3D", true, false
		):
			dynamic_models = dynamic_models and NativePlayerOcclusion.static_owner(mesh) == null
	check(
		"all actual cave monster model parts remain outside static fade ownership",
		dynamic_models and not preview._enemy_models.entries.is_empty()
	)

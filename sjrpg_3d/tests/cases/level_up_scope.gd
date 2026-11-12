extends TestCase
## A paused forest effect must not follow its reparented hero into the cave.


func run() -> void:
	var old_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var game := await make_game("mage")
	game.set_process(false)
	game.player.set_process(false)
	game.encounters.set_process(false)
	game.quest_runtime.set_process(false)
	game.exploration.set_process(false)
	var renderer: WorldRenderer3D = game.world_renderer
	var celebration: ProgressionEffects3D = renderer._level_up_fx
	game.player.position = game.dungeon.entry_point()
	game.grant_xp(GameState.xp_to_next())
	var forest_source: RewardFx = game.cosmetic_effects.back()
	var forest_world: Node2D = game.world
	var forest_id := forest_source.get_instance_id()
	renderer._process(0.0)
	check("a real forest level-up creates its native celebration", forest_source.get_parent() == forest_world and celebration._entries.has(forest_id))
	check("the hero can enter the actual cave during the celebration", game.dungeon.enter())
	for enemy: Enemy in game.enemies:
		enemy.set_process(false)
	var forest_age := forest_source.age
	await get_tree().physics_frame
	await _frames(3)
	renderer._process(0.0)
	check("cave entry pauses the original forest effect clock", forest_source.age == forest_age and forest_world.get_parent().process_mode == Node.PROCESS_MODE_DISABLED)
	check("the paused forest celebration leaves the native stage in the cave", not celebration._entries.has(forest_id))
	game.grant_xp(GameState.xp_to_next())
	var cave_source: RewardFx = game.cosmetic_effects.back()
	var cave_id := cave_source.get_instance_id()
	var cave_life := cave_source.life
	renderer._process(0.0)
	check("a real cave level-up has its own current-world source and native entry", cave_source.get_parent() == game.world and celebration._entries.size() == 1 and celebration._entries.has(cave_id))
	var cave_age := cave_source.age
	await get_tree().create_timer(0.08, false).timeout
	check("only the cave celebration advances while the forest is suspended", cave_source.age > cave_age and forest_source.age == forest_age)
	await get_tree().create_timer(cave_life + 0.15, false).timeout
	renderer._process(0.0)
	check("the cave celebration expires on its real source clock without reviving forest FX", not celebration._entries.has(cave_id) and celebration._entries.is_empty() and forest_source.age == forest_age)
	game.dungeon.leave("")
	await get_tree().physics_frame
	await _frames(3)
	renderer._process(0.0)
	check("returning to the forest restores only the still-current forest source", game.world == forest_world and forest_source.get_parent() == game.world and forest_source.age > forest_age and celebration._entries.size() == 1 and celebration._entries.has(forest_id))
	await get_tree().create_timer(forest_source.life + 0.15, false).timeout
	renderer._process(0.0)
	check("the resumed forest celebration also expires without another clock", celebration._entries.is_empty())
	Prefs.reduce_motion = old_reduce
	game.queue_free()
	await _frames(2)

extends TestCase
## Real2D XP grants retain their generated around-body art, banner and source clock.


func _sources(game: Node) -> Array:
	return game.cosmetic_effects.filter(func(effect) -> bool:
		return is_instance_valid(effect) and not effect.is_queued_for_deletion() and effect.kind == "reward" and effect.params.get("large", false))


func run() -> void:
	var old_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var game := await make_game("mage")
	game.set_process(false)
	game.player.set_process(false)
	game.encounters.set_process(false)
	game.quest_runtime.set_process(false)
	game.grant_xp(0)
	check("zero XP cannot create a level-up celebration", _sources(game).is_empty())
	game.grant_xp(GameState.xp_to_next())
	var source: RewardFx = _sources(game).back()
	source.set_process(false)
	var ink := source.material as CanvasItemMaterial
	check("real2D level-up creates the existing generated around-body art", GameState.level == 2 and source._large and source._cell == 1 and source._diameter == 196.0 and source.get_parent() == game.world and ink != null and ink.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD)
	var banner: LevelUpBanner = game.hud._level_up
	check("celebration preserves the existing nonblocking LEVEL UP banner", banner.active and banner.level == GameState.level and LevelUpBanner.TITLE == "LEVEL UP" and banner.mouse_filter == Control.MOUSE_FILTER_IGNORE and not game.hud._toast.text.contains("레벨 업"))
	var anchor := source._anchor
	game.player.position += Vector2(60, 25)
	source._process(0.05)
	check("generated celebration follows the actual moving hero and its foot halo", source.owner_node == game.player and source.position == game.player.position + anchor and source.position - source._anchor == game.player.position)
	var first_age := source.age
	source._process(0.20)
	check("generated glint lifetime advances only with its source effect", source.age > first_age and source.age < source.life)
	var paused_age := source.age
	var paused_position := source.position
	source.set_process(true)
	get_tree().paused = true
	await _frames(3)
	check("pause freezes the actual around-body source clock and anchor", source.age == paused_age and source.position == paused_position)
	get_tree().paused = false
	source.set_process(false)
	Prefs.reduce_motion = true
	source._process(0.20)
	check("reduced motion retains fixed generated art around the hero", source.position == paused_position and source.owner_node == game.player and source._large and source.age > paused_age)
	source._process(2.0)
	check("around-body art expires with its source effect", source.is_queued_for_deletion() and _sources(game).is_empty())
	Prefs.reduce_motion = false
	game.grant_xp(GameState.xp_to_next())
	source = _sources(game).back()
	source.set_process(false)
	source._process(5.0)
	check("a slow first update still presents the real2D celebration", not source.is_queued_for_deletion() and source.age <= source.life * 0.101)
	source._process(5.0)
	check("slow-frame celebration eventually expires", source.is_queued_for_deletion() and _sources(game).is_empty())
	for index in 4:
		game.grant_xp(GameState.xp_to_next())
	check("consecutive real level-ups retain their individual2D sources within the shared cosmetic budget", _sources(game).size() == 4 and game.cosmetic_effects.size() <= 64)
	for effect: Effect in _sources(game):
		effect.set_process(false)
		effect._process(2.0)
		effect._process(2.0)
	check("all generated celebrations clear when their source effects end", _sources(game).is_empty())
	check("level-up never creates a native3D subtree in the2D adventure", game.find_children("*", "Node3D", true, false).is_empty())
	Prefs.reduce_motion = old_reduce
	game.queue_free()
	await _frames(2)

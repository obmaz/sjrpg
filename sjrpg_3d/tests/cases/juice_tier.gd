extends TestCase
## JUICE #1: the hit tier is derived once from damage / max health and never changes damage itself.


func run() -> void:
	check("small hit is LIGHT", HitTier.of(5.0, 100.0, false) == HitTier.LIGHT)
	check("10% hit is MEDIUM", HitTier.of(10.0, 100.0, false) == HitTier.MEDIUM)
	check("30% hit is HEAVY like the original heavy rule", HitTier.of(30.0, 100.0, false) == HitTier.HEAVY)
	check("killing blow is KILL even when small", HitTier.of(1.0, 100.0, true) == HitTier.KILL)
	check("zero max health cannot divide by zero", HitTier.of(5.0, 0.0, false) == HitTier.HEAVY)
	check("only HEAVY and KILL count as heavy", not HitTier.is_heavy(HitTier.MEDIUM) and HitTier.is_heavy(HitTier.HEAVY) and HitTier.is_heavy(HitTier.KILL))

	var game := await make_game()
	var foe := Enemy.new()
	foe.setup(game, "goblin", 1)
	foe.position = game.player.position + Vector2(60, 0)
	foe.hp = 100.0
	foe.max_hp = 100.0
	game.world.add_child(foe)
	game.enemies.append(foe)
	foe.set_process(false)
	foe.take_damage(4.0, game.player)
	check("enemy records a LIGHT tier", foe.last_hit_tier == HitTier.LIGHT)
	check("tier does not change the damage taken", is_equal_approx(foe.hp, 96.0))
	foe.take_damage(12.0, game.player)
	check("enemy records a MEDIUM tier", foe.last_hit_tier == HitTier.MEDIUM and is_equal_approx(foe.hp, 84.0))
	var numbers: Array = game.cosmetic_effects.filter(func(e: Effect) -> bool: return e.kind == "text")
	check("light hit keeps the original 22pt number without a pop", numbers[0].font_size == 22 and not numbers[0].pop)
	check("medium hit number is larger and pops", numbers[1].font_size == HitTier.number_size(HitTier.MEDIUM) and numbers[1].font_size > 22 and numbers[1].pop)
	check("number colour differs per tier", HitTier.number_color(HitTier.LIGHT) != HitTier.number_color(HitTier.HEAVY))
	check("number sizes only grow with the tier", HitTier.number_size(HitTier.LIGHT) < HitTier.number_size(HitTier.MEDIUM) and HitTier.number_size(HitTier.MEDIUM) < HitTier.number_size(HitTier.HEAVY) and HitTier.number_size(HitTier.HEAVY) <= HitTier.number_size(HitTier.KILL))
	check("bounds are measured with the number's own size", numbers[1].text_bounds().size.y > numbers[0].text_bounds().size.y)
	check("pop starts enlarged and settles to normal size", Effect.text_pop_scale(0.0) > 1.0 and is_equal_approx(Effect.text_pop_scale(Effect.POP_SECONDS), 1.0))
	foe.take_damage(foe.hp + 1.0, game.player)
	check("lethal hit records KILL", foe.last_hit_tier == HitTier.KILL and foe.dead)
	var killing: Array = game.cosmetic_effects.filter(func(e: Effect) -> bool: return e.kind == "text" and e.font_size == HitTier.number_size(HitTier.KILL))
	check("killing blow shows the largest number", killing.size() == 1)
	game.queue_free()
	await _frames(2)

extends TestCase
## Real repeated damage retains separate, readable amounts and independent XP text.


func _labels(game: Node) -> Array:
	return game.cosmetic_effects.filter(func(effect) -> bool:
		return is_instance_valid(effect) and not effect.is_queued_for_deletion() and effect.kind == "text")


func _separated(labels: Array) -> bool:
	for index in labels.size():
		for other in range(index + 1, labels.size()):
			if labels[index].text_bounds().intersects(labels[other].text_bounds()):
				return false
	return true


func run() -> void:
	var previous_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var game := await make_game("mage")
	game.set_process(false)
	game.encounters.set_process(false)
	game.quest_runtime.set_process(false)
	game.player.set_process(false)
	var target := Enemy.new()
	target.setup(game, "goblin", 1)
	target.position = Vector2(-2200, 2000)
	target.hp = 1000.0
	target.max_hp = target.hp
	game.world.add_child(target)
	game.enemies.append(target)
	target.set_process(false)
	game.spawn_zone({"pos": target.position, "radius": 20.0, "duration": 2.0,
		"tick": 0.12, "damage": 44.78, "color": SkillDefs.FIRE})
	var zone: Effect
	for child in game.world.get_children():
		if child is Effect and child.kind == "zone":
			zone = child
	zone.set_process(false)
	var exact_amounts := true
	var readable := true
	for index in 5:
		for label: Effect in _labels(game):
			label._process(0.12)
		zone._process(0.12)
		var labels := _labels(game)
		exact_amounts = exact_amounts and labels.size() == index + 1
		for label: Effect in labels:
			exact_amounts = exact_amounts and label.text == HudArt.stat(44.78)
		readable = readable and _separated(labels)
	check("rapid real zone hits keep every original amount separate", exact_amounts and is_equal_approx(target.hp, 1000.0 - 44.78 * 5.0))
	check("rapid damage labels do not overlap their outlined glyphs", readable)
	var at := target.position + Vector2(0, -target.sprite.body_height - 20)
	game.float_text(at, "+9 XP", Color(0.7, 0.85, 1))
	var labels := _labels(game)
	var reward: Effect = labels.back()
	check("XP remains visibly distinct from damage amounts", reward.text == "+9 XP" and reward.color == Color(0.7, 0.85, 1) and _separated(labels))
	Prefs.reduce_motion = true
	var start := reward.position
	reward._process(0.1)
	check("reduced motion keeps floating text stationary", reward.position == start and reward.age > 0.0)
	var pause_age := reward.age
	get_tree().paused = true
	await _frames(2)
	check("paused simulation preserves floating text age", reward.age == pause_age)
	get_tree().paused = false
	for label: Effect in _labels(game):
		label._process(1.0)
	await _frames(2)
	game.float_text(at, "새 타격\n+9 XP", Color.WHITE)
	labels = _labels(game)
	check("new text ignores labels freed in earlier frames", labels.size() == 1 and labels[0].position == at)
	var multiline: Effect = labels[0]
	check("multiline bounds include both lines", multiline.text_bounds().size.y >= UiKit.BOLD_FONT.get_height(22) * 2.0)
	multiline._process(1.0)
	for index in 100:
		game.float_text(at, str(index), Color.WHITE)
	labels = _labels(game)
	var bounded: bool = labels.size() <= 9 and game.cosmetic_effects.size() <= 64
	for label: Effect in labels:
		bounded = bounded and absf(label.position.x - at.x) <= 96.0 and absf(label.position.y - at.y) <= 80.0
	check("dense text stays within fixed nearby positions and cosmetic budget", bounded and _separated(labels))
	for label: Effect in labels:
		label._process(1.0)
	check("floating text expires without a rendering frame", _labels(game).is_empty())
	Prefs.reduce_motion = previous_reduce
	game.queue_free()
	await _frames(2)

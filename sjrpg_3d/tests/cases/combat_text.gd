extends TestCase
## Real repeated hits form an ordered column per monster, with separate XP text.


func _labels(game: Node) -> Array:
	return game.cosmetic_effects.filter(func(effect) -> bool:
		return is_instance_valid(effect) and not effect.is_queued_for_deletion() and effect.kind == "text")


func _separated(labels: Array) -> bool:
	for index in labels.size():
		for other in range(index + 1, labels.size()):
			if labels[index].text_bounds().intersects(labels[other].text_bounds()):
				return false
	return true


func _stream(game: Node, target_id: int) -> Array:
	return _labels(game).filter(func(effect) -> bool: return effect._text_target_id == target_id)


func _column(labels: Array, x: float) -> bool:
	for index in labels.size():
		var label: Effect = labels[index]
		if not is_equal_approx(label.position.x, x):
			return false
		if index > 0:
			var previous: Effect = labels[index - 1]
			if previous.text_bounds().end.y + Effect.TEXT_STREAM_GAP > label.text_bounds().position.y + 0.001:
				return false
	return true


func _target(game: Node, at: Vector2) -> Enemy:
	var enemy := Enemy.new()
	enemy.setup(game, "goblin", 1)
	enemy.position = at
	enemy.hp = 100000.0
	enemy.max_hp = enemy.hp
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	enemy.set_process(false)
	return enemy


func run() -> void:
	var previous_reduce := Prefs.reduce_motion
	Prefs.reduce_motion = false
	var game := await make_game("mage")
	game.set_process(false)
	game.encounters.set_process(false)
	game.quest_runtime.set_process(false)
	game.player.set_process(false)
	var target := _target(game, Vector2(-2200, 2000))
	var target_id := target.get_instance_id()
	game.spawn_zone({"pos": target.position, "radius": 20.0, "duration": 2.0,
		"tick": 0.12, "damage": 44.78, "color": SkillDefs.FIRE})
	var zone: Effect
	for child in game.world.get_children():
		if child is Effect and child.kind == "zone":
			zone = child
	zone.set_process(false)
	var exact_amounts := true
	var readable := true
	var total := 0.0
	var expected: Array[String] = []
	for index in 5:
		for label: Effect in _labels(game):
			label._process(0.12)
		zone.damage = 44.78 + index
		total += zone.damage
		expected.append(HudArt.stat(zone.damage))
		zone._process(0.12)
		var labels := _stream(game, target_id)
		exact_amounts = exact_amounts and labels.size() == index + 1
		for row in labels.size():
			var label: Effect = labels[row]
			exact_amounts = exact_amounts and label.text == expected[row] and label.color == Color(1, 0.95, 0.6)
		readable = readable and _column(labels, target.position.x)
	check("rapid real zone hits keep every amount in hit order", exact_amounts and is_equal_approx(target.hp, 100000.0 - total))
	check("one monster's damage rises in one readable vertical column", readable)
	var other := _target(game, target.position + Vector2(170, 10))
	var other_id := other.get_instance_id()
	var first_positions: Array[Vector2] = []
	for label: Effect in _stream(game, target_id):
		first_positions.append(label.position)
	other.take_damage(7.25, null, zone)
	var independent := _stream(game, other_id).size() == 1
	var first_stream := _stream(game, target_id)
	for index in first_stream.size():
		independent = independent and first_stream[index].position == first_positions[index]
	check("another monster starts its own column without moving the first", independent and _column(_stream(game, other_id), other.position.x))
	target.position += Vector2(70, -20)
	for label: Effect in _labels(game):
		label._process(0.01)
	check("moving monsters retain their own aligned damage columns", _column(_stream(game, target_id), target.position.x) and _column(_stream(game, other_id), other.position.x))
	var at := target.position + Vector2(0, -target.sprite.body_height - 20)
	game.float_text(at, "+9 XP", Color(0.7, 0.85, 1))
	var labels := _labels(game)
	var reward: Effect = labels.back()
	check("XP stays outside the damage stream with its own amount and color", reward.text == "+9 XP" and reward._text_target_id == 0 and reward.color == Color(0.7, 0.85, 1) and _separated(labels))
	Prefs.reduce_motion = true
	var newest: Effect = _stream(game, target_id).back()
	var start := newest.position
	newest._process(0.1)
	check("reduced motion keeps the damage column stationary", newest.position == start and newest.age > 0.0)
	var pause_age := newest.age
	get_tree().paused = true
	await _frames(2)
	check("paused simulation preserves damage text age and position", newest.age == pause_age and newest.position == start)
	get_tree().paused = false
	other.take_damage(other.hp + 1.0, null, zone)
	var xp_labels := _labels(game).filter(func(effect) -> bool:
		return effect._text_target_id == 0 and effect.text == "+9 XP" and effect.color == Color(0.7, 0.85, 1))
	check("real monster death keeps XP separate from its final damage", xp_labels.size() == 2 and _stream(game, other_id).size() == 2)
	var dying_stream := _stream(game, other_id)
	var final_x := other.position.x
	other.position.x += 400.0
	for label: Effect in dying_stream:
		label._process(0.0)
	var frozen := _column(dying_stream, final_x)
	for label: Effect in _labels(game):
		label.set_process(false)
	other.queue_free()
	await _frames(2)
	for label: Effect in dying_stream:
		label._process(0.05)
		frozen = frozen and label._text_target.get_ref() == null
	check("dying and freed targets retain the last safe column anchor", frozen and _column(dying_stream, final_x))
	for label: Effect in _labels(game):
		label._process(1.0 + Effect.TEXT_STAGGER_MAX)
	await _frames(2)
	var before_dense := target.hp
	for index in 100:
		target.take_damage(float(index + 1) * 0.01, null, zone)
	var dense := _stream(game, target_id)
	var bounded: bool = not dense.is_empty() and game.cosmetic_effects.size() <= 64 and _column(dense, target.position.x)
	for index in dense.size():
		var label: Effect = dense[index]
		bounded = bounded and label._text_rise <= Effect.TEXT_STREAM_MAX_RISE and label.text == HudArt.stat(float(101 - dense.size() + index) * 0.01)
	check("dense real hits retain ordered individual amounts in a bounded column", bounded and is_equal_approx(before_dense - target.hp, 50.5))
	for label: Effect in _labels(game):
		label._process(1.0 + Effect.TEXT_STAGGER_MAX)
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
	bounded = labels.size() <= 9 and game.cosmetic_effects.size() <= 64
	for label: Effect in labels:
		bounded = bounded and absf(label.position.x - at.x) <= 96.0 and absf(label.position.y - at.y) <= 80.0
	check("dense text stays within fixed nearby positions and cosmetic budget", bounded and _separated(labels))
	for label: Effect in labels:
		label._process(1.0)
	check("floating text expires without a rendering frame", _labels(game).is_empty())
	Prefs.reduce_motion = previous_reduce
	game.queue_free()
	await _frames(2)

extends TestCase
## 실제 공격/함정 접촉을 회피했을 때만 한 번 알리고 원래 무적·쿨다운을 보존한다.


func _count(game: Node, kind: String, text := "") -> int:
	var total := 0
	for effect: Effect in Effect.in_world(game.world):
		if (
			not effect.is_queued_for_deletion()
			and effect.kind == kind
			and (text.is_empty() or effect.text == text)
		):
			total += 1
	return total


func run() -> void:
	var game := await make_game()
	game.set_process(false)
	var hero: Player = game.player
	hero.set_process(false)
	game.spatial_world.teleport_source_actor(
		hero, game.village.point(Vector2(.5, 1.15)), Player.RADIUS
	)
	var foe := Enemy.new()
	foe.setup(game, "goblin", 1)
	foe.position = hero.position + Vector2(60, 0)
	game.world.add_child(foe)
	game.enemies.append(foe)
	foe.set_process(false)
	await _frames(3)
	var reduced := Prefs.reduce_motion
	Prefs.set_reduce_motion(false)
	foe.force_chase()
	foe._process(.01)
	check("enemy attack starts through actual AI", foe._state == "windup")
	foe._process(foe._windup_duration - .02)
	hero.try_roll()
	var hp := hero.hp
	var duration := hero._roll_time
	var cooldown := hero._roll_cooldown
	var notices := _count(game, "text", "회피")
	var rings := _count(game, "nova")
	check("starting a roll alone never reports success", not hero._roll_confirmed)
	foe._process(.03)
	check(
		"a genuinely avoided AI contact reports once without damage",
		(
			hero.hp == hp
			and hero._roll_confirmed
			and _count(game, "text", "회피") == notices + 1
			and _count(game, "nova") == rings + 1
		)
	)
	var nova: NativeNovaFx3D = game.ortho_preview._nova_fx
	nova.sync()
	check(
		"success has an actual shared native ring, not a hidden Canvas effect",
		nova.entries.size() == rings + 1
	)
	var ring_builds := nova.builds
	check(
		"confirmation never extends the roll or cooldown",
		hero._roll_time == duration and hero._roll_cooldown == cooldown
	)
	for index in 12:
		hero.take_damage(5, foe)
	check(
		"many contacts in the same roll share one cue",
		_count(game, "text", "회피") == notices + 1 and _count(game, "nova") == rings + 1
	)
	hero._roll_time = 0
	hero._roll_confirmed = false
	hero._invulnerable = 1
	hero.take_damage(5, foe)
	check("passive invulnerability is not a successful dodge", not hero._roll_confirmed)
	hero._roll_time = Player.ROLL_TIME
	hero.warp_locked = true
	hero.take_damage(5, foe)
	check("warp protection cannot create a dodge cue", not hero._roll_confirmed)
	hero.warp_locked = false
	hero.take_damage(0, foe)
	check("zero contact cannot confirm a roll", not hero._roll_confirmed)
	get_tree().paused = true
	hero.take_damage(5, foe)
	check("paused refreshes cannot create new feedback", not hero._roll_confirmed)
	get_tree().paused = false
	hero._roll_time = 0
	hero._invulnerable = 0
	hero.take_damage(5, foe)
	check(
		"ordinary unprotected damage keeps its original behavior",
		hero.hp < hp and not hero._roll_confirmed
	)
	Prefs.set_reduce_motion(true)
	hero._roll_cooldown = 0
	hero.try_roll()
	rings = _count(game, "nova")
	notices = _count(game, "text", "회피")
	hero.take_damage(5, foe)
	check(
		"reduce motion keeps the essential word and omits the success ring",
		(
			hero._roll_confirmed
			and _count(game, "text", "회피") == notices + 1
			and _count(game, "nova") == rings
		)
	)
	nova.sync()
	check(
		"reduce motion retires native pulses without allocating replacements",
		nova.entries.is_empty() and nova.builds == ring_builds
	)
	var wave: AudioStreamWAV = SoundFx._streams["evade_confirm"]
	var pcm := wave.data
	var peak := 0.0
	for index in range(0, pcm.size(), 2):
		var sample := int(pcm[index]) | (int(pcm[index + 1]) << 8)
		if sample >= 32768:
			sample -= 65536
		peak = maxf(peak, absf(sample / 32768.0))
	check(
		"confirmation reuses the bounded voice pool and a small unclipped PCM cache",
		SoundFx._players.size() == 8 and pcm.size() > 0 and pcm.size() < 4000 and peak < .98
	)
	print("DODGE_SOUND_CACHE bytes=", pcm.size(), " peak=", peak)
	hero._roll_time = 0
	hero.position = game.dungeon.entry_point()
	check("trap confirmation fixture enters a real cave", game.dungeon.enter())
	for enemy: Enemy in game.enemies:
		enemy.set_process(false)
	await _frames(3)
	var trap: DungeonTrap = game.dungeon.hazards.traps[0]
	game.spatial_world.teleport_source_actor(hero, trap.position, Player.RADIUS)
	trap.phase = DungeonTrap.Phase.ACTIVE
	trap.age = .3
	trap.hit_actors.clear()
	Prefs.set_reduce_motion(false)
	hero._roll_cooldown = 0
	hero._invulnerable = 0
	hero.try_roll()
	hp = hero.hp
	notices = _count(game, "text", "회피")
	game.dungeon.hazards.tick(.01)
	game.dungeon.hazards.tick(.01)
	check(
		"real dangerous trap contact confirms once without consuming its damage record",
		(
			hero.hp == hp
			and hero._roll_confirmed
			and _count(game, "text", "회피") == notices + 1
			and not trap.hit_actors.has(hero.get_instance_id())
		)
	)
	nova.sync()
	check(
		"a new cave cue reuses the field pulse node on its actual floor",
		nova.entries.size() == 1 and nova.builds == ring_builds
	)
	hero._roll_time = 0
	hero._invulnerable = 0
	game.dungeon.hazards.tick(.01)
	check(
		"the same raised trap can still hurt after the original immunity ends",
		hero.hp < hp and trap.hit_actors.has(hero.get_instance_id())
	)
	Prefs.set_reduce_motion(reduced)
	game.queue_free()
	await _frames(2)

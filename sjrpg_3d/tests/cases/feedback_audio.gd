extends TestCase


func run() -> void:
	var enabled := Prefs.sound_enabled
	Prefs.sound_enabled = true
	var max_bytes := 0
	for family: String in SoundFx._sample_banks:
		var bank: Array = SoundFx._sample_banks[family]
		check("recorded family has at least three takes " + family, bank.size() >= 3)
		var previous: AudioStream
		for index in 12:
			var stream := SoundFx.sample_stream(family) as AudioStreamWAV
			check("consecutive takes never repeat " + family, stream != previous)
			check(
				"samples are bounded mono PCM " + family,
				(
					stream.mix_rate == 22050
					and not stream.stereo
					and stream.format == AudioStreamWAV.FORMAT_16_BITS
					and stream.get_length() <= 0.41
				)
			)
			max_bytes = maxi(max_bytes, stream.data.size())
			previous = stream
	check("sample buffers remain small", max_bytes < 19000)
	check(
		"recorded preparation stays quieter than contact",
		SoundFx.playback_volume_db("weapon_draw") < SoundFx.playback_volume_db("hit_flesh")
	)
	check(
		"skeleton warning reuses the same recorded knife buffers",
		SoundFx._sample_banks["warn_skeleton"] == SoundFx._sample_banks["weapon_draw"]
	)
	for player: AudioStreamPlayer in SoundFx._players:
		player.stream = SoundFx._streams["fire"]
		player.set_meta("voice_priority", 100)
		player.set_meta("voice_serial", 1)
		player.play()
	check("footsteps cannot cut eight important voices", SoundFx._voice_index(20) < 0)
	SoundFx._players[3].set_meta("voice_priority", 20)
	check("a warning steals a footstep instead of hurt audio", SoundFx._voice_index(80) == 3)
	for player: AudioStreamPlayer in SoundFx._players:
		player.stop()
	SoundFx._last.clear()
	var serial := SoundFx.played_serial
	Prefs.sound_enabled = false
	SoundFx.play("step_grass")
	check("the sound preference gates sampled playback", SoundFx.played_serial == serial)
	Prefs.sound_enabled = true
	SoundFx._last_warning_ms = -100000
	check("a far-off enemy is silent", not SoundFx.play_warning("wolf", 500.0))
	check(
		"a nearby warning uses the existing pool",
		SoundFx.play_warning("wolf", 100.0) and SoundFx._players.size() == 8
	)
	check("a crowd cannot burst preparation sounds", not SoundFx.play_warning("golem", 100.0))
	check(
		"species have distinct preparation materials",
		(
			SoundFx.warning_name("wolf") != SoundFx.warning_name("skeleton")
			and SoundFx.warning_name("skeleton") != SoundFx.warning_name("golem")
		)
	)
	for player: AudioStreamPlayer in SoundFx._players:
		player.stop()
	SoundFx._last.clear()
	Prefs.sound_enabled = enabled
	var game := await make_game("warrior")
	game.player.set_process(false)
	var foe := Enemy.new()
	foe.setup(game, "wolf", 1)
	foe.position = game.player.position + Vector2(40, 0)
	game.world.add_child(foe)
	game.enemies.append(foe)
	foe.set_process(false)
	foe.force_chase()
	Prefs.sound_enabled = true
	SoundFx._last_warning_ms = -100000
	SoundFx._last.clear()
	serial = SoundFx.played_serial
	var hp: float = game.player.hp
	foe._process(0.01)
	check(
		"real windup triggers one cue without an early hit",
		foe._state == "windup" and game.player.hp == hp and SoundFx.played_serial == serial + 1
	)
	foe._process(0.01)
	check(
		"holding windup cannot retrigger the preparation cue", SoundFx.played_serial == serial + 1
	)
	for player: AudioStreamPlayer in SoundFx._players:
		player.stop()
	var crawler := Enemy.new()
	crawler.setup(game, "goblin", 1)
	crawler.set_meta("visual_variant", "cave_crawler")
	crawler.position = game.player.position + Vector2(-40, 0)
	game.world.add_child(crawler)
	game.enemies.append(crawler)
	crawler.set_process(false)
	crawler.force_chase()
	SoundFx._last_warning_ms = -100000
	SoundFx._last.clear()
	crawler._process(0.01)
	check(
		"crawler variant sounds like its visible creature rather than goblin",
		crawler._state == "windup" and SoundFx.last_played["name"] == "warn_beast"
	)
	Prefs.sound_enabled = enabled
	game.queue_free()
	await _frames(3)

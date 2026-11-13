extends TestCase
## 실제 동시 피해와 표시 박자를 분리하고, 느린 프레임·수명·접근성의 경계를 검사한다.


func run() -> void:
	var old_motion := Prefs.reduce_motion
	var old_sound := Prefs.sound_enabled
	Prefs.reduce_motion = false
	Prefs.sound_enabled = true
	_check_stop_upgrade()
	_check_audio_accents()
	_check_pcm_mix()
	var game := await make_game()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var impacts: Array[Effect] = []
	var exact := true
	for index in 12:
		var foe := Enemy.new()
		foe.setup(game, "goblin", 1)
		foe.position = game.player.position + Vector2(65 + index * 2, index * 2)
		foe.hp = 1000.0
		foe.max_hp = foe.hp
		game.world.add_child(foe)
		game.enemies.append(foe)
		var before: int = game.cosmetic_effects.size()
		foe.take_damage(5.0, game.player)
		exact = exact and is_equal_approx(foe.hp, 995.0)
		for effect: Effect in game.cosmetic_effects.slice(before):
			if effect.kind == "impact":
				impacts.append(effect)
	check(
		"every victim receives exact damage before any queued beat", exact and impacts.size() == 12
	)
	check(
		"first contact is immediate and dense contacts share three bounded beats",
		(
			impacts[0].age == 0.0
			and game.contact_rhythm.snapshot()["pending"] == 3
			and impacts[1].age < 0.0
			and impacts[-1].age >= -0.120001
		)
	)
	var renderer: WorldRenderer3D = game.world_renderer
	renderer._sync_cards()
	renderer._hit_feel.sync(0.0)
	check(
		"queued contacts have neither a card nor native particles before their beat",
		(
			renderer._cards.has(impacts[0].get_instance_id())
			and not renderer._cards.has(impacts[1].get_instance_id())
			and not renderer._hit_feel.entries.has(impacts[1].get_instance_id())
		)
	)
	var waiting := impacts[1].age
	impacts[1]._process(0.2)
	check("effect processing cannot consume the rhythm clock twice", impacts[1].age == waiting)
	get_tree().paused = true
	game.contact_rhythm.tick(game, 0.2)
	check("pause preserves pending beat deadlines", impacts[1].age == waiting)
	get_tree().paused = false
	game.contact_rhythm.tick(game, 0.04)
	renderer._sync_cards()
	renderer._hit_feel.sync(0.0)
	check(
		"the second contact releases after40ms with a full visual lifetime",
		(
			impacts[1].age == 0.0
			and impacts[2].age < 0.0
			and renderer._cards.has(impacts[1].get_instance_id())
			and renderer._hit_feel.entries.has(impacts[1].get_instance_id())
		)
	)
	var beats: int = game.contact_rhythm.beats
	game.contact_rhythm.tick(game, 0.4)
	check(
		"a slow frame releases overdue visuals but plays only one overdue beat",
		(
			impacts[-1].age == 0.0
			and game.contact_rhythm.beats == beats + 1
			and game.contact_rhythm.snapshot()["pending"] == 0
		)
	)
	game.contact_rhythm.clear()
	_check_camera(game)
	var first := _impact(game)
	var cancelled := _impact(game)
	game.player.warp_locked = true
	game.contact_rhythm.tick(game, 0.02)
	check(
		"warp discards pending sounds and their owned cosmetic contacts",
		(
			cancelled.is_queued_for_deletion()
			and game.contact_rhythm.snapshot()["pending"] == 0
			and not first.is_queued_for_deletion()
		)
	)
	game.player.warp_locked = false
	game.contact_rhythm.clear()
	_impact(game)
	var retired := _impact(game)
	var original: Node2D = game.world
	var replacement := Node2D.new()
	game.add_child(replacement)
	game.world = replacement
	game.contact_rhythm.tick(game, 0.2)
	check(
		"changing active world cancels old contacts without late audio",
		retired.is_queued_for_deletion() and game.contact_rhythm.snapshot()["pending"] == 0
	)
	game.world = original
	replacement.queue_free()
	game.contact_rhythm.clear()
	_impact(game)
	var evicted := _impact(game)
	evicted.queue_free()
	beats = game.contact_rhythm.beats
	game.contact_rhythm.tick(game, 0.1)
	check("an evicted cosmetic cannot leave a phantom sound", game.contact_rhythm.beats == beats)
	game.contact_rhythm.clear()
	var unique := _impact(game)
	beats = game.contact_rhythm.beats
	game.contact_rhythm.confirm(game, unique, HitTier.HEAVY, 0, "wolf")
	check(
		"a confirmed contact cannot be scheduled twice",
		game.contact_rhythm.beats == beats and game.contact_rhythm.snapshot()["pending"] == 0
	)
	var expired := _impact(game)
	expired.age = expired.life
	game.contact_rhythm.tick(game, 0.01)
	game.contact_rhythm.tick(game, 0.04)
	check(
		"an expired pending contact cannot be revived by the scheduler",
		expired.age == expired.life and game.contact_rhythm.beats == beats
	)
	game.contact_rhythm.clear()
	for index in 512:
		_impact(game)
	check(
		"a dense burst bounds both effects and weak source references",
		(
			game.cosmetic_effects.size() <= Effect.COSMETIC_LIMIT
			and (
				game.contact_rhythm.snapshot()["sources"]
				<= ContactRhythm.MAX_PENDING * Effect.COSMETIC_LIMIT
			)
		)
	)
	game.contact_rhythm.tick(game, 0.12)
	check(
		"the dense burst drains without an audio backlog",
		game.contact_rhythm.snapshot()["pending"] == 0
	)
	game.queue_free()
	await _frames(3)
	Prefs.reduce_motion = old_motion
	Prefs.sound_enabled = old_sound


func _impact(game: Node) -> Effect:
	var impact := Effect.spawn_impact(game, game.player.position, null)
	impact.params["camera_position"] = game.player.position
	game.contact_rhythm.confirm(game, impact, HitTier.LIGHT, 0, "wolf")
	return impact


func _check_stop_upgrade() -> void:
	var stop := GameTempo.ContactStop.new()
	stop.trigger(HitTier.NORMAL_STOP)
	stop.consume(0.01)
	stop.trigger(HitTier.HEAVY_ATTACKER_STOP, HitTier.HEAVY_STOP_LIMIT)
	check(
		"later heavy contact upgrades the original pause rather than restarting it",
		is_equal_approx(stop.remaining, 0.08)
	)
	stop.trigger(HitTier.KILL_STOP, HitTier.KILL_STOP_LIMIT)
	check(
		"a kill later in the same sweep retains only the strongest pause",
		is_equal_approx(stop.remaining, 0.11)
	)
	for index in 20:
		stop.trigger(HitTier.KILL_STOP, HitTier.KILL_STOP_LIMIT)
	check("repeated contacts cannot stack the pause", is_equal_approx(stop.remaining, 0.11))
	stop.consume(0.12)
	stop.trigger(HitTier.KILL_STOP, HitTier.KILL_STOP_LIMIT)
	check("finished stop cannot restart during recovery", stop.remaining == 0.0)


func _check_camera(game: Node) -> void:
	game._update_impact_camera(1.0)
	game.camera.force_update_scroll()
	game.world_renderer.refresh()
	var native_before: Vector3 = game.world_renderer.camera.position
	game.combat_feedback(game.player.position + Vector2(40, 0), 1.0)
	game.camera.force_update_scroll()
	game.world_renderer.refresh()
	var native_shift := native_before.distance_to(game.world_renderer.camera.position)
	check(
		"the restrained impulse reaches the actual3D camera",
		native_shift > 0.001 and native_shift < 0.1
	)
	var initial: Vector2 = game.camera.offset
	game.combat_feedback(game.player.position + Vector2(0, 40), 0.1)
	check(
		"a weaker simultaneous hit cannot rotate or amplify the stronger impulse",
		game.camera.offset == initial and initial.length() > 0.65 and initial.length() <= 1.5
	)
	game._update_impact_camera(0.006)
	game._update_impact_camera(0.075)
	check(
		"camera gives only a tiny reverse rebound",
		game.camera.offset.dot(initial) < 0.0 and game.camera.offset.length() < 0.4
	)
	game._update_impact_camera(0.2)
	check("small camera rebound fully settles", game.camera.offset == Vector2.ZERO)
	Prefs.reduce_motion = true
	game.combat_feedback(game.player.position, 1.0, true)
	check("reduced motion suppresses the new shake", game.camera.offset == Vector2.ZERO)
	Prefs.reduce_motion = false


func _check_audio_accents() -> void:
	for voice: AudioStreamPlayer in SoundFx._players:
		voice.stop()
	SoundFx._last.clear()
	SoundFx._last_hit_ms = Time.get_ticks_msec()
	SoundFx._last_hit_tier = HitTier.HEAVY
	SoundFx._last_contact_tap_ms = -100000

	var serial := SoundFx.played_serial
	SoundFx.play_hit(HitTier.LIGHT, 0, "wolf")
	check(
		"a follow-up inside70ms plays one recorded contact accent",
		SoundFx.played_serial == serial + 1 and SoundFx.last_played["name"] == "hit_flesh"
	)
	var voice: AudioStreamPlayer = SoundFx._players[SoundFx.last_played["voice"]]
	check(
		"the follow-up uses a quieter layer within the existing voice budget",
		(
			(
				voice.volume_db
				== SoundFx.playback_volume_db("hit_flesh") + SoundFx.CONTACT_BEAT_GAIN_DB
			)
			and SoundFx._players.size() == 8
		)
	)
	serial = SoundFx.played_serial
	SoundFx.play_hit(HitTier.LIGHT, 0, "wolf")
	check("same-frame follow-ups cannot burst the audio pool", SoundFx.played_serial == serial)
	SoundFx._last_hit_ms = Time.get_ticks_msec() - 1000
	SoundFx._last_contact_tap_ms = -100000
	SoundFx.play_hit(HitTier.LIGHT, 0, "wolf", true)
	check(
		"a queued accent keeps its role after a slow frame",
		SoundFx.played_serial == serial + 1 and SoundFx.last_played["name"] == "hit_flesh"
	)
	serial = SoundFx.played_serial
	Prefs.sound_enabled = false
	SoundFx._last_contact_tap_ms = -100000
	SoundFx.play_hit(HitTier.LIGHT, 0, "wolf")
	check("muted follow-ups stay silent", SoundFx.played_serial == serial)
	Prefs.sound_enabled = true
	SoundFx._last.clear()
	SoundFx._last_hit_ms = -100000
	SoundFx.play_hit(HitTier.LIGHT, 0, "wolf")
	var first: AudioStreamPlayer = SoundFx._players[SoundFx.last_played["voice"]]
	SoundFx.play_hit(HitTier.HEAVY, 0, "skeleton")
	check("a stronger follow-up does not cut the previous contact tail", first.playing)
	for player: AudioStreamPlayer in SoundFx._players:
		player.stop()
	SoundFx._last.clear()
	SoundFx._last_hit_ms = -100000
	SoundFx._last_contact_tap_ms = -100000


func _check_pcm_mix() -> void:
	var peak := 0.0
	for tier in [HitTier.LIGHT, HitTier.HEAVY, HitTier.KILL]:
		for species: String in ["wolf", "skeleton", "golem"]:
			for variant in 3:
				for pitch in [0.96, 1.04]:
					var mix := PackedFloat64Array()
					mix.resize(int(SoundFx.RATE * 0.55))
					var names := SoundFx.hit_names(tier, variant, 1)
					names.append(SoundFx.material_hit_name(species))
					for name: String in names:
						_mix_into(mix, name, variant, 0.0, 0.0, pitch)
						_mix_into(
							mix, name, variant, 0.08, SoundFx.CONTINUOUS_CONTACT_GAIN_DB, pitch
						)
					_mix_into(
						mix,
						SoundFx.contact_beat_name(species),
						variant,
						0.04,
						SoundFx.CONTACT_BEAT_GAIN_DB,
						1.025
					)
					_mix_into(
						mix,
						SoundFx.contact_beat_name(species),
						variant,
						0.12,
						SoundFx.CONTACT_BEAT_GAIN_DB,
						1.05
					)
					for sample in mix:
						peak = maxf(peak, absf(sample))
					mix.fill(0.0)
					for name: String in names:
						_mix_into(mix, name, variant, 0.0, 0.0, pitch)
					for index in 3:
						_mix_into(
							mix,
							SoundFx.contact_beat_name(species),
							variant,
							(index + 1) * 0.04,
							SoundFx.CONTACT_BEAT_GAIN_DB,
							1.0 + 0.025 * index
						)
					for sample in mix:
						peak = maxf(peak, absf(sample))
					mix.fill(0.0)
					for index in 3:
						var stronger: int = [HitTier.LIGHT, HitTier.HEAVY, HitTier.KILL][index]
						var at: float = [0.0, 0.04, 0.12][index]
						var gain: float = [
							0.0,
							SoundFx.STRONGER_CONTACT_GAIN_DB,
							SoundFx.CONTINUOUS_CONTACT_GAIN_DB
						][index]
						var upgrade_names := SoundFx.hit_names(stronger, variant, 1)
						upgrade_names.append(SoundFx.material_hit_name(species))
						for name: String in upgrade_names:
							_mix_into(mix, name, variant, at, gain, pitch)
					_mix_into(
						mix,
						SoundFx.contact_beat_name(species),
						variant,
						0.08,
						SoundFx.CONTACT_BEAT_GAIN_DB,
						1.025
					)
					for sample in mix:
						peak = maxf(peak, absf(sample))
	check(
		"four-beat contact PCM keeps headroom across materials, takes and pitch endpoints",
		peak > 0.1 and peak < 0.95
	)
	print(
		"ART_AUDIT contact_rhythm_audio ",
		JSON.stringify({"peak": peak, "voices": SoundFx._players.size(), "device_listening": false})
	)


func _mix_into(
	mix: PackedFloat64Array, name: String, variant: int, at: float, gain_db: float, pitch: float
) -> void:
	var stream: AudioStreamWAV = SoundFx._streams[name]
	if SoundFx._sample_banks.has(name):
		stream = SoundFx._sample_banks[name][variant]
	var data := stream.data
	var start := roundi(at * SoundFx.RATE)
	var frames := mini(mix.size() - start, floori(data.size() * 0.5 / pitch))
	var gain := db_to_linear(SoundFx.playback_volume_db(name) + gain_db)
	for frame in frames:
		mix[start + frame] += data.decode_s16(int(frame * pitch) * 2) / 32768.0 * gain
